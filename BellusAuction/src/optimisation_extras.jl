using JuMP, HiGHS, Combinatorics
# using COSMO
using ProgressBars

"""
Linear program (LP) for finding prices for given market at which supply is cleared.
Note that it may not be possible to allocate reserve quantities to buyers at these prices.
"""
function simple_price_lp(market::BellusPMA)
    # Extract relevant information from market
    bidval, w = market.bidvalues, market.bidweights
    s = market.supply  # (without null good)
    n, m = numsuppliers(market), numbids(market)

    # Set up model
    model = Model(HiGHS.Optimizer)
    set_attribute(model, "solver", "simplex")
    set_silent(model)
   
    @variable(model, u[b ∈ 1:m] ≥ 0)
    @variable(model, p[i ∈ 1:n])

    @constraint(model, [b ∈ 1:m, i ∈ 1:n], u[b]+p[i] ≥ bidval[i,b])

    @objective(model, Min, sum(w .* u) + sum(s .* p))

    return model, p
end


"""
Compute an allocation that prioritises allocations for suppliers in descending order.

Assumes that every point in the feasible region of the model is a candidate allocation.
"""
function break_ties_for_suppliers(model, a, ax)
    suppliers = ax[1][1:end]
    for s in suppliers
        # Find allocation that maximises allocation to supplier s
        @objective(model, Max, sum(a[[s],:]))
        optimize!(model)
        A = value.(a[[s],:])
        println("Supplier $(s) gets $(A)")
        # Add constraints to fix this allocation in subsequent iterations
        @constraint(model, [key ∈ eachindex(A)], a[key] == A[key])
        optimize!(model)
    end

    allocation = a2matrix(Int, a, ax)
    return allocation
end


"""
Compute an allocation that prioritises allocations to buyers in descending order.

Assumes that every point in the feasible region of the model is a candidate allocation.
"""
function break_ties_for_buyers(model, a, ax)
    buyers = collect(ax[2])
    for b in buyers
        # Find allocation that maximises allocation to buyer b
        @objective(model, Max, sum(a[:,[b]]))
        optimize!(model)
        A = value.(a[:,[b]])
        # Add constraints to fix this allocation in subsequent iterations
        @constraint(model, [key ∈ eachindex(A)], a[key] == A[key])
        optimize!(model)
    end

    allocation = a2matrix(Int, a, ax)
    return allocation
end


"""
Formulate problem for finding a fractional allocation with fair rationing that clears supply & reserve quantities.
This modifies the feasibility LP by replacing the objective function.
"""
function fractional_fair_program(market::BellusPMA, prices::Vector{Float64}, buyergains; override_reserves=false)
    k = market.numbuyerbids
    w = market.bidweights
    bidval = market.bidvalues
    p = Origin(0)([0.0; prices])

    # Set up model
    model, a = feasibility_lp(market, prices; override_reserves=override_reserves)
    set_optimizer(model, HiGHS.Optimizer)  # ensure that solver is set to HiGHS
    # set_optimizer(model, COSMO.Optimizer)  # change solver to COSMO
    # set_attribute(model, "max_iter", 10^5)
    # set_attribute(model, "eps_abs", 1e-10)

    # Set constraint to ensure that buyer gains are maximised
    @constraint(model, sum( (bidval[i,b] - p[i]) * a[i,b] for (i,b) ∈ eachindex(a) if b ≤ k ) ≥ buyergains-EPS_TOL)

    # Set objective to minimise the squares of allocations to buyer bids
    nw = market.bidweights ./ gcd(market.bidweights)  # normalise the bid weights
    @objective(model, Min, sum( a[i,b]^2 / nw[b] for (i,b) in eachindex(a) if i ≠ 0 && b ≤ k ))

    return model, a
end


"""
Given a fractional fair allocation (as a matrix), the bid weights and the number of buyer bids, return an
integral equilibrium allocation delta obtained by rounding each entry up or down. Rounding
in this way is performed to minimise the original sum-of-squares objective that the
fractional allocation minimises.
"""
function optimal_rounding_lp(allocation, bidweights, numbuyerbids, reserves)
    w = bidweights
    k = numbuyerbids
    n, m = size(allocation); n -= 1
    a = allocation
    r = reserves
    fa = floor.(a)
    ca = ceil.(a)
    rowsum = round.(sum(a .- fa, dims=2))
    colsum = round.(sum(a .- fa, dims=1))
    Δreserve = r .- sum(fa[1:n,1:k], dims=2)
    ub = ca .- fa  # upper bounds for variables

    # Set up model
    model = Model(HiGHS.Optimizer)
    set_attribute(model, "solver", "simplex")
    set_silent(model)

    @variable(model, x[i ∈ 0:n, b ∈ 1:m], container = SparseAxisArray)

    @constraint(model, rowsums[i ∈ 0:n], sum(x[i,:]) == rowsum[i,1] )  # preserve row sums
    @constraint(model, colsums[b ∈ 1:m], sum(x[:,b]) == colsum[0,b] )  # preserve column sums
    @constraint(model, reserves[i ∈ 1:n], sum(x[i,1:k]) ≥ Δreserve[i])  # uphold reserve quantity constraints
    @constraint(model, bounds[i ∈ 0:n, b ∈ 1:m], 0 ≤ x[i,b] ≤ ub[i,b])  # upper and lower bounds on variables

    @objective(model, Min, sum( (ca[i,b]^2 - fa[i,b]^2)/w[b] * x[i,b] for i ∈ 1:n, b ∈ 1:k ))

    return model, x
end


"""
A fast method for computing a fair equilibrium allocation at given `prices`. If `overrides_reserves`
is not set to `false` (default), the allocation will clear reserve quantities, or the function returns
`nothing` if no such allocation exists. If `overrides_reserves` is set to `true`, an allocation that may
not clear reserve quantities is returned.
"""
function find_fair_allocation(market::BellusPMA, prices; override_reserves=false)
    # Solve basic feasibility model to get maximal buyer gains, or return nothing if market not feasible
    feasibility_model, _ = feasibility_lp(market, prices)
    optimize!(feasibility_model)
    # If feasible allocation not found, return nothing
    termination_status(feasibility_model) != OPTIMAL && return nothing
    buyergains = objective_value(feasibility_model)

    # Compute fractional allocation with fair rationing
    fractional_model, a = fractional_fair_program(
        market,
        prices,
        buyergains;
        override_reserves=override_reserves
    );
    optimize!(fractional_model)
    fractional_allocation = a2matrix(a, axes(market.bidvalues))
    
    # Optimally round each entry in fractional allocation up or down
    rounding_model, x = optimal_rounding_lp(
        fractional_allocation,
        market.bidweights,
        market.numbuyerbids,
        market.reservequantities
    )
    optimize!(rounding_model)
    delta = a2matrix(Int, x, axes(market.bidvalues))

    return floor.(Int, fractional_allocation) .+ delta
end


# function find_fairest_allocation(market::BellusPMA, prices; override_reserves=false)
#     # Prep
#     n,  = numgoods(market), numbids(market)
#     k = market.numbuyerbids
#     w = market.bidweights
#     bidval = market.bidvalues
#     p = Origin(0)([0.0; prices])

#     # Step 1: determine maximal buyer gains
#     model, a = feasibility_lp(market, prices)
#     set_optimizer(model, COSMO.Optimizer)  # change solver to COSMO
#     optimize!(model)
#     termination_status(model) != OPTIMAL && return nothing
#     buyergains = objective_value(model)

#     # Step 2: Fix buyer gains and minimise Σ(total demand of non-reject goods of bid)^2 over all buyer bids
#     # Add variables to capture total quantities of non-reject goods received by each buyer bid
#     @variable(model, x[b ∈ 1:k])
#     @constraint(model, [b ∈ 1:k], x[b] ==sum(a[i,j] for (i,j) in eachindex(a) if i > 0 && j == b))
#     # Add constraint to fix buyer gains
#     @constraint(model, sum( (bidval[i,b] - p[i]) * a[i,b] for (i,b) ∈ eachindex(a) if b ≤ k ) ≥ buyergains)
#     # Add objective
#     @objective(model, Min, sum(x[b]^2 for b in 1:k))  # sum of squares of demand expressions
#     optimize!(model)
#     # Extract values of demand variables x
#     demand = round.(value.(x))

#     # Step 3: Fix total demand of non-reject goods for each buyer bid and maximise sum of squares of allocation matrix entries
#     @constraint(model, [b ∈ 1:k], x[b] == demand[b])
#     @objective(model, Max, sum( a[i,b]^2 for (i,b) in eachindex(a) if i > 0 && b ≤ k))
#     optimize!(model)
#     fractional_allocation = a2matrix(a, axes(market.bidvalues))

#     # Step 4: Round consistently to get integer allocation
#     rounding_model, x = optimal_rounding_lp(
#         fractional_allocation,
#         market.bidweights,
#         market.numbuyerbids,
#         market.reservequantities
#     )
#     optimize!(rounding_model)
#     delta = a2matrix(Int, x, axes(market.bidvalues))

#     return floor.(Int, fractional_allocation) .+ delta
# end
using JuMP, HiGHS, Combinatorics, COSMO
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
Formulate problem for finding relaxed balanced allocation that clears supply & reserve quantities.
This modifies the feasibility LP by replacing the objective function.
"""
function relaxed_balancing_program(market::BellusPMA, prices::Vector{Float64}; override_reserves=false)
    k = market.numbuyerbids
    w = market.bidweights
    model, a = feasibility_lp(market, prices; override_reserves=override_reserves)
    set_optimizer(model, COSMO.Optimizer)  # change solver to COSMO
    set_attribute(model, "eps_abs", 1e-10)
    # Set objective to maximise the square roots of allocations to buyer bids
    @objective(model, Min, sum( a[i,b]^2 / w[b] for (i,b) in eachindex(a) if i ≠ 0 && b ∈ 1:k ))
    return model, a
end


"""
Given a relaxed balanced allocation (as a matrix) and the number of buyer bids, return an
integral equilibrium allocation delta obtained by rounding each entry up or down. Rounding
in this way is performed to maximise the original sum-of-squares objective that the
fractional allocation maximises.
"""
function optimal_rounding_lp(allocation, numbuyerbids, reserves)
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

    @objective(model, Min, sum( (ca[i,b]^2 - fa[i,b]^2) * x[i,b] for i ∈ 0:n, b ∈ 1:m ))

    return model, x
end


"""
A fast method for computing a balanced equilibrium allocation at given `prices`. If `overrides_reserves`
is not set to `false` (default), the allocation will clear reserve quantities, or the function returns
`nothing` if no such allocation exists. If `overrides_reserves` is set to `true`, an allocation that may
not clear reserve quantities is returned.
"""
function faster_find_balanced_allocation(market::BellusPMA, prices; override_reserves=false)
    relaxed_model, a = relaxed_balancing_program(market, prices; override_reserves=override_reserves)
    optimize!(relaxed_model)

    # If feasible allocation not found, return nothing
    termination_status(relaxed_model) != OPTIMAL && return nothing

    # Create allocation matrix
    fractional_allocation = a2matrix(a, axes(market.bidvalues))
    
    # Optimally round each entry in fractional allocation up or down
    rounding_model, x = optimal_rounding_lp(fractional_allocation, market.numbuyerbids, market.reservequantities)
    optimize!(rounding_model)
    delta = a2matrix(Int, x, axes(market.bidvalues))

    return floor.(Int, fractional_allocation) .+ delta
end
using JuMP, HiGHS, Combinatorics
using ProgressBars

### Finding market prices

"""
Linear program (LP) for finding elementwise minimal or maximal equilibrium prices for given market.
Objective must be `:min` or `:max`.
"""
function price_lp(market::BellusPMA, objective::Symbol)
    n, m = numsuppliers(market), numbids(market)
    bidval = market.bidvalues
    w = market.bidweights
    s = market.supply

    # Set up model
    ## NB: LP is a combination of the well-known primal and dual LPs for solving the SS-PMA.
    model = Model(HiGHS.Optimizer)
    set_attribute(model, "solver", "simplex")
    set_silent(model)
    
    @variable(model, p[i ∈ 1:n] ≤ PRICE_BOUND)  # primal variables
    @variable(model, u[b ∈ 1:m] ≥ 0)  # primal variables
    @variable(model, a[i ∈ 1:n, b ∈ 1:m] ≥ 0)  # dual variables
    @variable(model, gains)

    # Primal constraints
    @constraint(model, [i ∈ 1:n, b ∈ 1:m], u[b]+p[i] ≥ bidval[i,b])

    # Dual constraints
    @constraint(model, [b ∈ 1:m], sum(a[:,b]) ≤ w[b])  #  envy-free
    @constraint(model, [i ∈ 1:n], sum(a[i,:]) == s[i])  #  market-clearing

    # Strong duality constraints (objectives)
    @constraint(model, gains == sum(w .* u) + sum(s .* p))
    @constraint(model, gains == sum(bidval[1:n,:] .* a))

    if objective == :min
        @objective(model, Min, sum(p))
    elseif objective == :max
        @objective(model, Max, sum(p))
    else
        error("Objective must be \":min\" or \":max\".")
    end
    return model, gains, p, a
end

"""
Compute equilibrium prices for given market. Objective must be `:mean` (default), `:min` or `:max`.
"""
function find_prices(market::BellusPMA; objective::Symbol=:mean)
    if objective ∈ [:min, :max]
        model, gains, p = price_lp(market, objective)
        optimize!(model)
        prices = round.(abs.(value.(p)), digits=DIGITS)
        gains = round.(abs.(value.(gains)), digits=DIGITS)
    elseif objective == :mean  # compute mean of min and max prices
        gains, min_p = find_prices(market; objective=:min)
        max_p = find_prices(market, objective=:max).prices
        prices = round.((min_p + max_p) / 2, digits=DIGITS)
    else
        error("Objective must be \":min\", \":max\", or \":mean\".")
    end
    return (gains=gains, prices=prices)
end


# Find feasible allocations (feasible means that allocations to buyers weakly exceed reserve quantities.)

"""
Compute the boolean demand indicator matrix χ, where χ[i,b] is 1 iff bid b demands good i at prices p.

NB: Bidvalues and price vector should contain entries for the 0th good.
"""
function demand_indicators(bidval::OffsetArray{Float64}, prices::OffsetVector{Float64})
    n, m = size(bidval)  # number of goods includes null good here
    utils = bidval .- prices  # utility matrix
    # Compute indirect utility at prices p for each bid
    iud = maximum(utils, dims=1)
    # Compute demand indicator matrix
    return isapprox.(utils, iud; atol=EPS_TOL)
end


"""
Construct 'feasibility' LP to determine whether the market at given prices admits a
feasible allocation. This is true iff the LP is feasible.

The objective is set to maximise buyer utilities, but the resulting allocation may
not ration fairly.

Optionally, ignore reserve quantity constraints by setting `override_reserves` to true.
"""
function feasibility_lp(market::BellusPMA, prices::Vector{Float64}; override_reserves=false)
    # Extract information from market
    bidval = market.bidvalues
    n, m, k = numsuppliers(market), numbids(market), market.numbuyerbids
    p = Origin(0)([0; prices])  # set price of 0th good to 0.
    χ = demand_indicators(bidval, p)  # demand matrix specifying goods that each bid demands at prices
    
    # Extract coefficients for LP
    w = market.bidweights
    # Define supply and reserve quantities with 0-th entry for null good
    s0 = sum(w) - sum(market.supply)  # compute supply of null good
    s = Origin(0)([s0; market.supply])
    q = Origin(0)([0; market.reservequantities])

    # Set up model
    model = Model(HiGHS.Optimizer)
    set_attribute(model, "solver", "simplex")
    set_silent(model)

    # Variable for each good-bid pair (i,b)
    @variable(model, a[i ∈ 0:n, b ∈ 1:m; χ[i,b]] ≥ 0)

    # Constraints
    @constraint(model, envyfree[b ∈ 1:m], sum(a[:,b]) == w[b])  #  envy-freeness
    @constraint(model, marketclearing[i ∈ 0:n], sum(a[i,:]) == s[i])  #  market-clearing
    !override_reserves && @constraint(model, reserves[i ∈ 0:n], sum(a[i,1:k]) ≥ q[i])  # reserve quantities

    # Determine an allocation that maximises aggregate buyer utilities
    @objective(model, Max, sum( (bidval[i,b] - p[i]) * a[i,b] for (i,b) ∈ eachindex(a) if b ≤ k ))

    return model, a
end


"""Return true if market admits a feasible allocation at given prices, and false otherwise."""
function isfeasible(market::BellusPMA, prices; override_reserves=false)
    model, _ = feasibility_lp(market, prices; override_reserves=override_reserves)
    optimize!(model)
    return termination_status(model) == OPTIMAL
end


"""
Convert the solutions stored in JuMP variables into an allocation matrix.
"""
function a2matrix(T, a, ax)
    allocation = a2matrix(a, ax)
    return T.(round.(allocation))
end


function a2matrix(a, ax)
    allocation = zeros(ax)
    for key in eachindex(a)
        allocation[key...] = max.(0, value(a[key]))
    end
    return allocation
end

"""
Compute an equilibrium allocation at given `prices`. If `overrides_reserves` is not set to `false` (default),
the allocation will clear reserve quantities, or the function returns `nothing` if no such allocation exists.
If `overrides_reserves` is set to `true`, an allocation that may not clear reserve quantities is returned.
    
Important: the allocation may not be balanced.
"""
function find_allocation(market::BellusPMA, prices; override_reserves=false)
    model, a = feasibility_lp(market, prices; override_reserves=override_reserves)
    optimize!(model)

    # If feasible allocation not found, return nothing
    termination_status(model) != OPTIMAL && return nothing

    # Create allocation matrix
    allocation = a2matrix(Int, a, axes(market.bidvalues))
    
    return allocation
end


# """
# Construct integer program for finding a balanced allocation that clears supply & reserve quantities.
# This modifies the feasibility LP by forcing the variables to be integral and replacing the objective function.
# """
# function balanced_allocation_program(market::BellusPMA, prices::Vector{Float64}; override_reserves=false)
#     k = market.numbuyerbids
#     w = market.bidweights
#     model, a = feasibility_lp(market, prices; override_reserves=override_reserves)
#     # Start modifying the model
#     set_optimizer(model, SCIP.Optimizer)  # change solver to SCIP
#     set_integer.(a)  # force all variables to be integral
#     # Set objective to maximise the square roots of allocations to buyer bids, weighted by bid weights
#     @variable(model, x)  # introduce variable for new objective
#     @constraint(model, x == sum( (a[i,b])^2 / w[b] for (i,b) in eachindex(a) if i ≠ 0 && b ∈ 1:k) )
#     @objective(model, Min, x)
#     return model, a
# end


# """
# Compute a balanced equilibrium allocation at given `prices`. If `overrides_reserves` is not set to `false`
# (default), the allocation will clear reserve quantities, or the function returns `nothing` if no such
# allocation exists. If `overrides_reserves` is set to `true`, an allocation that may not clear reserve
# quantities is returned.
# """
# function find_balanced_allocation(market::BellusPMA, prices; override_reserves=false)
#     model, a = balanced_allocation_program(market, prices; override_reserves=override_reserves)
#     optimize!(model)

#     # If feasible allocation not found, return nothing
#     termination_status(model) != OPTIMAL && return nothing

#     # Create allocation matrix
#     allocation = a2matrix(Int, a, axes(market.bidvalues))
    
#     return allocation
# end


"""
Solve the given market, optionally overriding reserves.

Returns nothing if no feasible allocation exists. Otherwise gains, mean equilibrium prices,
and a balanced allocation.
"""
function solve(market; override_reserves=false)
    gains, prices = find_prices(market, objective=:mean)
    allocation = find_fair_allocation(market, prices; override_reserves=override_reserves)
    isnothing(allocation) && return nothing
    return (gains=gains, prices=prices, allocation=allocation)
end


"""
Perform exhaustive search to find a Bellus-PMA equilibrium. The best equilibrium is chosen according to
total order function `lt`.

The fn `lt` (short for 'less than') must be a bivariate function lt(x,y) that returns `true` if x < y and
`false` otherwise.

Returns the best market instance and (gains, prices, allocation).
"""
function exhaustivesearch(market, lt; display_progress=false)
    n = numsuppliers(market)
    # First we search for the optimal supplier subset leading to an equilibrium, according to total order `lt`.
    best = (gains=-1, suppliers=Int[])
    if display_progress
        possibilities = ProgressBar(collect(powerset(1:n)))  # all possible subsets of suppliers
    else
        possibilities = powerset(1:n)
    end
    for suppliers ∈ possibilities
        restricted_market = market[suppliers]
        gains, prices = find_prices(restricted_market, objective= :min)
        if isfeasible(restricted_market, prices)
            result = (gains=gains, suppliers=suppliers)
            lt(best, result) && (best = result)
        end
    end
    # Now we solve the auction with the optimal subset of suppliers,
    # finding mean market-clearing prices and a balanced equilibrium
    best_market = market[best.suppliers]
    best_outcome = solve(best_market)
    return best_market, best_outcome
end


"""
Return true iff result x has lower gains than y, or if the gains are identical and x has fewer suppliers than y.
"""
lt_gains(x,y) = (x.gains < y.gains) || (x.gains == y.gains && length(x.suppliers) < length(y.suppliers))


"""
Return true iff x has fewer suppliers than y, or if they have the same number of suppliers but x has lower gains than y. 
"""
lt_numsuppliers(x,y) = length(x.suppliers) < length(y.suppliers) || (length(x.suppliers) == length(y.suppliers) && x.gains < y.gains)


"""
Implement exhaustive search with two objectives: `gains`, and `numsuppliers`.

Returns the 'best' market as well as (gains, prices, allocation)
"""
function exhaustivesearch(market, objective::Symbol; display_progress=false)
    objective == :gains && return exhaustivesearch(market, lt_gains; display_progress=display_progress)
    objective == :numsuppliers && return exhaustivesearch(market, lt_numsuppliers; display_progress=display_progress)
    error("Objective $(objective) not yet implemented.")
end


"""
Helper function for the heuristic method proposed by Bellus implemented below. Returns the fraction of
reserve quantity sold for each supplier. If reserve quantity is 0 for some supplier, fraction is set to 1
"""
function satisfraction(market)
    k = market.numbuyerbids
    r = market.reservequantities
    outcome = solve(market; override_reserves=true)
    sold = vec(sum(outcome.allocation[1:end,1:k], dims=2))
    fraction = [ r[i] == 0 ? 1. : sold[i] / r[i] for i in supplierids(market) ]
    return fraction
end


"""
Implement the heuristic proposed by Bellus. Greedily remove a supplier with the least fraction of
reserve quantity allocated, until all suppliers sell at least their reserve quantity.

Returns the final market as well as (gains, prices, allocation). The allocation is balanced.
"""
function heuristic(market)
    suppliers = supplierids(market)
    restricted_market = market
    fractions = satisfraction(restricted_market)
    while any(fractions .< 1)
        # Remove a least-satisfied supplier from market
        s = argmin(fractions)
        @info "Removing supplier $(restricted_market.suppliernames[s])."
        suppliers = setdiff(supplierids(restricted_market), s)
        restricted_market = restricted_market[suppliers]
        @info "Remaining suppliers: $(join(restricted_market.suppliernames, ", "))"
        fractions = satisfraction(restricted_market)
    end
    return restricted_market, solve(restricted_market)
end
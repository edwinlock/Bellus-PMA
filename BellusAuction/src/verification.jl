using OffsetArrays: Origin

function is_envyfree(market, outcome)
    a = outcome.allocation
    w = market.bidweights
    # Check that allocations to each bid (incl. reject good) sum up to its bid weight
    any(sum(a, dims=1) .!= w') && return false
    # Check that allocations are 0 for all goods not demanded
    p = Origin(0)([0.0; outcome.prices])
    χ = BellusAuction.demand_indicators(market.bidvalues, p)
    return all( χ[k] || isapprox(a[k],0; atol=EPS_TOL) for k in eachindex(χ) )
end

"""
Check that quantities allocated sum up to supply, and (optionally) are weakly greater
than reserve quantities.
"""
function clears_market(market, outcome; override_reserves=false)
    a = sum(outcome.allocation[1:end,:], dims=2)  # aggregate allocation per good
    any(a .> market.supply) && return false
    if !override_reserves
        any(a .< market.reservequantities) && return false
    end
    return true
end

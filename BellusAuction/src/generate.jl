using Random, Distributions

"""
Generate `m` bids. Bid value entries are drawn from `bidvals[i]` distribution
for each good i in eachindex(bidvals). Bid weights/quantities are drawn from
distribution `weights`.
"""
function generate_buyerbids(vals, weights, m)
    n = length(vals)
    bidvalues = Origin(0,1)(zeros(n+1, m))
    for b in 1:m
        bidvalues[1:end,b] .= rand(vals[1], n)
    end
    weights = rand(weights, m)
    buyernames = ["Buyer$(i)" for i in 1:m]
    buyerbids = Dict("Buyer$(i)" => [i] for i in 1:m)
    return (bidvalues=bidvalues, bidweights=weights, buyerbids=buyerbids, buyernames=buyernames)
end


"""Generate `m` bids with values drawn from `bidvals` for `n` goods."""
generate_buyerbids(values, weights, n, m) = generate_buyerbids(ntuple(x->values, n), weights, m)


"""
Generate `n` suppliers with supply quantities drawn from `supplyvals', and reserve quantities
computed as a percentage of supply drawn from reserve_pcts.
"""
function generate_suppliers(supplyvals, reserve_pcts, n)
    supply = rand(supplyvals, n)
    bidvalues = Origin(0,1)(zeros(n+1,n))
    weights = copy(supply)
    reserves = rand(reserve_pcts, n) .* supply
    suppliernames = ["$(Char(64+i))Corp" for i in 1:n]
    return (bidvalues=bidvalues, bidweights=weights, supply=supply, reserves=reserves, suppliernames=suppliernames)
end


"""Generate `n` suppliers with supply quantities drawn from `supplyvals'."""
generate_suppliers(supplyvals, n) = generate_suppliers(supplyvals, 0:0, n)


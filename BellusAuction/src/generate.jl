using Random, Distributions, DataFrames, CSV

"""
Generate `m` bids. Bid value entries are drawn from `bidvals[i]` distribution
for each good i in eachindex(bidvals). Bid weights/quantities are drawn from
distribution `weights`.
"""
function generate_buyerdata(vals, weights, m)
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
generate_buyerdata(values, weights, n, m) = generate_buyerdata(ntuple(x->values, n), weights, m)


"""
Generate `n` suppliers with supply quantities drawn from `supplyvals', and reserve quantities
computed as a percentage of supply drawn from reserve_pcts.
"""
function generate_supplierdata(supplyvals, reserve_prices, reserve_pcts, n)
    supply = rand(supplyvals, n)
    bidvalues = Origin(0,1)(zeros(n+1,n))
    for i ∈ 1:n; bidvalues[i,i] = rand(reserve_prices); end
    weights = copy(supply)
    reserves = Int.(round.(rand(reserve_pcts, n) .* supply))
    suppliernames = ["Supplier$(Char(64+i))" for i in 1:n]
    return (bidvalues=bidvalues, bidweights=weights, supply=supply, reserves=reserves, suppliernames=suppliernames)
end


"""Generate `n` suppliers with supply quantities drawn from `supplyvals'."""
generate_supplierdata(supplyvals, n) = generate_supplierdata(supplyvals, 0:0, 0:0, n)


function buyerdata2file(buyerdata, output)
    bidvals = buyerdata.bidvalues[1:end,:]
    weights = buyerdata.bidweights
    names = buyerdata.buyernames
    n = size(bidvals)[1]
    matrix = [weights'; bidvals]'
    df = DataFrame([names matrix], [:buyer, :quantity] ∪ Symbol.(1:n))
    CSV.write(output, df)
    # return df
end

"""Currently only supports one-step supply curves."""
function supplierdata2file(supplierdata, output)
    n = length(supplierdata.supply)
    prices = [ supplierdata.bidvalues[i,i] for i ∈ 1:n]
    supply = supplierdata.supply
    reserves = supplierdata.reserves
    supplier_col = vcat( [[n,n] for n in supplierdata.suppliernames]... )
    price_col = vcat( [[p,p] for p in prices]... )
    quantity_col = vcat( [[reserves[i], supply[i]] for i in eachindex(supply)]... )
    df = DataFrame(
        :supplier => supplier_col,
        :price => price_col,
        :quantity => quantity_col
    )
    # return df
    CSV.write(output, df)
end


# Command used to generate 'large' examples
# buyerdata_large1 = generate_buyerdata(0.7:0.01:0.9, 1000:500:7000, 10, 100)  # low demand
# buyerdata_large2 = generate_buyerdata(0.7:0.01:0.9, 0:1000:20000, 10, 100)  # high demand

## GENERATE GIANT FILES
# buyerdata_giant = BellusAuction.generate_buyerdata(0.7:0.01:0.9, 1000:500:7000, 15, 100)
# supplierdata_giant = BellusAuction.generate_supplierdata(1000:1000:10000, 0.0:0.01:1.0, 0.:0.1:1.0, 15)
# BellusAuction.buyerdata2file(buyerdata_giant, "buyers_giant.csv")
# BellusAuction.supplierdata2file(supplierdata_giant, "suppliers_giant.csv")
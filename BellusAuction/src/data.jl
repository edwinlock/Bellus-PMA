using CSV, DataFrames, OffsetArrays


### Functions to input data from CSV files

"""
Input: CSV specifying buyer data
Returns:
- bidvalue matrix with bids as columns,
- bid weight vector (Int),
- vector of corresponding buyer names
- a mapping from buyer names to list of indices pointing to their bid columns in the matrix
"""
function process_buyer_CSV(file)
    df = CSV.read(file, DataFrame)
    
    isvalid_buyer_df(df)  # run checks to make sure the input file is valid

    # Create list of buyer names and generate dictionary map
    buyernames = unique(df.buyer)
    buyerbids = Dict{String, Vector{Int}}()  # initialise dict
    for (bid_id, row) in enumerate(eachrow(df))
        idlist = get!(buyerbids, row.buyer, [])
        append!(idlist, bid_id)
    end

    # Extract bid values and weights.
    # NB: we will want to transpose rows and columns
    numrows, numcols = size(df)
    bidvals = Origin(0,1)(zeros(numcols-1, numrows)) 
    weights = Vector{Int}(df[!,:quantity])
    bidvals[1:end,:] .= Matrix{Float64}(df[:, 3:numcols])'
    return (bidvalues=bidvals, bidweights=weights, buyerbids=buyerbids, buyernames=buyernames)
end

"""Check that the buyer input is valid, and give descriptive error message otherwise."""
function isvalid_buyer_df(df)
    @assert hasproperty(df, :buyer) "Buyer CSV file must contain a buyer column"
    @assert hasproperty(df, :quantity) "Buyer CSV file must contain a quantity column"
    @assert typeof(df[!,:quantity]) == Vector{Int} "Bid quantities in buyer CSV file must be positive integers."
    @assert all(df[!, :quantity] .> 0) "Bid quantities in buyer CSV file must be positive integers."
    @assert all(all.(eachcol(0 .<= df[!,3:end] .<= 1))) "Bid values in buyer CSV file must be decimal numbers in interval [0,1]."
end

function supplydata2bids(prices, quantities, numsuppliers, good)
    @assert length(prices) == length(quantities) ≥ 0
    m = length(prices)
    n = numsuppliers+1  # num of goods, incl. null good
    bidval = Origin(0,1)(zeros(n,m))
    weights = copy(quantities)
    weights[2:end] = quantities[2:end] .- quantities[1:end-1]
    bidval[good, 1:m] .= prices
    return bidval, weights
end


"""
Input: CSV specifying supplier data
Returns: bidlist, supply, reserve quantities, and a mapping from supplier names to good numbers
"""
function process_supplier_CSV(file)
    df = CSV.read(file, DataFrame)
    isvalid_supplier_df(df)
    n = length(unique(df.supplier))  # count number of suppliers

    # Initialise data structures for output
    bidvals = Matrix{Float64}(undef, n+1, 0)
    weights = Vector{Int}(undef,0)
    supply = zeros(Int, n)  # default supply is 0
    reserves = zeros(Int, n)  # default reserve quantity is 0
    suppliernames = Vector{String}(undef, n)

    # Compute supply, reserve quantity, and reserve bids for,
    # and assign a good number to, every supplier
    for (good, sdf) in enumerate(groupby(df, :supplier))
        # Extract name of company and map to good
        suppliernames[good] = first(sdf.supplier)
        # Extract reserve quantity
        @assert sdf[begin, :quantity] ≥ 0 "Reserve quantity must be non-negative."
        reserves[good] = sdf[begin, :quantity]
        # Compute supply and bidlist, and append to the global bid list
        prices, quantities = sdf[!, :price], sdf[!, :quantity]
        supply[good] = quantities[end]
        v, w = supplydata2bids(prices, quantities, n, good)
        bidvals = hcat(bidvals, v)  # concatenate supplier bid(s) with aggregate matrix
        weights = vcat(weights, w)
    end
    bidvalues = Origin(0,1)(bidvals)
    return (bidvalues=bidvalues, bidweights=weights, supply=supply, reserves=reserves, suppliernames=suppliernames)
end

isascending(v) = all(v[2:end] .>= v[1:end-1])

function isvalid_supplier_df(df)
    @assert hasproperty(df, :supplier) "Supplier CSV must contain a supplier column."
    @assert hasproperty(df, :price) "Supplier CSV must contain a price column."
    @assert hasproperty(df, :quantity) "Supplier CSV must contain a quantity column."
    @assert typeof(df[!,:quantity]) == Vector{Int} "Supply curve quantities in supplier CSV file must be non-negative integers."
    @assert all(df[!, :quantity] .>= 0) "Supply curve quantities in supplier CSV file must be non-negative integers."
    @assert all(0 .<= df[!,:price] .<= 1) "Supply curve prices in supplier CSV file must be decimal numbers in interval [0,1]."
    for sdf in groupby(df, :supplier)
        @assert isascending(sdf[!, :price]) "Supply curve prices for each supplier must be weakly increasing."
        @assert isascending(sdf[!, :quantity]) "Supply curve quantities for each supplier must be weakly increasing."
    end
end


"""Helper function to merge buyer and supplier (reserve) bids."""
function merge_bids(buyervalues, buyerweights, suppliervalues, supplierweights)
    bidvalues = Origin(0,1)(hcat(buyervalues, suppliervalues))
    weights = vcat(buyerweights, supplierweights)
    return bidvalues, weights
end


function data2auction(buyerdata, supplierdata)
    bidvals, weights = merge_bids(
        buyerdata.bidvalues, buyerdata.bidweights,
        supplierdata.bidvalues, supplierdata.bidweights
    )
    numbuyerbids = length(buyerdata.bidweights)
    return BellusPMA(
        bidvals, weights, numbuyerbids,
        buyerdata.buyerbids, buyerdata.buyernames,
        supplierdata.supply, supplierdata.reserves, supplierdata.suppliernames
        )
end


function files2auction(buyerfile, supplierfile)
    buyerdata = process_buyer_CSV(buyerfile)
    supplierdata = process_supplier_CSV(supplierfile)
    return data2auction(buyerdata, supplierdata)
end


### Functions for outputting results

"""Helper function to aggregate allocations to buyers, per buyer. Doesn't include the null good!"""
function allocation_by_buyer(market, outcome)
    # Preallocate output matrix
    output = zeros(Int, length(market.suppliernames), length(market.buyernames))
    # Assign values
    for b in buyerids(market)
        name = market.buyernames[b]
        output[:,b] .= sum(outcome.allocation[1:end, market.buyerbids[name]], dims=2)
    end
    return output
end


"""Summarise auction outputs in dataframes."""
function summaries(market, outcome)
    suppliers = supplierids(market)
    gains, prices, allocation = outcome
    buyers = buyerids(market)
    b_names, s_names = market.buyernames, market.suppliernames

    alloc = allocation_by_buyer(market, outcome)
    # quantities sold to buyers (per supplier, for all suppliers [n])
    sold = vec(sum(alloc, dims=2))  # for each supplier in [n], quantities sold to buyers
    bought = vec(sum(alloc, dims=1))  # for each buyer, total quantity obtained
    spending_matrix = round.(alloc .* prices, digits=DIGITS)
    spent = round.(sum(spending_matrix, dims=1), digits=DIGITS)  # for each buyer, total amount spent
    revenue = round.(prices .* sold, digits=DIGITS)

    prices_summary = DataFrame([[p] for p in prices], s_names)

    supplier_summary = DataFrame(
        "Supplier" => s_names,
        "Supply" => market.supply,
        "Reserves" => market.reservequantities,
        "Sold" => sold,
        "Price" => prices,
        "Revenue" => revenue,
    )
    
    buyer_summary = DataFrame("Buyer" => b_names)
    for s in suppliers  # add amounts bought 
        buyer_summary[!, "$(s_names[s])"] = ["$(alloc[s,b]) ($(spending_matrix[s,b]))" for b in buyers]
    end
    buyer_summary[!, Symbol("Total")] = ["$(bought[b]) ($(spent[b]))" for b in buyers]

    a = outcome.allocation[1:end, 1:market.numbuyerbids]'
    allocation_df = DataFrame(a, string.(s_names))
    namecol = Vector{String}(undef, market.numbuyerbids)
    # numcol = zeros(Int, length(namecol))
    for name in market.buyernames
        namecol[market.buyerbids[name]] .= name
        # numcol[market.buyerbids[name]] .= 1:length(market.buyerbids[name])
    end
    insertcols!(allocation_df, 1, "Buyer" => namecol)

    return prices_summary, buyer_summary, supplier_summary, allocation_df
end


function print_outcomes(market, outcome)
    price_df, buyer_df, supplier_df, allocation_df = summaries(market, outcome)

    println("\nBellus-PMA outcomes\n-------------------\n")
    
    s_names = market.suppliernames
    if isempty(s_names)
        println("No suppliers were included in the market.")
        return nothing
    end
    println("The following suppliers are included in the market: $(join(market.suppliernames, ", ", " and ")).\n")
    
    println("Per-unit prices.\n")
    show(price_df; eltypes=false, summary=false, truncate=0)
    println("\n")

    println("Quantities obtained from each supplier for each buyer. Prices paid are given in parentheses.\n")
    show(buyer_df; eltypes=false, summary=false, truncate=0)
    println("\n")

    println("Statistics for suppliers.\n")
    show(supplier_df; eltypes=false, summary=false, truncate=0)
    println("\n")

    println("Breakdown of allocations per bid.\n")
    show(allocation_df; eltypes=false, summary=false, truncate=0)
    println("\n")
    return nothing
end


function save_outcomes(market, outcome, output_dir)
    mkpath(output_dir)  # create path 'output_dir' if it doesn't exist yet    
    price_df, buyer_df, supplier_df, allocation_df = summaries(market, outcome)
    CSV.write(joinpath(output_dir, "prices.csv"), price_df)
    CSV.write(joinpath(output_dir, "buyer_summary.csv"), buyer_df)
    CSV.write(joinpath(output_dir, "supplier_summary.csv"), supplier_df)
    CSV.write(joinpath(output_dir, "allocation.csv"), allocation_df)
    return nothing
end
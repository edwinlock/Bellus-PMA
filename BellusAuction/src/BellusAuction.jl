module BellusAuction

const DIGITS = 4  # the precision for rounding prices
const PRICE_BOUND = 1  # upper bound on the values of prices
const EPS_TOL = 1e-6

using OffsetArrays
using OffsetArrays: Origin

"""
Data structure for storing a Bellus-PMA instance.

The bid values and weights are stored separately.

Important notes:
* The first k bids are buyer bids, and the remaining m-k bids are supplier reserve bids.
* bidvalues matrix is indexed at 0 for goods and 1 for bids.
"""
struct BellusPMA
    bidvalues :: OffsetArray{Float64, 2}
    bidweights :: Vector{Int}
    numbuyerbids :: Int # number of buyer bids (first bids)
    buyerbids::Dict{String, Vector{Int}}  # maps buyer names to bids (indices of bidvalues/bidweights)
    buyernames::Vector{String}  # maps buyer ids to names
    supply :: Vector{Int}
    reservequantities :: Vector{Int}
    suppliernames::Vector{String}  # maps supplier ids to names
end

numgoods(auction::BellusPMA) = length(auction.supply)+1
numsuppliers(auction::BellusPMA) = length(auction.supply)
numbids(auction::BellusPMA) = size(auction.bidweights)[1]
numbuyers(auction::BellusPMA) = length(auction.buyernames)
buyerids(auction::BellusPMA) = collect(1:length(auction.buyernames))
supplierids(auction::BellusPMA) = collect(1:numsuppliers(auction::BellusPMA))

function Base.getindex(M::BellusPMA, suppliers::Vector{Int})
    goods = [0] ∪ suppliers
    return BellusPMA(
        Origin(M.bidvalues)(M.bidvalues[goods,:]),
        M.bidweights,
        M.numbuyerbids,
        M.buyerbids,
        M.buyernames,
        M.supply[suppliers],
        M.reservequantities[suppliers],
        M.suppliernames[suppliers],
    )
end

include("data.jl")
include("optimisation.jl")
include("generate.jl")
include("main.jl")
include("optimisation_extras.jl")
include("verification.jl")

export find_prices, find_min_prices, find_allocation, find_balanced_allocation, isfeasible, find_exact_balanced_allocation, find_fair_allocation
export price_lp, relaxed_balancing_program, a2matrix, optimal_rounding_lp
export solve, exhaustivesearch, heuristic
export BellusPMA, AuctionOutcome, numgoods, numsuppliers, numbids, numbuyers, buyerids, supplierids
export generate_buyerbids, generate_suppliers, data2auction, files2auction
export print_outcomes, allocation_by_buyer, save_outcomes, summaries
export main
export isequilibrium

using PrecompileTools
@compile_workload begin
    redirect_stdout(devnull) do  # suppress output to terminal while precompiling
        dir = joinpath(@__DIR__, "")
        buyers = joinpath(dir, "buyers.csv")
        suppliers = joinpath(dir, "suppliers.csv")
        args1 = ["-b", buyers, "-s", suppliers, "-m", "exhaustive", "-o", "gains"]
        args2 = ["-b", buyers, "-s", suppliers, "-m", "exhaustive", "-o", "numsuppliers"]
        args3 = ["-b", buyers, "-s", suppliers, "-m", "heuristic"]
        args4 = ["-b", buyers, "-s", suppliers, "-m", "override-reserves"]
        BellusAuction.main(args1)
        BellusAuction.main(args2)
        BellusAuction.main(args3)
        BellusAuction.main(args4)
    end
end

end  # module end
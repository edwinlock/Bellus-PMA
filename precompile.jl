
import Pkg; Pkg.activate("BellusAuction", shared=true)
using BellusAuction

redirect_stdout(devnull) do  # suppress output to terminal while precompiling
    dir = joinpath(@__DIR__, "examples/")
    buyers = joinpath(dir, "buyers_small.csv")
    suppliers = joinpath(dir, "suppliers_small.csv")
    market = files2auction(buyers, suppliers)

    exhaustivesearch(market, :gains)
    exhaustivesearch(market, :numsuppliers)
    # args1 = ["-b", buyers, "-s", suppliers, "-m", "exhaustive", "-o", "gains"]
    # args2 = ["-b", buyers, "-s", suppliers, "-m", "exhaustive", "-o", "numsuppliers"]
    # BellusAuction.main(args1)
    # BellusAuction.main(args2)
    args3 = ["-b", buyers, "-s", suppliers, "-m", "heuristic"]
    args4 = ["-b", buyers, "-s", suppliers, "-m", "override-reserves"]
    BellusAuction.main(args3)  # run heuristic and precompile ArgParse etc. 
    BellusAuction.main(args4)  # run solve with override_reserves
end
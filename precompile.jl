
import Pkg; Pkg.activate("BellusAuction", shared=true)
using BellusAuction

redirect_stdout(devnull) do  # suppress output to terminal while precompiling
    dir = joinpath(@__DIR__, "examples/")
    buyers = joinpath(dir, "buyers1.csv")
    suppliers = joinpath(dir, "suppliers1.csv")
    args1 = ["-b", buyers, "-s", suppliers, "-m", "exhaustive", "-o", "gains"]
    args2 = ["-b", buyers, "-s", suppliers, "-m", "exhaustive", "-o", "numsuppliers"]
    args3 = ["-b", buyers, "-s", suppliers, "-m", "heuristic"]
    args4 = ["-b", buyers, "-s", suppliers, "-m", "override-reserves"]
    BellusAuction.main(args1)
    BellusAuction.main(args2)
    BellusAuction.main(args3)
    BellusAuction.main(args4)
    try
        BellusAuction.main([])
    catch
    end
end
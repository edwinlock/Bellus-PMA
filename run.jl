#!/usr/local/bin/julia

import Pkg
Pkg.activate("BellusAuction", shared=true)

print("Loading program...")
using BellusAuction
println("done.")

try
    BellusAuction.main(ARGS)
catch e
    println("Error: $(e.msg)")
end
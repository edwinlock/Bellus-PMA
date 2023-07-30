#!/usr/local/bin/julia

import Pkg
Pkg.activate("BellusAuction", shared=true)

print("Loading program...")
using BellusAuction
println("done.")

BellusAuction.main(ARGS)
#!/usr/local/bin/julia

import Pkg
Pkg.activate("BellusAuction", shared=true)
Pkg.develop(path="./BellusAuction")
Pkg.add("PackageCompiler")

import PackageCompiler
PackageCompiler.create_sysimage(
    ["BellusAuction"];
    sysimage_path=joinpath(@__DIR__, "sys_bellus.so"),
    # precompile_execution_file=joinpath(@__DIR__, "precompile.jl")
)
using BellusAuction
exit()
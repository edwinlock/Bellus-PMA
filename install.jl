#!/usr/local/bin/julia

import Pkg
Pkg.activate("BellusAuction", shared=true)
Pkg.develop(path="./BellusAuction")
Pkg.add("PackageCompiler")

import PackageCompiler
PackageCompiler.create_sysimage(
    ["BellusAuction"];
    sysimage_path="sys_bellus.so",
    precompile_execution_file="precompile.jl"
)
using BellusAuction
exit()
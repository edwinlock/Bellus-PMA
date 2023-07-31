@echo off
julia --project="%HOMEPATH%\.julia\environments\BellusAuction" --sysimage="sys_bellus.so" run.jl %*

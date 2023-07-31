path|find /i "%CD%" > nul || setx path %PATH%;%CD%
julia install.jl
echo @echo off ^&^& julia --project="%HOMEPATH%\.julia\environments\BellusAuction" --sysimage="%CD%\sys_bellus.so" %CD%/run.jl %%^* > bpma.bat
pause
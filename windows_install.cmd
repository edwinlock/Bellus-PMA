path|find /i "%CD%" > nul || setx path %PATH%;%CD%
julia install.jl
pause
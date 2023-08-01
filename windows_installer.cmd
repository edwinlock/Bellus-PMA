@echo off

: Ensure that current working directory is the directory containing this file
@setlocal enableextensions
@cd /d "%~dp0"

: create directory for program files if it doesn't exist yet
set dir=%HOMEPATH%\AppData\Local\Programs
if not exist "%dir%\NUL" mkdir "%dir%"
: copy over files
XCOPY /e /r /y "%CD%\*.*" "%dir%"
: create 'executable'
echo @echo off ^&^& julia --project="%HOMEPATH%\.julia\environments\BellusAuction" --sysimage="%dir%\sys_bellus.so" "%dir%\run.jl" %%^* > "%dir%\bpma.cmd"
: run Julia install script
julia --threads auto "%dir%\install.jl"
: Add program files directory to PATH
path|find /i "%dir%" > nul || setx path "%PATH%;%dir%"
echo "Installation completed"
pause
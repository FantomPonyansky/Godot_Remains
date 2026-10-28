@echo off
rem V-07: the tunnel turret room 0,3, god mode
setlocal
call "%~dp0..\_shared\run_case.cmd" "god 1; tp 0 3"
endlocal

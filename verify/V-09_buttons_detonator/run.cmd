@echo off
rem V-09: next to the shootable button in room 2,1
setlocal
call "%~dp0..\_shared\run_case.cmd" "debug; tp 2 1 14 17"
endlocal

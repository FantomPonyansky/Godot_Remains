@echo off
rem V-09: next to the press button in room 4,1
setlocal
call "%~dp0..\_shared\run_case.cmd" "tp 4 1 25 22"
endlocal

@echo off
rem V-01: healthy pony next to the exit in room 3,2
setlocal
call "%~dp0..\_shared\run_case.cmd" "heal; tp 3 2 42 19"
endlocal

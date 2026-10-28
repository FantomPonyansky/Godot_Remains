@echo off
rem V-05: god mode and weapons, a bloat3 and a bloat8 in front
setlocal
call "%~dp0..\_shared\run_case.cmd" "god 1; debug; tp 3 3 16 14; spawn bloat3; spawn bloat8"
endlocal

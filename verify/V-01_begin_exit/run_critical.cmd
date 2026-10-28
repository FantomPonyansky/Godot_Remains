@echo off
rem V-01: same, with the head at 1 hit point
setlocal
call "%~dp0..\_shared\run_case.cmd" "heal; tp 3 2 42 19; set /root/GameState head_hp 1"
endlocal

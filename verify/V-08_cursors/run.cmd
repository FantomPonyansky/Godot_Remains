@echo off
rem V-08: in game with a raider ahead and objects around
setlocal
call "%~dp0..\_shared\run_case.cmd" "god 1; debug; tp 3 0 8 18; spawn raider1"
endlocal

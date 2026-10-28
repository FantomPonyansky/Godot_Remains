@echo off
rem V-11: same, with a raider walking in
setlocal
call "%~dp0..\_shared\run_case.cmd" "god 1; tp 3 0 33 21; spawn raider1"
endlocal

@echo off
rem V-06: the camp with a raider spawned next to you
setlocal
call "%~dp0..\_shared\run_case.cmd" "god 1; debug; land rbl; tp 0 0 24 22; spawn raider1"
endlocal

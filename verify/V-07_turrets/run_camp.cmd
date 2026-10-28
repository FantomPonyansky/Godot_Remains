@echo off
rem V-07: the four player-side camp turrets in rbl
setlocal
call "%~dp0..\_shared\run_case.cmd" "god 1; debug; land rbl; tp 0 0 24 22; spawn raider1"
endlocal

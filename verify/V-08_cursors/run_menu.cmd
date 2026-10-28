@echo off
rem V-08: the main menu
setlocal
set "VERIFY_BOOT=menu"
call "%~dp0..\_shared\run_case.cmd" ""
endlocal

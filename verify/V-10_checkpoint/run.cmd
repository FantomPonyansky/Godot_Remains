@echo off
rem V-10: hurt and drained, next to the checkpoint in room 2,0
setlocal
call "%~dp0..\_shared\run_case.cmd" "set /root/GameState mana_hp 100; set /root/GameState head_hp 50; tp 2 0 18 15"
endlocal

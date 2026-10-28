@echo off
rem run_case.cmd "<console lines separated by ;>"
rem Starts the project from the checkout in its own user folder (tmp\verify_user), so your
rem real settings and saves are never touched, and runs the console lines once the first
rem land has loaded. A line that travels (land, quiet, trial, boss) waits for the next land.
rem   VERIFY_BOOT=new (default) | cont | slot=N | menu (show the main menu, no skip)
rem   VERIFY_KEEP=1   keep the saves and run state of the previous verify run
rem   VERIFY_QUIT=N   smoke test: quit after N frames and wait for the exit
rem   VERIFY_LAND=<id>[:room_x:room_y]  open the new game on that land (begin is not built)
rem   VERIFY_ROOM=<file>:<room>         open that room alone as a test land (begin:3:2 = rooms_begin room_3_2)
setlocal
call "%~dp0config.cmd"
if not exist "%GODOT%" (
  echo Godot not found at "%GODOT%"
  pause
  exit /b 1
)
if not defined VERIFY_BOOT set "VERIFY_BOOT=new"
if not "%VERIFY_KEEP%"=="1" if exist "%USERDIR%\saves" rmdir /s /q "%USERDIR%\saves"
set "BOOTARG=--boot=%VERIFY_BOOT%"
if /i "%VERIFY_BOOT%"=="menu" set "BOOTARG=--boot="
if defined VERIFY_LAND set "BOOTARG=%BOOTARG% --land=%VERIFY_LAND%"
if defined VERIFY_ROOM set "BOOTARG=%BOOTARG% --room=%VERIFY_ROOM%"
echo Verify run: %VERIFY_BOOT%  ^|  %~1
echo Log: %USERDIR%\logs  (lines starting "cmd>" show each command's answer)
if defined VERIFY_QUIT (
  "%GODOT%" --path "%PROJECT%" --quit-after %VERIFY_QUIT% -- "--user-dir=%USERDIR%" %BOOTARG% "--cmd=%~1"
) else (
  start "" "%GODOT%" --path "%PROJECT%" -- "--user-dir=%USERDIR%" %BOOTARG% "--cmd=%~1"
)
endlocal

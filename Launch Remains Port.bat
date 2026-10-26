@echo off
setlocal
set GODOT=%~dp0tools\godot\Godot_v4.7.2-stable_win64.exe
if not exist "%GODOT%" (
  echo Godot not found at "%GODOT%"
  echo Install Godot 4.7+ or re-run the download step.
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0godot"
endlocal

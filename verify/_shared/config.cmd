@echo off
rem Paths for the verify\ kit. A value already set in the environment is kept.
for %%I in ("%~dp0..\..") do set "REPO_DEFAULT=%%~fI"
if not defined REPO set "REPO=%REPO_DEFAULT%"
if not defined GODOT set "GODOT=%REPO%\tools\godot\Godot_v4.7.2-stable_win64.exe"
if not defined PROJECT set "PROJECT=%REPO%\godot"
if not defined USERDIR set "USERDIR=%REPO%\tmp\verify_user"
if not defined PY set "PY=python"
set "PYTHONUTF8=1"

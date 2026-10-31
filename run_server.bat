@echo off
setlocal
cd /d "%~dp0"
set PORT=7777
if defined MXD_PORT set PORT=%MXD_PORT%

if exist "mxdpppplus_server.exe" (
  echo [mxdpppplus] starting bundled server on UDP %PORT%
  set MXD_PORT=%PORT%
  mxdpppplus_server.exe --headless -- --server --port=%PORT%
  pause
  exit /b
)

set GODOT_BIN=
if exist "Godot_v4.7.2-stable_win64_console.exe" set GODOT_BIN=Godot_v4.7.2-stable_win64_console.exe
if exist "Godot_v4.7.2-stable_win64.exe" set GODOT_BIN=Godot_v4.7.2-stable_win64.exe
if not defined GODOT_BIN set GODOT_BIN=godot

echo [mxdpppplus] starting server on UDP %PORT%
"%GODOT_BIN%" --headless --path "%~dp0" -- --server --port=%PORT%
pause

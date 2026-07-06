@echo off
rem Procedural walk-cycle editor launcher. Double-click to open the standalone
rem walk-cycle editor (game.exe walkeditor): pick a unit, tune stride / step
rem height / step curve / bounce / arm swing while it walks on a treadmill, then
rem Save to persist. %~dp0 is this script's own folder, so it works wherever the
rem script sits (CMake copies it next to game.exe on every build).
cd /d "%~dp0"
start "RTS Walk Editor" game.exe walkeditor

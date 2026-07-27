@echo off
rem Local 2-player test launcher. Double-click to start both instances on
rem 127.0.0.1: player 0 listens on 7777, player 1 dials it from 7778.
rem %~dp0 is this script's own folder, so it works wherever the script sits
rem (CMake copies it next to game.exe on every build).
cd /d "%~dp0"
rem game.exe reopens stderr to ClaudeRTS-log-p0/p1.txt (truncated each launch), so a desync's "divergent subsystem(s)"
rem line lands there; the desync_P0/P1_tick*.log state dumps are cleared at startup so only THIS run's remain. Diff the
rem two desync_P0/P1 dumps for the first differing field; read ClaudeRTS-log-pN.txt for the subsystem name.
start "RTS Player 0" game.exe direct 7777 7778 0
start "RTS Player 1" game.exe direct 7778 7777 1

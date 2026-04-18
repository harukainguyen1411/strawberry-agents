@echo off
REM Launch Yuumi in Windows Mode — Remote Control + dangerously-skip-permissions
REM
REM Yuumi is Evelynn's restart buddy. She runs as a second, parallel Claude Code
REM instance alongside Evelynn so Duong can ask her to kill and relaunch the
REM Evelynn process when Evelynn needs a fresh session.
REM
REM How to launch:
REM   - Double-click this file from Windows Explorer, OR
REM   - From cmd: windows-mode\launch-yuumi.bat
REM
REM Once the session starts, a Remote Control session URL appears. Open it in
REM Claude Desktop (or claude.ai/code) to drive Yuumi. When you want to restart
REM Evelynn, just tell Yuumi "restart Evelynn" and she'll run scripts\restart-evelynn.ps1.
REM
REM See windows-mode/README.md for the general Windows Mode details.
cd /d "%~dp0\.."
claude --dangerously-skip-permissions --remote-control "Yuumi"

@echo off
REM Launch Evelynn in Windows Mode — Remote Control + dangerously-skip-permissions
REM See windows-mode/README.md for details
REM Identity env vars exported before claude spawns (INV-4).
set CLAUDE_AGENT_NAME=Evelynn
set STRAWBERRY_AGENT=Evelynn
set STRAWBERRY_CONCERN=personal
cd /d "%~dp0\.."
claude --dangerously-skip-permissions --remote-control --agent Evelynn

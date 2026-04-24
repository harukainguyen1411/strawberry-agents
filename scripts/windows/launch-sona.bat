@echo off
REM Launch Sona in Windows Mode — Remote Control + dangerously-skip-permissions
REM See windows-mode/README.md for details
REM Identity env vars exported before claude spawns (INV-4).
set CLAUDE_AGENT_NAME=Sona
set STRAWBERRY_AGENT=Sona
set STRAWBERRY_CONCERN=work
cd /d "%~dp0\.."
claude --dangerously-skip-permissions --remote-control --agent Sona

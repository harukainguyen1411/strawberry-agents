@echo off
REM Launch Evelynn in Windows Mode — Remote Control + dangerously-skip-permissions
REM See windows-mode/README.md for details
cd /d "%~dp0\.."
claude --dangerously-skip-permissions --remote-control "Evelynn"

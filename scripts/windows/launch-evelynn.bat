@echo off
REM Launch Evelynn in Windows Mode — Remote Control + dangerously-skip-permissions
REM Spawned via cmd /c child process so env vars are scoped to the child and
REM do not persist in the calling session. Writes .coordinator-identity for
REM inbox-watch.sh Tier 3 fallback.
cmd /c "set CLAUDE_AGENT_NAME=Evelynn& set STRAWBERRY_AGENT=Evelynn& set STRAWBERRY_CONCERN=personal& cd /d "%~dp0\..\.."& echo|set /p="Evelynn"> .coordinator-identity.tmp& move /y .coordinator-identity.tmp .coordinator-identity& claude --dangerously-skip-permissions --remote-control --agent Evelynn"

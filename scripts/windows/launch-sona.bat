@echo off
REM Launch Sona in Windows Mode — Remote Control + dangerously-skip-permissions
REM Spawned via cmd /c child process so env vars are scoped to the child and
REM do not persist in the calling session. Writes .coordinator-identity for
REM inbox-watch.sh Tier 3 fallback.
cmd /c "set CLAUDE_AGENT_NAME=Sona& set STRAWBERRY_AGENT=Sona& set STRAWBERRY_CONCERN=work& cd /d "%~dp0\..\.."& echo|set /p="Sona"> .coordinator-identity.tmp& move /y .coordinator-identity.tmp .coordinator-identity& claude --dangerously-skip-permissions --remote-control --agent Sona"

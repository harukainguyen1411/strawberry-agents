# Subagent false Bash-deny — retry with verbatim-error instruction

**Date:** 2026-04-21
**Context:** Wave 1 impl dispatch (fifth leg, ship-day). Viktor and Jayce subagents reported "Bash permission denied" on early exploratory commands and stopped working, despite Bash being available in the work repo (confirmed by S3 and S5 Jayce progress on the third dispatch before agents were killed).

## What happened

First Wave 1 dispatch: multiple subagents reported Bash unavailable on first exploratory commands and bailed without attempting meaningful work. This is a false negative. Bash is available to builder agents (Viktor, Jayce) in the strawberry-agents work repo — the permission model is per-command, not session-wide. A first opaque response ("Bash permission denied") does not confirm Bash is unavailable.

## The lesson

When a builder subagent (Viktor, Jayce) reports Bash unavailable on an early command:
1. Instruct the agent to **retry the specific command** and **report the exact error verbatim**, not just "permission denied."
2. If the verbatim error confirms a real sandbox block, then and only then consider alternatives (Write/Edit-only approach or redispatch to a tester/devops agent).
3. Never redispatch without first requiring verbatim error output. A bail-on-first-opaque-response is almost always a false Bash-deny.

**Related prior learning:** `2026-04-21-bash-deny-builder-specific-not-session-wide.md` — builder agents (Viktor/Jayce) differ from tester agents (Vi/Rakan/Ekko) in their Bash availability. That learning covered the session-wide assumption; this one covers the per-command false-positive failure mode.

## Application

Include this in delegation context for all Wave 2+ impl dispatches: "If Bash reports denied on any command, retry and return the exact error verbatim before concluding Bash is unavailable."

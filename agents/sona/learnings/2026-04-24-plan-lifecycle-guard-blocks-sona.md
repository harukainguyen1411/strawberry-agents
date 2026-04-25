# Learning: Plan lifecycle guard blocks Sona on all phase transitions — not just proposed→approved

**Date:** 2026-04-24
**Session:** 576ce828-0eb2-457e-86ac-2864607e9f22 (shard 4df78d45)
**Concern:** work

## What happened

Sona's coordinator addendum (`agents/sona/CLAUDE.md`) states under "Plan approval gate":

> Phase transitions past `approved` (→ `in-progress` → `implemented` → `archived`) are my calls as coordinator.

This is factually incorrect at the enforcement layer. The PreToolUse plan-lifecycle guard (`scripts/hooks/pretooluse-plan-lifecycle-guard.sh`, wired via `.claude/settings.json`) blocks ALL moves out of protected plan directories — including `approved/`, `in-progress/`, `implemented/`, `archived/` — for any agent identity that is not Orianna or Duong's admin accounts.

Identity resolution order in the guard:
1. Framework `agent_type` (Agent-tool subagent dispatch)
2. `CLAUDE_AGENT_NAME` env var
3. `STRAWBERRY_AGENT` env var
4. Fail-closed

The `.claude/settings.json` `.agent` field defaults to Evelynn. Even in a genuine Sona session, STRAWBERRY_AGENT is not automatically set in the environment, so the guard can resolve identity as Evelynn or fail-closed — never as Sona. Real Sona coordinator sessions trip the guard on any plan-move attempt.

Confirmed this session: both approved→in-progress transitions for the Wave C plan were executed by Orianna Agent dispatch (task #48), not by Sona directly.

## Impact

Any plan content in Sona's addendum or muscle memory that assumes Sona can directly execute post-proposed phase transitions is wrong and will fail at execution time. The first signal will be a PreToolUse guard rejection.

## Correct behavior

All phase transitions in the plan lifecycle require Orianna Agent dispatch, regardless of which phase boundary is being crossed. Rule 19 is absolute.

Sona's role is:
- Decide *when* to promote (coordinator judgment call).
- Dispatch Orianna with the plan path and target stage.
- Confirm the Orianna return (APPROVE/REJECT + commit SHA).

Sona never holds a git tool or executes `git mv` on plan directories directly.

## Action item

Update `agents/sona/CLAUDE.md` "Plan approval gate" section to remove the claim that phase transitions past `approved` are Sona's direct calls. Replace with: all phase transitions require Orianna Agent dispatch; Sona's authority is the dispatch decision, not the mechanical execution.

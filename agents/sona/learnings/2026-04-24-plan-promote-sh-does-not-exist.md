# Learning: scripts/plan-promote.sh does not exist — use Orianna Agent dispatch

**Date:** 2026-04-24
**Session:** 576ce828-0eb2-457e-86ac-2864607e9f22 (shard 4df78d45)
**Concern:** work

## What happened

The Sona coordinator addendum (`agents/sona/CLAUDE.md`) in the "Plan approval gate" section states:

> the `scripts/plan-promote.sh` script is agent-runnable under the `Duongntd` account and runs the Orianna gate, signs, moves, and pushes without admin identity.

This script does not exist. The actual path for all plan promotions is direct Orianna Agent dispatch (`.claude/agents/orianna.md`). Yuumi caught this discrepancy when attempting to locate the script.

The reference was accurate for an earlier version of the system (commit `81b0d17` archived the script when Orianna-as-callable-agent was introduced). The CLAUDE.md addendum was not updated at that time.

## Impact

Any agent or process that attempts to invoke `scripts/plan-promote.sh` will hit a file-not-found error. The broader consequence is that the authoritative governance document for Sona contains stale implementation guidance that contradicts the enforced reality.

## Correct behavior

All plan promotions out of `plans/proposed/` require Orianna Agent dispatch:
- Invoke `.claude/agents/orianna.md` with the plan path and target stage.
- Orianna reads the plan, renders APPROVE or REJECT, and on APPROVE moves the file, appends the approval block, commits with `Promoted-By: Orianna` trailer, and pushes.
- Rule 19 (CLAUDE.md Universal Invariant) enforces this at the PreToolUse guard level — Sona cannot move plan files directly regardless of what her addendum claims.

Phase transitions past `approved` (approved→in-progress→implemented→archived) are also Orianna-gated per Rule 19, not Sona's direct call as the addendum implies.

## Action item

Update `agents/sona/CLAUDE.md` "Plan approval gate" section to:
- Remove the `scripts/plan-promote.sh` reference.
- Clarify that Orianna Agent dispatch is the mechanism for all phase transitions out of `proposed/`, and that Rule 19 enforces this at the guard level for all subsequent transitions too.

This is Evelynn's lane (strawberry-agents infrastructure). Send inbox message or handle at next Evelynn session.

# Isolation infrastructure should precede large greenfield tasks

**Date:** 2026-04-24
**Session:** 5e94cd09 (pre-compact 2)
**Trigger:** Universal worktree isolation vs Slack MCP sequencing decision

## What was learned

I flagged — after the fact — that dispatching Jayce for a large greenfield Slack MCP implementation before landing universal worktree isolation was a priority-ordering miss. The isolation impl would have protected the shared working tree during Jayce's C4 migration commit window; instead, that risk window is open and accepted.

The correct sequencing principle: **infrastructure changes that protect against shared-tree race conditions should land before large autonomous greenfield tasks that expose the shared tree.**

Duong explicitly ordered Slack MCP first on pragmatic grounds (Jayce is already context-loaded; isolation rollout needs its own careful dispatch). This is a legitimate override. But the coordinator should have surfaced the ordering risk proactively before Jayce was dispatched, not after.

## Generalizable rule

Before dispatching any long-running autonomous agent with a final migration/merge commit on the shared working tree: ask whether isolation infrastructure is in place. If not, surface the ordering risk to Duong before dispatching — don't flag it as a retrospective observation after the task is in flight.

## Impact

Applies to any future large-scale greenfield dispatch. The Slack MCP session is the triggering incident; risk is bounded and accepted for this case.

# Pre-commit structure-check is shared state across concurrent plan drafts

**Date:** 2026-04-21
**Session:** ship-day fourth leg (shard 2026-04-21-4c6f055d)

## What happened

Karma #61 was dispatched to fast-lane the S5 fullview plan. The plan file it authored was structurally clean. But the pre-commit hook fired on Karma #59's MCP-merge plan — a separate file authored by a separate concurrent agent — because both files were untracked in the same working tree. The violations (time-unit "h)" notation + missing `## Test plan` section) existed on Karma #59's file, not Karma #61's. Karma #61's commit was blocked by another agent's work-in-progress.

## The lesson

The pre-commit plan-structure-check runs against all staged/untracked plan files in the working tree, not just the file a given agent is trying to commit. When multiple planner agents are running concurrently and leaving plan files untracked on disk, any of them can block any other's commit attempt — even if the blocking file came from a different agent. This is the same class of concurrency hazard as the body-hash invalidation pattern (documented in `2026-04-21-signing-ceremony-cost-scales-with-body-edits.md`), but at the commit-gating layer rather than the signing layer.

## Pattern

- Concurrent planner dispatches (multiple Karma/Azir/Swain agents writing plan files simultaneously) are safe at the writing stage
- They become hazardous at commit time if any file in the working tree violates structure-check constraints
- The hook's scope is working-tree-wide, not file-specific

## Mitigation

1. Brief planners to run `scripts/check_plan_structure.py` (or equivalent) on their own file before attempting to commit
2. When a commit fails for an agent, check git status first — the violation may be on a different file
3. Dispatch agents sequentially if their commit timing will overlap, or ensure each agent commits and pushes before the next is dispatched
4. If a fast-lane plan is time-sensitive (S5 fullview), ensure preceding concurrent plans (MCP-merge) are committed first before dispatching

## Cross-reference

- Prior hazard class: `2026-04-21-signing-ceremony-cost-scales-with-body-edits.md` (concurrent body edits → signing failures)
- Root cause entry: `2026-04-20-plan-structure-hook-false-positives.md` (hook fires on "h)" and "(d)" substrings in prose)

# Sequential Plan Promotion — Stale Cross-Plan Path Reference

**Date:** 2026-04-19
**Session:** ekko s27

## Lesson

When promoting two plans sequentially where Plan B references Plan A's path, Plan B's
reference becomes stale the moment Plan A is promoted. `plan-promote.sh` runs an Orianna
fact-check gate that will block on the stale path.

## Pattern

Plan A: `plans/proposed/2026-04-19-stale-green-merge-gap.md` — promoted first (clean).
Plan B: `plans/proposed/2026-04-19-reviewer-identity-split.md` — referenced Plan A at
its `proposed/` path. Orianna blocked with: "not found" (severity: block).

## Fix

Before running the second `plan-promote.sh`, grep the second plan for any cross-plan
references and update `proposed/` to `approved/` for plans already promoted in the same
batch. Commit the fix, then re-run.

## Prevention

When authoring a plan that references a sibling proposed plan, use a relative path note
like "see plan at `plans/proposed/...` (will move to approved/)" so the reviewer knows
to update the path before or during promotion.

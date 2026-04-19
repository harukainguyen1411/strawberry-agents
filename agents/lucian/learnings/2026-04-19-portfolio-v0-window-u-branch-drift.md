# Portfolio v0 Window U — base:main drift across parallel branches

**Date:** 2026-04-19
**PRs:** harukainguyen1411/strawberry-app #32, #43, #45 (triage batch)

## What I found

Portfolio v0 plan (`plans/approved/2026-04-19-portfolio-tracker-v0-tasks.md`) has two
parallel windows after V0.3:

- Window H (V0.4 → V0.8): correctly stacked — each PR (#34, #36, #40, #41, #42)
  uses `base=feature/portfolio-v0-V0.<prev>-...`. Diffs show only the task's delta.
- Window U (V0.9 → V0.17): all base:main (#43, #44, #45). Each carries ancestors'
  commits transitively. #45 diff contained 8 tasks (V0.3, V0.4, V0.5, V0.6, V0.7,
  V0.9, V0.10, V0.11).

## Why it matters for fidelity review

Plan §Conventions says "one branch per task … squash-merge." With Window U
base:main, merging #43 squashes V0.3+V0.9 into one commit, making #33 a no-op
and breaking the task-per-commit audit trail that the plan's Refs-V0.x body
convention relies on.

## Decision rubric I used

- V0.11 implementation itself plan-faithful → not a code issue.
- Bundled 8 tasks into one squash-merge → **structural block** per my Lucian scope.
- Rule 12 xfail-first honored per sub-task → didn't count as additional defect.

Request-changes on #43 and #45. Approved #32 because its diff was actually clean
(V0.2 only) despite base:main — branch was cut from V0.1 tip but V0.1's files
aren't in the diff, so the concern there is only merge-ordering (flag but don't
block).

## Review-authoring pattern

When a PR is plan-faithful in code but structurally bundled, lead the review with
"implementation PASS" then call out the bundle explicitly with per-task attribution
(which files belong to which task). Offer two remediation options (retarget base
vs. merge-in-order) because rule 11 forbids rebase and some fixes are only
practical if the dependency chain has already drained.

## Next time

If asked to triage a Window U-style batch again, check the merged+open PR list
upfront to map the dependency graph before opening diffs. Caught this in ~3
tool calls but could have gone to 1 with the PR list as the first query.

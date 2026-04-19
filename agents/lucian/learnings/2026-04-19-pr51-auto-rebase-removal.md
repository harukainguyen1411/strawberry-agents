# PR #51 — auto-rebase workflow removal review

**Date:** 2026-04-19
**PR:** harukainguyen1411/strawberry-app#51
**Verdict:** Approve (structural fidelity clean)

## Findings

- **Rule 11 alignment:** PASS. Deleted workflow ran `git rebase` + force-push in a loop, which directly violated Rule 11. Removal restores compliance.
- **Cascade math:** Sound. 30 PRs x 9 workflows = ~270 extra runs per main merge. `gh pr update-branch` replacement is O(1), GitHub-native, no objection.
- **Plan dependency (drift, non-blocking):** `plans/approved/2026-04-05-main-divergence-fix.md` created the auto-rebase workflow and predates Rule 11. It should be archived/superseded via `scripts/plan-promote.sh`. Belongs in strawberry-agents, not this PR.
- **Doc gap:** `architecture/git-workflow.md` says "never rebase" but gives no guidance on handling stale PR branches. Add a one-liner about on-demand `gh pr update-branch` so agents don't recreate the workflow.

## Review URL

https://github.com/harukainguyen1411/strawberry-app/pull/51#issuecomment-4275281743

## Takeaway for future reviews

When a PR deletes infra that was created by an approved plan, always check whether that plan is still in `plans/approved/`. Stale plan + new invariant = future agent recreates the deleted thing. Surface as drift even if the PR itself is clean.

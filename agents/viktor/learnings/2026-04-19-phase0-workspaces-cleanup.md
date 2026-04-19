# 2026-04-19 — Phase 0: apps/portal stale workspace cleanup

## Context

Executed Phase 0 (P0.1 + P0.2) of `plans/approved/2026-04-19-apps-restructure-darkstrawberry-layout.md`.
PR: harukainguyen1411/strawberry-app#60

## What I did

**P0.1 — verification (read-only):**
- Confirmed all 8 portfolio PRs (#29, #32, #33, #40, #42, #44, #45, #57) merged to main via `gh pr list`.
- Confirmed no open PRs from any `feature/portfolio-v0-*` head.
- Remote stale branches (`origin/feature/portfolio-v0-*`) are merged-not-deleted refs — no active work on any.

**P0.2 — stale entry removal:**
- Root `package.json` workspaces listed `apps/portal` which does not exist in the repo.
- Removed the single line. `package-lock.json` updated automatically (same single-line lockfile diff).
- Ran `npm install --ignore-scripts` in the worktree — clean, no workspace-not-found errors.
- Committed as `chore:` on branch `chore/phase0-workspaces-cleanup` from a git worktree at `/tmp/strawberry-app-phase0`.

## Patterns

- **Worktree workflow:** `git worktree add /tmp/<name> -b <branch>` from the main repo checkout. Work in the worktree; push from there.
- **Stale workspace entries:** When a workspace glob references a non-existent directory, npm silently skips it during install — so the stale entry doesn't cause failures. But it confuses Phase 1 diff and should be cleaned pre-restructure.
- **Lockfile side-effect:** `npm install` after removing a workspace entry updates `package-lock.json` even though no packages changed — the workspaces metadata in the lockfile root mirrors `package.json`. Include `package-lock.json` in the commit; single-line diff is expected and benign.

## Phase 1 readiness

No blockers found for Phase 1. The runway is clear:
- Portfolio stack drained.
- Workspace glob cleaned.
- Phase 1 can begin once this PR merges.

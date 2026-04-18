---
date: 2026-04-18
topic: TDD hooks + CI wiring (task #1)
---

# TDD Hooks + CI Wiring — Session Learnings

## What was already done
All hook scripts and CI workflows were already on main before this session:
- `scripts/hooks/pre-commit-unit-tests.sh`
- `scripts/hooks/pre-push-tdd.sh`
- `scripts/install-hooks.sh` (dispatch-based, runs all `<verb>-*.sh` sub-hooks)
- `.github/workflows/tdd-gate.yml` (xfail-first + regression-test jobs)
- `.github/workflows/e2e.yml`
- `.github/workflows/pr-lint.yml`
- `scripts/setup-branch-protection.sh`

## What this session added
- `architecture/testing.md` — smoke tagging convention, TDD rules 12–17 enforcement overview, hook installation guide, branch protection table
- `.github/pull_request_template.md` — Testing section (xfail SHA, regression test, QA-Report fields + checklist)

## Gotchas
- `scripts/safe-checkout.sh` calls raw `git checkout` — it is NOT a worktree wrapper. Always use `git worktree add` directly.
- There were uncommitted Jhin session files (memory + learnings) blocking worktree creation. Had to commit them on main first.
- Task #32 (J1) was marked completed by Vi before this session, but the PR template in main still lacked a Testing section. Ekko's PR adds it.

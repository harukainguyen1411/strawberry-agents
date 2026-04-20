# Auto-rebase cascade CI fix — PR #9

Date: 2026-04-21

## Problem

`.github/workflows/auto-rebase.yml` fired on `push: main`, iterated every open PR,
ran `git rebase origin/main`, then `git push --force-with-lease`. The force-push
triggered `pull_request: synchronize` on all open PRs, re-running full CI for each.
Minutes consumed = (N open PRs) × (per-PR CI cost) per merge.

Also violated invariant #11 (never rebase — always merge).

## Fix

Deleted `auto-rebase.yml` via branch `ops/delete-auto-rebase`, PR #9.

## Push:main workflow audit (post-fix)

| Workflow | trigger | keep? |
|---|---|---|
| auto-rebase.yml | push:main | DELETED |
| release.yml | push:main + workflow_dispatch | Keep — guarded by path `if:` conditions; skips unless functions/ or rules changed |
| auto-label-ready.yml | issues:opened | Keep |
| pr-lint.yml | pull_request | Keep |
| tdd-gate.yml | pull_request + push:branches-ignore:main | Keep |
| validate-scope.yml | pull_request | Keep |

## Branch protection blocker

`harukainguyen1411` account is the repo owner and only admin, but is not authenticated
in any gh CLI keyring or decryptable secret on this machine. `duongntd99` and `Duongntd`
both have `admin: false`. Task 2 (applying protection) is a human-only step; payload
has been prepared.

## Confirmed check names (from PR #9 check-runs API)

- `QA report present (UI PRs)` — pr-lint.yml job `qa-report-present`
- `xfail-first check` — tdd-gate.yml job `xfail-first`
- `regression-test check` — tdd-gate.yml job `regression-test`
- `validate-scope` — validate-scope.yml job `validate-scope`

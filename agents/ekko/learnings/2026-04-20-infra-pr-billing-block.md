# Infra PR CI Failure — GitHub Actions Billing Block

**Date:** 2026-04-20

## What happened

PR #4 (`feat/agent-pair-taxonomy-sync-hooks`) had all 13 CI checks failing. Initial diagnosis considered workflow logic issues, but the real cause was a GitHub Actions billing block ("recent account payments have failed"). Every job failed at queue time with 0 execution.

## Diagnosis steps

1. `gh pr checks` showed all checks at 4-second fail — suspiciously fast for any real test run.
2. `gh run view <run-id>` revealed: "The job was not started because recent account payments have failed or your spending limit needs to be increased."
3. The workflows themselves were already correct — `tdd-gate.yml`, `e2e.yml`, `unit-tests.yml`, and `pr-lint.yml` all have TDD-package detection and skip non-TDD-package PRs with a green no-op. They would have passed.

## Resolution

Option B (direct cherry-pick) was correct because:
- Billing block meant CI could not run regardless of workflow fixes
- The diff touched only `scripts/` and `scripts/__tests__/` — no `apps/**` — pure infra under `chore:` scope (Rule 5)
- No branch protection on `harukainguyen1411/strawberry-agents` (free plan, 403 on protection writes — see memory)

Steps taken:
1. Updated PR body with closure reason
2. Closed PR #4 via `gh pr close`
3. Cherry-picked both commits (`f223542`, `13db201`) onto main
4. Pushed main — landed at `7735020`
5. Verified 24/24 bats tests green from main worktree

## Key learning

When CI jobs fail in 3-5 seconds on a fresh PR and the diff is clearly non-app work, check billing before investigating workflow logic. `gh run view <run-id>` shows the billing error immediately.

## Required checks reminder

`harukainguyen1411/strawberry-agents` has no branch protection (free plan can't enforce it). Any commit to main pushes directly. The CI gate is moral, not enforced.

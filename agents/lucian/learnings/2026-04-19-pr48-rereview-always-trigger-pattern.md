# PR #48 re-review — always-trigger + internal-gate pattern resolves required-check trap

Date: 2026-04-19
Repo: harukainguyen1411/strawberry-app
PR: #48 (`chore/e2e-scope-myapps`)
Prior review: CHANGES_REQUESTED (learning `2026-04-19-pr48-e2e-paths-ignore-required-check-trap.md`)

## Outcome

APPROVE (posted as `--comment` — GitHub blocks `--approve` from the PR-author account, so same auth-path constraint that applied to the prior CHANGES_REQUESTED review).

## What changed

Jayce's fix commit `1b7e38f`:
- Removed `paths-ignore` from `on.pull_request`
- `detect` step now computes both `has_tdd` and `only_myapps`
- New early-exit step fires when `only_myapps == true`, prints success, lets heavy steps remain skipped
- Heavy steps gated on `only_myapps != 'true' && has_tdd == 'yes'`
- Switched diff base to `pull_request.base.sha`/`head.sha` (consistent with `myapps-test.yml`)
- Empty-diff fallback: `only_myapps="false"` so an empty changeset doesn't silently skip

## Why this works

GitHub does emit a job status for workflows that always trigger, even when every step is a no-op `echo`. So the required `Playwright E2E` check reports green on myapps-only PRs. The PR's own run (check ID `71995242037`) empirically confirmed this — 9s pass.

## Pattern file

This is now the canonical Strawberry pattern for required-check workflows with per-app ownership splits:

1. No `paths-ignore` on `on.pull_request`
2. A `detect` step computing per-scope booleans from `base.sha`/`head.sha` diff
3. An early-exit step with a friendly `echo` that fires when the workflow's scope doesn't apply
4. Heavy steps `if:`-gated on the scope booleans
5. Empty-diff fallback to avoid silent green skips

Mirror files to check when designing a new required-check workflow: `.github/workflows/myapps-test.yml`, `.github/workflows/myapps-pr-preview.yml`, and now `.github/workflows/e2e.yml`.

## Rule 18 reminder

My approval-comment is advisory. A non-author account still needs to `--approve` before merge, per Rule 18. I made this explicit in the review body so the next agent/human in the chain doesn't mis-read the comment as a merge clearance.

## Unrelated red checks

`Deploy Preview` and `Firebase Hosting PR Preview` were red but pre-existing/environmental, unrelated to this diff. Flagged in review body as out-of-scope for fidelity review — Senna's lane if they turn out to be real.

---
title: apps/myapps legacy test cleanup
date: 2026-04-17
owner: pyke
status: proposed
tags: [ci, tech-debt, apps/myapps, test-removal]
---

# apps/myapps legacy test cleanup

## Problem

Every PR's CI is red on `main` due to pre-existing legacy tech debt in `apps/myapps/`, not PR content:

1. **Firebase Hosting PR Preview** — `scripts/composite-deploy.sh` expects `apps/portal/dist` or `apps/myapps/dist`; neither gets built anymore.
2. **Lint + Test + Build (affected)** — ESLint: 3 errors, 31 warnings in `apps/myapps/task-list/src/`.
3. **Unit tests (Vitest)** — `rolldown-binding.linux-x64-gnu.node` missing on Linux CI.
4. **E2E (Playwright / Chromium)** — `apps/myapps/e2e/visual-regression.spec.ts` has darwin snapshots only; `navigation.spec.ts` times out on `locator.click`.

Duong's direction: **remove the old tests**. `dashboards/` is the going-forward test surface.

## Inventory — files/workflows/scripts to delete or neutralize

### Tests (delete)
- `apps/myapps/e2e/visual-regression.spec.ts` and `apps/myapps/e2e/visual-regression.spec.ts-snapshots/` (darwin-only snapshots, no linux parity).
- `apps/myapps/e2e/navigation.spec.ts` (cd75f timeout test, brittle locator).
- `apps/myapps/e2e/home.spec.ts`, `forms-crud.spec.ts`, `portfolio-tracker.spec.ts`, `read-tracker.spec.ts`, `auth-local-mode.spec.ts` — evaluate each; if any still gate live functionality **and** pass locally on linux, keep (see Preservation). Default: delete the whole `apps/myapps/e2e/` tree if no spec reliably passes on CI Linux.
- `apps/myapps/playwright.config.ts` — delete if entire e2e suite goes.
- `apps/myapps/playwright-report/` and `apps/myapps/test-results/` — delete (stale artifacts, should already be gitignored).

### Unit tests (neutralize)
- Remove the Vitest invocation for `apps/myapps` from the affected-unit-test task until rolldown/Linux is resolved. Prefer removing the `test` script from `apps/myapps/package.json` (or renaming to `test:manual`) so Nx/affected doesn't pick it up, over deleting test files — the tests themselves aren't broken, only the runner on Linux.

### Lint
- Delete `apps/myapps/task-list/src/` files only if the feature is dead. Otherwise: scope the ESLint config in `apps/myapps/eslint.config.js` to exclude `task-list/src/` (or add per-file disables) so the 3 errors no longer fail CI. 31 warnings don't fail; leave them.

### Deploy script
- `scripts/composite-deploy.sh` — remove the `apps/myapps/dist` / `apps/portal/dist` path branches. If this script has no remaining callers after myapps removal, delete it.
- Firebase config: `apps/myapps/firebase.json` — keep if Firebase project is still live; otherwise delete alongside.

### Workflows
- `.github/workflows/myapps-pr-preview.yml` — delete (relies on composite-deploy + dist).
- `.github/workflows/myapps-prod-deploy.yml` — **confirm with Duong before deleting**: is myapps still deployed to prod? If yes, keep and repoint build; if no, delete.
- `.github/workflows/myapps-test.yml` — delete.
- `.github/workflows/e2e.yml` — audit; remove any `apps/myapps`-scoped job. Keep dashboards e2e.
- `.github/workflows/ci.yml` — audit lint/test/build matrix; drop `apps/myapps` entries.

## Preservation — do NOT delete

- `apps/myapps/functions/` — Cloud Functions serve live endpoints (verify with `firebase functions:list` before any removal there). Out of scope for this cleanup.
- `apps/myapps/firestore.rules`, `storage.rules`, `firestore.indexes.json` — live data gates. Keep untouched.
- Any spec in `apps/myapps/e2e/` that Duong confirms is the sole gate for a still-shipping user flow. Default assumption: none, since `dashboards/` supersedes.
- `dashboards/` tests — untouched. Out of scope.

## CI workflow updates — required checks must stay green on empty diff

Per `plans/approved/2026-04-17-branch-protection-enforcement.md` (PR #143 pending), required status checks on `main` are:
- `xfail-first check`
- `regression-test check`
- `unit-tests`
- `Playwright E2E`
- `QA report present`

After cleanup, each required check must still run and report **green** on an empty diff:
- `unit-tests` — must resolve without the `apps/myapps` vitest job. Confirm the workflow that produces this check still has at least one target (dashboards) and doesn't fail on "no tests found".
- `Playwright E2E` — must still run against `dashboards/` e2e. If the check name is produced by `e2e.yml`, ensure the job still exists after myapps matrix entries are removed.
- `xfail-first check`, `regression-test check`, `QA report present` — verify none of these depend on `apps/myapps` test output. They're expected to be dashboards-scoped but must be confirmed by Viktor during implementation.

**Implementation requirement:** before merging the cleanup PR, run the full required-check set against a no-op branch off main to prove green.

## Rollback

Low risk — deletions only, no live behavior change. Tag `pre-myapps-test-cleanup` on main before the cleanup PR merges, so the old test tree is recoverable via `git checkout pre-myapps-test-cleanup -- apps/myapps/e2e/` if a specific spec turns out to still matter.

## Owners

- **Refactor/removal:** Viktor — delete files, update workflows, scope ESLint, remove composite-deploy paths.
- **Replacement tests (if any gap found):** Vi — only if Viktor surfaces a live flow that was solely gated by a deleted spec. Expected: none.

## Open questions for Duong

1. Is `apps/myapps` still deployed to prod? (Governs whether `myapps-prod-deploy.yml` and `composite-deploy.sh` stay.)
2. Is `apps/myapps/task-list/` a dead feature or just un-maintained? (Governs delete vs. lint-scope.)
3. Confirm `dashboards/` is the sole going-forward test surface — no other app expects myapps e2e to cover it.

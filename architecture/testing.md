---
title: Testing Architecture
updated: 2026-04-18
---

# Testing Architecture

## TDD Enforcement Overview

TDD enforcement applies to all packages with `"tdd": { "enabled": true }` in their `package.json`. Packages without this marker are exempt until a migration plan lands.

### Rule 12 — xfail-first (CLAUDE.md §12)

Any implementation commit in a TDD-enabled package must be preceded on the same branch by a commit adding an xfail test. The xfail test must carry a comment `# xfail: <task-id-or-plan-path>`.

**Enforcement:**
- Client-side: `scripts/hooks/pre-push-tdd.sh` (walks commits, blocks push on violation)
- Server-side (authoritative): `.github/workflows/tdd-gate.yml` job `xfail-first`
- Bypass: `TDD-Waiver: <reason>` trailer on the tip commit (Duong only)

**xfail annotations recognised:**
- Vitest: `it.failing`
- Playwright: `test.fail`
- pytest: `@pytest.mark.xfail`
- Shell/bats: `# xfail:` comment

### Rule 13 — Regression test required for bug fixes (CLAUDE.md §13)

Commits with `bug`, `bugfix`, `regression`, or `hotfix` in the subject line must be accompanied by a regression test commit on the same branch.

**Enforcement:**
- Client-side: `scripts/hooks/pre-push-tdd.sh` job `regression-test` check
- Server-side (authoritative): `.github/workflows/tdd-gate.yml` job `regression-test`
- Bypass: `TDD-Waiver: <reason>` or `TDD-Trivial: <reason>` trailer (Duong only; `TDD-Trivial` only for `docs/**` and `**/*.md` paths)

### Rule 14 — Pre-commit unit tests (CLAUDE.md §14)

On every `git commit`, unit tests run for staged TDD-enabled packages. Commit is blocked on failure.

**Enforcement:**
- `scripts/hooks/pre-commit-unit-tests.sh` (installed by `scripts/install-hooks.sh`)
- Looks for `package.json#scripts["test:unit"]` in each affected package
- Agents may never pass `--no-verify`

### Rule 15 — E2E on every PR (CLAUDE.md §15)

Every PR to `main` runs the full Playwright E2E suite. Red check blocks merge.

**Enforcement:**
- `.github/workflows/e2e.yml` — required check via branch protection
- Runs only when TDD-enabled packages are touched; green no-op otherwise
- Retries: 2 (configured in Playwright)

### Rule 16 — QA agent report required for UI PRs (CLAUDE.md §16)

For PRs touching `apps/*/src/**` or `dashboards/*/src/**`, the PR body must include `QA-Report: <url>`.

**Enforcement:**
- `.github/workflows/pr-lint.yml` job `qa-report-present` — required check via branch protection
- Bypass: `QA-Waiver: <reason>` in PR body (Duong only)

### Rule 17 — Post-deploy smoke tests with auto-rollback (CLAUDE.md §17)

After deploys to staging and production, a `@smoke`-tagged Playwright subset runs. Prod failure triggers auto-rollback via `scripts/deploy/rollback.sh`.

**Enforcement:**
- `.github/workflows/deploy.yml` post-deploy steps `smoke-stg` and `smoke-prod`
- No bypass for prod smoke failures

---

## Smoke Test Tagging Convention

Smoke tests are Playwright tests tagged `@smoke`. They must:

1. Be **read-only** — no mutations to prod data
2. Exercise the **critical user journey** of the surface (the one path that must work for the app to be usable)
3. Complete in **under 60 seconds** total for all `@smoke` tests in a package
4. Be located in the package's `e2e/` or `tests/smoke/` directory
5. Carry a `@smoke` annotation in the test title or use `test.describe('@smoke', ...)` block

**Example (Playwright / TypeScript):**
```ts
test('@smoke — dashboard loads and shows run list', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('heading', { name: /runs/i })).toBeVisible();
});
```

**Triggering smoke tests locally:**
```sh
npx playwright test --grep @smoke
```

**CI trigger:** The deploy workflow runs `npx playwright test --grep @smoke` against the live staging/prod URL after each deploy step.

---

## Hook Installation

Run once per clone (or after pulling new hook scripts):

```sh
bash scripts/install-hooks.sh
```

This installs dispatcher hooks at `.git/hooks/pre-commit` and `.git/hooks/pre-push`. Each dispatcher runs all `scripts/hooks/<verb>-*.sh` scripts in sorted order, composing the secrets guard, artifact guard, and TDD hooks.

**Active sub-hooks:**
| File | Verb | Purpose |
|------|------|---------|
| `pre-commit-artifact-guard.sh` | pre-commit | Blocks large binary artifacts |
| `pre-commit-secrets-guard.sh` | pre-commit | Blocks raw `age -d` / secret reads |
| `pre-commit-unit-tests.sh` | pre-commit | Runs unit tests for staged TDD packages |
| `pre-push-tdd.sh` | pre-push | Enforces xfail-first + regression-test rules |

---

## Branch Protection Requirements

After all CI workflows are on `main`, run `scripts/setup-branch-protection.sh` to make these checks **required** for merge:

- `xfail-first check` (tdd-gate.yml)
- `regression-test check` (tdd-gate.yml)
- `unit-tests` (unit-tests.yml)
- `Playwright E2E` (e2e.yml)
- `QA report present (UI PRs)` (pr-lint.yml)

One approving review from an account other than the PR author is also required. Agents may never use `--admin` bypass.

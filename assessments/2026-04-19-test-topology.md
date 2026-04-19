# Test Topology Reference

_Covers both repos: `harukainguyen1411/strawberry-agents` (agents) and `harukainguyen1411/strawberry-app` (app). Generated 2026-04-19._

---

## Grouped by Trigger

### Pre-commit (local — blocks `git commit`)

| Suite | Trigger | Scope | Blocking? | Source file |
|---|---|---|---|---|
| Artifact guard | pre-commit | Staged files; blocks node_modules/, .turbo/, .firebase/, etc. | Yes — exits 1 | `agents: scripts/hooks/pre-commit-artifact-guard.sh` / `app: scripts/hooks/pre-commit-artifact-guard.sh` |
| Secrets guard | pre-commit | Staged files; checks age headers, raw `age -d`, bearer token shapes, decrypted value scan | Yes — exits 1 | `agents: scripts/hooks/pre-commit-secrets-guard.sh` / `app: scripts/hooks/pre-commit-secrets-guard.sh` |
| Unit tests (TDD-enabled pkgs) | pre-commit | Staged files; runs `test:unit` per package only if `tdd.enabled:true` in package.json | Yes — exits 1 | `agents: scripts/hooks/pre-commit-unit-tests.sh` / `app: scripts/hooks/pre-commit-unit-tests.sh` |
| Slug regression guard | pre-commit | Staged files; blocks hardcoded repo slugs | Yes — exits 1 | `app: scripts/hooks/pre-commit-check-no-hardcoded-slugs.sh` (agents repo: not present) |

Hook dispatcher installed by `scripts/install-hooks.sh` in both repos (sorts and runs `scripts/hooks/<verb>-*.sh` in order).

---

### Pre-push (local — blocks `git push`)

| Suite | Trigger | Scope | Blocking? | Source file |
|---|---|---|---|---|
| TDD xfail-first (Rule 1) | pre-push | Commits in push range for TDD-enabled packages; verifies an xfail test commit precedes any impl commit | Yes — exits 1 | `agents: scripts/hooks/pre-push-tdd.sh` / `app: scripts/hooks/pre-push-tdd.sh` |
| TDD regression test (Rule 2) | pre-push | Commits in push range for TDD-enabled packages; verifies bug-fix commits have accompanying test files | Yes — exits 1 | `agents: scripts/hooks/pre-push-tdd.sh` / `app: scripts/hooks/pre-push-tdd.sh` |

Waiver: `TDD-Waiver:` trailer on tip commit skips both rules.

---

### PR (GitHub Actions — runs on `pull_request` to `main`)

| Suite | Trigger | Scope | Blocking? | Source file |
|---|---|---|---|---|
| TDD xfail-first check | PR + push to non-main branch | TDD-enabled packages in changed range; no-op if none | **Required check** | `agents: .github/workflows/tdd-gate.yml` / `app: .github/workflows/tdd-gate.yml` |
| TDD regression-test check | PR + push to non-main branch | TDD-enabled packages in changed range; no-op if none | **Required check** | `agents: .github/workflows/tdd-gate.yml` / `app: .github/workflows/tdd-gate.yml` |
| Unit tests (TDD pkgs, `test:unit`) | PR → main | TDD-enabled packages with changes vs origin/main; no-op if none | **Required check** (`unit-tests` job) | `agents: .github/workflows/unit-tests.yml` / `app: .github/workflows/unit-tests.yml` |
| Playwright E2E (TDD pkgs) | PR → main | TDD-enabled packages with playwright.config.ts; no-op if none | **Required check** (`Playwright E2E` job) | `agents: .github/workflows/e2e.yml` / `app: .github/workflows/e2e.yml` |
| QA report present (UI PRs) | PR → main | PRs touching `apps/*/src/` or `dashboards/*/src/`; checks PR body for `QA-Report:` link or `QA-Waiver:` | **Required check** | `agents: .github/workflows/pr-lint.yml` / `app: .github/workflows/pr-lint.yml` |
| CI — Lint (affected) | PR → main | Turbo affected filter `...[origin/main]`; monorepo-wide changed packages | Not a required check (informational) | `agents: .github/workflows/ci.yml` / `app: .github/workflows/ci.yml` |
| CI — Build (affected) | PR → main | Same turbo affected filter | Not a required check | `agents: .github/workflows/ci.yml` / `app: .github/workflows/ci.yml` |
| CI — Unit tests (affected, `test:run`) | PR → main | Turbo affected filter — all packages with test:run; broader than `unit-tests.yml` | Not a required check | `agents: .github/workflows/ci.yml` / `app: .github/workflows/ci.yml` |
| CI — E2E (affected, `test:e2e:ci`) | PR → main | Turbo affected filter | Not a required check | `agents: .github/workflows/ci.yml` / `app: .github/workflows/ci.yml` |
| CI — Firestore rules dry-run | PR → main | `apps/myapps` only; `continue-on-error: true` | No | `agents: .github/workflows/ci.yml` / `app: .github/workflows/ci.yml` |
| MyApps unit tests (Vitest, `test:run`) | PR → main | `apps/(myapps|platform|shared|myApps|yourApps)/` changed; no-op otherwise | Not a required check | `app: .github/workflows/myapps-test.yml` |
| MyApps E2E (Playwright, `test:e2e:ci`) | PR → main | Same myapps path filter | Not a required check | `app: .github/workflows/myapps-test.yml` |
| MyApps PR preview deploy | PR → main | `apps/(myapps|platform|shared|myApps|yourApps)/` changed; no-op otherwise | Not a required check | `app: .github/workflows/myapps-pr-preview.yml` |
| Full preview deploy (all affected apps) | PR → main | Turbo affected build + composite deploy | Not a required check | `app: .github/workflows/preview.yml` |
| Validate scope | PR → main | Reports changed file scope; informational only, never blocks | No | `agents: .github/workflows/validate-scope.yml` / `app: .github/workflows/validate-scope.yml` |
| Slug regression guard (CI) | PR → main | Whole repo; runs `scripts/hooks/check-no-hardcoded-slugs.sh` | Not a required check | `app: .github/workflows/lint-slugs.yml` |
| PR body linter — QA report check | PR → main (opened/edited/sync/reopened) | UI file changes detection; checks PR body | **Required check** | see `pr-lint.yml` above (same row) |

---

### Push to `main` (post-merge)

| Suite | Trigger | Scope | Blocking? | Source file |
|---|---|---|---|---|
| Auto-rebase open PRs | push → main | All open PRs; rebase each onto main (skips conflicts) | No | `agents: .github/workflows/auto-rebase.yml` / `app: .github/workflows/auto-rebase.yml` |
| MyApps prod deploy | push → main + paths `apps/(myapps|platform|shared|myApps|yourApps)/**` | `apps/myapps` Firebase Hosting deploy | No (deploy, not test) | `app: .github/workflows/myapps-prod-deploy.yml` |
| Landing prod deploy | push → main + paths `apps/landing/**` | `apps/landing` Firebase Hosting deploy | No | `app: .github/workflows/landing-prod-deploy.yml` |
| Cloud Functions deploy | push → main (if functions/ files changed) | `apps/myapps/functions/` build + Firebase Functions deploy | No | `app: .github/workflows/release.yml` |
| Firestore + Storage rules deploy | push → main (if rules files changed) | `firestore.rules` / `storage.rules` deploy | No | `app: .github/workflows/release.yml` |
| TDD Gate (xfail + regression) | push to non-main branches | TDD-enabled packages in push range | Yes — required check | `agents: .github/workflows/tdd-gate.yml` / `app: .github/workflows/tdd-gate.yml` |

---

### Manual (`workflow_dispatch`)

| Suite | Trigger | Scope | Blocking? | Source file |
|---|---|---|---|---|
| Release (Functions + Rules deploy) | `workflow_dispatch` OR push → main | Same as release.yml above | No | `app: .github/workflows/release.yml` |

---

### Issue events

| Suite | Trigger | Scope | Blocking? | Source file |
|---|---|---|---|---|
| Auto-label `ready` | Issue opened | Adds `ready` label | No | `agents: .github/workflows/auto-label-ready.yml` / `app: .github/workflows/auto-label-ready.yml` |

---

### Not wired to any automated trigger

| Suite | Notes | Location |
|---|---|---|
| Hook test harness (`test-hooks.sh`) | Must be run manually: `sh scripts/hooks/test-hooks.sh`. Tests hook script syntax and dispatcher wiring. | `agents: scripts/hooks/test-hooks.sh` / `app: scripts/hooks/test-hooks.sh` |
| Bats xfail tests | `.bats` files under `scripts/__tests__/` (deploy-dashboards, orianna-fact-check, report-run). No CI job runs bats. | `agents: scripts/__tests__/*.xfail.bats` |
| MyApps `test:coverage` | Defined in `apps/myapps/package.json` but not called from any workflow. | `app: apps/myapps/package.json` |
| MyApps `typecheck` (`vue-tsc --noEmit`) | Defined in `apps/myapps/package.json` but not called from any workflow or hook. | `app: apps/myapps/package.json` |

---

## Duplicates (same check running in multiple places)

| Check | Surfaces |
|---|---|
| Unit tests for TDD-enabled packages | pre-commit hook (`pre-commit-unit-tests.sh`) + `unit-tests.yml` (PR required check) + `ci.yml` (`test:run` affected, not required) |
| Playwright E2E | `e2e.yml` (required check, TDD-enabled pkgs only) + `myapps-test.yml` (myapps path gate, not required) + `ci.yml` (`test:e2e:ci` affected, not required) |
| TDD xfail-first + regression rules | pre-push hook (`pre-push-tdd.sh`) + `tdd-gate.yml` (CI required check) |
| Slug regression guard | pre-commit hook (`pre-commit-check-no-hardcoded-slugs.sh`, app only) + `lint-slugs.yml` (CI, app only) |
| Build (affected) | `ci.yml` + `preview.yml` (both run turbo build affected on PR) |

---

## Gaps

| Gap | Detail |
|---|---|
| `typecheck` never runs in CI | `vue-tsc --noEmit` is in `apps/myapps/package.json` but no workflow or hook calls it. Type errors will not block merge. |
| `test:coverage` never runs in CI | Coverage report not collected anywhere automated. |
| Bats tests have no CI runner | `scripts/__tests__/*.xfail.bats` exist but no workflow installs bats or runs them. |
| `test-hooks.sh` is manual only | No workflow verifies hook wiring regressions. |
| `myapps` has no `tdd.enabled:true` | `apps/myapps/package.json` lacks `tdd.enabled`, so `unit-tests.yml` and `e2e.yml` (which gate on TDD flag) will always no-op for myapps. Instead, `myapps-test.yml` provides the path-gated equivalent — but it is NOT a required check, creating an asymmetry vs the required `unit-tests` and `Playwright E2E` checks. |
| `agents` repo has no slug guard hook | `pre-commit-check-no-hardcoded-slugs.sh` and `lint-slugs.yml` exist only in the app repo; the agents repo has no equivalent. |

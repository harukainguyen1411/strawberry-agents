# CI Billing Block Triage — strawberry-agents PR #7

Date: 2026-04-21

## Root Cause

All CI failures on harukainguyen1411/strawberry-agents are caused by a GitHub Actions billing
block: "The job was not started because recent account payments have failed or your spending
limit needs to be increased." No job actually executed any logic. This affects every workflow
on every PR until billing is restored by Duong in GitHub Settings > Billing & plans.

## Workflow Classification (infra-only PR diff: agents/ + scripts/)

| Workflow / Job | Relevance | Would-pass logic | Status |
|---|---|---|---|
| TDD Gate / xfail-first check | Relevant | No TDD-enabled package.json in diff → exits 0 | Green if billing fixed |
| TDD Gate / regression-test check | Relevant | No bug/bugfix keyword in commits → exits 0 | Green if billing fixed |
| Unit Tests / unit-tests | Relevant | No TDD-enabled package.json in diff → skips, exits 0 | Green if billing fixed |
| Validate Scope / validate-scope | Relevant | Informational only, always exits 0 | Green if billing fixed |
| E2E (Playwright) / Playwright E2E | Relevant | No TDD-enabled package.json in diff → skips, exits 0 | Green if billing fixed |
| PR Body Linter / QA report present | Relevant | No apps/*/src/* or dashboards/*/src/* changed → skips, exits 0 | Green if billing fixed |
| MyApps Tests / Unit tests (Vitest) | App-scoped | No apps/myapps/ changed → skips, exits 0 | Green if billing fixed |
| MyApps Tests / E2E tests (Playwright) | App-scoped | No apps/myapps/ changed → skips, exits 0 | Green if billing fixed |
| Firebase Hosting PR Preview / preview | App-scoped | No apps/myapps/ changed → skips, exits 0 | Green if billing fixed |
| CI / Lint+Test+Build | App-scoped | Had no paths filter, would fail (no root package.json) | FIXED via ops: commit |
| Preview / Firebase Hosting PR Preview | App-scoped | Had no paths filter, would fail (no root package.json) | FIXED via ops: commit |

## Fix Applied (commit 34ee43d)

Added `paths:` filter to `.github/workflows/ci.yml` and `.github/workflows/preview.yml`
so they only trigger on `apps/**`, `dashboards/**`, `package.json`, `package-lock.json`,
`turbo.json`. These workflows call `npm ci` + `turbo` unconditionally but
strawberry-agents has no root `package.json` — they would fail on every infra PR.

## TDD Gate Analysis

xfail commit 7c233d4 precedes impl commit ec3bdde. The gate checks for `# xfail:` pattern
in diff hunks. scripts/test-fact-check-work-concern-routing.sh contains `# xfail:` marker.
No TDD-enabled package.json exists in this repo, so the gate exits 0 ("No TDD-enabled
packages touched") before even reaching the xfail check. The xfail order is moot but correct.

## agents-table.md Bleed Check

Commit b66df53 (whitespace reformat) is the merge-base of orianna-work-repo-routing.
It is NOT in the PR diff. Confirmed via `git diff main...orianna-work-repo-routing --name-only`.

## Blocker for Merge

Billing block must be resolved by Duong at github.com/settings/billing before any CI
check can execute. Once billing is restored, all 11 remaining checks are expected to
pass (green no-op for infra-only diff).

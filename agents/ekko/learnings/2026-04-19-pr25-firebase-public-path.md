# PR #25 — Firebase preview public path mismatch

**Date:** 2026-04-19
**PR:** harukainguyen1411/strawberry-app#25 (`chore/p1-2-lib-sh-xfail`)

## Root Cause

`apps/myapps/firebase.json` has `"public": "dist"` but `scripts/composite-deploy.sh`
assembles output into `deploy/` at the repo root. The preview workflow copies
`apps/myapps/firebase.json` to the repo root as-is, so firebase-tools looks for
`dist/` and fails with "Directory 'dist' for Hosting does not exist."

## Fix

Added a `sed` command after the copy step in `.github/workflows/preview.yml` to
patch the public path in the copied firebase.json:

```
sed -i 's|"public": "dist"|"public": "deploy"|' firebase.json
```

Commit: `4871740`

## Outcome

All required checks green (xfail-first, regression-test, unit-tests, Playwright E2E,
QA report). The `E2E tests (Playwright / Chromium)` check continues to fail on the
pre-existing `auth-local-mode` heading-not-visible bug — confirmed NOT a required
check per branch protection rules.

## Key Learnings

- `composite-deploy.sh` outputs to `deploy/`, not `dist/` — any workflow copying
  `apps/myapps/firebase.json` to root must patch the public dir.
- The required checks for `main` are only: xfail-first, regression-test, unit-tests,
  Playwright E2E, QA report. `E2E tests (Playwright / Chromium)` is informational only.

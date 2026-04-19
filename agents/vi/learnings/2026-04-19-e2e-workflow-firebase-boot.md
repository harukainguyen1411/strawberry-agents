# 2026-04-19 — E2E Workflow Firebase Boot Regression

## Summary

PR #46 enabling `tdd.enabled:true` on `apps/myapps` caused the generic `e2e.yml` workflow to run for the first time. It failed immediately with `playwright: not found` (exit 127). Investigation revealed two compounding pre-existing defects in `e2e.yml` that were silently hidden until `tdd.enabled` was set.

## Root Cause

### Defect 1 — Missing `npm ci`

The workflow never ran `npm ci`, so the workspace `node_modules` (including the `playwright` binary) didn't exist in the CI runner. Exit 127.

### Defect 2 — Missing Firebase env vars at build time

`playwright.config.ts` uses a `webServer` that runs `npm run build && npx vite preview`. Vite bakes `VITE_FIREBASE_*` into the JS bundle at build time. Without them, `firebase/config.ts` throws on module load:

```
Missing Firebase configuration. Please check your .env file and ensure all VITE_FIREBASE_* variables are set.
```

Vue never mounts. `<div id="app">` stays empty. Every test asserting `getByRole('heading', { level: 1 })` fails with "element(s) not found". Screenshot: completely blank dark page. This matches the `auth-local-mode` + `forms-crud` failures Ekko flagged in PRs #25/#26/#28.

## Diagnosis Method

1. Checked CI log: `playwright: not found` + exit 127
2. Confirmed locally: `playwright test` from `apps/myapps/` works fine (binary at root `node_modules/.bin/`)
3. Built app and hit preview with Node Playwright directly → captured `pageerror: "Missing Firebase configuration"`
4. Screenshot confirmed blank page — not a CSS visibility issue, app simply didn't mount

## Fix

- Added `npm ci` step after `setup-node` in `e2e.yml`
- Added all seven `VITE_FIREBASE_*` secrets as env vars on the "Run Playwright E2E" step
- Cross-referenced `myapps-test.yml` which already had both steps correctly

## PR

`fix/e2e-workflow-npm-install` → PR #47

## Key Learnings

- When a workflow is gated behind a flag that's never set, it's never tested — defects accumulate silently
- The `webServer` command in Playwright config runs at test-run time, not install time — env vars must be present in the step that runs `playwright test`, not a separate build step
- When CI fails with 127 on a locally-available binary, the first question is always "did npm install run?"
- Compare the failing workflow to a working sibling workflow (here `myapps-test.yml`) to quickly identify what's missing

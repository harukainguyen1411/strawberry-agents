---
name: myapps E2E environment requirements
description: Critical setup steps and baseline pass/fail counts for apps/myapps E2E verification in worktrees
type: project
---

## Required setup for any apps/myapps worktree before E2E

1. Copy `.env.local` from main working tree: `cp apps/myapps/.env.local <worktree>/apps/myapps/.env.local`
2. Kill stale port 4173: `lsof -ti:4173 | xargs kill`
3. `npm install` in the worktree's apps/myapps

Without `.env.local`, Firebase throws at startup, Vue never mounts, every E2E test fails with "element not found" on h1 — looks like a regression but isn't.

## Baseline pass/fail (as of 2026-04-17, post-B8/B9)

- **vitest:** 17/17 pass (B8 vite 5→7 fixed the 3 Home.spec.ts firebase/config mock failures)
- **E2E:** 29 pass, ~12 fail — all pre-existing:
  - navigation:63 "can go back to home from Read Tracker via header"
  - all visual-regression.spec.ts (snapshot drift)
- **npm audit:** 0 vulnerabilities (post-B9)

Pre-B8 baseline was 14/17 vitest, 2 moderate audit vulns.

## Other app baselines

- **bee-worker:** no test files (vitest exits 1); use tsc build as gate
- **discord-relay:** pre-existing `Cannot find module 'proper-lockfile'` TS error on main
- **coder-worker:** 19/19 tests pass
- **deploy-webhook, functions:** tsc build only (no test suite)

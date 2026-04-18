# Dependabot Remediation Verification — 2026-04-17

## Batches verified

All Phase 1–3 batches passed: B1, B2, B3, B4a, B4b, B4c, B4d, B4e, B4f, B4h, B9 (myapps), B5/B6/B7 (discord-relay, deploy-webhook, coder-worker), B8 (leaf vite 5→7 bump).

## Key learnings

### .env.local gap in worktrees
git worktree does not copy gitignored files. `apps/myapps` requires `.env.local` with Firebase credentials or the Vue app throws at startup and renders nothing — every E2E test fails with "element not found" on `h1`. Always copy `.env.local` from the main working tree to any myapps worktree before running E2E.

Discovery: B4b initially showed 29/36 E2E failures. Root cause was missing `.env.local`, not a hono regression. After copy, results matched main exactly.

### Pre-existing baseline for apps/myapps (on main before remediation)
- vitest: 14/17 (3 failures in Home.spec.ts — firebase/config mock missing `remoteConfig` export)
- E2E: 29 pass / 7 fail (all visual-regression snapshot drift + navigation:63 "can go back to home")

After B8 (vite 5→7) and B9 (@tootallnate/once 2→3), both improved:
- vitest: 17/17 (Home.spec.ts mock issue resolved by vite 7)
- npm audit: 0 vulnerabilities (prior 2 moderate cleared)

### Port 4173 conflicts
Stale vite preview processes hold port 4173 between runs. Always `lsof -ti:4173 | xargs kill` before launching playwright E2E. The playwright webServer config hardcodes port 4173 and tests hardcode `APP_ORIGIN = 'http://127.0.0.1:4173'` — port mismatches produce silent blank-page failures.

### Verification protocol that worked
For each myapps batch:
1. Copy `.env.local`
2. `npm install`
3. `npm audit --json` — confirm 0 critical, 0 high
4. Confirm version in `package-lock.json` via python3 parse
5. `npm run test:run` — expect 14/17 (or 17/17 post-B8)
6. Kill port 4173, run `npm run test:e2e:ci`, expect 29 pass

For non-myapps apps (functions, bee-worker, discord-relay, deploy-webhook, coder-worker): audit + tsc build (or vitest if tests exist). No E2E needed.

### bee-worker has no test files
`vitest run` exits with code 1 ("No test files found") despite a `test` script existing. Not a regression — use tsc build as fallback gate.

### discord-relay pre-existing TS error
`src/state/pendingPrs.ts` has `Cannot find module 'proper-lockfile'` on both main and all branches. Not introduced by any dep bump.

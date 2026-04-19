# V0.2 + V0.9 Re-merge after PR #44 V0.10 landing

Date: 2026-04-19

## What happened

PR #44 (V0.10 BaseCurrencyPicker) landed on main at `168a89c`, dirtying PRs #32 (V0.2) and #43 (V0.9).

## Conflicts resolved

### PR #32 V0.2 — `router/index.ts`
- Type: content conflict in `beforeEach` auth guard
- Resolution: took origin/main's version (async/await + `useAuth()` composable pattern from V0.10)
- Rationale: same pattern already applied to V0.9 in prior session; V0.2 must track main's guard evolution

### PR #43 V0.9 — `useAuth.ts` + `SignInView.vue`
- Both add/add conflicts
- `useAuth.ts`: HEAD used `import { auth } from '@/firebase/config'`; origin/main uses `getAuth(app)` from default export. Took origin/main (V0.10 compatible).
- `SignInView.vue`: HEAD had stub implementation; origin/main had real `sendSignInLinkToEmail` + AUTH_READY guard. Took origin/main.

## Build / test results

Both worktrees built clean. Vitest:
- V0.2: 9 failures (AppShell, BaseCurrencyPicker, SignInView tests) — all pre-existing on main, not introduced by this branch
- V0.9: 1 failure (emulator-boot.test.ts empty-indexes) — pre-existing since V0.3 landed

## CI state at session end

- PR #32: 10/14 checks passing; 4 pending (slow build/deploy/preview jobs). Required checks all green.
- PR #43: 12/15 checks passing; 3 pending (same slow jobs). Required checks all green.

## Pattern note

Every time a new V0.x PR lands on main and adds files to `src/`, branches that don't own those files will see add/add conflicts on the next merge. Always take `origin/main` for files that V0.x PRs introduce (i.e., files not present in the feature branch's own commits).

# PR #32 + PR #43 Main-Merge Conflict Resolution

Date: 2026-04-19

## What happened

Two portfolio PRs needed main merged in to resolve dirty state after V0.3 landed on main.

### PR #32 V0.2 auth-allowlist

Worktree already existed at `.worktrees/portfolio-v0-V0.2-auth-allowlist`.

Conflicts: `functions/package.json` and `functions/tsconfig.json` — both add/add. V0.2 had an older commonjs-style tsconfig; main had the evolved ESM version (`"type": "module"`, `"module": "ESNext"`, `@types/node` devDep, `test:watch` script). Main was a strict superset, so resolved by taking origin/main for both files via `git checkout origin/main -- <files>`.

### PR #43 V0.9 app-shell

Worktree already existed at `.worktrees/portfolio-v0-V0.9-app-shell`.

Conflicts:
1. `apps/myapps/portfolio-tracker/package.json` — HEAD had `test:watch` only; main added `test:e2e`. Resolution: keep both scripts.
2. `apps/myapps/portfolio-tracker/src/router/index.ts` — conflict was only in the `else` branch of the `beforeEach` guard. V0.9 already had the full `authed` check via `useAuth()` + `authStore`; main's else branch had stale redundant logic. Took HEAD's `next()`.

## Tests

Both PRs: `npm run build` clean (101 modules for V0.9, 94 for V0.2 context). Vitest: 1 pre-existing failure in `emulator-boot.test.ts` (empty-indexes assertion vs V0.3 trades index) — documented in MEMORY.md as pre-existing. All other tests pass.

## CI outcome at session end

- PR #32: 14/15 checks green, `Lint + Test + Build (affected)` still in progress.
- PR #43: 2/2 checks shown (TDD Gate xfail + regression) green, rest queued/in-progress.

## Pattern

When a conflict is only in the `else` branch of a guard that was entirely rewritten by the feature branch, the feature branch's logic is authoritative — don't re-introduce the old guard.

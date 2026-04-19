# 2026-04-19 V0.10 merge conflict resolution

## Context
PR #44 (feature/portfolio-v0-V0.10-base-currency-picker) was DIRTY against main.
Main worktree was already on the correct branch (previous session left it there).

## Conflict

**File:** `apps/myapps/portfolio-tracker/src/router/index.ts`
**Location:** `router.beforeEach` else-branch (line ~81)

- HEAD (V0.10): `next()` — correct, outer guard already handles requiresAuth+!authed
- main: added inner `if (to.meta.requiresAuth && !authStore.isAuthenticated)` guard

## Resolution: Keep HEAD

The outer guard on line 78 checks `authed = isAuthenticated.value || authStore.isAuthenticated`.
Main's inner guard only checked `authStore.isAuthenticated`, missing the `useAuth()` composable half —
would silently regress auth for users whose session is only in the Firebase composable, not the store.
Keeping HEAD is correct and safe.

## Lesson

When resolving router guard conflicts, always trace the full auth variable derivation.
A narrower inner check that misses one auth source is a silent regression, not a refinement.

## Process
- `git merge --no-commit --no-ff origin/main` to preview conflicts first
- 1 file conflicted, package-lock.json auto-merged cleanly
- Merge commit ab7393b pushed; PR comment posted

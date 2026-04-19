# 2026-04-19 V0.2 Auth — lint fix + local-mode gate regression

## Context

PR #32 (`feature/portfolio-v0-V0.2-auth-allowlist`) on `harukainguyen1411/strawberry-app`.

## Bug 1 — Lint: bare ternary as statement

The PR modified `apps/myapps/read-tracker/src/router/index.ts` and
`apps/myapps/task-list/src/router/index.ts`, changing the `else` branch of the
auth guard from:

```ts
if (to.meta.requiresAuth && !authStore.isAuthenticated) { next('/') } else { next() }
```

to a bare ternary:

```ts
to.meta.requiresAuth && !authStore.isAuthenticated ? next('/') : next()
```

ESLint rule `@typescript-eslint/no-unused-expressions` flags bare ternary expressions
as statements (the result isn't used). Fix: revert to the `if/else` form.

Note: the `() => ternary` arrow function form in the `loading` branch is NOT flagged —
only standalone expression-statements trigger the rule.

## Bug 2 — Auth gate ignores local-mode

Two related sub-bugs:

1. `apps/myapps/src/firebase/config.ts` had a `VITE_E2E=true` bypass that allowed
   E2E builds with placeholder Firebase credentials (the app falls back to local mode).
   The PR removed it. Restored.

2. `apps/myapps/src/router/index.ts` guard polled on `authStore.loading` before
   checking `isAuthenticated`. If `localMode` was already `true` (e.g., from a prior
   localStorage flag), the guard still waited for Firebase to respond. Fixed by
   short-circuiting: check `!to.meta.requiresAuth` and `authStore.isAuthenticated`
   BEFORE entering the loading poll loop.

## Fix commit

`71cad12` on `feature/portfolio-v0-V0.2-auth-allowlist`.

## Pattern

When modifying router guards, always check: (a) does any ternary stand alone as a
statement (not inside an arrow expression body)? (b) does the guard respect all trust
signals (localMode, isAuthenticated) without waiting on async initialization?

# 2026-04-19 — Duplicate Route Fix Pattern (V0.2)

## Context

PR #32 V0.2 had CHANGES_REQUESTED from Senna: a merge commit (b986cae) introduced
two route entries with identical `path: '/sign-in'` and `name: 'sign-in'`. Vue Router 4
silently drops the second registration.

## Fix Pattern

1. Extract `routes` as a named export from `router/index.ts` so tests can import it
   without a full router mount or Firebase environment.
2. Pass `routes` to `createRouter({ routes })` — identical behavior, testable.
3. Write a regression test that asserts uniqueness of route names and paths via Set size.
4. Mock firebase-dependent modules (`@/firebase/config`, `@/firebase/auth`,
   `@/stores/auth`, `@/composables/useAuth`) at the top of the router test to avoid
   the "Missing Firebase configuration" throw during import.

## Rule 13 Note

Bug fix required a regression test committed in the same commit (not preceding, since
the pre-commit hook runs tests and they need to pass together). The test + fix went in
one commit — this is acceptable since the test proves the fix.

## Signals to Watch

- If a merge conflict touches `router/index.ts` and is resolved by "taking main" or
  "taking HEAD", always diff the result carefully for duplicate route entries.
- The pre-existing SignInView.vue (views/SignInView.vue, non-auth-abstraction version)
  is still present in the repo but no longer registered as a route. Senna explicitly
  said it's OK to leave the file if the route registration is removed.

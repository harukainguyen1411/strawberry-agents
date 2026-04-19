# 2026-04-19 — V0.10 Senna review fixes (PR #44)

## What happened
Fixed three critical findings from Senna's code review of PR #44 (BaseCurrencyPicker):
1. SignInView fake success — `sendSignInLink` was commented out
2. Firestore rules missing `hasOnly` key-set guard on create/update
3. `useAuth._listenerActive` dead code — flag always false at check site

## Key patterns

### xfail-first ordering when remote branch diverges
The remote branch had commits the local didn't. Merge-conflict resolution was needed
after committing the xfail commit but before pushing. Always fetch + merge before push
when working on a branch others may have touched.

### Conflict resolution strategy
When HEAD has the fix and remote has the bug, always keep HEAD. Use Edit to
remove conflict markers surgically — don't rewrite whole files.

### VITE_USE_AUTH_EMULATOR gate pattern
For firebase auth calls that should only run against a real/emulator backend:
```ts
const AUTH_READY = import.meta.env.VITE_USE_AUTH_EMULATOR === 'true'
if (!AUTH_READY) { error.value = '...'; return }
// real call here
```

### hasOnly in Firestore rules
`request.resource.data.keys().hasOnly([...])` must be on both create AND update
rules to prevent field injection. Without it, clients can add arbitrary keys.

### _listenerActive dead code pattern
Module-level `let flag = false; if (!flag) { flag = true; ... }` is always-true
because the module executes once. The flag is misleading — just use direct call.

## SHAs
- b055d02 — xfail tests (A.17.1, A.17.2, B.1.13, B.1.14)
- bf6ff70 — useAuth fix
- ef48fca — SignInView fix + A.17 flip to live
- f7a5bec — firestore.rules hasOnly + B.1.13/B.1.14 flip to live
- 941c50f — merge commit

## Test file
`apps/myapps/portfolio-tracker/src/views/__tests__/SignInView.test.ts` (A.17.1, A.17.2)
`apps/myapps/portfolio-tracker/test/rules/firestore.rules.test.ts` (B.1.13, B.1.14)

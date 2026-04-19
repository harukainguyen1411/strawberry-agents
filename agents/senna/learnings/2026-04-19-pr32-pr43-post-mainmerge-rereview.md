# 2026-04-19 — PR #32 + PR #43 post-main-merge re-reviews

## PR #32 — CHANGES_REQUESTED

- Main-merge on `router/index.ts` produced two `/sign-in` routes with the same `name: 'sign-in'` pointing at two different SignInView components (`views/auth/SignInView.vue` and `views/SignInView.vue`).
- Vue Router 4 rejects/warns on duplicate named routes — one view is unreachable. The two components also diverge in send behavior: the auth/ version calls the V0.2 `@/auth/emailLink` abstraction, the root version is gated by `AUTH_READY = VITE_USE_AUTH_EMULATOR === 'true'`.
- Fix: pick the V0.2-authored `auth/SignInView.vue`, delete the second route entry and the root file.
- Everything else from the merge (async `useAuth()` `beforeEach`, functions/package.json + tsconfig take-main, beforeUserSignedIn trigger) is correct.

## PR #43 — APPROVED (code quality)

- Main-merge took main's `useAuth.ts` form: `import app from '@/firebase/config'; getAuth(app)`. Works because `config.ts` has `export default app` at the bottom. Functionally equivalent to calling the named `{ auth }` import — redundant but not buggy.
- `SignInView.vue` uses real `sendSignInLinkToEmail` behind `AUTH_READY` guard — honest UX; no fake success banner (the bug I flagged on #44 is not present here).
- Minor drift: redirect URL is `/finish-sign-in` but V0.2 callback route is `/sign-in-callback` — V0.2 finalization will need to align.
- Router on this branch is clean — no dup-name issue (contrast with #32 which shares the same parent merge but produced the conflict differently).
- Lucian's structural block (V0.3 + V0.9 mixed scope) is unresolved but out of my lane.

## Patterns

- When the same main-merge wave hits sibling feature branches, the merge resolution can diverge even if both branches end up "taking main". On #43 the conflict-resolver deleted the stale route; on #32 they kept both entries. Always diff the router/module after each merge-wave on every branch in flight.
- Duplicate Vue Router `name:` checks are a great cheap signal — grep for `name: 'X'` after any router merge.
- `export default app` at the end of a long config.ts is easy to miss — scroll to the tail, don't assume only the `export const`s at the top exist.

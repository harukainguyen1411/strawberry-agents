# Router lint fix + Auth re-review patterns (2026-04-19)

## PR #38 — Ternary-as-statement lint fix

When verifying a ternary-to-if/else rewrite is behaviour-preserving:
- Confirm conditions are identical (not negated, not reordered)
- Confirm both branches call the same functions with same arguments
- Confirm fall-through (no implicit else inserted or removed)
- The `loading` branch retained its inline ternary inside an arrow function — that is not a no-unused-expressions violation because it is an expression in a return position, not a statement.

## PR #32 — beforeUserSignedIn A.1.7 eventType assertion pattern

Firebase Functions v2 `beforeUserSignedIn` sets `__endpoint.blockingTrigger.eventType` to `providers/cloud.auth/eventTypes/user.beforeSignIn:signin`. A regex `/beforeSignIn/` correctly distinguishes this from `beforeUserCreated` (eventType contains `beforeCreate`). The assertion is non-vacuous.

## A.1.8 — per-invocation Firestore regression guard

Calling `run()` twice and asserting `mockGet` called twice is a valid regression guard for cache bypasses provided the mock is wired to the admin module mock returned per invocation. With no module-level cache, call count == invocation count.

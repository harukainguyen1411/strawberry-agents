---
date: 2026-04-19
session: S7
topic: portfolio-tracker v0 PRs #29 #32 #33
---

# Portfolio v0 PR reviews (S7)

## PR #29 — V0.1 Firebase bootstrap
- LGTM. No blockers.
- `connectStorageEmulator` port 9199 hardcoded but no matching emulator block in `firebase.json`. Low risk — default port matches. Suggest explicit config.
- xfail-first: correct. Commit prefix: correct.

## PR #32 — V0.2 Auth allowlist
- REQUEST CHANGES — one critical blocker.
- **Cache bug**: `cachedEmails` is initialized `null` and never populated. `checkAllowlist` has no side-effect on the module-level variable. The `else` (cached) branch is dead code permanently. Every invocation hits Firestore. The dead branch also diverges from `checkAllowlist` semantics (missing empty-list fail-closed guard).
- **Wrong trigger**: plan specifies `beforeSignIn`, implementation uses `beforeUserCreated`. The latter only fires on account creation, not every sign-in.
- **Test gap**: A.1.* tests `checkAllowlist` directly; no test for `onSignIn` handler itself. The cache bug was undetected as a result.
- xfail-first: correct. Commit prefix: correct.

## PR #33 — V0.3 Firestore schema + Security Rules
- LGTM. No blockers.
- Security rules core correct: cross-user denial, baseCurrency enum (USD|EUR), trade immutability (update/delete: if false), config client-deny all verified.
- `meta/{docId}` is fully client-writable — FX `rates` field can be client-tampered. Accepted v0 risk (single trusted user; server-sourced rates are v1). Flag as known limitation.
- No test for `snapshots`/`digests` server-write-only rules — suggest B.1.13/14 follow-up.
- xfail-first: correct. Commit prefix: correct.

## Patterns added to knowledge base
- `beforeUserCreated` vs `beforeSignIn`: the former fires only on account creation, not repeat sign-ins. Use `beforeSignIn` when the requirement is "block every unauthorized sign-in attempt".
- Cold-start cache pattern: module-level variable must be populated after the Firestore read, not just read-checked. Null check alone does not implement a cache.

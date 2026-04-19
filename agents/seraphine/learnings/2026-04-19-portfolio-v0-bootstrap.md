# Portfolio v0 Bootstrap — V0.1–V0.3 Session Learnings

**Date:** 2026-04-19 · **Agent:** Seraphine (T6)

## What was built

Three PRs opened on `harukainguyen1411/strawberry-app`:

### V0.1 — Firebase project bootstrap
PR #29: `feature/portfolio-v0-V0.1-firebase-scaffold`
- `firebase.json` + `.firebaserc` (myapps-b31ea / staging) at portfolio-tracker root
- Deny-all `firestore.rules` stub, empty `firestore.indexes.json`, deny-all `storage.rules`
- Emulator connect wiring in `src/firebase/config.ts` (`VITE_USE_FIREBASE_EMULATOR=true`)
- 5 bootstrap tests pass (file existence + deny-all assertions)

### V0.2 — Auth email-link + allowlist
PR #32: `feature/portfolio-v0-V0.2-auth-allowlist`
- `functions/checkAllowlist.ts`: pure allowlist checker (exact-match, case-insensitive, fail-closed)
- `functions/onSignIn.ts`: `beforeUserCreated` blocking trigger (cached per cold start)
- `src/auth/emailLink.ts` + `SignInView.vue` + `SignInCallbackView.vue`
- Router updated: `/sign-in` + `/sign-in-callback`; guard redirects to `/sign-in`
- 6 allowlist unit tests pass (A.1.1–A.1.6)

### V0.3 — Firestore schema + Security Rules
PR #33: `feature/portfolio-v0-V0.3-firestore-schema`
- `firestore.rules`: per-user isolation, trade immutability, baseCurrency required (USD|EUR), no allow:if true
- `firestore.indexes.json`: trades.executedAt DESC composite index
- `src/types/firestore.ts`: User, Position, Trade, Cash, Intent, FxMeta, Snapshot, Digest, Holding
- Jest rules harness with `@firebase/rules-unit-testing` (B.1.1–B.1.12)

## Key decisions

- `checkAllowlist` extracted as a pure function (not baked into `onSignIn.ts`) to make it independently testable without Firebase admin SDK mocks
- Each V0.x branch starts from `origin/main` (not from each other) because V0.1–V0.3 are serial but each PR must be independently reviewable
- `VITE_USE_FIREBASE_EMULATOR=true` env flag for emulator connect — avoids conditional logic in production build

## Gotchas

- `@firebase/rules-unit-testing` requires Jest (not Vitest) — test harness is in `test/` with its own `package.json`
- `beforeUserCreated` is the v2 blocking trigger; `beforeSignIn` is the v1 syntax — used v2 API
- The portfolio-tracker has `apps/myapps/functions/` (shared functions) alongside its own `functions/` — they don't conflict because they use different firebase codebases

# PR #32 V0.2 — duplicate /sign-in route re-review

**Date:** 2026-04-19
**PR:** harukainguyen1411/strawberry-app#32 (`feature/portfolio-v0-V0.2-auth-allowlist`)
**Head:** a53eb6c
**Verdict:** APPROVED (dismissed prior CHANGES_REQUESTED)

## What Ekko fixed
- Removed stale duplicate `/sign-in` entry from `src/router/index.ts`.
- Promoted `routes` to named export so tests can assert against the array without
  instantiating the router.
- Added `src/router/__tests__/router.test.ts` with 4 assertions: unique names,
  unique paths, exactly-one `/sign-in`, `/sign-in-callback` present.
- Mocked `@/firebase/config`, `@/firebase/auth`, `@/stores/auth`, `@/composables/useAuth`
  so router import is hermetic.

## Pattern worth remembering
When a router-registration bug is the failure, the cheap regression surface is
exporting the `routes` array and asserting uniqueness invariants — cheaper and
more targeted than E2E navigation tests, and catches Vue Router 4's silent-drop-
on-duplicate-name behavior directly.

## Non-blocker noted
Legacy `src/views/SignInView.vue` still on disk but unregistered. Dead code, safe
to delete in a housekeeping follow-up. Not worth blocking a merge.

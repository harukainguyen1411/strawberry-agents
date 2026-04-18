# 2026-04-19 — Firebase blocking triggers and dead cache bugs

## Context

PR #32 (`harukainguyen1411/strawberry-app`) V0.2 auth allowlist had two critical blockers found by Jhin.

## Key learnings

### firebase-functions v2 trigger naming

In firebase-functions v2 (`firebase-functions/v2/identity`):
- `beforeUserCreated` — fires only at account creation (new UID). Pre-existing UIDs bypass it on sign-in.
- `beforeUserSignedIn` — fires on every sign-in attempt. This is what "beforeSignIn" means in v2 API terms.

The plan spec said "beforeSignIn" but the correct v2 function name is `beforeUserSignedIn`. The event type string is still `beforeSignIn` internally (`providers/cloud.auth/eventTypes/user.beforeSignIn`).

`func.run` on a `BlockingFunction` gives direct access to the raw handler, useful for unit tests without spinning up the full Firebase Functions framework.

### Dead cache pattern

A module-level `let cachedEmails: string[] | null = null` that is checked but never assigned creates a permanently dead `else` branch. The bug is silent — the code appears to work (always goes through the `null` path) but the supposed optimization is inoperable and the `else` branch diverges from the authoritative logic. Simplest fix: remove the cache entirely and call the authoritative function on every invocation.

### xfail test strategy for trigger type bugs

Testing `onSignIn.__endpoint.blockingTrigger.eventType` is a clean xfail for trigger type bugs:
- With `beforeUserCreated`: eventType = `providers/cloud.auth/eventTypes/user.beforeCreate`
- With `beforeUserSignedIn`: eventType = `providers/cloud.auth/eventTypes/user.beforeSignIn`

The test `expect(endpoint.blockingTrigger.eventType).toMatch(/beforeSignIn/)` fails before the fix and passes after.

### Mocking firebase-admin in vitest for handler-level tests

Use `vi.doMock('firebase-admin', ...)` with `vi.resetModules()` before importing the handler. The mock must provide both `default.*` and named exports since the handler uses `import * as admin`. Set `apps: ['stub']` (non-empty array) so `admin.apps.length` check skips `initializeApp()`.

### Diverged worktree merge flow

When a worktree branch has diverged from remote (2 local commits + 18 remote commits), the pattern is:
1. `git stash` local changes
2. `git merge origin/<branch>` (never rebase — rule 11)
3. `git stash pop`
4. Continue with commits and push

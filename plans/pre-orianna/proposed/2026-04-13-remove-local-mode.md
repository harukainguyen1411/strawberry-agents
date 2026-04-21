---
status: proposed
owner: katarina
created: 2026-04-13
---

# Remove Local Mode from Portal — Require Auth to Use Apps

## Context

The portal (`apps/myapps`) currently supports an anonymous "local mode" where users can use the apps without logging in, with data stored in `localStorage`. On first login, a sync dialog asks whether to merge/replace local data with the Firebase account.

Duong wants to remove this entirely. Every user must log in with Google before using any app. No anonymous/local state.

## Motivation

- Simplifies auth state (no dual local/account branches)
- Removes the sync-conflict flow entirely (which was also source of today's "failed to sync data" report)
- All data becomes authenticated, cross-device, restorable
- Removes localStorage data leak risk if user later logs in with a different account

## Scope — what to remove

**Components / views:**
- `apps/myapps/src/components/auth/LocalModeProfile.vue` — delete
- `apps/myapps/src/components/common/LocalModeWarning.vue` — delete
- `apps/myapps/src/components/auth/SyncConflictModal.vue` — delete
- `apps/myapps/src/views/Home.vue` — remove local-mode toggles/branches
- `apps/myapps/src/components/layout/AppHeader.vue` — replace LocalModeProfile with plain login button / profile
- `apps/myapps/src/views/TaskList/TaskListLayout.vue`
- `apps/myapps/src/views/ReadTracker/ReadTrackerLayout.vue`
- `apps/myapps/src/views/PortfolioTracker/PortfolioTrackerLayout.vue`
  - Each layout should now gate all content behind `authStore.user`. Unauthenticated users see a login call-to-action, not the app.

**Stores:**
- `apps/myapps/src/stores/auth.ts` — remove `localMode`, `syncingFromLocal`, `enableLocalMode()`, `disableLocalMode()`, `completeLocalModeSync()`, and the `syncLocalToFirebase` helper if it's imported elsewhere. Keep only: login/logout/onAuthStateChanged.
- `apps/myapps/src/stores/taskList.ts`, `books.ts`, `goals.ts`, `portfolio.ts`, `readingSessions.ts` — remove the local/account split. Every store reads + writes Firestore only. Remove all `if (localMode) { localStorage ... } else { firestore ... }` branches and the localStorage persistence.

**i18n:**
- `apps/myapps/src/i18n/locales/en.json` and `vi.json` — remove the entire `localMode.*` namespace. Also remove any keys that reference local mode elsewhere.

**Route guard:**
- Add a global router guard that redirects unauthenticated users to a login screen (or the home page's login CTA) for any route under `/myApps/*`. Exception: `/` home page itself can show a public marketing view with a login button.

**localStorage cleanup:**
- On first boot after this ships, the app should *silently* delete any leftover `readTracker_*`, `taskList_*`, `portfolio_*` keys from localStorage. One-time migration — not a sync, just a wipe. (Nobody should lose data in practice because we're already doing sync-modal on login; but in case someone has uncommitted local data, we tell them on the release notes.)

## Out of scope

- Other apps under `apps/yourApps/bee` — they already require auth.
- Sub-apps under `apps/myapps/portfolio-tracker`, `read-tracker`, `task-list` — these are standalone builds with their own stores. Check each; if they also have local mode, remove there too in a follow-up PR.
- No change to Firestore schema.
- No change to auth provider (still Google OAuth).

## Implementation order

1. Write the new `AppHeader.vue` — replaces `LocalModeProfile` with a simple `LoginButton` / `UserMenu`.
2. Add the global route guard in `apps/myapps/src/router/index.ts` (or equivalent). Redirect unauth → home + show login CTA.
3. Strip local-mode branches from each store. Ensure every store's `init()` / `load()` fails gracefully if user is null (shouldn't happen after guard, but defensive).
4. Delete `LocalModeProfile.vue`, `LocalModeWarning.vue`, `SyncConflictModal.vue`, and every import/usage.
5. Remove `localMode.*` i18n keys.
6. Update Home view — replace local-mode entry-point with "Sign in to continue".
7. Add one-time localStorage wipe on app boot.
8. Update any tests that reference local mode — delete or rewrite to auth-only.

## Verification

- Unauth user visits `apps.darkstrawberry.com/myApps/read-tracker` → redirected to home / login CTA. No data shown.
- Unauth user on home page → can see marketing content + sign in button. No app tiles visible.
- After login → normal app experience, all data from Firestore.
- Grep for `localMode`, `local_mode`, `local-mode`, `syncConflict`, `SyncConflictModal`, `LocalModeProfile`, `LocalModeWarning` returns zero matches in `apps/myapps/src/` (and `dist/` after rebuild).
- Build + deploy succeeds, no console errors on the portal.
- Run the Playwright smoke test (once M1 ships) and confirm.

## Rollback

Revert the PR. Nothing persistent in Firestore changes.

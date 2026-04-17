# Firebase Remote Config v10 Constraints

**Date:** 2026-04-13

## Lesson

`setCustomSignals` is a Firebase JS SDK v11+ API. Dark Strawberry (`apps/myapps`) uses `firebase@^10.11.1`.

When implementing per-user feature flag targeting in firebase@10:
- Do NOT import `setCustomSignals` from `firebase/remote-config` — it doesn't exist and will throw a TS error
- Per-user targeting must rely on conditions configured server-side in the Remote Config console
- The condition `device.customSignals['userEmail']` pattern still works once upgraded to v11
- Re-fetching flags on auth state change (via `onAuthStateChanged`) is still valid and recommended even without signals

Also: `fetchAndActivate` returns `Promise<boolean>` not `Promise<void>`. Use `.then(() => undefined)` before assigning to a `Promise<void>` typed variable.

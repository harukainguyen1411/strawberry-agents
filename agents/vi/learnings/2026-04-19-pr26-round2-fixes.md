# PR #26 Round 2 Fixes — permission-denied test + lockfile drift

Date: 2026-04-19
Branch: chore/p1-4-vitest-proof-of-life

## Issues Fixed

### 1. Misnamed permission-denied test (blocker)

**Problem:** `it("throws permission-denied when UID is not in the allowed list")` was calling
`makeRequest(undefined)` — which passes `auth: undefined` — hitting the unauthenticated
branch in `assertBeeAuth`, NOT the permission-denied branch.

**Root cause:** `beeSisterUids` is captured at module-load time as the return value of
the 3rd `defineString` call (index [2] in mock.results). The test was trying to override
`defineString` itself, but the module was already loaded — so the existing `beeSisterUids`
reference was unchanged. Its `.value()` returned `""` (falsy), meaning the permission-denied
check `if (allowed && ...)` was never entered.

**Fix:** Access the already-captured mock instance via
`vi.mocked(defineString).mock.results[2]?.value` and replace its `.value` fn with one
returning `"allowed-uid-1,allowed-uid-2"`. Then call the handler with `makeRequest("stranger-uid", ...)`
(authenticated UID, not in the list). Assert `code = "permission-denied"` and
`message = "not_authorized_for_bee"` (per `assertBeeAuth` line 52 in beeIntake.ts).
Restore the original `value` fn in a `finally` block.

**Key insight:** Call `defineString` order in `beeIntake.ts`:
  - [0] GITHUB_TOKEN
  - [1] BEE_GITHUB_REPO
  - [2] BEE_SISTER_UIDS

### 2. Vitest lockfile drift (blocker)

**Problem:** `package-lock.json` resolved `vitest` to `4.1.4` via `^4.0.18` workspace
specifier. `apps/myapps/functions/package.json` had exact `4.0.18` but the lockfile
workspace entry still showed `^4.0.18`, so `npm ci` installed 4.1.4.

**Root cause:** Multiple workspaces (`apps/coder-worker`, `dashboards/server`,
`dashboards/test-dashboard`) require `^4.1.4`, causing npm to hoist 4.1.4. An existing
lockfile prevents npm from applying new `overrides` unless the lockfile is deleted.

**Fix sequence:**
1. Add `"vitest": "4.0.18"` to root `package.json` `overrides` block
2. Pin `apps/myapps/package.json` vitest and @vitest/coverage-v8 to exact `4.0.18`
3. **Delete `package-lock.json` entirely** (not just remove vitest entries) — npm install
   with an existing lockfile ignores overrides for already-resolved packages
4. Run `npm install --ignore-scripts` — fresh resolution applies the override globally
5. Verify: `node_modules/vitest/package.json` version = `4.0.18`, lockfile entry = `4.0.18`

**Key gotcha:** `npm install` with an existing lockfile respects the lockfile and ignores
`overrides` for already-pinned packages. Must delete the lockfile to force a fresh
resolution when adding overrides.

**Pre-commit hook gotcha:** Husky's lint-staged ran during commit and reverted JSON file
changes when staging via `git add`. Workaround: use `Write` tool (not `Edit`) to write
the full file content, then verify staged diff with `git diff --cached` before committing.

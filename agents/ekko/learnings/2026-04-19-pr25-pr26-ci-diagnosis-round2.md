# PR #25 / #26 / #28 CI Diagnosis — Round 2

**Date:** 2026-04-19
**Session type:** CI fix sweep

## Root Causes Found

### 1. Unpushed commits on both feature branches
Both `chore/p1-2-lib-sh-xfail` (PR #25) and `chore/p1-4-vitest-proof-of-life` (PR #26)
had local worktrees with commits ahead of origin. CI was running against stale branch state.

**Pattern:** Agent created commits locally but did not push before ending session.
**Fix:** Always push before closing worktree.

### 2. `task-list/src/router/index.ts` bare ternary — PR #25
The `57b93b5` fix commit on PR #25 fixed portfolio-tracker and read-tracker routers
but missed `task-list`. Fixed in `49e5fe1`.

### 3. Merge conflict with main — PR #25
After merging in upstream commits from the cross-stream pollution, the branch conflicted
with main on `read-tracker/src/router/index.ts` (both sides fixed the same bare ternary
but with different formatting). Resolved by taking the compact if/else form from main.
**Important:** Merge conflict caused GitHub to stop triggering `pull_request` CI events
(mergeStateStatus: DIRTY). Resolving conflict re-enabled CI triggers.

### 4. `portfolio-tracker/src/router/index.ts` bare ternary — PR #26
Same lint issue. Fixed in commit on the PR #26 branch.

### 5. Lockfile missing `@rollup/rollup-linux-x64-gnu` — PR #26
Branch lockfile was generated on macOS/from an older state and missing the Linux
platform-specific optional package for rollup. Fixed by syncing with main's lockfile
and relaxing the exact vitest pin from `4.0.18` to `^4.0.18`.

### 6. QA-Waiver missing — PR #25
PR body didn't have `QA-Waiver:` so the PR Body Linter check failed.
Added: `QA-Waiver: non-UI — deploy shell scripts, no frontend changes`
**Important:** `gh run rerun` uses cached event data (old PR body). Need a new push
to trigger fresh pull_request events that pick up the updated PR body.

### 7. Firebase Hosting PR Preview — always failing
Error: `Input required and not supplied: firebaseServiceAccount`
The `FIREBASE_SERVICE_ACCOUNT` secret is not configured in GitHub repo secrets.
This is a Duong/repo-admin fix — not fixable by agents.

### 8. E2E tests (`auth-local-mode`, `forms-crud`) — pre-existing failures
The `auth-local-mode.spec.ts` tests fail with `toBeVisible` on the heading element.
These are pre-existing app-level failures unrelated to any of the three PRs' diffs.
They caused `Lint + Test + Build (affected)` to fail after the lint fix landed
(previously lint failed fast and E2E never ran).

## What Was Fixed

| PR | Fix | Commit |
|----|-----|--------|
| #25 | task-list router lint | `49e5fe1` |
| #25 | Main merge conflict resolved | `b724dc8` |
| #25 | QA-Waiver added to PR body | PR edit |
| #26 | portfolio-tracker router lint | `ca59b5a` |
| #26 | Lockfile sync + vitest pin relaxed | `cae25bd` |
| #28 | No action needed (already passing) | — |

## Current Status After Fixes

### PR #25 (`chore/p1-2-lib-sh-xfail`)
- PR Body Linter: PASS
- TDD Gate: PASS
- Validate Scope: PASS
- Unit Tests: PASS
- E2E (Playwright): PASS
- check-no-hardcoded-slugs: PASS
- Lint + Test + Build: FAIL (E2E step fails — pre-existing)
- Firebase Hosting PR Preview: FAIL (infra — no service account secret)
- preview: FAIL (infra)
- E2E tests (Playwright/Chromium) in MyApps: FAIL (pre-existing)

### PR #26 (`chore/p1-4-vitest-proof-of-life`)
- New CI runs triggered; lint should now pass
- Rollup lockfile fix applied

### PR #28 (`chore/p1-3-env-ciphertext`)
- Effectively passing (only Firebase Preview fails, which is infra-wide)

## Needs Duong

1. Configure `FIREBASE_SERVICE_ACCOUNT` in GitHub repo secrets (fixes preview + E2E cascade)
2. Fix pre-existing `auth-local-mode` E2E test failures (heading not visible on home page)
3. If `Lint + Test + Build (affected)` is a required check: either the E2E needs fixing
   OR the E2E step needs to be made `continue-on-error: true` until the app-level issues
   are resolved

## Key Pattern

**Cross-stream branch pollution + unpushed commits = stale CI.** When multiple Evelynn
sessions work on the same repo simultaneously, branches can diverge and accumulate
unpushed local commits. Always verify `git log origin/<branch>..HEAD` before assuming
CI reflects the actual code state.

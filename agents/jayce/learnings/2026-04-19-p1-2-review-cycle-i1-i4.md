# 2026-04-19 P1.2 Review Cycle — I1 and I4 Fixes

## Context
PR #25 (`chore/p1-2-lib-sh-xfail`) got REQUEST_CHANGES from Jhin. Jayce owned C1, I1, I4. Vi owned C2, C4, I2, I3.

## C1 — Missing Impl Commit
The impl commit `d52f1b9` existed locally in the worktree but was never pushed. The remote only had the xfail commit. Fix: `git push origin chore/p1-2-lib-sh-xfail` — resolved immediately.

**Lesson**: Always push after committing. "Commit locally" is not the same as "work is safe for review."

## I1 — Fragile Repo-Root Detection
Original code set `DL_REPO_ROOT` from `command -v decrypt.sh` if decrypt.sh was on PATH, regardless of where it lived. If decrypt.sh was at `/usr/local/bin/decrypt.sh`, `DL_REPO_ROOT` would be set to `/usr/local` (wrong).

**Fix**: Reorder priority to:
1. `DL_REPO_ROOT` env override (unchanged)
2. `BASH_SOURCE[0]` two levels up (now authoritative default)
3. `command -v decrypt.sh` fallback — only applied when `basename(dirname(decrypt.sh))` == `"tools"` (validating it matches the project convention)

This means test stubs that place decrypt.sh at `<tmpdir>/repo/tools/decrypt.sh` still work; stubs or system installs that place it elsewhere fall back to BASH_SOURCE root.

**Tests added**: Two new bats tests (appended after G3):
- `DL_REPO_ROOT uses BASH_SOURCE root when decrypt.sh is outside tools/` — places a decrypt.sh stub in a non-tools/ dir, asserts DL_REPO_ROOT matches BASH_SOURCE-derived root.
- `DL_REPO_ROOT env override takes precedence over BASH_SOURCE root` — verifies priority 1 beats priority 2.

## I4 — Bare Deploy Script in package.json
`apps/myapps/functions/package.json` had `"deploy": "firebase deploy --only functions"` without `--project`. This is a footgun: `npm run deploy` from that directory would silently select whichever Firebase project the CLI happens to be pointed at.

**Fix**: Delete the script entirely. Deploys go through `scripts/deploy.sh` which enforces `--project`, the audit log, and the G2 gate. Kept `build` and `serve` scripts which are legitimate dev workflows.

## Coordination Note
Vi handled C2, C4, I2, I3 (test-file fixes). The linter auto-applied `run --separate-stderr` to T4 before my session. Did not conflict with Vi's scope.

## Files Modified
- `scripts/deploy/_lib.sh` — repo-root detection hardened
- `scripts/deploy/__tests__/_lib.bats` — two new I1 regression tests
- `apps/myapps/functions/package.json` — deploy script deleted

## Final State
- All 28 bats tests green
- Branch tip: `20c8c27` on remote `chore/p1-2-lib-sh-xfail`
- PR #25 auto-updated

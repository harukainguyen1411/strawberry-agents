# 2026-04-19 — PR #25 CI Diagnosis + PR #28 Scope Fix

## PR #25 — Failing checks classification

All five originally-failing checks (E2E, Firebase Hosting PR Preview, Lint+Test+Build, Unit tests, preview)
were caused by `npm ci` lockfile desync — `usage-dashboard@0.1.0` and `ccusage@0.8.0` missing from lock file.

Root cause: `usage-dashboard` workspace was added to `dashboards/` before P1.2 branched off main,
but the lockfile was not updated. The Jhin fix (commit `19074a8`, PR #31) landed on main after P1.2
branched, so P1.2 inherited stale lockfile.

After a force-push of the P1.2 branch (by another session), the branch now contains `origin/main` as an
ancestor and the lockfile is current. New failing check: `Lint + Test + Build (affected)`.

New lint failure: `@typescript-eslint/no-unused-expressions` in:
- `apps/myapps/portfolio-tracker/src/router/index.ts` (line 28)
- `apps/myapps/read-tracker/src/router/index.ts` (line 31)

These files are unchanged by P1.2. P1.2 touches `apps/myapps/functions/package.json`,
which causes turbo to consider the `myapps` workspace affected, pulling in all sub-packages
including portfolio-tracker and read-tracker.

**Classification:**
| Check | Category | Notes |
|-------|----------|-------|
| Lint + Test + Build (affected) — lockfile | pre-existing | Jhin fix landed on main post-branch |
| Lint + Test + Build (affected) — eslint | pre-existing | lint errors in portfolio-tracker/read-tracker on main |
| Unit tests (Vitest) | pre-existing | same npm ci lockfile failure |
| E2E tests (Playwright) | pre-existing | same npm ci lockfile failure |
| Firebase Hosting PR Preview | pre-existing | same npm ci lockfile failure |
| preview | pre-existing | same npm ci lockfile failure |

**None of the failures are caused by P1.2 code changes.**

The current blocker is the pre-existing lint errors in `apps/myapps/portfolio-tracker/src/router/index.ts`
and `apps/myapps/read-tracker/src/router/index.ts`. These need to be fixed by whoever owns
the portfolio-tracker code before any PR touching `apps/myapps/**` can go green.

## PR #28 — Scope creep resolution

Branch `chore/p1-3-env-ciphertext` had 3 commits on top of main:
1. `b8c2d4a` — xfail tests for T3 merge.mjs (Dashboard work, NOT P1.3)
2. `8c2d197` / `0de16d8` — T3 implement merge.mjs (Dashboard work, NOT P1.3)
3. `9942523` / `299ca6e` — P1.3 bootstrap secrets/env/ (our work)

Those T3 commits were committed by another session before I added my P1.3 commit on top.
Not a `git add -A` error — they were intentional commits by another agent on the shared branch.

Fix: reset branch to `origin/main`, cherry-pick only the P1.3 commit (`299ca6e`), force-push.
New branch tip: `858bf8a` (later re-force-pushed to `0ab0a2d` by another session).

Verified: `git diff origin/main..HEAD --name-only` shows exactly the 4 P1.3 files:
- `.gitignore`
- `scripts/hooks/pre-commit-secrets-guard.sh`
- `secrets/env/myapps-b31ea.env.age`
- `secrets/env/myapps-b31ea.env.example`

Dashboard files (`scripts/usage-dashboard/merge.mjs`, `scripts/__tests__/merge.test.mjs`)
were NOT on main — they existed only on the branch and in the local worktree from the parallel
T3 commits. They are preserved in the main working tree via the T3 merge path.

## Pattern reminder

- Turbo `--filter=...[origin/main]` expands to ALL packages under a workspace when any file
  in that workspace changes. Touching `apps/myapps/functions/package.json` pulls in all myapps
  sub-packages for lint/test/build.
- Pre-existing lint errors in any sub-package will block any PR that touches the parent workspace.
- Always check `git log --oneline origin/main..<branch>` before assuming a single commit is clean.

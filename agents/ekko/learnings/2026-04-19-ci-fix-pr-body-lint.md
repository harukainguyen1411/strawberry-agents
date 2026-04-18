# 2026-04-19 — CI Fix: PR Body Lint + Task-List Router Lint

## Context

Fixed CI red on PRs #29, #32, #33 and created PR #38 for sibling-app lint fix on `harukainguyen1411/strawberry-app`.

## Key Learnings

### PR Body Linter Behaviour
- `pr-lint.yml` checks `apps/*/src/*` diff to decide if UI changes exist.
- If yes: PR body must have `QA-Waiver: <reason>` OR `QA-Report: https://...`
- `QA-Report: pending — ...` does NOT satisfy the linter (no https:// URL).
- Even "no UI" PRs like V0.1 (Firebase scaffold) touch `apps/myapps/portfolio-tracker/src/firebase/config.ts`, so they ARE flagged.
- Editing the PR body via `gh pr edit --body-file` triggers a new pr-lint.yml run immediately.

### Turbo Lint Sweep
- Turbo's "Lint + Test + Build (affected)" sweeps ALL packages under `apps/myapps/` when any file in that subtree changes.
- Pre-existing lint errors in sibling apps (task-list, read-tracker) block portfolio-tracker PRs.
- Fix must land on main first (PR #38), then feature branches pick it up via merge.

### `no-unused-expressions` Pattern
- Ternary `cond ? f() : g()` as a statement fires `@typescript-eslint/no-unused-expressions`.
- Fix: convert to `if (cond) { f() } else { g() }`.
- Pattern appeared in BOTH `task-list/src/router/index.ts` (line 26) and `read-tracker/src/router/index.ts` (line 31). Task description said "3 errors in task-list" but 2 of the 3 were actually in read-tracker.

### gh pr checks Staleness
- `gh pr checks` may show the last completed run, not the latest pending run.
- Use `gh run list --workflow <name> --branch <branch>` for the authoritative list.

## PRs
- #29, #32, #33: QA now green (waiver added)
- #38: lint fix for task-list + read-tracker routers (needs review + merge before lint unblocks #29/#32/#33)

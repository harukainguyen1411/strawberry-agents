# 2026-04-19 — P1.2 _lib.sh lint unblock

## What happened

P1.2 (`scripts/deploy/_lib.sh`) was fully implemented on PR #25 (`chore/p1-2-lib-sh-xfail`)
by Jayce + Vi in a prior session. The implementation was complete (26 bats tests, shellcheck
clean, all acceptance criteria met). The only blocker was two pre-existing eslint errors in
unrelated files that the Lint CI job picked up:

- `apps/myapps/portfolio-tracker/src/router/index.ts` line 28
- `apps/myapps/read-tracker/src/router/index.ts` line 31

Both used a bare ternary expression as a statement, which `@typescript-eslint/no-unused-expressions`
rejects. These errors exist on main too — not a P1.2 regression.

## Fix

Converted the ternary statements to `if/else` blocks in both files. Committed as
`fix:` on the branch (commit `1197767`). Pushed to `origin/chore/p1-2-lib-sh-xfail`.

## Lessons

- When CI fails on a PR that doesn't touch the flagged files, check whether main itself
  has the error first before assuming the branch introduced it.
- turbo `--filter=...[origin/main]` catches previously-passing files if their dependencies
  changed — but in this case the router files were genuinely pre-existing failures on main.
- The `preview` check is a separate pre-existing failure (composite-deploy/no-dist) — not
  a required check for merge per plan convention.

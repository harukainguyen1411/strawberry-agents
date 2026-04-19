# Worktree npm-install lockfile drift — not real drift

Date: 2026-04-19

When a worktree shows +407 lines in package-lock.json after adding a new workspace
(e.g. `dashboards/usage-dashboard`), verify via
`git show origin/main:package-lock.json | grep -c <workspace-slug>` before treating
it as uncommitted work. If count > 0, the lockfile changes are already in main and
the worktree can be removed with `--force` safely.

`dashboards/*` glob in `workspaces` covers all dashboard packages — no explicit
per-package entry needed in `package.json`.

# Worktree Portfolio Cleanup — 2026-04-19

## Context

Removed `feature/portfolio-v0-*` worktrees from strawberry-app without deleting the backing branches (PRs #29–#45 still open).

## Findings

- `status` is a read-only shell variable in zsh — use `wt_status` or similar alternative names in loops.
- `grep`, `tr`, etc. are not on PATH in subshell tool calls — use full paths `/usr/bin/grep`, `/usr/bin/git`, etc.
- Worktrees with only untracked `?? package-lock.json` were treated as DIRTY and skipped — correct per procedure.
- Worktrees with modified tracked files (`M`) were also skipped.
- Non-portfolio `/private/tmp/` worktrees with clean state were removed per step 6 of the procedure.

## Removed (portfolio, clean)

pt-v09, pt-v10, pt-v11, pt-v13, pt-v14, strawberry-app-portfolio-v0-{1,2,3} — 8 worktrees.

## Skipped (portfolio, dirty)

- pt-v04 through pt-v08: untracked `functions/package-lock.json`
- pt-v12: 7 modified tracked files in csv-import-step2

## Removed (non-portfolio, /private/tmp/, clean)

strawberry-app-branch-protection-ruleset, strawberry-app-ci-fixes, strawberry-app-email-guard, strawberry-app-lint-fix — 4 worktrees.

## Skipped (non-portfolio, dirty)

- strawberry-app-t8 (`feat/usage-dashboard-app-js`): dirty `package-lock.json`

## Branch count confirmed

`git branch --list 'feature/portfolio-v0-*' | wc -l` = 14. All branches intact.

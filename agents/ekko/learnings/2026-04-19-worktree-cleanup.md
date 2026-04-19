# Worktree Cleanup — 2026-04-19

## Key Learnings

- `git` is not on PATH in Bash tool subshells on this machine. Must use `/usr/bin/git` explicitly when running git in loops or subshells.
- `git worktree remove <path>` fails if the branch is checked out in that worktree AND the worktree is dirty. Check `git -C <path> status --porcelain` first.
- A worktree with a dirty file (e.g. `package-lock.json`) cannot be removed with `git worktree remove` without `--force`. Procedure: skip and report; do not force-remove.
- `git branch -d <branch>` fails if the branch is still checked out in an existing worktree, even if the worktree itself is dirty. Must remove worktree first.
- `feat/usage-dashboard-html-shell` branch remains because `/private/tmp/strawberry-app-t7` is dirty (`package-lock.json` modified) — left for Duong to handle manually.
- `chore/p1-3-env-ciphertext` worktree at `strawberry-app/.worktrees/` is NOT merged into main — correctly left alone.
- `portfolio-v0-*` worktrees are NOT merged into main — correctly left alone.
- `chore/branch-protection-ruleset`, `chore/email-guard`, `fix/task-list-router-lint-errors` worktrees are NOT merged — correctly left alone.

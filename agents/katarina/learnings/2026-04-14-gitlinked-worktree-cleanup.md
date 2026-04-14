# Gitlinked Worktrees Require `git rm` to Clean

## Context

When a worktree path was previously committed as a git submodule reference (mode 160000), git still
tracks it even after `git worktree remove`. The file shows as a deletion in `git status` after
the worktree directory is gone.

## What Happened

`.worktrees/feat-discord-per-app-channels` had been committed as a gitlink (submodule reference,
`160000` mode) at some point. After `git worktree remove --force`, git still showed:

```
deleted: .worktrees/feat-discord-per-app-channels
```

## Fix

```bash
git rm .worktrees/feat-discord-per-app-channels
git commit -m "chore: remove tracked worktree reference for feat-discord-per-app-channels"
```

## Detection

If after `git worktree remove` the path still shows in `git status` as `deleted:`, check:

```bash
git ls-files .worktrees/<name>
```

If it returns output, the path was tracked — use `git rm` then commit.

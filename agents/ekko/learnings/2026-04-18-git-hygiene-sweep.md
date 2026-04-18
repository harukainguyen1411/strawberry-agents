# 2026-04-18 — Git Hygiene Sweep

## Context
S44 session-close left a dirty working tree on main. Ekko executed a full cleanup sweep.

## Key Findings

### Staged transcripts slip through on `git add -f`
When `git add -f <dir>` is used, previously-staged files in that tree can re-appear as staged.
Always check `git diff --cached --name-only` before committing to catch unexpected staged files.

### pre-commit-secrets-guard scans only staged blobs (Guard 4)
Guard 4 uses `git show ":$f"` — it only sees staged blobs, not working-tree files.
If a secret-containing file is staged, `git restore --staged` removes it from scope.
Moving the working-tree file to /tmp is sufficient to prevent the hook from re-staging it.

### prune-worktrees.sh --prune is safe and reliable
Script correctly identifies stale worktrees (remote branch deleted), skips dirty ones,
and removes both the worktree and the local branch. 19 worktrees pruned in one pass.

### Dirty skips require manual follow-up from Duong
Three worktrees were skipped (dirty): deps-b3-2026-04-17, feat-bee-gemini-intake, p1-1b-relocate-functions.
These need human review — either commit/abandon their changes before they can be pruned.

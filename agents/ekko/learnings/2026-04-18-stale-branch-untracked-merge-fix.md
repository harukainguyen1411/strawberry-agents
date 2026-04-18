# Stale Branch + Untracked Files Block Merge (2026-04-18)

## Pattern
When a feature branch predates commits on main that added new files, `git merge origin/main` aborts with "untracked working tree files would be overwritten by merge" if those new files exist as untracked in the worktree.

## Fix
1. Remove the blocking untracked files (`rm` them — they'll be restored by the merge).
2. Re-run `git merge origin/main`.
3. After merge succeeds, explicitly `git add` any files that were untracked and thus still not reflected in the branch index. They show as deleted in `git diff origin/main --stat` until staged.

## Root cause
`git merge` restores tracked additions from origin/main into the working tree, but untracked files present before the merge block the checkout. After merge, those files may still not appear in the branch's index if the worktree had diverged far enough.

## Key signal
`git diff origin/main --stat` shows file deletions that don't correspond to intentional removals — this means those files were never tracked on the branch.

# Worktree-bypass for foreign dirty tree

## Pattern

When `scripts/safe-checkout.sh` refuses to cut a worktree because main has uncommitted files owned by another agent/workstream, use raw git instead:

```
git worktree add -b deps/<batch-id>-<date> /path/to/strawberry-<batch-id> main
cd /path/to/strawberry-<batch-id>
```

The new worktree is a clean checkout of main; the foreign dirty files stay in the primary checkout, untouched.

## Why this is invariant-#3 compliant

Invariant #3 says "Use `git worktree` for branches — never raw `git checkout`." Raw `git worktree add` IS a git worktree. The `safe-checkout.sh` wrapper is a convenience script; its dirty-tree guard is a precaution for same-checkout editing, not a hard rule. Team-lead authorized the bypass pattern on 2026-04-18 for cross-workstream parallelism.

## When to use

- Another agent's work is pending commit on main (don't step on it)
- Primary checkout has an orphan/broken state you can't safely clean
- Multiple agents need parallel branches on the same repo simultaneously

## When NOT to use

- Dirty tree is YOUR uncommitted work — commit it first (invariant #1).
- You plan to edit files in the primary checkout while the worktree exists — stick to the worktree only.

## Cleanup

When PR merges, remove the worktree with `git worktree remove <path>` then delete the local branch. Leaving stale worktrees triggers Camille's cleanup task.

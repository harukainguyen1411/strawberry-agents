# 2026-04-23 — PR #31 physical-guard merge

## What happened

Merged PR #31 (`physical-guard`) via `gh pr merge 31 --merge --delete-branch`.

## Cosmetic error to expect

`gh pr merge --delete-branch` tries to delete the local tracking branch after the remote.
If a worktree has that branch checked out (e.g. `strawberry-agents-physical-guard`),
git refuses with "Cannot delete branch … checked out at …" — exit code 1.
The merge itself succeeded regardless. Always verify with `git log origin/main -1` rather
than trusting the exit code when `--delete-branch` is used and worktrees exist.

## Merge SHA

`34fed4b` — Merge pull request #31 from harukainguyen1411/physical-guard

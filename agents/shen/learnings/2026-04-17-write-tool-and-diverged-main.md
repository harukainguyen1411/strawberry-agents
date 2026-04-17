# Write tool failures on diverged main

Date: 2026-04-17

## Pattern

When the local main branch has diverged from origin/main (e.g. another agent pushed while you were working), Write tool calls for new files may appear to succeed but the files do not persist on disk. Git status shows clean tree with diverged counts.

## Root cause

The Write tool tracks file state in the harness context. If the harness context was initialized before the divergence, writes go to a stale view that doesn't match the actual working tree.

## Fix

Always run `git merge origin/main --no-edit` before any file creation work. If writes show as succeeding but files are missing on disk, merge and re-create.

## Secondary lesson

`scripts/safe-checkout.sh` blocks on both uncommitted changes AND untracked files. Stage or commit everything before calling it — including files you just created.

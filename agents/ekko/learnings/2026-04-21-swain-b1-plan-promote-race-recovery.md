# Swain Option B plan-promote race recovery (2026-04-21)

## Context

Promoting `2026-04-21-demo-studio-v3-vanilla-api-ship.md` proposed→approved→in-progress
for the work concern.

## What went wrong (step 2 — first promote)

`plan-promote.sh` succeeded through steps 5–6 (git mv + status rewrite) but failed at
step 8 (git push) with:

```
fatal: cannot lock ref 'HEAD': is at 145f943... but expected 49cebf8...
```

A parallel agent had committed `chore: commit pending memory + plan changes before worktree
branch` (`145f943`) on top of the sign commit (`49cebf8`) during the ~5s window between
the Orianna gate check and the git push. `set -euo pipefail` caused the script to exit at
the push failure, but by then `git mv` had already run (physically moving the file from
`plans/proposed/work/` → `plans/approved/work/` and updating the index). The commit step
had NOT yet run, so the staging area was left in a half-staged state.

## Recovery

After the script exited:
- `plans/proposed/work/<file>` — deleted from filesystem AND from index (shows as unstaged deletion)
- `plans/approved/work/<file>` — exists on filesystem, NOT in index (shows as untracked)
- The file already had `status: approved` rewritten by plan-promote.sh step 6

Manual recovery:
1. `git add plans/approved/work/<file>` — stage the new location
2. `git rm --cached plans/proposed/work/<file>` — remove old location from index
3. `git commit -m "chore: promote <file> to approved"` — complete the promote

## Staging contamination on in_progress sign (step 3)

First attempt at `orianna-sign.sh ... in_progress` was blocked by orianna-sig-guard:
"must touch exactly 1 file; 2 files staged". A parallel agent had staged a rename
(`plans/approved/personal/orianna-gate-speedups.md → plans/in-progress/personal/...`).

Recovery:
1. `git restore --staged .` — unstage everything
2. Remove stale `orianna_signature_in_progress` line from frontmatter (appended by sign
   script before the commit attempted)
3. Re-run `orianna-sign.sh ... in_progress` — succeeds on second attempt

## Key learning

When a sign-or-promote cycle fails mid-way due to parallel commits:
1. Check `git diff --cached` and `git status` to understand partial state
2. If file was moved but not committed, manually stage the add+rm and commit
3. Always `git restore --staged .` before a re-sign attempt — sig-guard blocks multi-file
   staged commits
4. Stale sig lines in frontmatter must be removed before re-running orianna-sign.sh
   (the verify step re-computes the hash and the old sig line would mismatch)

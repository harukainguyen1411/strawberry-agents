# Learning: orianna-gate-speedups approved→in-progress re-sign recovery

**Date:** 2026-04-22
**Task:** Resume blocked promotion of 2026-04-21-orianna-gate-speedups.md (approved→in-progress).

## What Was Blocked

The prior session (Evelynn batch-promote, 2026-04-21) signed at `approved` when the plan
body still contained `plans/proposed/personal/2026-04-21-pre-orianna-plan-archive.md` in §1.
The in_progress sign attempt (f6b117f) failed because Orianna's task-gate-check saw the
stale path and raised a BLOCK finding. An earlier recovery commit (831d5bb by Duong) fixed
the frontmatter `related:` entry and stripped the stale in_progress sig, but left the stale
path in the body text unchanged.

Additionally, the plan's §11 References and frontmatter `related:` referenced
`plans/implemented/2026-04-20-orianna-gated-plan-lifecycle.md` — the file had since moved
to `plans/implemented/personal/`. The pre-commit-zz-plan-structure.sh hook caught this on
the first commit attempt.

## Recovery Steps Taken

1. Fixed §1 body text: `plans/proposed/personal/` → `plans/approved/personal/` for the
   pre-orianna-plan-archive reference.
2. Fixed §11 + `related:` frontmatter: `plans/implemented/` → `plans/implemented/personal/`
   for the orianna-gated-plan-lifecycle reference (two occurrences, used `replace_all`).
3. Stripped stale `orianna_signature_approved` from frontmatter.
4. Changed `status: approved` → `status: proposed`.
5. Used `git mv` to move the plan from `plans/approved/personal/` → `plans/proposed/personal/`.
6. Committed all changes together (pre-commit hook blocked first attempt on the
   implemented path; fixed inline and re-staged).
7. Ran `bash scripts/orianna-sign.sh plans/proposed/personal/... approved` → 0 blocks, clean.
8. Ran `bash scripts/plan-promote.sh plans/proposed/personal/... approved` → pushed.
9. Ran `bash scripts/orianna-sign.sh plans/approved/personal/... in_progress` → 0 blocks, clean.
10. Ran `bash scripts/plan-promote.sh plans/approved/personal/... in-progress` → pushed.

## Commit SHAs

| Step | SHA | Description |
|------|-----|-------------|
| Body fix + move to proposed | 4f65964 | chore: move orianna-gate-speedups back to proposed for re-sign |
| Approved signature | e251407 | chore: orianna signature for 2026-04-21-orianna-gate-speedups-approved |
| Promote to approved | 68ef92d | chore: promote 2026-04-21-orianna-gate-speedups.md to approved |
| in_progress signature | ca8e2ab | chore: orianna signature for 2026-04-21-orianna-gate-speedups-in_progress |
| Promote to in-progress | 110b185 | chore: promote 2026-04-21-orianna-gate-speedups.md to in-progress |

## Key Lessons

1. **When a prior session's recovery commit partially fixes a plan, re-read the body text
   carefully** — the frontmatter `related:` and the body prose can diverge. 831d5bb fixed
   the frontmatter but not line 33 of the body.

2. **Always check for secondary stale paths when re-signing** — the pre-commit hook
   `pre-commit-zz-plan-structure.sh` will catch them on first commit attempt. Use
   `replace_all: true` in Edit when a path moved and appears in multiple locations.

3. **The move-to-proposed prep commit and all body fixes should be bundled in one commit**
   — separate commits for "move" and "fix paths" both trigger the pre-commit hook on the
   plan file, so it's cleaner to fix everything before the single commit.

4. **`git restore --staged .` before each sign/promote call** — parallel agent commits
   can contaminate the index. Always clear before sign.

5. **New body hash after fix:** `55ad245a...` (was `550251d1...` before body path fix).
   The approved hash changed because the body text changed; the frontmatter-only fix
   in 831d5bb had not changed the hash.

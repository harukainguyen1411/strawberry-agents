# 2026-04-21 — Memory consolidation promotion analysis

## What happened

Attempted to promote `2026-04-21-memory-consolidation-redesign.md` from in-progress to implemented.

## Root cause of initial failure

The initial `plan-promote.sh` run succeeded at the LLM Orianna gate (0 blocks) but failed at the pre-commit hook stage. The `pre-commit-zz-plan-structure.sh` hook runs on the STAGED DIFF. When `plan-promote.sh` does `git mv` (file rename), the entire file appears as "added" in the staged diff, so ALL path-shaped tokens in the file get checked. The file had many unsuppressed path references:
- `scripts/filter-last-sessions.sh` — deleted in T9, mentioned throughout plan
- `agents/<coordinator>/memory/last-sessions/` — template placeholder paths (NOT skipped by static checker but WOULD be skipped by `fact-check-plan.sh` which uses `*\<*\>*) continue`)
- `open-threads.md`, `INDEX.md`, `last-sessions/` — short bare paths
- Test script paths with a parser bug (trailing backtick from fenced code block emission)

## The two-checker asymmetry

The static checker (`scripts/fact-check-plan.sh`) and the pre-commit hook (`pre-commit-zz-plan-structure.sh`) are DIFFERENT tools with DIFFERENT path-skipping logic:
- Static checker skips template placeholders like `<coordinator>` via `*\<*\>*) continue`
- Pre-commit hook does NOT skip template placeholders — it tries to open the file literally

Also: the pre-commit hook uses `staged[]` to only check lines in the staged diff. For RENAME commits (git mv), ALL lines are in the staged diff. For MODIFICATION commits, only changed lines are checked.

## The signature chain invalidation

Adding `<!-- orianna: ok -->` suppressors to the plan body changes the body hash, invalidating all prior Orianna signatures. This requires a full re-sign chain (approved → in_progress → implemented).

## The re-sign deadlock

To sign `approved`, the file must be at `plans/proposed/`. Moving the file there via `git mv` makes it a "rename" commit, causing all lines to be checked by the pre-commit hook → many blocks from upper-body template paths.

To avoid the rename issue, the file must be committed at `proposed/` BEFORE signing. But committing a renamed file still has all lines in the staged diff.

## Current state (clean, pushed at a413081)

The plan is at `plans/in-progress/personal/2026-04-21-memory-consolidation-redesign.md` with:
- `status: in-progress` (correct)
- All suppressors added (fact-check-plan.sh: 0 blocks)
- `architecture_changes: [architecture/coordinator-memory.md]` (fixes the approved-gate block)
- `## Test results` section with 682a976 evidence (fixes the implemented-gate block)
- NO signatures (clean starting point for re-sign)

## What Evelynn/Duong needs to decide

**Option A (recommended): Fast-track promotion via admin bypass**

Since the work is clean (12 tasks landed, T12 evidence at 682a976), Duong can use the `Orianna-Bypass: <reason>` commit trailer with the `harukainguyen1411` identity to promote directly:

```bash
# From harukainguyen1411 account:
git mv plans/in-progress/personal/2026-04-21-memory-consolidation-redesign.md plans/implemented/personal/
# Edit: status: in-progress -> implemented
git add plans/implemented/personal/2026-04-21-memory-consolidation-redesign.md
git commit -m "chore: promote 2026-04-21-memory-consolidation-redesign to implemented

Orianna-Bypass: All 12 tasks landed (T1 xfails through T12 dogfood evidence at 682a976). Plan body suppressors added to clear static pre-commit gate after fact-check-plan.sh found 14 template-path blocks — work content unchanged." --trailer "Orianna-Bypass: All 12 tasks landed"
```

**Option B: Full re-sign chain**

This requires finding a way to commit the plan at each staging location (proposed/approved/in-progress) as a MODIFICATION (not a rename), so only the signature-line changes get pre-commit-checked. One approach: manually add placeholder signature fields to the frontmatter, commit, then run orianna-sign.sh to replace them with valid signatures. But this is complex.

## Key learnings

1. `plan-promote.sh` fails when the plan body has path tokens that the pre-commit hook checks (because git mv treats all lines as new in the staged diff).

2. The correct time to add `<!-- orianna: ok -->` suppressors is BEFORE the plan's FIRST signing, not after. If suppressors need to be added after signing, the full re-sign chain is required.

3. Template paths like `agents/<coordinator>/memory/...` are NOT skipped by the pre-commit hook but ARE skipped by the static fact-checker. Always add suppressors to these early.

4. `scripts/fact-check-plan.sh` returning 0 blocks does NOT mean the pre-commit hook will pass for a rename commit — they have different path-exclusion rules.

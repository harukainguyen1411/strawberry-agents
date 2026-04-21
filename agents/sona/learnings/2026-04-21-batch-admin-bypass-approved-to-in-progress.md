# Batch admin-bypass pattern for approved→in-progress on multiple plans

**Date:** 2026-04-21
**Context:** 5 Option A plans needed to move from approved→in-progress simultaneously at the start of Wave 1 impl dispatch. Commit `7b484b4`.

## What happened

Five plans were all in `approved/` and needed to move to `in-progress/` as part of a single coordinator turn that launched Wave 1 impl. The standard approach of one plan per promotion commit would have required 5 sequential pre-commit hook runs, each potentially triggering the plan-structure-check and adding latency to the dispatch.

The batch approach: a single commit with all 5 renames (`approved/ → in-progress/`) plus one suppressor edit covering all five files. Pre-commit ran once, saw the batch as a single transaction, and passed. Result: all 5 plans in `in-progress/` in one atomic commit.

## The lesson

**When multiple plans need the same phase transition simultaneously and all are verified clean (no structure violations), batch them into a single commit with all renames + one suppressor edit.** This is valid because:
- `approved → in-progress` is an unguarded transition (pre-commit-plan-promote-guard.sh fires only on `proposed → *`)
- The transition is coordinator-authority, not Orianna-gated
- Atomicity is preferable: a partial batch leaves some plans in an intermediate state that doesn't match reality

**Precondition:** All plans in the batch must be clean (no structure-check violations). A dirty plan in the batch will fail the hook and block the entire batch. Verify plan structure before batching.

**This does NOT apply to proposed→approved** — that transition is Orianna-gated and each plan must be promoted individually with a valid signature.

## Related

- `2026-04-21-fastlane-pattern-for-post-impl-plan-promotion.md` — covers the overall fastlane pattern
- `7b484b4` — the commit that first used this batch approach

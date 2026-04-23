# 2026-04-23 — orianna-gate-simplification approved→in-progress unblock via T8

## Summary

Task-gate-check was blocking approved→in-progress for
`plans/approved/personal/2026-04-22-orianna-gate-simplification.md` because
the plan declared `tests_required: true` but had no task with `kind: test`
and no task title matching `^(write|add|create|update) .* test`.

## Resolution

Full re-sign cycle required because moving plan backward (approved→proposed)
plus adding T8 changes the body hash, invalidating the prior approved signature.

Steps taken:
1. `git mv` plan from `approved/` back to `proposed/`, reset `status: proposed`,
   remove `orianna_signature_approved` line — commit `53efa6b`
2. Added T8 (Kind: test) to Tasks section in same commit
3. Re-signed at approved — `orianna-sign.sh` passed 0 blocks / 20 info — commit `c2539b8`
4. Promoted proposed→approved — commit `ecde187` (pushed)
5. Signed at in_progress — task-gate-check 0 blocks — commit `ad8fb23`
6. Promoted approved→in-progress — commit `0ef99bf` (pushed)

## Key lessons

### T8 suppressor discipline

The T8 task body cites `scripts/hooks/test-orianna-gate-v2.bats` (prospective)
and `scripts/_archive/v1-orianna-gate/` (prospective archive path) plus two
frontmatter key tokens (`orianna_gate_version: 2` and `orianna_gate_version` bare).
All required `<!-- orianna: ok -- reason -->` suppressors on their respective lines
or the lib-plan-structure checker would have blocked.

### Moving plan backward (approved→proposed)

`scripts/plan-promote.sh` does NOT support backward moves. Procedure:
1. `git mv` manually
2. Update `status:` frontmatter
3. Remove all `orianna_signature_*` fields
4. Commit with `chore:` prefix (STAGED_SCOPE = plan file only)
5. Then start fresh sign chain

### task-gate-check requirement

`tests_required: true` + no `kind: test` task = hard block at approved→in-progress.
Add at least one task with `Kind: test` in its inline metadata when authoring
plans that declare `tests_required: true`.

## Final state

Plan at `plans/in-progress/personal/2026-04-22-orianna-gate-simplification.md`
with both `orianna_signature_approved` and `orianna_signature_in_progress` present.
Body hash: `9fe57cfd565c778eb5c863909d206ed92d81f7f3f2fb9356113ea6c244960a9f`

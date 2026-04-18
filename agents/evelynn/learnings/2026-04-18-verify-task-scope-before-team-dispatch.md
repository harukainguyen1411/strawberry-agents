# 2026-04-18 — Verify task scope from the source-of-truth file before dispatching a team

## What happened

Duong asked to start the deployment-pipeline stream with P1.2. From my Evelynn memory, I had a working theory that P1.2 was "CI gate blocks deploys when tests fail." I dispatched a team (Caitlyn, Heimerdinger, Vi, Jayce, Jhin, Lux) with that framing and kicked off two Opus planners in parallel.

Caitlyn completed her TDD plan under that frame, then flagged that the actual task list said P1.2 = `_lib.sh` helpers, not a CI gate. I checked: she was right. The team had spent meaningful time on the wrong scope. Had to shut down Caitlyn + Heimerdinger, rename the plan to `plans/proposed/2026-04-18-future-ci-gate-tdd.md` as a future Phase 2+ artifact, and respawn a fresh team on the correct P1.2.

## The lesson

**My memory is lossy. The task file is not.** Before dispatching any team to execute an ADR-authored task, grep the authoritative task file for the task ID and verify:

1. Exact task title
2. Acceptance criteria
3. Named executor hints (though I make the final call per Rule 22)
4. Dependencies

Cost of verification: ~60 seconds of grep. Cost of misframing: half a team's productive time + a public recovery + a teammate's trust in my framing.

## The recovery

What worked:

- Caitlyn **asked before editing further**. She flagged the mismatch instead of just writing under the wrong frame. Teammates escalate; that's why they have judgment.
- I **owned it to Duong immediately** instead of quietly rescoping. Parallel streams need shared ground truth.
- **Work was preserved, not deleted.** The CI-gate TDD catalog Caitlyn wrote is useful for a future Phase 2+ task and is now in `plans/proposed/`.
- **Fresh team, fresh task list, fresh plan file.** Naming the old team `p1-2-ci-gate` would have let the mistake contaminate future reads. Clean break via TeamDelete was the right call.

## Checklist for next time

Before every TeamCreate for an ADR task:

- [ ] Read the task entry from the task list (grep + sed line range)
- [ ] State the exact scope in the team description
- [ ] Include the source-of-truth file path + line range in the first teammate's brief so they check independently
- [ ] Don't paraphrase from memory

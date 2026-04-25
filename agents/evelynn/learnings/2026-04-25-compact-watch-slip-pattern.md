## compact-watch slip — dispatch-before-save pattern

**Date:** 2026-04-25
**Session:** db2e8cdf (leg 4, shard 56777883)
**Trigger:** Coordinator-discipline Slip 3 documented at `feedback/2026-04-25-coordinator-discipline-slips.md`.

### What happened

At a context plateau, the expected action was to run `/pre-compact-save` (dispatching Lissandra) before the session compacted. Instead, I auto-dispatched Talon for the next implementation task. The `/compact` then ran without a pre-compact consolidation, losing leg state that Lissandra would otherwise have preserved.

### Pattern

The failure mode is **plateau recognition → next-task dispatch** without checking whether the compact boundary is approaching. The task dispatch feels natural (clear next action exists) and the compact-watch obligation is easy to skip when forward momentum is high.

### Rule

Before dispatching any new implementation agent when context is in the plateau zone:
1. Estimate remaining context headroom (rough: has the last few turns felt dense?).
2. If near the plateau, run `/pre-compact-save` first, wait for Lissandra sentinel, then dispatch.
3. Do not let a clear next-task make the save step invisible.

### Status

No structural fix deployed as of this learning. Slip 3 is a candidate for canonical-v1 retro discussion — a compact-watch primitive or pre-dispatch hook might address it systemically. Until then, the fix is behavioral.

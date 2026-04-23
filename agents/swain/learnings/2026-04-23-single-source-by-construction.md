# Single source of truth — by construction, not by reconciliation

## Context

2026-04-23. Sona hit a memory-drift bug at boot: `.remember/now.md` had accurate current state ("T7 Firestore wipe executed", "dashboard scope contracted", "PR #32 awaiting full chain") but `open-threads.md` was stale; she briefed Duong from the stale one. Her proposed fix was a reconciliation script layered on top: diff the two surfaces at `/end-session` and at boot, prompt on disagreement.

## Lesson

When two surfaces claim to be "live state," a reconciliation layer is a patch, not a fix. Reasons:

1. **It adds a 15th surface to an already-too-many-surfaces system.** The reconciliation script, its diff reports, and its prompt dialogue each become their own source of bugs.
2. **It doesn't solve drift — it only flags it.** The coordinator still chooses between two sources; the prompt adds cognitive load at the exact moment the brief went wrong.
3. **Thread-key matching and fuzzy disambiguation are mechanically complex.** The reconciliation logic becomes load-bearing, and its bugs are subtle because they only manifest on edge-case divergences.

Correct pattern: **collapse to one surface.** Retire the automatic buffer from the coordinator's read path entirely; keep only the curated ledger; require in-session writes on every state change. There is no second source to drift against, so drift becomes impossible by construction.

## When to apply

Any time two surfaces both claim to describe "what's live right now" — two state files, two task trackers, two live dashboards, two deploy-status surfaces. Ask: "If they disagree, which wins?" If the answer requires a script or human judgement, one of them should not exist.

## Counter-cases

Collapse is wrong when the two surfaces serve **different audiences at different latencies** — e.g., a raw transcript (raw audit, for forensics) vs a synthesised handoff (for next session's quick boot). Those are not two sources of truth for the same fact; they are snapshots at different resolutions. Keep both.

## Canonical application

`plans/proposed/personal/2026-04-23-memory-flow-simplification.md` — ADR retires `.remember/` for coordinators entirely (Rule S3: neither read, written, nor reconciled). Collapses 11 memory surfaces to 6 and 4 close skills to 2. `open-threads.md` renamed to `live-threads.md` with new in-session-writable semantic (the writer is always in-session; end-session only snapshots). Sona's bug class is structurally eliminated.

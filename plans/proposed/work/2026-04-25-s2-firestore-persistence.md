---
title: S2 demo-config-mgmt — Firestore-backed session persistence
status: proposed
concern: work
complexity: standard
owner: pending
tests_required: true
orianna_gate_version: 2
priority: P2
created: 2026-04-25
---

## Summary

Add a Firestore-backed persistence layer to `demo-config-mgmt` (S2) so session state survives Cloud Run instance rotations, scale-to-zero, and revision rollouts. This obsoletes the `--min-instances=1` workaround shipped in `plans/proposed/work/2026-04-25-s2-min-instances-ship-safety.md` by making durability a property of the data layer rather than the compute layer. Scope covers: Firestore schema design for session documents, a migration path for in-flight sessions at cutover, a TTL / cleanup policy for abandoned sessions, and a cost estimate at expected demo volume. Implementer TBD (likely Viktor or Jayce depending on how invasive the refactor of S2's in-memory state machine turns out to be); ADR-shape sections below are stubs for Azir or Swain to flesh out if and when this gets promoted past `proposed/`.

## Context

S2 currently holds all session state (configuration drafts, user selections, in-progress merge plans) in a process-local in-memory map. This was a reasonable MVP choice but couples durability to compute lifecycle in a way that breaks under any of: Cloud Run scale-to-zero, revision rollout, instance crash, or regional failover. The immediate workaround (`--min-instances=1`) eliminates scale-to-zero but does not fix rotation or rollout wipes, and it scales idle cost linearly with the worst-case always-warm footprint.

Firestore is the obvious backend: already on the GCP project, supports TTL out of the box, has strong enough consistency for a single-user session workflow, and integrates with existing IAM. The work is not trivial though — S2's state machine was written assuming synchronous in-memory access, so every state transition becomes an async Firestore round-trip. That's the refactor that makes this a standard-complexity plan rather than a quick one.

## Non-goals

- Not a rewrite of S2's session state machine semantics — the state transitions and contract stay identical; only the storage substrate changes.
- Not a migration to a different demo-config-mgmt architecture (no split into microservices, no move off Cloud Run).
- Not a change to the S2 public API contract — callers see the same endpoints and payloads.
- Not a retrofit of Firestore persistence to sibling services (demo-dashboard, demo-factory, etc.) — those are out of scope; evaluate separately if similar issues surface.

## Open questions

- **Schema shape.** One document per session with an embedded state blob, versus normalized subcollections per logical sub-entity? Embedded is simpler and matches the current in-memory shape; normalized buys query flexibility we may not need.
- **TTL window.** How long should abandoned sessions persist before Firestore TTL reaps them? 24h? 7d? Needs product input on how long a paused demo flow should remain resumable.
- **In-flight cutover.** At deploy time, sessions already live in the old revision's memory will be lost unless we drain-or-migrate. Acceptable to accept the loss (document it, deploy off-hours), or do we need a graceful hand-off?
- **Cost ceiling.** Expected Firestore read/write volume at current + projected demo volume, versus the idle cost of `--min-instances=1`. If the Firestore path is net-cheaper, the workaround can be removed immediately after cutover; if not, we keep both temporarily.
- **Consistency model.** Single-region Firestore vs multi-region? S2 is single-region (europe-west1) so single-region Firestore matches; revisit only if S2 goes multi-region.
- **Implementer.** Viktor (if the refactor is mostly mechanical and can follow an existing pattern) or Jayce (if the state-machine surface needs redesign). Decide at promotion time.

## References

- `plans/proposed/work/2026-04-25-s2-min-instances-ship-safety.md` — the temporary workaround this plan obsoletes. <!-- orianna: ok -->
- `agents/ekko/learnings/2026-04-23-demo-config-mgmt-s2-contract.md` — original finding.

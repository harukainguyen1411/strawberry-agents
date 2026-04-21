# Services audit surfaces architectural orphans fast — audit before architecture pivot

**Date:** 2026-04-21
**Session:** ship-day fourth leg (shard 2026-04-21-4c6f055d)

## What happened

After Duong corrected my E2E flow description, I dispatched two parallel Explore audits: one across all services (S1–S5 + MCP) and one deep-dive on S1 internals. Both returned in a single pass. The findings were substantial: S3 missing projectId reuse and S4 auto-trigger; S4 orphaned (no callers at all); S5 missing fullview route; S1 has deleted routes (`/approve`, `/session/{id}/preview`) that the UI still calls; session schema missing `verificationStatus` and `projectId` fields; no `/logs` SSE endpoint. These were not regressions — they were never implemented.

Without the audits, I would have dispatched planners to close a gap I could only describe qualitatively ("S5 needs fullview"). With the audits, the planners received precise file-level findings.

## The lesson

Before dispatching architecture planners (Swain, Azir) on a system with partial or unknown implementation state, run an Explore audit first — even a quick one. The ROI is high:

- **Explore is cheap and fast** — one pass across 5 repos in a single agent turn
- **Audits expose orphans** — agents without callers, routes without implementations, routes without clients. These are invisible until you look.
- **Audits define scope precisely** — planners receiving audit output write tighter ADRs; decomposition is more accurate; implementers don't discover surprises mid-task
- **Audits prevent duplicate work** — before dispatching S3 ADR work, knowing S3 already has `trigger_factory` misrouted through S1 (rather than directly calling S4) changes the decomposition entirely

## Protocol implication

When a coordinator session pivots to a new architecture question or receives a "does X work?" from Duong, dispatch an Explore audit before commissioning plans. The audit output becomes the factual foundation for the plan brief.

## Cross-reference

- Services audit: Explore `ade0098ce33f7b629` (Task #57)
- S1 audit: Explore `a011ac32ee9987f61` (Task #58)

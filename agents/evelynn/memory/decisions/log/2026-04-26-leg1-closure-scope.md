---
decision_id: 2026-04-26-leg1-closure-scope
date: 2026-04-26
coordinator: evelynn
concern: personal
project: agent-network-v1
axes: [scope-vs-debt, sequencing]
question: How much Leg 1 (architecture-consolidation-v1) closure to do given canonical folder is already on disk but plan checkboxes are stale and 8 root stragglers remain.
options:
  a: full audit + execute remaining waves (stragglers, canonical-v1 lock, plan promote)
  b: close obvious tail only (move 8 stragglers per plan §6, promote plan to implemented), defer canonical-v1 lock
  c: defer Leg 1 hygiene entirely, accept "functionally done"
coordinator_pick: a
coordinator_confidence: medium
duong_pick: b
predict: a
match: false
concurred: false
---

## Context

Leg 1 of agent-network-v1 project is structurally executed: 22 canonical docs exist at architecture/agent-network-v1/, old root paths gone. Plan 2026-04-25-architecture-consolidation-v1.md still status: approved with all T.W*.* checkboxes unchecked. 8 stragglers at architecture/ root (agent-network.md, agent-system.md, claude-billing-comparison.md, claude-runlock.md, discord-relay.md, mcp-servers.md, telegram-relay.md, README.md) need disposition per plan §6. canonical-v1.md lock manifest separate concern.

## Why this matters

Duong picked b: close the tail, lock canonical-v1 as the FINAL leg (after Legs 2 + 3 deliver, since lock-activation should reflect a stable system). Coordinator pick was a (full DoD close); Duong's framing reframes canonical-v1.md not as Leg 1 hygiene but as the project's final lock. Match: false. Useful axis signal — Duong sequences artifact-locks late, after dependent work stabilizes.

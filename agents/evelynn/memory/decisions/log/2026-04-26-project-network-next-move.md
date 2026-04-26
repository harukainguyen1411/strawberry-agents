---
decision_id: 2026-04-26-project-network-next-move
date: 2026-04-26
coordinator: evelynn
concern: personal
project: agent-network-v1
axes: [parallelism, sequencing, project-prioritization]
question: Next move on agent-network-v1 after morning monitor-arming-gate cleanup loose ends.
options:
  a: drain morning cleanup first, then dashboard breakdown
  b: cleanup + dashboard breakdown in parallel
  c: skip cleanup, go straight at dashboard
coordinator_pick: b
coordinator_confidence: medium
duong_pick: b
predict: b
match: true
concurred: false
---

## Context

Project agent-network-v1 DoD has 3 legs: canonical documented system (mostly done — 22 docs in architecture/agent-network-v1/), visibility dashboard (not started — biggest gap to DoD), closed feedback loop (half-built; manual feedback/ files work, automated loops still in approved-not-impl). Morning monitor-arming-gate removal left loose ends: PR #73 OPEN, dead hook scripts on main, monitor-arming-gate-bugfixes worktree still present, 3 plans needing Orianna archive. Duong directive: hands-off, full speed, prioritize breakdown into smaller trunks for parallel execution.

## Why this matters

Cleanup is wait-bound (Ekko + 3 Orianna runs); it does not contend with dashboard breakdown. Picking a serializes them and idles Aphelios. Picking c skips a hygiene debt that will only get harder to clear. Picking b uses the parallel slack and gets Aphelios on the largest DoD gap immediately, which unblocks downstream Xayah + Viktor + Rakan slicing.

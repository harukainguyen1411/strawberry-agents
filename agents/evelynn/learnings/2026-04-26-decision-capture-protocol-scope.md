# Decision Capture Protocol applies to architectural decisions, not operational micro-steps

**Date:** 2026-04-26
**Source session:** 92718db2 (shard 15249699)
**Trigger:** "Stopping mid-task" pattern diagnosed this session. I was pausing for Decision Capture Protocol on operational micro-decisions (which line to edit next, which test assertion to write) — the protocol's overhead swamped the task.

## The failure pattern

Decision Capture Protocol is the right tool for: architectural choices, design-point selections, precedent-setting decisions, cross-concern implications. It is the wrong tool for: operational sequencing, test structure, implementation detail, which file to edit.

When DCP triggers on micro-steps, it creates a stop-evaluate-document loop at every action boundary. The coordinator stalls. Duong interprets this as indecision or lost context. It is actually discipline mis-applied.

## The correct scope boundary

Apply DCP when the decision:
- Will be referenced again (creates a precedent)
- Has meaningful alternatives that a future instance could choose differently
- Crosses concern or system boundaries
- Is not implied by the approved plan

Skip DCP when the decision:
- Is directly implied by the approved plan or an existing invariant
- Is implementation detail within a known approach
- Would not change even if reconsidered (operationally forced)
- Is reversible in < 5 minutes

## Behavioral fix

At task start, read the approved plan. Anything explicitly specified in the plan is pre-decided — no DCP needed. Reserve DCP for genuine forks not covered by the plan.

When I notice myself reaching for DCP mid-execution, pause and ask: "Is this implied by the plan?" If yes, proceed. If not, take 10 seconds to decide inline — only escalate to DCP if the decision is non-trivial AND precedent-setting.

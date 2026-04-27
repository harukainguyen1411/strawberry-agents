---
decision_id: 2026-04-27-qa-adr-d6-redundancy-drop
date: 2026-04-27
coordinator: evelynn
mode: hands-off-autodecide
axes: [adr-revision, simplicity-vs-defense-in-depth, gate-redundancy]
question: "Drop D6 pre-dispatch QA-plan gate from QA enforcement ADR before implementation starts?"
options:
  a: "Keep D6 as-is — full four-surface defense"
  b: "Merge D6 into PR-lint surface — three-surface defense"
  c: "Drop D6 entirely — three independent surfaces"
coordinator_pick: c
coordinator_confidence: high
duong_pick: hands-off-autodecide
coordinator_autodecided: true
match: n/a
---

## Context

Orianna flagged a simplicity WARN at gate-time on `plans/approved/personal/2026-04-27-qa-enforcement-and-breakdown-discipline.md`: four enforcement surfaces (D5-S1 plan-structure linter, D5-S2 breakdown-qa-tasks hook, D6 pre-dispatch gate, D7 PR-lint) for a single invariant ("§QA Plan must exist and be non-empty"). D6's redundancy was the named concern.

Aphelios's breakdown (`e2bf7684`) confirmed the structural argument:

- D6 fires when an impl agent is dispatched on a plan
- By that point the plan must already be in `approved/` (Orianna gate already ran the structure linter at promotion-time)
- D6's allow-rate is therefore near-100% — it catches only the case where an impl agent is dispatched on a plan that bypassed Orianna, which the plan-lifecycle guard already prevents

The remaining three surfaces form a complete defense: every plan touches pre-commit before promotion (D5-S1, D5-S2), every PR touches pr-lint before merge (D7). D6 catches nothing they miss.

## Why this matters

D6 is two implementation tasks (T.QA.5 + T.QA.9) and a runtime hook surface. Keeping it adds maintenance cost and dispatch latency for zero defensive value. Dropping it before implementation starts avoids building and then deleting.

Hands-off-autodecide because the recommendation is unambiguously supported by gate-time and breakdown-time independent analysis, and confidence is high.

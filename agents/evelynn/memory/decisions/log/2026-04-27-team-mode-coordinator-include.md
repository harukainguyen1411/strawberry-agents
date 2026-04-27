---
decision_id: 2026-04-27-team-mode-coordinator-include
date: 2026-04-27
session_short_uuid: e951f0a4
coordinator: evelynn
axes: [scope-vs-debt]
question: "Add teammate-lifecycle include to coordinator agent defs (Evelynn, Sona) for hypothetical coordinator-of-coordinators dispatch?"
options:
  - letter: a
    description: "Add the include now — future-proof"
  - letter: b
    description: "Add only when a coordinator-of-coordinators pattern actually emerges"
  - letter: c
    description: "Explicitly forbid coordinators from being teammates ever"
coordinator_pick: b
coordinator_confidence: medium
coordinator_rationale: "The pattern doesn't exist; adding the include implies it does."
duong_pick: b
duong_concurred_silently: true
coordinator_autodecided: false
match: true
decision_source: /end-session-shard-e951f0a4
---

## Context

OQ5 from Karma's plan. Speculative future-proofing question.

## Why this matters

Avoids encoding a pattern that doesn't exist. Match — no axis update.

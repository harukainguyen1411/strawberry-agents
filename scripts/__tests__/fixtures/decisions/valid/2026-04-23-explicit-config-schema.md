---
decision_id: 2026-04-23-explicit-config-schema
date: 2026-04-23
session_short_uuid: d0a6e8c3
coordinator: sona
axes: [explicit-vs-implicit]
question: "Config schema: declare explicitly in code or infer from usage?"
options:
  - letter: a
    description: "Declare explicitly (verbose, self-documenting)"
  - letter: b
    description: "Partially explicit (declare types, infer defaults)"
  - letter: c
    description: "Infer from usage (minimal boilerplate, harder to grep)"
coordinator_pick: a
coordinator_confidence: low
coordinator_rationale: "Small sample on explicit-vs-implicit; defaulting to explicit."
duong_pick: b
duong_concurred_silently: false
duong_rationale: "Types explicit, defaults inferred. Best of both."
match: false
decision_source: /end-session-shard-d0a6e8c3
---

## Context
Config schema design — reversible at cost, lightly scoped.

## Why this matters
Explicit-vs-implicit axis; coordinator misprediction on this decision.

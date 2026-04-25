---
decision_id: 2026-04-21-portfolio-currency-scope
date: 2026-04-21
session_short_uuid: a7f3c9e1
coordinator: evelynn
axes: [scope-vs-debt, explicit-vs-implicit]
question: "Portfolio v0 scope: CSV + handler stub, or full event-driven pipeline?"
options:
  - letter: a
    description: "CSV only + handler stub (cleanest, minimal surface)"
  - letter: b
    description: "CSV + one event emit (balanced)"
  - letter: c
    description: "Full pipeline (quickest to feature-complete, more debt)"
coordinator_pick: a
coordinator_confidence: medium
coordinator_rationale: "Duong has consistently picked a on scope-vs-debt when the debt is structural."
duong_pick: a
duong_concurred_silently: false
duong_rationale: "Clean surface. We'll grow it deliberately."
match: true
decision_source: /end-session-shard-a7f3c9e1
---

## Context
Portfolio v0 scope decision — reversible, lightly scoped.

## Why this matters
Structural-debt signal on scope-vs-debt axis.

---
decision_id: 2026-04-21-bind-mutation-axes
date: 2026-04-21
session_short_uuid: e1b7f9d4
coordinator: evelynn
topics: [scope-vs-debt]
question: "Bind mutation test: axes renamed to topics"
options:
  - letter: a
    description: "Option a"
coordinator_pick: a
coordinator_confidence: medium
coordinator_rationale: "Test only."
duong_pick: a
duong_concurred_silently: false
match: true
decision_source: /end-session-shard-e1b7f9d4
---

## Context
Bind mutation test — axes field renamed to topics.

## Why this matters
Tests that the bind-contract tripwire catches a rename of axes -> topics.

---
log_id: 2026-04-21-bind-mutation-log-id
date: 2026-04-21
session_short_uuid: b4e0a2c7
coordinator: evelynn
axes: [scope-vs-debt]
question: "Bind mutation test: decision_id renamed to log_id"
options:
  - letter: a
    description: "Option a"
coordinator_pick: a
coordinator_confidence: medium
coordinator_rationale: "Test only."
duong_pick: a
duong_concurred_silently: false
match: true
decision_source: /end-session-shard-b4e0a2c7
---

## Context
Bind mutation test — decision_id renamed to log_id.

## Why this matters
Tests that the bind-contract tripwire catches a rename of decision_id -> log_id.

---
decision_id: 2026-04-21-bind-mutation-coord-conf
date: 2026-04-21
session_short_uuid: a3d9f1b6
coordinator: evelynn
axes: [scope-vs-debt]
question: "Bind mutation test: coordinator_confidence renamed to coord_conf"
options:
  - letter: a
    description: "Option a"
coordinator_pick: a
coord_conf: medium
coordinator_rationale: "Test only."
duong_pick: a
duong_concurred_silently: false
match: true
decision_source: /end-session-shard-a3d9f1b6
---

## Context
Bind mutation test — coordinator_confidence renamed to coord_conf.

## Why this matters
Tests that the bind-contract tripwire catches a rename of coordinator_confidence -> coord_conf.

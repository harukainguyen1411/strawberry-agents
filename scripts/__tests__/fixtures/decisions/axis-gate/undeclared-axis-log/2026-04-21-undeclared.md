---
decision_id: 2026-04-21-undeclared
date: 2026-04-21
session_short_uuid: zz000001
coordinator: evelynn
axes: [scope-vs-debt, undeclared-axis]
question: "Test decision tagging an undeclared axis"
options:
  - letter: a
    description: "Option a"
coordinator_pick: a
coordinator_confidence: medium
coordinator_rationale: "Test only."
duong_pick: a
duong_concurred_silently: false
coordinator_autodecided: false
match: true
decision_source: /end-session-shard-zz000001
---

## Context
Axis gate test — undeclared axis.

## Why this matters
Tests that rollup rejects logs tagging axes not present in axes.md.

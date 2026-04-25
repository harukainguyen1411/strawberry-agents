---
decision_id: 2026-04-01-old-decision
date: 2026-04-01
session_short_uuid: zz000003
coordinator: evelynn
axes: [old-deprecated-axis]
question: "Historical decision tagging now-deprecated axis (should be preserved)"
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
decision_source: /end-session-shard-zz000003
---

## Context
Axis gate test — old log (predates deprecation date 2026-05-01) tagging deprecated axis.

## Why this matters
Tests that historical decisions on deprecated axes are retained per 3.4.

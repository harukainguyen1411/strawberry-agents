---
decision_id: 2026-05-02-new-uses-deprecated
date: 2026-05-02
session_short_uuid: zz000002
coordinator: evelynn
axes: [old-deprecated-axis]
question: "New decision tagging a deprecated axis (should be rejected)"
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
decision_source: /end-session-shard-zz000002
---

## Context
Axis gate test — new log (mtime after deprecation date) tagging deprecated axis.

## Why this matters
Tests that rollup rejects new decisions tagging deprecated axes.

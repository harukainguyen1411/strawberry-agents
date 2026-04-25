---
decision_id: 2026-04-22-rollout-phased-vs-single
date: 2026-04-22
session_short_uuid: c9f5a7b2
coordinator: evelynn
axes: [rollout-phased-vs-single-cutover]
question: "Pipeline migration: phased rollout or single cutover?"
options:
  - letter: a
    description: "Phased rollout (safer, incremental)"
  - letter: b
    description: "Single cutover with staged verification"
  - letter: c
    description: "Single cutover, fast (quickest to completion)"
coordinator_pick: a
coordinator_confidence: medium-high
coordinator_rationale: "Duong prefers incremental on cross-cutting migrations."
duong_pick: a
duong_concurred_silently: false
duong_rationale: "Phase it. Cross-cutting is risky."
match: true
decision_source: /end-session-shard-c9f5a7b2
---

## Context
Pipeline migration cadence — somewhat irreversible, cross-cutting.

## Why this matters
Rollout-phased-vs-single-cutover axis; phased preference confirmed.

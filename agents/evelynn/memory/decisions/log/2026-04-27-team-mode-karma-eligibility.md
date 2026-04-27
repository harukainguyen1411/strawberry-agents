---
decision_id: 2026-04-27-team-mode-karma-eligibility
date: 2026-04-27
session_short_uuid: e951f0a4
coordinator: evelynn
axes: [explicit-vs-implicit]
question: "Should Karma be teammate-eligible by default, or one-shot by default with teammate as opt-in?"
options:
  - letter: a
    description: "Teammate-eligible by default"
  - letter: b
    description: "One-shot by default with teammate as opt-in"
  - letter: c
    description: "Teammate by default but with single-pass terminator semantics"
coordinator_pick: b
coordinator_confidence: high
coordinator_rationale: "Karma's whole shape is decisive single pass; staying alive across turns is the antipattern for a quick-lane planner."
duong_pick: b
duong_concurred_silently: true
coordinator_autodecided: false
match: true
decision_source: /end-session-shard-e951f0a4
---

## Context

OQ2 from Karma's plan. Self-recommending against teammate-default is honest — Karma's job is hermetic single-pass planning.

## Why this matters

Sets the default dispatch shape for the planner role. Match — no axis update.

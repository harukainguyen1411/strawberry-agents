---
decision_id: 2026-04-27-team-mode-marker-schema
date: 2026-04-27
session_short_uuid: e951f0a4
coordinator: evelynn
axes: [explicit-vs-implicit, scope-vs-debt]
question: "Confirm the completion-marker schema or amend?"
options:
  - letter: a
    description: "Confirm {type, ref, summary} with four type literals AND add optional next_action: <string> for blocked only"
  - letter: b
    description: "Confirm exactly as proposed, no next_action — keep schema minimal"
  - letter: c
    description: "Expand more — severity for clarification_needed, eta for blocked, etc."
coordinator_pick: a
coordinator_confidence: medium
coordinator_rationale: "Blocked without an action hint gives the lead nothing actionable; one optional field is the right minimum-actionable expansion."
duong_pick: a
duong_concurred_silently: true
coordinator_autodecided: false
match: true
decision_source: /end-session-shard-e951f0a4
---

## Context

OQ3 from Karma's plan. The completion-marker is the load-bearing protocol for decision 3 (typed completion-marker convention).

## Why this matters

Locks the schema before Talon implements. Match — no axis update.

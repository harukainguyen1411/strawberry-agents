---
decision_id: 2026-04-27-team-mode-reviewer-flush-protocol
date: 2026-04-27
session_short_uuid: e951f0a4
coordinator: evelynn
axes: [scope-vs-debt]
question: "When Senna or Lucian runs as a teammate, when do they flush memory/learnings? On every verdict, only on shutdown, or both?"
options:
  - letter: a
    description: "Flush memory/learnings on first verdict and stay alive across re-review turns"
  - letter: b
    description: "Flush only on shutdown_request"
  - letter: c
    description: "Flush twice — first verdict and shutdown"
coordinator_pick: b
coordinator_confidence: medium-high
coordinator_rationale: "Per-verdict flush produces partial learnings that pollute the next session; shutdown matches natural session-end semantics."
duong_pick: b
duong_concurred_silently: true
coordinator_autodecided: false
match: true
decision_source: /end-session-shard-e951f0a4
---

## Context

OQ1 from Karma's quick-lane plan for project agent-team-mode-comms-discipline. Senna and Lucian currently say "self-close as final action" — that contradicts the new teammate lifecycle. The flush timing question is downstream.

## Why this matters

Locks reviewer behaviour as teammates. Match — no axis update.

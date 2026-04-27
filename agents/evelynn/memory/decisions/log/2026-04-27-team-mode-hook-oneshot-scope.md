---
decision_id: 2026-04-27-team-mode-hook-oneshot-scope
date: 2026-04-27
session_short_uuid: e951f0a4
coordinator: evelynn
axes: [scope-vs-debt]
question: "Should the T9 detection hook ignore idle_notification events from one-shot subagents (no team_name)?"
options:
  - letter: a
    description: "Ignore — completion-marker contract is teammate-scoped; one-shots have a different lifecycle"
  - letter: b
    description: "Warn anyway — extra observability never hurts"
  - letter: c
    description: "Warn but route to a separate log so signal isn't mixed"
coordinator_pick: a
coordinator_confidence: high
coordinator_rationale: "One-shots' lifecycle is governed by a different contract (final-message-is-the-only-message); conflating them dilutes the warning."
duong_pick: a
duong_concurred_silently: true
coordinator_autodecided: false
match: true
decision_source: /end-session-shard-e951f0a4
---

## Context

OQ6 from Karma's plan. Scopes the new hook's noise floor.

## Why this matters

Avoids signal pollution in the new detection mechanism. Match — no axis update.

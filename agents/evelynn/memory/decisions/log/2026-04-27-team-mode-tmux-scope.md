---
decision_id: 2026-04-27-team-mode-tmux-scope
date: 2026-04-27
session_short_uuid: e951f0a4
coordinator: evelynn
axes: [scope-vs-debt]
question: "Should the runbook revision actively engineer for tmux substrate failures, or relegate tmux to a footnote with the existing escape hatch?"
options:
  - letter: a
    description: "Full coverage — both backends, tmux-death detection plus recovery automation"
  - letter: b
    description: "In-process is the documented default; tmux gets a known-fragile footnote with the config.json escape hatch; not actively engineered"
  - letter: c
    description: "Drop tmux from the runbook entirely — single-backend doc"
coordinator_pick: b
coordinator_confidence: medium
coordinator_rationale: "In-process is verified working end-to-end; tmux engineering is high surface area for rare wins; existing escape hatch is documented."
duong_pick: b
duong_concurred_silently: true
coordinator_autodecided: false
match: true
decision_source: /end-session-shard-e951f0a4
---

## Context

Three-decision batch shaping the agent-team-mode-comms-discipline project. This decision binds whether tmux failure modes consume any of the Karma plan's surface or stay as a documented footnote.

## Why this matters

The tmux backend only activates when the parent CLI is launched from inside tmux; in-process is the verified default. Engineering recovery for a rare path costs more than it saves. Match — scope-vs-debt: leaning b (don't pay for breadth that isn't load-bearing yet).

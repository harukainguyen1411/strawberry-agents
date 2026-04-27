---
decision_id: 2026-04-27-team-mode-sendmessage-contract
date: 2026-04-27
session_short_uuid: e951f0a4
coordinator: evelynn
axes: [scope-vs-debt, explicit-vs-implicit]
question: "Should the runbook mandate SendMessage as the exclusive channel for substantive teammate output, or accept terminal output as a parallel channel?"
options:
  - letter: a
    description: "Hard mandate — every substantive teammate output must be a SendMessage; rule in all teammate-eligible agent defs plus a detection mechanism"
  - letter: b
    description: "Prefer — runbook recommends SendMessage; terminal flagged as user-only side channel; no enforcement"
  - letter: c
    description: "Best-practice prose only"
coordinator_pick: a
coordinator_confidence: high
coordinator_rationale: "Terminal-only output is the structural root cause of every reported failure; soft norms have not held."
duong_pick: a
duong_concurred_silently: true
coordinator_autodecided: false
match: true
decision_source: /end-session-shard-e951f0a4
---

## Context

Three-decision batch shaping the agent-team-mode-comms-discipline project. This decision binds whether the Karma plan includes a structural SendMessage-required rule + detection mechanism, or stays at norm-only prose.

## Why this matters

Without a hard contract, the Lux-style silent-death and Lulu-style empty-idle patterns recur because the harness exposes terminal output as a parallel visible-to-user-only channel. Going hard on (a) is the only option that stops the lead from being blind. Match — no signal update on the axes.

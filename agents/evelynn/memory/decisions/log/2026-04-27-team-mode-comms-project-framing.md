---
decision_id: 2026-04-27-team-mode-comms-project-framing
date: 2026-04-27
session_short_uuid: e951f0a4
coordinator: evelynn
axes: [scope-vs-debt, hand-curated-vs-automated]
question: "How to frame the agent-team-mode-comms-discipline project — scope, research depth, and output shape?"
options:
  - letter: a
    description: "Full graph (lead+peer-to-peer) from day one; research includes empirical + Anthropic docs + Claude Code source/issues; output via Karma quick-lane plan"
  - letter: b
    description: "Lead↔teammate first, defer peer-to-peer; empirical + docs only; same Karma plan output"
  - letter: c
    description: "Lead↔teammate only; empirical only; direct runbook edit, no plan"
coordinator_pick: b
coordinator_confidence: medium
coordinator_rationale: "Smallest credible scope; expected (a) only if the breakage was bigger than I read it; turned out it is."
duong_pick: a
duong_concurred_silently: false
coordinator_autodecided: false
match: false
decision_source: /end-session-shard-e951f0a4
---

## Context

Framing the new project `agent-team-mode-comms-discipline`. Teammates respond into their
own terminals (only Duong sees) instead of replying to the lead via SendMessage; shutdown
requests get ignored. Four framing questions presented; Duong picked 1a (full peer-to-peer
scope), 2a (deepest research), 3a (Karma plan output). Q4 (find empirical example) is
operational and untracked.

## Why this matters

Three of four picks went one band cleaner / deeper than my recommendation. Signal: when the
problem is "communication discipline that has measurably broken in practice," Duong wants
the structurally correct first pass, not the minimum viable one. Tag: scope-vs-debt heavy
lean to `a`, and hand-curated-vs-automated favouring `a` (do the source dive rather than
trust the docs to be complete — we already lost time on the `it2` aspirational entry).

---
decision_id: 2026-04-27-team-mode-completion-signal
date: 2026-04-27
session_short_uuid: e951f0a4
coordinator: evelynn
axes: [explicit-vs-implicit, scope-vs-debt]
question: "How does a teammate signal task completion and acknowledge shutdown — explicit typed marker, ad-hoc ping, or status quo?"
options:
  - letter: a
    description: "Explicit completion-marker convention — typed SendMessage reply for every inbound task and every shutdown_request; idle-without-marker is a runbook violation; lead detects and escalates structurally"
  - letter: b
    description: "Lead pings once on idle-without-content; if no reply by next idle, surfaces stuck-teammate to coordinator log; no marker convention"
  - letter: c
    description: "Status quo — accept ambiguity; runbook says wait, do not ping"
coordinator_pick: a
coordinator_confidence: medium-high
coordinator_rationale: "Collapses three failure modes — silent death, stale-task-already-done, ignored shutdown — under one structural fix. Without it every other rule stays norm-only."
duong_pick: a
duong_concurred_silently: true
coordinator_autodecided: false
match: true
decision_source: /end-session-shard-e951f0a4
---

## Context

Three-decision batch shaping the agent-team-mode-comms-discipline project. This decision binds the runbook's protocol layer — completion signalling and shutdown ack — and is the structural foundation under decision 1.

## Why this matters

The new stale-task pattern Duong added late in the batch (lead dispatches task → teammate already finished it → goes idle without reporting) collapses under the same root cause as Lux's silent death and ignored shutdown_requests. Picking (a) makes one convention solve all three. Match — explicit-vs-implicit and scope-vs-debt both lean toward making the protocol explicit and structural rather than norm-only.

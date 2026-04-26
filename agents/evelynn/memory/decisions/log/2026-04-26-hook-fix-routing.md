---
decision_id: 2026-04-26-hook-fix-routing
date: 2026-04-26
coordinator: evelynn
concern: personal
project: agent-network-v1
axes: [scope-vs-debt, explicit-vs-implicit]
question: How to fix the three pretooluse-monitor-arming-gate.sh bugs (CLAUDE_AGENT_NAME leaks to subagents, CLAUDE_SESSION_ID unset in coordinator shell, post-compact sentinel migration)?
options:
  a: Karma → Talon plan with proper xfail-first, regression tests, full Senna+Lucian review.
  b: Hot-patch in-place — fixes the bleed in 5min but no regression test coverage.
  c: Disable the hook in settings.json for the rest of this session, fix later.
coordinator_pick: a
coordinator_confidence: medium
duong_pick: a
predict: a
match: true
concurred: false
---

## Context

Three real bugs in `scripts/hooks/pretooluse-monitor-arming-gate.sh`: env leak to subagents (the load-bearing one Duong called out), session-id unset bypass, post-compact sentinel loss. Cross-process semantics — Rule 22 / coordinator-intent-check.md mandates full chain regardless of line count.

## Why this matters

Skipping the chain on cross-process-semantics edits is the canonical bypass-self-license failure mode (commit `240bd394` reference). Even surgical, even auto-mode — the rule holds. Karma authors plan + xfail + breakdown in one pass, Talon implements, Senna+Lucian review. Same gates as standard, fewer hops than Azir → Kayn full chain.

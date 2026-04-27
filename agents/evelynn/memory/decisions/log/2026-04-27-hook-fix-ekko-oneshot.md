---
decision_id: 2026-04-27-hook-fix-ekko-oneshot
date: 2026-04-27
coordinator: evelynn
concern: personal
axes: [routing, lane-selection]
question: Which lane fixes pre-commit-agent-shared-rules.sh false-positive on depth-2 nested includes?
options: |
  a: Karma-quick (plan + Talon impl + Senna+Lucian review)
  b: Ekko one-shot in arch-w4-v2 team with regression bats test
  c: Defer — leave 13 files uncommitted on Viktor working tree
coordinator_pick: b
coordinator_confidence: high
duong_pick: hands-off-autodecide
coordinator_autodecided: true
match: hands-off-autodecide
---

# Hook fix dispatch lane: Ekko one-shot

## Context

`pre-commit-agent-shared-rules.sh` false-positive on depth-2 nested includes blocks 13 files (8 agent defs + 5 `_shared/` files) from Viktor's Wave 4 working tree. Bug is bounded: hook reads inlined content to EOF instead of stopping at next `<!-- include: -->` marker.

## Why this matters

Bug spec is precise, fix is surgical (one regex/loop bound), regression test is straightforward. Karma-quick is ceremony for a single-line hook fix. Adding Ekko to existing team rather than spawning a new one keeps team-mode mandate intact while honoring the bounded scope.

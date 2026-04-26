---
status: proposed
concern: personal
owner: azir
created: 2026-04-26
tests_required: false
priority: HIGH
last_reviewed: 2026-04-26
tags: [test]
---

# Fixture: proposed plan with invalid priority value

This fixture has `priority: HIGH` which is not in the allowed set (P0|P1|P2|P3).
The pre-commit-zz-plan-structure.sh hook must reject this file with a message
naming the offending value.

---
status: proposed
concern: personal
owner: azir
created: 2026-04-26
tests_required: false
priority: P2
last_reviewed: not-a-date
tags: [test]
---

# Fixture: proposed plan with non-ISO last_reviewed

This fixture has `last_reviewed: not-a-date` which is not a valid ISO date (YYYY-MM-DD).
The pre-commit-zz-plan-structure.sh hook must reject this file.

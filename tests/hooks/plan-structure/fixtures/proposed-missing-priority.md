---
status: proposed
concern: personal
owner: azir
created: 2026-04-26
tests_required: false
last_reviewed: 2026-04-26
tags: [test]
---

# Fixture: proposed plan missing priority field

This fixture is intentionally missing the `priority:` frontmatter field.
The pre-commit-zz-plan-structure.sh hook must reject this file when staged
under plans/proposed/.

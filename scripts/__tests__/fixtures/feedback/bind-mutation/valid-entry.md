---
date: 2026-04-21
time: "09:00"
author: sona
concern: work
category: review-loop
severity: high
friction_cost_minutes: 30
related_feedback: []
state: open
---

# Bind mutation test fixture

## What went wrong

This fixture exists to support the TT2-bind mutation-simulation test. When the renderer is invoked with `FEEDBACK_INDEX_RENAME_SEVERITY=Priority` the bind-contract assertion that the `Severity` column is present should FAIL, proving the test catches breaking changes before they ship.

## Suggestion

- (A) Ensure the bind-contract test remains in the suite alongside any future INDEX schema changes.

## Why I'm writing this now

Test fixture only — not a real feedback entry. Used by `scripts/__tests__/feedback-index-bind-contract.xfail.bats`.

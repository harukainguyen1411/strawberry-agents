---
date: 2026-04-21
time: "09:15"
author: sona
concern: work
category: review-loop
severity: medium
friction_cost_minutes: 15
related_plan:
related_pr:
related_commit:
related_feedback: [2026-04-21-0900-sona-orianna-signing-latency.md]
state: open
---

# Orianna signing followups

## What went wrong

Three remaining ADRs (managed-agent-lifecycle, s1-s2-service-boundary, session-state-encapsulation) each required 2-3 sign iterations, for a combined ~45 minutes additional signing time following the initial latency report.

## Suggestion

- (A) Apply the batch-fix pre-pass from the sibling entry before any multi-ADR signing session. Effort: S. Owner: Syndra.
- (B) Maintain a known-pattern suppression list per ADR type to cut iterations. Effort: M. Owner: Orianna.

## Why I'm writing this now

Trigger #4 (review/sign cycle >3 iterations) continued across the remaining three ADRs; this entry amends the sibling `orianna-signing-latency` entry with the total cost.

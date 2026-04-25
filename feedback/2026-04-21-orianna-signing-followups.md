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
related_feedback: [2026-04-21-orianna-signing-latency.md]
state: open
---

# Orianna signing followups

## What went wrong

Three remaining ADRs (managed-agent-lifecycle, s1-s2-service-boundary, session-state-encapsulation) each required 2-3 sign iterations, for a combined ~45 minutes additional signing time following the initial latency report. Four additional failure modes surfaced beyond the first entry: (1) body-hash guard missing — Yuumi inlined tasks into signed ADRs, silently invalidating signatures, discovered only at promotion time after ~50 min wall time; (2) signed-fix commit shape forces two commits per successful iteration instead of one; (3) stale .git/index.lock halted an Ekko dispatch requiring a full re-dispatch; (4) sibling -tasks.md vs §D3 one-file shape mismatch blocked all three ADRs simultaneously.

## Suggestion

- (A) Apply the batch-fix pre-pass from the sibling entry before any multi-ADR signing session. Effort: S. Owner: Syndra.
- (B) Add `scripts/hooks/orianna-body-hash-guard.sh` to pre-commit chain; allow signed-fix commit shape (body + signature in one atomic commit). Effort: M. Owner: Viktor.
- (C) Auto-clear stale .git/index.lock (age >60s, no holder) with audit line. Effort: S. Owner: Viktor/Ekko scripts.
- (D) Enforce §D3 one-plan-one-file at plan-structure-check time; error if -tasks.md sibling exists. Effort: S. Owner: Syndra/Kayn.

## Why I'm writing this now

Trigger #4 (review/sign cycle >3 iterations) continued across the remaining three ADRs; this entry amends the sibling `orianna-signing-latency` entry with four additional failure modes discovered in the same session.

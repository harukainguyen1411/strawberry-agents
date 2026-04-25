---
date: 2026-04-21
time: "09:00"
author: sona
concern: work
category: review-loop
severity: high
friction_cost_minutes: 30
related_plan: plans/in-progress/work/2026-04-20-managed-agent-dashboard-tab.md
related_pr:
related_commit: 71fd8a5
related_feedback: []
state: open
---

# Orianna signing latency

## What went wrong

Orianna signing a batch of four work-concern ADRs took ~30 minutes due to full fact-check per attempt, multiple iterations per ADR, and a commit ceremony per fix. The dashboard-tab ADR required 4 commits before a clean sign.

## Suggestion

- (A) Batch-fix pre-pass before first sign: sweep all pending ADRs for known finding categories in one pass. Effort: S. Owner: Syndra.
- (B) Lightweight sign mode skipping path-resolution for `work` ADRs. Effort: M. Owner: Orianna.
- (C) Cache the fact-check output for unchanged sections. Effort: L. Owner: Viktor.

## Why I'm writing this now

Trigger #4 (review/sign cycle >3 iterations) fired: dashboard-tab required 4 sign attempts before clean.

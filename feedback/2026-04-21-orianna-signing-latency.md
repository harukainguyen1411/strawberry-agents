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

Orianna signing a batch of four work-concern ADRs took ~30 minutes due to full fact-check per attempt, multiple iterations per ADR, and a commit ceremony per fix. The dashboard-tab ADR required 4 commits before a clean sign. Three compounding costs: full fact-check per attempt (~90–180s per pass on a 600-line ADR), multiple iterations per ADR (dashboard-tab took 4 commits: 71fd8a5, 0929a4b, b31ecae, e09e245), and commit ceremony per fix (pre-commit hooks, pre-push hooks, signature trailer generation). Result: 3 ADRs × ~3 iterations × ~2 min Orianna + fix composition ≈ 18–30 min floor for a clean batch.

## Suggestion

- (A) Batch-fix pre-pass before first sign: one agent sweeps all pending ADRs for known finding categories (legacy `tools/` paths, URL-tokens, unresolved `?` markers) in a single pass before the first sign attempt. Effort: S. Owner: Syndra.
- (B) Pre-lint at author time: planners (Azir, Swain, Karma) run `check_plan_structure` + lightweight claim-contract pre-scan before handoff. Effort: M. Owner: Lux/Syndra (planner-definition refresh).
- (C) Cache the fact-check output for unchanged sections, reduce over-citation. Effort: L. Owner: Viktor/Orianna prompt team.

## Why I'm writing this now

Trigger #4 (review/sign cycle >3 iterations) fired: dashboard-tab required 4 sign attempts before clean. This is the costliest friction this session.

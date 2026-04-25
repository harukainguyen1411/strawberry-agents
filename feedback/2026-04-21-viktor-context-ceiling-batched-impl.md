---
date: 2026-04-21
time: "11:00"
author: sona
concern: work
category: context-loss
severity: medium
friction_cost_minutes: 20
related_plan: plans/in-progress/work/2026-04-20-managed-agent-dashboard-tab.md
related_pr:
related_commit:
related_feedback: []
state: open
---

# Viktor context ceiling batched impl

## What went wrong

Viktor was dispatched to implement MAL.B and MAD.B/C/F on the `company-os-integration` branch in one run (Task #46, 147 tool uses, 20 min 42 sec). Viktor terminated with "Prompt is too long" — no commit inventory, no pytest output, no progress checkpoint. The coordinator had to reconstruct state by inspecting the integration branch directly. Root cause: complex-track builders batched across multiple phases on a single mutable branch exceed context budget because every phase compounds state (merged tree grows, impl surface grows, pytest output grows, hook chatter grows). Contrast: Rakan ran for similar budget (153 tool uses, 21 min 53 sec) on three independent branches and returned a clean structured report — because her branches didn't share state.

## Suggestion

- (A) Cap Viktor's task batches at 3 tasks per session to stay under context ceiling; split cross-phase impl into one-phase-per-dispatch for complex-track builders on mutable branches. Effort: S. Owner: Aphelios (breakdown sizing).
- (B) Add a mid-session checkpoint step to Viktor's protocol that writes a partial handoff shard before context pressure grows. Effort: M. Owner: Viktor.
- (C) Distinguish phase-independent xfail authoring (Rakan-shape) from cumulative impl (Viktor-shape) in task routing at breakdown step. Effort: S. Owner: Kayn/Aphelios.

## Why I'm writing this now

Trigger #7 (surprise costing >5 minutes) fired: context ceiling was not anticipated from the task batch size, and recovery consumed ~20 minutes of coordinator time. One Viktor dispatch lost.

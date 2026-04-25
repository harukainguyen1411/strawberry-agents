---
date: 2026-04-21
time: "10:00"
author: sona
concern: personal
category: coordinator-discipline
severity: medium
friction_cost_minutes: 10
related_plan:
related_pr:
related_commit:
related_feedback: []
state: open
---

# Phase discipline approved vs in-progress

## What went wrong

Sona began implementation commits on a plan still in `plans/approved/` rather than first moving it to `plans/in-progress/` via the Orianna-gated lifecycle. The pre-push hook caught the violation, but the fix required a branch rename and additional coordination.

## Suggestion

- (A) Add an explicit phase-gate check to the coordinator boot chain that surfaces any plan with open implementation tasks still in `approved/` state. Effort: S. Owner: Evelynn.
- (B) Codify the phase-flip as a mandatory first step in any implementation dispatch prompt. Effort: S. Owner: Aphelios.

## Why I'm writing this now

Trigger #6 (coordinator-discipline slip) fired: a bookkeeping step (phase flip from approved to in-progress) was skipped before implementation began.

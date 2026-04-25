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

Sona began implementation commits on a plan still in `plans/approved/` rather than first moving it to `plans/in-progress/` via the Orianna-gated lifecycle. Three work ADRs (MAD, MAL, BD) were Orianna-signed at the `approved` phase and lived in `plans/approved/work/`. Implementation work was dispatched against them while they were still in `approved/`. The `approved → in-progress` phase flip never ran until Duong asked why the folder was wrong. Momentum and hands-off mode caused the bookkeeping step to be skipped — bookkeeping is invisible until it breaks.

## Suggestion

- (A) Add an explicit phase-gate check to the coordinator boot chain that surfaces any plan with open implementation tasks still in `approved/` state. Effort: S. Owner: Evelynn.
- (B) Codify the phase-flip as a mandatory first step in any implementation dispatch prompt ("flip ADR to in-progress before dispatching the first implementation agent"). Effort: S. Owner: Aphelios.
- (C) Hook: a coordinator-side PreToolUse hook could check that any Agent dispatch referencing a plan path in `plans/approved/` triggers a reminder to promote first. Effort: M. Owner: Viktor.

## Why I'm writing this now

Trigger #6 (coordinator-discipline slip) fired: a bookkeeping step (phase flip from approved to in-progress) was skipped before implementation began.

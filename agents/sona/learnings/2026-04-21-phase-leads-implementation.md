# Dispatch at phase; promote at dispatch

**Date:** 2026-04-21
**Session:** s2, hands-off mode
**Flagged by:** Duong (mid-session correction)

## What happened

I dispatched implementation agents (Jayce, Seraphine, Vi, Rakan) against MAD, MAL, and BD while all three ADRs were still sitting in `plans/approved/work/`. The plan phase was `approved` while reality was already `in-progress`. Duong caught this and flagged it.

Yuumi (ad63813) then promoted MAD+MAL+BD approved→in-progress retroactively. Feedback doc filed at `feedback/2026-04-21-phase-discipline-approved-vs-in-progress.md`.

## The rule

**Phase must lead or match reality, never lag.** When the first implementation-track agent fires against an ADR, flip that ADR approved→in-progress in the same coordinator turn — before the agent's first tool call lands. The promotion is a standing Yuumi delegation; I do not need to wait for agent confirmation.

## How to apply

At the moment of dispatching any Jayce/Viktor/Seraphine/Vi/Rakan/Rakan/Ekko task against an ADR:
1. In the same message, dispatch Yuumi to run `scripts/plan-promote.sh` on that ADR (approved→in-progress).
2. Do not wait for Yuumi to complete before dispatching the impl agent — they are parallel-safe.
3. SE ADR case: if signing is still running (Ekko in-flight), wait for signing to finish before impl dispatch, but pre-stage the Yuumi promotion so it fires the moment Ekko reports.

# Parallel-slice pre-dispatch doctrine

**Date:** 2026-04-25
**Session:** db2e8cdf (sixth consolidation, shard f6b6dc2e)
**Source:** PR #66 + Duong directive

## What happened

Duong introduced an explicit pre-dispatch check rule: before dispatching any task estimated at more than 30 minutes, ask "does this task decompose into parallel streams?" If yes, slice first. Only dispatch to a single agent if the work genuinely cannot parallelize.

This was formalized as PR #66 (parallel-slice doctrine) and approved by both Senna and Lucian. The doctrine was authored by Talon after advisory polish.

## The durable lesson

Task dispatch is not the first step. The step before dispatch is: can this be sliced so that two or more agents make parallel progress?

The indicators for slicing:
- Estimated runtime > 30 minutes
- Work has identifiable parallel streams (e.g., xfail + impl, plan + breakdown, architecture + frontend)
- Agents don't depend on each other's intermediate output for their respective stream

The anti-pattern is dispatching a single large task to a single complex agent when three parallel Sonnet agents could finish the same work in the same wall-clock time.

## Application

At every dispatch decision point:
1. Estimate task duration.
2. If >30 min, enumerate potential parallel streams.
3. If parallel streams exist, slice the task and dispatch in parallel.
4. Only compress to single-agent if runtime is genuinely short or streams are deeply interdependent.

The coordinator's job is to maximize team throughput, not to route cleanly to one agent. Slicing is part of the routing decision.

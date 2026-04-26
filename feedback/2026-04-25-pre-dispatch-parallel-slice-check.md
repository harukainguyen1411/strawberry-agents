---
date: 2026-04-25
time: "12:00"
author: evelynn
concern: personal
severity: medium
category: coordinator-discipline
friction_cost_minutes: 30
slug: pre-dispatch-parallel-slice-check
state: open
---

## What Duong observed

Coordinator dispatches single subagents on tasks estimated to take hours, where the task could be sliced into meaningful parallel streams. Two failure modes flagged by Duong directly:

1. **Subagents are not optimized to run complex tasks nonstop.** "subagent does not have large context window and are not optimized to run complex task nonstop. the result will be worsen the longer it runs."
2. **Parallel-slicing speeds execution multiplicatively.** "If the task can be broken down into multiple parallel stream, it would speed up the execution by multiple factors."

## The pre-dispatch question (Duong's exact framing)

Before any non-trivial dispatch, ask:
- Does the task take longer than 30 minutes?
- Can the task be broken down into meaningful parallel streams?

If BOTH yes → slice and dispatch in parallel. Exception: long-but-simple wait tasks (test runs, deploy validation, etc.) — don't slice these.

## Whose job

- Breakdown agents (Aphelios/Kayn, Xayah/Caitlyn): produce slice-able task lists when the work is non-trivial.
- Coordinator critical thinking: apply the 30m + parallel-stream check before each dispatch.

## Time estimation accuracy

Duong: "the estimation of how long a task last is still heavily bloated, and we should improve on that too." Calibration loop is needed — likely belongs in retrospection-dashboard prompt-quality v1.5 work (post canonical-v1 lock).

## Why this is pre-lock material

Lock target is Saturday post-Phase-2-dashboard-ship. Doctrine should be encoded BEFORE the lock so canonical-v1 includes it.

## Related

- `feedback/2026-04-25-coordinator-discipline-slips.md` (today's three slips — same shape root cause)
- `plans/approved/personal/2026-04-25-coordinator-routing-discipline.md` (routing-check primitive — natural home for the parallel-slice gate amendment)
- Retrospection dashboard plan (time-estimation calibration target)

## What went wrong

Coordinator dispatched single subagents on tasks estimated to take hours without
first checking whether the work could be sliced into parallel streams. Two
compounding failure modes: subagents' context windows degrade on long tasks, and
parallel streams multiply execution speed. Pattern identified by Duong directly.

## Suggestion

Add an explicit pre-dispatch gate to the coordinator protocol: before any
non-trivial dispatch (>30 min estimated), ask "can this be sliced into
meaningful parallel streams?" If yes, slice and dispatch in parallel. Encode
in coordinator-routing-discipline ADR. Exception: long-but-simple wait tasks
(test runs, deploy validation) should not be sliced.

## Why I'm writing this now

Duong flagged this directly as a coordination discipline issue on 2026-04-25.
Writing now to capture the directive before the lock so canonical-v1 includes
the doctrine.

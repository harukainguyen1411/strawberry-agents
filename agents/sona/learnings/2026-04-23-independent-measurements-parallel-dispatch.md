# Independent measurements are parallel dispatch — never serialize in one agent

**Date:** 2026-04-23
**Session:** 536df25c (shard 2026-04-23-cbe48dfe)
**Tags:** dispatch, parallelism, verification

## What happened

Ekko was dispatched to verify Vi's 73-failure baseline claim. The verification required two full pytest suite runs — one on `feat/firebase-auth-2c-impl` (Vi's branch) and one on `feat/demo-studio-v3` (baseline). A single Ekko ran them sequentially, which took materially longer than necessary. When Duong noticed the delay, the correction was made mid-flight: ping the active Ekko to scope down to branch-only, dispatch a second Ekko for baseline.

## Lesson

When a verification task consists of N independent measurements (separate repos, separate branches, separate test scopes), dispatch N agents in parallel from the start. Do not bundle them into a single agent to "reduce overhead" — the overhead of an extra Agent call is negligible compared to the wall-clock cost of sequential execution.

**Rule:** Before dispatching any verification agent, ask: can this be split into independent measurements? If yes, split immediately and dispatch in parallel. The baseline branch vs feature branch pytest comparison is a canonical case.

## Consequence of missing it

Added several minutes of wall-clock wait. Duong had to course-correct mid-session. Pattern is now documented to prevent recurrence.

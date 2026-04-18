# Mock results index fragility in Vitest

## Date
2026-04-19

## Context
PR #26 round-2 — `smoke.test.ts` uses `vi.mocked(defineString).mock.results[2]` to retrieve the `beeSisterUids` param object. The index is derived from the call order of `defineString` in `beeIntake.ts`.

## Problem
If `beeIntake.ts` adds a new `defineString` call before `BEE_SISTER_UIDS`, or reorders calls, `mock.results[2]` silently points to the wrong param. The test continues to green because the mock's `.value` override is applied to the wrong object — the permission-denied branch is never exercised.

## Guard pattern
After retrieving the mock result by index, assert the call name:

```ts
expect(vi.mocked(defineString).mock.calls[2]?.[0]).toBe("BEE_SISTER_UIDS");
```

This turns a silent mis-wire into a loud failure on the next run.

## General rule
Whenever a test selects a mock result by positional index, it must assert the call identity (function name, param name, or first argument) at that index. Without this guard, the test is one refactor away from a vacuous green.

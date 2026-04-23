# Parallel xfail+impl branches drift on API shapes — add reconciliation check before review dispatch

**Date:** 2026-04-23
**Session:** c4af884e (shard 2026-04-23-b1acd96a)
**Tags:** tdd, parallel-dispatch, review-gate

## What happened

PR #75 (Firebase 2c impl, Jayce) and PR #70 (xfails, Vi) were authored in parallel on separate branches per the normal-lane TDD pattern. Seven-way parallel review on PR #75 returned a composite NO-GO: Vi TDD gate failure, Senna request-changes, Akali PARTIAL. Root cause was three API-shape mismatches between what Vi's xfail suite imported and what Jayce's impl actually exposed:
- Root A: `auth._load_session` import path (Vi expected one path; Jayce used another)
- Root B: CI header injection mechanism
- Root C: `session.py` placement

Lucian's LGTM was unaffected because he checks plan fidelity, not API surfaces. The mismatches were invisible until the test runner ran.

## Lesson

When dispatching xfail author (Vi/Rakan) and impl author (Jayce/Viktor) in parallel, their branches diverge during execution. At handoff — before dispatching a review wave — the coordinator should run a lightweight API-shape reconciliation check: do the xfail imports and call signatures match the actual impl surface? This check can be a single Vi or Senna read-only pass, or even a coordinator-level `grep` on key import paths.

**Rule:** After parallel xfail+impl dispatch returns, always gate on "import paths and public API shapes match" before opening PRs to review. A two-minute reconciliation pass here saves a full review-wave cycle.

## Consequence of missing it

Full seven-agent review wave wasted; second wave dispatched for reconciliation only; PR #75 remains blocked until Vi returns.

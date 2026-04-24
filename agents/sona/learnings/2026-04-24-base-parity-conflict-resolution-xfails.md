# Base-parity conflict resolution for stale xfail decorators on merge

**Date:** 2026-04-24
**Session:** 84b7ba50-c664-40d8-9865-eb497b704fb3
**Trigger:** PRs #105 + #106 re-conflicted after PRs #103 + #104 landed on `feat/demo-studio-v3`. Talon resolved by taking base-parity on stale `@P1_XFAIL` decorators.

## Learning

When a feature branch carries `@P1_XFAIL` (or equivalent pending-impl) decorators on tests that have since been implemented and are passing on the base branch, a merge conflict can arise on those decorator lines. The correct resolution is:

**Take base-parity: remove the stale decorator, keeping the test as a live passing test.**

Do NOT keep the `@P1_XFAIL` decorator just because it was present in the feature branch. The base branch's state is truth — if the test is passing on base without the decorator, the decorator is stale.

## Why this is safe

The `@P1_XFAIL` decorator marks a test as expected to fail (pending impl). Once the impl lands and the test passes, the decorator becomes dead code. Keeping it causes the test suite to expect failure and report an xpass (unexpected pass) which may fail CI depending on `strict=True` setting.

## Talon's round 2

PR #106 re-conflicted a second time after PR #105 landed (because #105's merge shifted line positions). This is expected when two PRs touch overlapping test files. The same base-parity resolution applies: run the merge, check the conflict sections, take base on any stale decorators, verify tests pass.

## Instruction to Talon (and future conflict-resolve dispatches)

When resolving merge conflicts involving `@P1_XFAIL` / `@pytest.mark.xfail` decorators:
1. Check the base branch — is the underlying test passing without the decorator?
2. If yes: take base (remove the decorator).
3. If no: keep the decorator (impl hasn't landed yet).
4. After resolution, run the test suite and verify no unexpected xpass or xfail regressions.

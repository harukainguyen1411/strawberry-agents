# PR #22 coordinator-race-closeout — plan/ADR fidelity review

**Date:** 2026-04-22
**Plan:** `plans/in-progress/personal/2026-04-22-concurrent-coordinator-race-closeout.md` (Karma-authored)
**Verdict:** APPROVED (Lucian lane)

## What I checked

- 7/7 tasks mapped to named commits on branch.
- Rule 12 chronology clean: T1+T2 xfails at 09:07Z precede all impl commits (09:09Z onward).
- Orthogonal adoption plan (`staged-scope-adoption.md`) not absorbed — file boundary held.
- Out-of-scope items (worktree split, CC #51885, rename-aware pre-lint) not silently included.
- Plan body byte-identical between `main` and `feat/coordinator-race-closeout` — approved+in_progress signatures remain valid.
- `architecture/key-scripts.md` T7 contract fully honored (all three promised subsections present).

## Noteworthy

- `5799a03` (--absolute-git-dir fix) is justified scope creep — the pre-existing bug was exposed by the T1/T2 test harness; fixing it is a prerequisite for T4 tests passing. Plan fidelity lane does not block this; flagged as commentary-free since plan's Decision implicitly covers "make the tests pass."
- Karma's task decomposition was tight: each commit named its task in the body trailer (`Plan: <path> T<N>`), making the fidelity check trivial. Other planners should emulate this convention.

## Lock contract doc verification pattern

For PRs that promise "update key-scripts.md with X, Y, Z" — grep the final file for the three promised tokens in one shot rather than reading the whole doc. Example:

```
git show <branch>:architecture/key-scripts.md | grep -n -iE "coordinator[- ]lock|_lib_coordinator|strawberry-promote|staged_scope|auto-derive"
```

Fast confirmation all three bullets landed.

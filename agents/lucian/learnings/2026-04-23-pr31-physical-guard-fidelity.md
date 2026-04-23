# PR #31 — plan-lifecycle physical guard fidelity review

**Date:** 2026-04-23
**PR:** #31 (`physical-guard`)
**Plan:** `plans/approved/personal/2026-04-23-plan-lifecycle-physical-guard.md`
**Verdict:** APPROVE

## Summary

PR implements all 7 tasks (T1-T7) faithfully. Single guard script (`pretooluse-plan-lifecycle-guard.sh`) dispatches on tool_name; .claude/settings.json wires it in via two matcher entries (Bash + Write|Edit|NotebookEdit) both pointing at the same script — no second file to drift. v2 commit-phase guards properly archived to `_archive/v2-commit-phase-plan-guards/`. T7 audit is non-blocking (literal `exit 0` at end). All 13 new tests pass locally.

## Fidelity highlights

- Commit order honors Rule 12: T4 xfail commit `f045597` precedes T1 impl `94f504b`; same xfail commit also precedes T7 impl `788e4c6`.
- Protected-path list matches plan exactly. `plans/proposed/**` correctly remains unprotected (verified via INV-4 which has karma writing to `plans/proposed/personal/` → exit 0).
- Single-gate principle preserved — audit script reports orphans but never blocks/reverts.
- T1 collapsed (was T1+T2 in earlier plan revision per `5cc4e2a`); confirmed only one guard file in active hooks dir.

## Reusable patterns

- Two-shape PreToolUse hook (one Bash branch parsing `.tool_input.command`, one Write/Edit/NotebookEdit branch reading `.tool_input.file_path`) is a clean way to gate one logical concern across multiple tool families. The single-script-multiple-matcher pattern in settings.json is the right way to avoid drift.
- xfail-first works well even when the test must guard `[ ! -f $GUARD ] && exit 1` — it gives a meaningful failing-then-passing transition across the impl commit.

## What I'd watch for in similar PRs

- If Claude Code adds new filesystem-mutation tool names (already noted as a maintenance comment in the plan), the dispatch case statement must extend in lockstep with the matcher list in settings.json. A test that pipes an unknown `.tool_name` and asserts pass-through would be a useful regression guard.

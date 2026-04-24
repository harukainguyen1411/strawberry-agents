# Learning: Plan lifecycle guard — staged-commit hole

**Date:** 2026-04-24
**Session:** 576ce828-0eb2-457e-86ac-2864607e9f22 (shard ec53a0d6)
**Concern:** work (cross-concern)
**Severity:** medium

## What happened

Commit `b11eb761` (my consolidation sweep) accidentally included staged plan files from a parallel session. Specifically, a plan was moved from `plans/approved/` to `plans/in-progress/` without going through Orianna — a Rule 19 violation.

## Root cause

`scripts/hooks/pretooluse-plan-lifecycle-guard.sh` covers:
- Bash tool calls with `mv/cp/rm/tee/touch` targeting protected plan directories.
- Write/Edit/NotebookEdit tool calls targeting protected plan directories.

It does **not** cover:
- Files that were already staged (via a prior Write or Bash call) at the time of a `git commit` call.

The gap: if an agent stages a plan-move file in one turn (Bash `mv` caught by the guard? No — it fires pre-tool; if the guard fires it blocks. But if a Write to a new path in `plans/in-progress/` was already staged before this session), a subsequent `git commit` call in a different session will include it without any hook running on the staging operation.

In practice: the guard fires on the act of staging (Write/Edit to protected path, or Bash mv), but a file already staged by a prior action or parallel agent's write is invisible to the per-commit hook. The PreToolUse hook only sees the tool call about to happen, not the existing index state.

## Impact

Rule 19 violation committed to main. Plan appeared to move outside Orianna without her gate — the commit log lacks a `Promoted-By: Orianna` trailer.

## Structural fix needed

PreCommit hook or a pre-push hook that validates: any file newly added under `plans/{approved,in-progress,implemented,archived}/` must have a `Promoted-By: Orianna` trailer in the HEAD commit or a recent ancestor. Alternatively: the plan-lifecycle guard should also run a `git diff --cached` check at commit time to catch pre-staged violations.

## Assigned to

Evelynn's lane (inbox'd in 20260424-0759-017564.md). I flagged it as item 1 of the 5-item backlog.

## Standing rule until fixed

Before any consolidation commit, run `git diff --cached --name-only | grep "plans/in-progress\|plans/approved\|plans/implemented\|plans/archived"` and verify any staged plan-directory files have a valid Orianna gate in their lineage.

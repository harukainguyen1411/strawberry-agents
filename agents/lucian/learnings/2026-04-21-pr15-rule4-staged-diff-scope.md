# PR #15 — rule-4 staged-diff scope fix (prelint shift-left follow-up)

Date: 2026-04-21
Verdict: APPROVE
PR: https://github.com/harukainguyen1411/strawberry-agents/pull/15
Branch: feat/prelint-rule4-staged-diff-scope

## Context

Bug-fix PR dispatched without a standalone plan — correcting a catch-22
introduced by PR #12. The T3 "Migration — grandfather" section of
`plans/approved/personal/2026-04-21-plan-prelint-shift-left.md` (line 37)
had stated: "The hook only runs on staged diffs, so untouched existing plans
stay unaffected until next edit." PR #12 shipped rule 4 as a whole-file
scan anyway, so `orianna-sign.sh` appending a signature to a legacy approved
plan re-triggered rule 4 on prose the current author didn't touch. This PR
restores the stated contract by scoping rule 4 to lines present in
`git diff --cached --unified=0` hunks.

## Fidelity takeaway

- Rules 1 (canonical `## Tasks`), 3 (test-task qualifier), 5 (forward
  self-ref) are **structural invariants** and must stay whole-file.
- Rule 4 is a **line-local prose check** and is the only rule that should
  be staged-diff-scoped. The PR correctly narrows only rule 4.
- The distinction between "hook runs only on staged files" (file-level,
  always true) and "rule 4 validates only staged lines within a staged
  file" (line-level, the new behavior) is the subtlety to watch for in
  future prelint rule additions.

## Review process notes

- Delegation prompt claimed the originating plan was at
  `plans/implemented/personal/...` — it was actually still at
  `plans/approved/personal/...`. PR #12 landed but the plan never promoted.
  Presumably blocked by this exact catch-22. Flagged as a follow-up.
- Running the PR's test file against main's hook (via stash/unstash) gave
  a false "32 passed / 1 failed" result because the new R4 tests assume
  the new impl. Always checkout the PR's worktree to run tests cleanly;
  the existing `strawberry-agents-feat-rule4` worktree was used.
- Rule 12 TDD ordering verified via commit timestamps on branch:
  xfail commit 5bc880c authored 06:14:07Z, impl commit c3817c0 authored
  06:18:52Z. Correct.

## Takeaway for future PRs

When a bug-fix PR is dispatched without its own plan, anchor fidelity
review to the quoted design intent from the originating plan. Here,
the single line "hook only runs on staged diffs" in the Migration
section was the full contract — the PR either honors that phrase or
it doesn't. No room to negotiate.

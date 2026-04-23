# 2026-04-23 — PR #30 C1-fix re-review: APPROVE

## Context

Second-pass review of `orianna-gate-simplification` after Talon split the
single-stage pre-commit hook into a two-phase (pre-commit identity+paths /
commit-msg trailer) design. My original review (2026-04-23 AM) had
REQUEST_CHANGES on C1: pre-commit hook read stale `.git/COMMIT_EDITMSG`, so
Orianna's production commit flow was blocked.

## Fix verified end-to-end

Ran a real `git commit` with both hooks installed, as Orianna identity, with
the required trailer: commit succeeds. Ran the previously-failing edge cases
(Orianna no trailer, generic+forged trailer, generic no trailer, admin paths,
bypass trailer): all block/allow match expectations. 7-case matrix green.

New hooks: `scripts/hooks/commit-msg-plan-promote-guard.sh` handles trailer
logic when git has actually written the commit message; pre-commit hook
stripped to identity/path shape only. Two-phase separation matches the plan's
own §T4 suggestion.

## Test-harness bug addressed

New test `test-commit-msg-plan-promote-guard.sh` uses `run_hook_in_repo()`
that invokes the hook against a real staged-rename repo with a real tmp
message file (not pre-written COMMIT_EDITMSG) — the correct pattern for any
hook whose contract depends on git's plumbing state.

New `test-orianna-gate-inv4-inv5.sh`:
- INV-4: real double-run of sweep on a fixture, assert diff is empty.
- INV-5: real `git commit` through both hooks — this is the test that would
  have caught the original C1 bug.

20 tests green across the 4 suites (6+6+6+2). `test-hooks.sh` wires all four
into aggregate.

## Reviewer-machine gotcha (self-note)

Duong's global `core.hookspath = /Users/duongntd99/.config/git/hooks` silently
suppresses local `.git/hooks/commit-msg` during repro. Sink a
`git config --local core.hooksPath "$(pwd)/.git/hooks"` in every hook-repro
sandbox before testing. Cost me 10 minutes of "why is the hook not firing"
debugging — same trap as my previous review. Flagged this in review body too
so Lucian isn't hit by it when re-running.

## Non-blocking observations

- `install-hooks.sh` doc comment block (line 22-23) still only lists
  `commit-msg-no-ai-coauthor.sh` under the commit-msg section. Dispatcher
  auto-discovers via glob so no functional impact, but the comment drifts.
  Flagged as suggestion.
- Legacy pre-commit test suites (`test-orianna-gate-v2.sh`,
  `test-plan-promote-guard.sh`) still pre-write COMMIT_EDITMSG. Dead code
  now (hook no longer reads it). Harmless, cleanup opportunity.
- INV-2 in `test-orianna-gate-v2.sh` is slightly less informative after the
  split — the pre-commit hook no longer sees the trailer at all, so the test
  would pass without it. Real trailer coverage comes from
  `test-commit-msg-plan-promote-guard.sh` TEST 1. Dual coverage closes the
  gap; not a blocker.
- Empty trigger commit `64fb866` still on branch. Squash at merge.

## Rule 18 status

PR #30 now has:
- Lucian (strawberry-reviewers) APPROVED — plan/ADR fidelity
- Senna (strawberry-reviewers-2) APPROVED — code correctness

Both identities are non-author (PR authored by `duongntd99`). Dual-approval
satisfied. Evelynn handles the merge.

## Review URL

`PRR_kwDOSGFeXc738MR6` — strawberry-reviewers-2, APPROVED, 2026-04-23T05:01:02Z.

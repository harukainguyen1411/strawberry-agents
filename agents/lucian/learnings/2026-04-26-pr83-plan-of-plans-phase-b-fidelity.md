---
date: 2026-04-26
agent: lucian
pr: 83
plan: plans/approved/personal/2026-04-25-plan-of-plans-and-parking-lot.md
verdict: APPROVE
---

# PR #83 — plan-of-plans Phase B (T4–T9) fidelity

Jayce shipped Phase B lint hooks: `pre-commit-zz-plan-structure.sh` (T6) and
`pre-commit-zz-idea-structure.sh` (T7), with auto-wire (T8) and warning-only
sunset gating (T9). All six T4–T9 DoDs verified met; TDD ordering clean
(xfail commit `f8b7d2c1` precedes impl `e69b2b52`).

## What I checked

- Commit headlines match Rule 12 xfail-first contract; CI `xfail-first check` green.
- T4 fixtures cover the three failing classes (missing/bad/stale) + happy path; bats includes `bash -n`.
- T5 fixtures + bats cover all 7 forbidden headers (a–g), plus missing-field, bad-concern, valid, non-ideas-path skip.
- T6 hook: POSIX-portable date validation (`grep -E` regex, no `date -d`); `is_proposed_path` predicate scopes correctly; bad-value error names offending string.
- T7 hook: canonical ADR §A2 error message emitted byte-for-byte (verified via diff inspection).
- T8: `scripts/hooks-dispatchers/pre-commit` globs `pre-commit-*.sh` — auto-wire confirmed; `install-hooks.sh` comment updated per DoD's "if explicit list" allowance.
- T9: `SUNSET_DATE="2026-05-09"` constant; `STRAWBERRY_IDEA_LINT_LEVEL` env knob with `warn|error|auto` semantics.

## Drift notes (non-blocking, posted in review)

1. T6 error message wording — DoD specified literal `"plans/proposed/**: ..."`, hook uses actual file path. T4 test only asserts substring; flagged as wording drift.
2. T9 sunset boundary — auto resolver treats 2026-05-09 itself as warn (off-by-one inclusivity vs ADR's "two weeks"). Will be caught by T18 sunset audit.
3. PR body proactively clarifies the new narrower `pre-commit-zz-plan-structure.sh` does NOT resurrect the archived broader structural linter — fidelity-positive disclosure.

## Pattern reinforcement

Two-commit Phase pattern (xfail bundle + impl bundle) holds clean here. The
`hook_absent_guard()` skip-with-XFAIL-message idiom is reusable and made the
xfail-first commit pass CI without ugly red. Worth promoting as a snippet.

## Identity

Personal-concern, `strawberry-reviewers` lane via `scripts/reviewer-auth.sh`. No `--lane` flag (default = Lucian).

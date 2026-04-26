# PR #86 — T7b depth-2 nested-include impl fidelity

**Verdict:** APPROVE.

**Plan:** `plans/approved/personal/2026-04-21-agent-feedback-system.md` T7b.
**Branch:** `feedback-system-T7b`. **Commit:** `12c3a058`.

## Verified
- §D4.1 depth-2 contract: `resolve_shared_content()` inlines one level deep; nested markers NOT propagated (idempotency preserved, Invariant 5).
- §D4.2 single-marker: lint phase-2 `sort | uniq -d` on `_shared/*.md` markers — passes single, fails duplicate.
- §OQ2 depth-3 error message contains `depth-3`, `Max depth is 2`, plan path + `§OQ2`.
- T8 isolated: diff is only the two scripts. No `_shared/<role>.md` edits, no paired-agent regen. Strict-serial preserved.
- Rule 12: T7a xfail on main at `79ffd373` (PR #84 → f542a766). T7b flips xfail→green on its branch. Bats 15/15 green locally.

## Pattern
- impl-flip PR's diff scope MUST be only the impl file(s); `_shared/<role>.md` mass edits go to T8. Verified by `gh pr view --json files`.
- For depth-N nested-include scripts, the load-bearing assertion is "nested marker NOT emitted" — that's what preserves idempotency, not the inlining itself.
- When impl PRs add CLI args (here, `--agents-dir`), check whether the arg is in service of the test harness (legitimate scope expansion) or a divergent feature — here it's the former (lint runnable against bats fixture dirs).

## Review URL
Personal-lane approve via `scripts/reviewer-auth.sh` as `strawberry-reviewers`.

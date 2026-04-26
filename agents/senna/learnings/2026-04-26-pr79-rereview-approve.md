# PR #79 re-review — retro-dashboard xfail bundle, APPROVE

**Date:** 2026-04-26
**Repo:** strawberry-agents (personal concern)
**Author lane:** Rakan
**Verdict:** APPROVE — all six findings addressed in `bc176a90`
**Auth:** `scripts/reviewer-auth.sh --lane senna` as `strawberry-reviewers-2` (clean)

## Fix-train discipline observation

Rakan's fix commit message was unusually clean — he listed each finding ID (C1, I1-I5) with file/line specifics and the exact substitution applied. That made re-review fast (~12 min including auth verification). Pattern worth flagging in future Rakan PRs as the right shape for fix-commit messages addressing reviewer findings.

## Two non-blocking residuals I documented but did not block on

**(a) "12 contracted columns" mislabel.** The ALLOWED set in `queries-coordinator-weekly.test.mjs` contains 13 members but the test name and comments say "12". The plan §11 also drifts ("12-column row" vs T.P2.1 DoD-(e) which enumerates 11 metric + 2 group-key columns = 13). Test correctness is fine — it enforces the right thing. Fix is a comment edit + plan amendment, not a code change.

**(b) Two `if (!existsSync(...)) return` guards in `quality-grader-gate.test.mjs:178,185` for rollup expected-file presence.** These still read as vacuous-pass-via-internal-early-return, BUT the immediately preceding `it` block on L172-175 fails-loud via `assert.ok(existsSync(ROLLUP_EXPECTED_OFF))`. So in node:test's declared-order execution, file absence already fails the test. Fragile under reorder but narrow surface. Worth a follow-up cleanup — not a blocker.

Calling out these two without blocking is the right move when the deeper pathology (vacuous-pass-via-export-missing) has been fixed everywhere it could meaningfully hide failure. The remaining `existsSync` guards are belt-and-braces, not silent skips of the actual invariant being tested.

## Reviewer-auth flow nominal

`scripts/reviewer-auth.sh --lane senna gh api user` resolved `strawberry-reviewers-2` immediately, no fallback. Personal-concern PRs continue to use the formal-review path; no work-scope concerns apply here.

## Time

~12 min total — most of it was per-finding grep verification (5 lookups) + comment count audit. Fast turnaround because the fix commit message was specific.

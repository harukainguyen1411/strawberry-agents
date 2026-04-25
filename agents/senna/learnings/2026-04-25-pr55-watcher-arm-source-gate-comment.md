# PR #55 — watcher-arm source-gate review (verdict: COMMENTED)

**Date:** 2026-04-25
**Concern:** personal
**Identity:** strawberry-reviewers-2 (Senna lane)
**Branch:** `watcher-arm-source-gate`
**Plan:** `plans/approved/personal/2026-04-25-watcher-arm-directive-source-gate.md`

## Summary

Reviewed Talon's quick-lane fix for the duplicate-watcher-on-/compact bug. Two-prong patch:
1. Source-gate narrowing in `inbox-watch-bootstrap.sh` from `startup|resume|clear|compact` to `startup` only.
2. Prompt rewrite from literal "Arm it before doing anything else" to verify-then-arm (`check existing Monitor tasks and run ps aux | grep ...`).

Posted **COMMENTED** rather than approved because CI is red on `No AI attribution (Layer 3)` — a false-positive on the literal token `CLAUDE_AGENT_NAME` inside the smoke-transcript JSON quoted in the PR body. Code itself is clean.

## Verifications performed

- `run_xfail` is aliased to `run_real` at line 38 — all six bootstrap tests are live assertions, confirmed by reading the file.
- Checked out commit `478fc40d` (T1 only) and ran the test suite: 6 failed / 24 passed. T1's xfail floor is honest under Rule 12.
- HEAD of branch: 30 passed / 0 failed. T2 and T3 turn the 6 red tests green.
- New prompt-shape tests assert four conjuncts (`verify` AND `no-op|already armed` AND `Monitor` AND `inbox-watch.sh`), a regression floor on the old literal, and an operational `ps |Monitor tasks` mention. Not substring tautologies.
- Searched `*.sh`, `*.md`, settings for stale references to the old wording — none in code, only in docs/transcripts/plan file (expected).
- No-jq JSON fallback still valid: new prompt has no `"` or `\` characters, matching the source comment's invariant.

## Pattern: CI Layer 3 false-positive on `CLAUDE_AGENT_NAME`

The `pr-lint-no-ai-attribution.sh` regex flags any verbatim `Claude` token. Smoke transcripts that quote `CLAUDE_AGENT_NAME` (a legitimate env var) trip this. Override is `Human-Verified: yes` in the PR body. Worth a future plan: word-boundary / context awareness so legitimate env-var mentions don't gate merge. Saw the same shape elsewhere in this repo's smoke output style — likely to recur.

## Pattern: literal-vs-goal directive in SessionStart hooks

Same shape as PR #49 (deliberation-primitive). When the literal directive ("X before doing anything else") and the goal ("X is true") diverge after a state-preserving boundary (/compact persists Monitor tasks), literal compliance breaks the goal. Defense-in-depth: gate-narrowing PLUS verify-then-arm wording. The wording fix alone wouldn't be enough if the model treats "verify" loosely; the gate fix alone would be brittle to future re-widening. Combined, both layers must fail for the bug to recur.

## Files referenced

- `/tmp/pr55-review.md` — review body posted
- `scripts/hooks/inbox-watch-bootstrap.sh` (PR diff)
- `scripts/hooks/tests/inbox-watch-test.sh` (PR diff)
- `agents/karma/memory/karma.md` (PR diff — pattern note)

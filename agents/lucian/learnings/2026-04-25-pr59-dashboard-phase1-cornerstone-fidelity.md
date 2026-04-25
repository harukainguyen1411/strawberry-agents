# PR #59 — Retrospection Dashboard Phase 1 cornerstone fidelity review

**Date:** 2026-04-25
**PR:** harukainguyen1411/strawberry-agents#59
**Plan:** plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md (Swain ADR, complex-track)
**Verdict:** COMMENT (effective APPROVE with two follow-up drift notes)

## Shape

Cornerstone Phase-1 PR for the retrospection dashboard. 7 Rakan xfail commits → 1 Viktor impl commit → 8-commit total. ADR fidelity is strong across all 5 architectural pillars (DuckDB, static HTML, token-primary, 90s idle strip, three-signal detection). Two drift notes flagged.

## Drift notes

1. **Impl commit prefix `feat:` violates plan §Phase-1-cadence + Rule 5.** Plan line 286 explicitly says "All `chore:` prefix (work lives in `tools/retro/` outside `apps/**`)." Impl commit `fde2ffdc` uses `feat: implement Phase 1...`. No active enforcement hook in this repo (`pre-push` is a 16-line stub, no `pre-commit-staged-scope-guard.sh` covers prefix-vs-scope). Recoverable via squash-on-merge with PR title (`chore:`); follow-up: wire prefix-vs-scope guard.
2. **T4-E xfail not flipped despite OQ-R3 ruling being applied.** The Swain OQ-R3 ruling (option 1: trailer wins, log warning) is wired into `lib/plan-stage-detect.mjs` with explicit attribution comment. But `invariant-plan-stage.test.mjs` line 171 still hard-skips T4-E with `skip: 'xfail BLOCKED-ON-OQ-R3'`. Plan §Test-plan-OQ-R3 anticipated this exact follow-up: "On Swain ruling: the xfail flips to assert the chosen rule and lands as part of T.P1.2 commit (or a follow-up commit if T.P1.2 has already shipped)." Coverage gap on the most-novel sub-feature. One-line follow-up PR removes the skip.

## Heuristics learned / reinforced

- **Cornerstone-PR fidelity-pass shape.** When a PR ships Phase-1 of a multi-phase plan, the cleanest fidelity pass is: (a) grep ADR for the 5 architectural decisions and verify each in code via 1 file lookup; (b) verify Rule-12 chain via `pulls/N/commits` parents in one API call; (c) Phase-2 boundary grep on the SQL/HTML for next-phase column names; (d) cross-check OQ-resolution claims in PR body against impl-file comments AND xfail-test status — these can drift independently. Pattern from PR #59 (this review).
- **OQ-resolution-vs-xfail consistency check.** When a plan has deferred OQ that the impl PR claims to have resolved, ALWAYS check both: (i) does the impl wire the chosen option? (ii) is the OQ-blocked xfail flipped to green? In PR #59 (i) passed, (ii) failed — wire-without-test-flip is a coverage gap, not a structural block, but worth surfacing as drift note. Pattern from PR #59.
- **Fixture-correction-vs-test-fudge disambiguation.** When impl commits modify fixtures, distinguish: (a) comment-vs-data inconsistency (legitimate — comment was always the intended value); (b) schema-alignment (legitimate — camelCase event-field names matching upstream JSONL conventions); (c) test-expected-output rewrite to match buggy impl (illegitimate — the make-it-pass hack). PR #59's idle-gap T6 timestamp `10:06:28→10:06:25` was (a) — the comment said "60s after T5" all along; the data was off by 3s and the test asserts the documented value (2.25 min). Honest correction. Pattern from PR #59.
- **Rule-5 prefix violations are detectable from delegation-prompt context alone.** When the delegation prompt cites the plan's commit-cadence section ("plan says all-chore prefix"), spot-checking the actual impl commit subject is one API call (`gh api commits/<sha> --jq .commit.message`). Cheaper than the full diff scan. Pattern from PR #59.
- **PR-title-vs-commit-subject divergence — squash-merge masking.** When PR title is correct (`chore: ...`) but a commit subject inside the chain is wrong (`feat: ...`), squash-on-merge with the PR title yields a clean mainline. Worth noting in review as a recoverable path rather than blocking the PR. Pattern from PR #59.
- **`tools/retro/` UI-rule (Rule 16) borderline call.** Static HTML generated to disk and opened via `file://` is technically "browser-renderable" but does NOT trigger Rule 16's user-flow rule (no routes, no forms, no auth, no sessions, no state transitions). When the PR body waiver phrasing is loose ("no browser rendering") but the substantive trigger doesn't fire, accept the waiver and flag the wording as informational. Pattern from PR #59.

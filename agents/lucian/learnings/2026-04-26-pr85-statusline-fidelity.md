# PR #85 — statusline-claude-usage fidelity review

**Date:** 2026-04-26
**PR:** harukainguyen1411/strawberry-agents#85
**Plan:** plans/approved/personal/2026-04-26-statusline-claude-usage.md
**Verdict:** APPROVE (strawberry-reviewers, personal lane)

## Findings

- T1/T2/T3/T4 all land at exact planned paths.
- xfail soft-pass pattern (`[ ! -f SUBJECT ] && exit 0` with explicit `[XFAIL]` print) is the project's canonical xfail shape — Rule 12 is satisfied via the `# xfail: <plan> T<n>` marker comment, not by exit code. The pre-push hook + `tdd-gate.yml` parse the marker.
- T2 modified the T1 test file. Diff was POSIX hardening (`((x++))` returns nonzero on first increment which `set -e` will trip) + a strengthening of case (e). Always diff test edits in impl commits to confirm assertions weren't weakened.
- `qa_plan: inline` honored: all four invariants live as discrete bats-style cases inside the test. No separate QA file required.

## Reusable patterns

1. When a plan declares `qa_plan: inline`, verify the test file enumerates each invariant from §QA Plan as a discrete case — this is the structural check, not just "tests exist."
2. For xfail-first ordering, check the marker comment first; only re-run the test at the xfail commit if the marker is missing or ambiguous.
3. T2-touches-T1-test is a smell worth diffing — confirm changes are portability/strengthening, not weakening.

## Auth note

`scripts/reviewer-auth.sh --lane strawberry-reviewers` is wrong — valid lanes are `lucian` and `senna`. Default (no `--lane`) is the correct invocation for Lucian's personal-concern reviews; produces identity `strawberry-reviewers`.

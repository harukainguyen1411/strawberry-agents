# PR 59 re-review — three new blockers from regression-test handling

Date: 2026-04-25
Verdict: CHANGES_REQUESTED (re-review)
PR: https://github.com/harukainguyen1411/strawberry-agents/pull/59

## Pattern: xfail-first commit fixed the lint, but skip-flip step was dropped

Viktor's xfail-first ordering (commit `6d3226ec` precedes `c036e2ff`) honors Rule 12. But after the impl fix landed, the regression-guard tests (TP1.T8 for B1, TP1.T4-F for I1) were never un-skipped. Their `describe(..., { skip: '<bug-description>' }, ...)` blocks remain unconditional — `node --test` reports `tests 0` for the regression file. This is the inert-guard antipattern: the regression test exists in the tree, but it never runs, so it cannot catch a re-regression of the very bug it was added to guard against.

**Lesson:** when reviewing a B-label resolution that adds a regression test in an xfail-first commit, ALWAYS verify (a) the test was un-skipped after the impl fix landed in the same PR, and (b) it actually runs and passes. Counted-skipped is not the same as protective. Look for `tests 0` / `skipped N` in `node --test` output as a tell.

## Pattern: comment text matching scan regex

The I3 fix extended `DETERMINISM_SCAN_SOURCES` to scan `lib/sources.mjs`. The same fix replaced `new Date()` with the deterministic sentinel — but the replacement comment includes the literal token `new Date()` ("rather than `new Date()`"). The regex `/new Date\(\)/` matches the comment, so the test fails on every CI run. The I3 fix introduced its own regression.

**Lesson:** when extending a source-scan regex to a new file, run the suite locally before submitting. Comments and docstrings can contain the very token the regex tries to forbid. Either rephrase to avoid the literal, or strip comments before scanning. The reviewer trick: clone the worktree, `node --test <file>` and confirm green before posting "looks good."

## Workflow notes

- Branch already had a worktree at `/private/tmp/strawberry-dashboard-phase-1` at the latest HEAD `c036e2ff`.
- Ran `node --test tools/retro/__tests__/*.test.mjs` to surface the R2 failure that gh CI would also catch.
- Ran `bats tools/retro/__tests__/e2e-pipeline.bats` — 9/9 pass (the unit-suite failure is isolated to the determinism source-scan).
- Manually exercised the I1 cross-commit fold via direct call into `parsePlanStageFromGitLog` to confirm the impl works correctly — the only blocker is that the test itself is skipped.
- Submitted via `scripts/reviewer-auth.sh --lane senna gh pr review 59 --request-changes ...` — preflight `gh api user --jq .login` returned `strawberry-reviewers-2`.

## Top three findings posted to PR

1. **B1-NEW (blocker)** — R2 source-scan now red on every CI run. `tools/retro/lib/sources.mjs:384` comment contains literal `new Date()`. Fix: rephrase comment.
2. **B2-NEW (blocker)** — TP1.T8 regression test never un-skipped after B1 fix. Fix: drop unconditional `skip:` from describe block.
3. **B3-NEW (blocker)** — TP1.T4-F xfail test never un-skipped after I1 fix. Same fix as B2.

All three blockers are small, mechanical fixes. The substantive work (B1, I1, I2, I3, nits) is correct.

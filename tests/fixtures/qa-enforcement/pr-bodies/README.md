# PR-lint regression fixtures

Test fixtures for `scripts/ci/pr-lint-qa-verification.sh` (D6 of
`plans/approved/personal/2026-04-27-qa-enforcement-and-breakdown-discipline.md`).

Each fixture is a plain `.txt` file containing a PR body. The expected linter result
is encoded in the filename prefix (a–e) and documented in the table below.

## Fixture map

| File | Expected result | Rule exercised |
|------|----------------|----------------|
| `a-waiver-no-sign-off.txt` | REJECT | D6/D1: `QA-Waiver:` present without paired `Duong-Sign-Off: <iso8601>` line — the explicit PR #59 regression case |
| `b-waiver-with-sign-off.txt` | ACCEPT | D6/D1: `QA-Waiver:` present WITH paired `Duong-Sign-Off: 2026-04-27T10:00:00Z` — valid escape hatch |
| `c-non-ui-no-verification.txt` | REJECT | D6: non-UI PR body with no `QA-Verification:` line and no `QA-Verification-Skipped:` line |
| `d-non-ui-with-verification.txt` | ACCEPT | D6: non-UI PR body with `QA-Verification: <non-empty>` line |
| `e-ui-pr-with-qa-report-no-figma-ref.txt` | ACCEPT | D6/D1: UI PR with `QA-Report:` populated; no `Figma-Ref:` opt-in so `Visual-Diff:` not required |

## Invoking the linter against a fixture

```sh
bash scripts/ci/pr-lint-qa-verification.sh \
  --pr-body-file tests/fixtures/qa-enforcement/pr-bodies/<fixture>.txt
```

Reject cases (a, c) should exit non-zero; accept cases (b, d, e) should exit zero.

## xfail test

`tests/qa-enforcement/test_pr_lint_qa_verification.sh` runs all five fixtures against
the linter helper. That test is RED (xfail) until implementation task T.QA.8 creates
`scripts/ci/pr-lint-qa-verification.sh`.

## The PR #59 false-waiver regression

Fixture `a-waiver-no-sign-off.txt` reproduces the exact `QA-Waiver:` string from PR #59
(`chore: xfail test skeletons — dashboard Phase 1`, merged 2026-04-25). The new pr-lint
job must reject this body shape even though the original PR passed all checks at the time.
This fixture is the concrete regression test commitment for the PR #59 false-waiver case
(ADR §QA Tasks T-QA1).

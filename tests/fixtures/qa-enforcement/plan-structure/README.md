# Plan-structure linter test fixtures

Test fixtures for `scripts/hooks/pre-commit-zz-plan-structure.sh` §QA Plan extension
(D5 Surface 1 of `plans/approved/personal/2026-04-27-qa-enforcement-and-breakdown-discipline.md`).

Each fixture is a minimal plan `.md` file. The expected linter result is encoded in the
filename prefix (a–h) and documented in the table below.

## Fixture map

| File | Expected result | Rule exercised |
|------|----------------|----------------|
| `a-missing-qa-plan-heading.md` | REJECT | D5/D2: `## QA Plan` heading absent; `qa_plan: required` in frontmatter but no body section |
| `b-empty-qa-plan-body.md` | REJECT | D5/D2: `## QA Plan` heading present but body whitespace-only — counts as unpopulated |
| `c-missing-ui-involvement-line.md` | REJECT | D5/D2: body non-empty but `**UI involvement:** yes\|no` line absent |
| `d-invalid-ui-involvement-value.md` | REJECT | D5/D2: `**UI involvement:** maybe` — only `yes` or `no` (case-insensitive) accepted |
| `e-qa-plan-none-missing-justification.md` | REJECT | D5/OQ#4a: `qa_plan: none` without companion `qa_plan_none_justification:` field |
| `f-qa-plan-none-missing-downstream-plan.md` | REJECT | D5/OQ#4a: `qa_plan_none_justification:` present but lacks `downstream_plan: <path>` pointing at a plan in `proposed/`, `approved/`, or `in-progress/` |
| `g-valid-ui-branch.md` | ACCEPT | D5/D2: fully populated UI branch with `**UI involvement:** yes` and all required bullets |
| `h-valid-non-ui-branch.md` | ACCEPT | D5/D2: fully populated non-UI branch with `**UI involvement:** no` and all required bullets |

## Invoking the linter against a fixture

```sh
bash scripts/hooks/pre-commit-zz-plan-structure.sh \
  --fixture-path tests/fixtures/qa-enforcement/plan-structure/<fixture>.md \
  --staged-path plans/proposed/test-fixture.md
```

Reject cases (a–f) should exit non-zero; accept cases (g–h) should exit zero.

## xfail test

`tests/qa-enforcement/test_plan_structure_qaplan.sh` runs all eight fixtures against
the linter. That test is RED (xfail) until implementation task T.QA.6 lands the
`## QA Plan` extension in `scripts/hooks/pre-commit-zz-plan-structure.sh`.

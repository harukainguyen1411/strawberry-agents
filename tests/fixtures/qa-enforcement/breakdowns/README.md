# Breakdown-qa-tasks linter test fixtures

Test fixtures for `scripts/hooks/pre-commit-breakdown-qa-tasks.sh` (D5 Surface 2 of
`plans/approved/personal/2026-04-27-qa-enforcement-and-breakdown-discipline.md`).

The linter is identity-gated: it only enforces `### QA Tasks` when `STRAWBERRY_AGENT`
resolves to `aphelios` or `kayn`. For any other identity the commit is allowed through.

## Fixture map

| File | Identity | Expected result | Rule exercised |
|------|----------|----------------|----------------|
| `a-aphelios-tasks-no-qa-tasks.md` | aphelios | REJECT | D5 Surface 2 / D3: `## Tasks` present, `### QA Tasks` absent |
| `b-aphelios-tasks-empty-qa-tasks.md` | aphelios | REJECT | D5 Surface 2 / D3: `### QA Tasks` heading present but no task lines (no `-` or `*` items) |
| `c-aphelios-tasks-with-qa-tasks.md` | aphelios | ACCEPT | D5 Surface 2 / D3: `### QA Tasks` present and has at least one task line |
| `d-evelynn-tasks-no-qa-tasks.md` | evelynn | ACCEPT | D5 Surface 2: non-breakdown identity; gate does not fire |

## Invoking the harness

```sh
# Reject case (a) — should exit 1
bash tests/fixtures/qa-enforcement/breakdowns/run-fixture.sh \
  tests/fixtures/qa-enforcement/breakdowns/a-aphelios-tasks-no-qa-tasks.md \
  aphelios

# Accept case (c) — should exit 0
bash tests/fixtures/qa-enforcement/breakdowns/run-fixture.sh \
  tests/fixtures/qa-enforcement/breakdowns/c-aphelios-tasks-with-qa-tasks.md \
  aphelios

# Accept case (d) — non-breakdown identity, should exit 0
bash tests/fixtures/qa-enforcement/breakdowns/run-fixture.sh \
  tests/fixtures/qa-enforcement/breakdowns/d-evelynn-tasks-no-qa-tasks.md \
  evelynn
```

## xfail test

`tests/qa-enforcement/test_breakdown_qa_tasks.sh` runs all four fixtures against the
linter. That test is RED (xfail) until implementation task T.QA.7 creates
`scripts/hooks/pre-commit-breakdown-qa-tasks.sh`.

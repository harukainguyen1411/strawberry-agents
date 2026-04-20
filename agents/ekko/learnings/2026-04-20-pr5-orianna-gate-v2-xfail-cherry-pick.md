# PR #5 cherry-pick: orianna gate v2 xfail tests

Date: 2026-04-20

## What happened

PR #5 (`feat: orianna gate v2 — xfail tests for Phase 5`) on `harukainguyen1411/strawberry-agents` had all CI checks fail in 4-5s — billing block, same pattern as PR #4.

All 5 required checks were failing (xfail-first, regression-test, unit-tests, Playwright E2E, QA report). `Deploy Preview` and `Firebase Hosting PR Preview` also failed but are NOT required checks.

## Resolution

Same as PR #4 precedent: diff is `scripts/` + `assessments/` only (no `apps/**`), so Rule 5 chore-scope exemption applies. Closed PR with explanatory comment, cherry-picked 8 commits onto main preserving authorship.

## Local test verification

All 7 test scripts (`scripts/test-orianna-*.sh` + `scripts/hooks/test-pre-commit-orianna-signature.sh`) exit 0 with structured xfail output. 38 total xfail cases as expected — implementation scripts not present yet.

## Commits landed on main

- 3ad163d chore: xfail T5.1 — hash-body helper tests (4 cases)
- 1f0ac30 chore: xfail T5.2 — verify-signature tests (6 cases)
- af9a0ac chore: xfail T5.3 — signature-shape hook tests (4 cases)
- 0e285ba chore: xfail T5.4 — estimate_minutes parser tests (7 cases)
- 57d3337 chore: xfail T5.5 — architecture verifier tests (5 cases)
- a584ac7 chore: xfail T5.6 — sibling-file grep tests (2 cases)
- 672226c chore: xfail T5.7+T7.2 — end-to-end smoke harness + offline-fail test (10 cases)
- 9b49d89 chore: stub T11.1 — assessments placeholder

## Pattern note

When CI is billing-blocked on `harukainguyen1411/strawberry-agents` PRs that are scripts/assessments-only:
1. Check `gh pr checks` — all 4-5s fails = billing block
2. Run test scripts locally to confirm exit 0
3. Close PR with billing block explanation + cherry-pick precedent note
4. Cherry-pick 8 commits, push to main

# 2026-04-19 — PR #48 review: e2e.yml paths-ignore for myapps

## Context
PR #48 on `harukainguyen1411/strawberry-app` added `paths-ignore: ['apps/myapps/**']` to `.github/workflows/e2e.yml` to eliminate duplicate Playwright runs (e2e.yml + myapps-test.yml both ran on myapps PRs).

## Findings
- Change is correct and minimal (2 lines).
- `paths-ignore` only skips when ALL changed paths match; mixed-path PRs still run — correct semantics.
- No collateral impact on other 14 workflows.
- Branch protection is empty today so no required-check hang risk, but if "Playwright E2E" becomes required later, myapps-only PRs would hang (paths-ignore skipped runs report NO status). PR body acknowledges with a wrapper-job follow-up.
- No security surface delta.

## Process learning
- Hit Rule 18: GraphQL rejected `--approve` because reviewer account (Duongntd) == PR author. Fell back to `--comment` advisory LGTM. Always check PR author before choosing approve vs comment.
- `gh pr review --approve` errors with `Review Can not approve your own pull request (addPullRequestReview)` — clear signal to pivot to comment mode.

## Pattern worth remembering
GitHub `paths-ignore`-skipped workflow runs do not fire any status check at all. If the workflow is a required check under branch protection, this creates a pending-forever hang. The canonical fix is a thin always-runs wrapper job that reports success when the path is skipped.

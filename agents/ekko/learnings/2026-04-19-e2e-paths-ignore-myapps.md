# e2e.yml paths-ignore for apps/myapps

## Date
2026-04-19

## Context
Two workflows both ran Playwright on apps/myapps: the generic `e2e.yml` and the per-app `myapps-test.yml`.

## Key findings

- `gh api repos/<owner>/<repo>/branches/main/protection` returns 404 if there are no branch protection rules — this is NOT an auth error. Confirm with GraphQL `branchProtectionRules` query which returns `nodes: []` for truly empty rules.
- When no required checks are configured, a `paths-ignore` skip in GitHub Actions is benign — the job simply doesn't appear in the check suite, it does not block merge.
- The required-check trap (skipped = pending-forever) only matters when the job name is explicitly listed as a required status check in branch protection. Always verify with GraphQL before deciding to add a wrapper job.

## Outcome
PR #48 — `chore/e2e-scope-myapps` — adds `paths-ignore: ['apps/myapps/**']` to `e2e.yml`. No wrapper job needed.

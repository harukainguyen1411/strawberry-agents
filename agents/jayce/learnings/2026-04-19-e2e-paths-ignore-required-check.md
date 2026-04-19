# 2026-04-19 — e2e.yml paths-ignore vs required-check contract

## Session: PR #48 Lucian CHANGES_REQUESTED fix

## Core lesson

`paths-ignore` on a GitHub Actions workflow trigger causes the workflow to not fire at all for matching PRs. GitHub does NOT synthesise a passing status for skipped runs. If the workflow produces a required status check, `paths-ignore` breaks that contract: PRs matching the ignore pattern will sit with the required check pending forever, unmergeable without admin bypass.

## Correct pattern (for required-status workflows)

No `paths-ignore` on the trigger. Always run so the check always reports. Gate inside the job:

1. A detect step computes what changed (using PR base/head SHAs, consistent with `${{ github.event.pull_request.base.sha }}` / `head.sha`).
2. If only the scoped path changed (e.g. `apps/myapps/**`), a skip step echoes a success message. All heavy steps are guarded with `if: steps.detect.outputs.only_myapps != 'true'`.
3. The job exits green without doing real work.

This pattern is already used by `myapps-test.yml` and `myapps-pr-preview.yml` — always cite "No paths filter — always run so the required status check always reports" as the canonical comment.

## Diff base gotcha

The original detect step used `git diff --name-only origin/main...HEAD` which can be stale or incorrect in CI. Sibling workflows use `${{ github.event.pull_request.base.sha }}` / `head.sha` — use those consistently.

## Branch protection probe 404

Non-admin accounts (`Duongntd`, `duongntd99`) receive a 404 on `/repos/.../branches/main/protection` even when protection is active. The top-level `/branches/main` endpoint still reports `protected: true`. Never cite `branchProtectionRules → nodes: []` as "no branch protection" — it's a permission gap, not truth.

## Files changed

- `.github/workflows/e2e.yml` on branch `chore/e2e-scope-myapps`, commit `1b7e38f`

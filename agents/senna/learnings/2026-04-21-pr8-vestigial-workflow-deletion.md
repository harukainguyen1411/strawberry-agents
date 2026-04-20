# PR #8 — Vestigial workflow deletion (strawberry-agents)

## Date
2026-04-21

## Verdict
APPROVED via `strawberry-reviewers-2` lane.

## What the PR does
Deletes 8 workflows copied from `strawberry-app` during the 2026-04-19 public-repo migration:
`ci.yml`, `e2e.yml`, `unit-tests.yml`, `preview.yml`, `landing-prod-deploy.yml`, `myapps-pr-preview.yml`, `myapps-prod-deploy.yml`, `myapps-test.yml`.

Keeps 6 agent-infrastructure workflows: `auto-label-ready.yml`, `auto-rebase.yml`, `pr-lint.yml`, `release.yml`, `tdd-gate.yml`, `validate-scope.yml`.

## Verification checklist for workflow-deletion PRs
1. Surface HEAD commit scope: `git show --stat HEAD -- .github/workflows/` — commit should touch *only* what the PR claims.
2. Grep the full repo for deleted filenames (`ci\.yml|e2e\.yml|...`). Triage matches:
   - Active callers (workflow_call / workflow_run / `uses: ./.github/workflows/*`) → MUST be updated or the PR blocks.
   - Scripts referencing filenames → check whether they read or invoke.
   - Prose in plans/CLAUDE.md/docs → note but usually non-blocking.
3. Confirm no `workflow_call:` / `workflow_run:` cross-refs among the 6 kept workflows.
4. Confirm branch protection absent OR confirm none of the deleted workflows is a required check (PR body cited `gh api .../branches/main/protection` → 404).
5. Confirm commit prefix matches diff scope: `.github/**`-only → `ops:` per invariant 5.

## Three-dot-diff divergence gotcha
`gh pr diff` uses three-dot (merge-base vs HEAD), so a stale branch base makes the PR "look" larger than the commit(s) actually push. On PR #8, the branch base predated 2 main commits; GitHub showed 11 files (8 deletions + 3 "adds"), but the HEAD commit touched only 8 paths. Always diff HEAD directly (`git show --stat HEAD`) to see what the PR actually introduces. If the three-dot view carries unrelated adds/deletes, those are main-side state the branch simply hasn't merged yet — not PR scope. Suggest a merge-main to the author if the divergence is confusing.

## Cross-reference with CLAUDE.md Rule 15
Strawberry/CLAUDE.md rule 15 still references `e2e.yml` as a required check. That rule applies to `strawberry-app` (apps/** lives there), not the agents repo. Deleting `e2e.yml` here is fine; the rule is unaffected. Worth a follow-up plan to disambiguate rule-scope-per-repo, but not a blocker for this PR.

## Lane hygiene
Preflight check `scripts/reviewer-auth.sh --lane senna gh api user --jq .login` returned `strawberry-reviewers-2` as expected. No identity drift.

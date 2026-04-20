# PR #10 — Vestigial workflow deletion round 2 (strawberry-agents)

## Date
2026-04-21

## Verdict
APPROVED via `strawberry-reviewers-2` lane.

## What the PR does
Follow-up to PR #8. Duong approved a deeper audit: the agent repo doesn't need release deploys (no `apps/myapps/`), QA-report linter (no `apps/*/src/`), issue automation (uses Task tools not Issues), or informational validate-scope. This PR deletes:
- `auto-label-ready.yml` (17 lines) — issue labeler; repo uses Task tools not Issues
- `pr-lint.yml` (56 lines) — QA-report presence linter; no UI code to QA
- `release.yml` (61 lines) — Firebase Functions + Firestore/Storage rules deploy; no apps/myapps/ here
- `validate-scope.yml` (33 lines) — informational commit-prefix echo; pre-commit hook already enforces

Also clears `.github/branch-protection.json` contexts[] (had `validate-scope` + `preview`, both stale).

Remaining workflows post-merge: `tdd-gate.yml` + `auto-rebase.yml`. Task brief said "only tdd-gate.yml remains" but auto-rebase.yml does real work (force-rebases open PRs onto main) and was correctly left alone — spec imprecision.

## Verification pattern (reusable)
1. `gh pr view <N> --json files,additions,deletions` — confirm file count/paths match PR title
2. `gh pr diff <N>` — spot-check the JSON edits (branch-protection.json contexts[] emptying)
3. Checkout the PR head via worktree, `ls .github/workflows/` — verify remaining set
4. Grep the checked-out tree for deleted filenames, triage matches by path prefix:
   - `scripts/`, `.github/workflows/` (cross-refs), `.github/branch-protection.json` → blocker if stale
   - `architecture/`, `.claude/agents/`, `.github/pull_request_template.md` → active prose, non-blocking but flag
   - `plans/`, `assessments/`, `agents/*/learnings/`, `agents/*/transcripts/` → historical, ignore
5. Confirm `ops:` commit prefix (diff is `.github/**`-only per invariant 5)

## Doc-drift backlog from this PR
Stale but non-blocking references now exist in:
- `architecture/testing.md` L61, L129 (pr-lint.yml, QA report present)
- `architecture/git-workflow.md` L74 (required-checks table)
- `architecture/deployment.md` L59 (validate-scope section)
- `.claude/agents/akali.md` L25, L33, L38 (QA-Report/QA-Waiver protocol)
- `.github/pull_request_template.md` L24 (QA-Report column)

akali.md is the most load-bearing — that agent's contract points at a CI job that no longer exists. Worth a follow-up chore PR.

## Lane hygiene
`scripts/reviewer-auth.sh --lane senna gh api user --jq .login` → `strawberry-reviewers-2`. Clean.

## Cross-ref
Builds on `2026-04-21-pr8-vestigial-workflow-deletion.md`. The "prose in docs is usually non-blocking" pattern holds — reaffirmed here.

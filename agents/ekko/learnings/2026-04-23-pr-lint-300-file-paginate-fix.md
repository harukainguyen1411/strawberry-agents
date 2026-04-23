# PR Lint >300 File Pagination Fix

Date: 2026-04-23
Topic: gh pr diff HTTP 406 on large PRs

## Problem

`.github/workflows/pr-lint.yml` used `gh pr diff "$PR_NUMBER" --repo "$REPO" --name-only`
to get changed files. GitHub returns HTTP 406 when a PR exceeds 300 changed files.
Combined with `set -e` (implicit in GitHub Actions bash), this killed the workflow
before the Rule 16 check logic ran.

## Fix

Replaced `gh pr diff` with the paginated Files API:
```bash
CHANGED_FILES=$(gh api "repos/$REPO/pulls/$PR_NUMBER/files" --paginate --jq '.[].filename')
```

`--paginate` handles GitHub's 30-per-page default automatically. Output format
(newline-separated filenames) is identical to what `--name-only` produced.

## CI Re-trigger

`gh pr edit 30 --body "$(gh pr view 30 --json body -q .body)"` did NOT trigger
a new workflow run (GitHub deduplicates unchanged body edits). The reliable trigger
is an empty commit pushed to the PR branch — creates a `synchronize` event.

```bash
git --git-dir=<worktree>/.git commit --allow-empty -m "chore: trigger CI re-run"
git --git-dir=<worktree>/.git push origin <branch>
```

## Outcome

- Commit `cd5ff94` on main fixes the workflow.
- PR #30 (orianna-gate-simplification): all 5 checks green after re-run `24816951737`.

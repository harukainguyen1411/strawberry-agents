# PR #48 re-review — e2e.yml myapps scope refactor

**Date:** 2026-04-19
**Repo:** harukainguyen1411/strawberry-app
**PR:** #48 (chore/e2e-scope-myapps)
**Commit reviewed:** 1b7e38f
**Verdict:** advisory LGTM (self-approval blocked; posted via `gh pr comment`)
**Review URL:** https://github.com/harukainguyen1411/strawberry-app/pull/48#issuecomment-4275296107

## What changed vs prior review

The author dropped the `paths-ignore` approach (which Lucian flagged as breaking the required-check contract) and instead:

- Keeps `on.pull_request` unfiltered so the "Playwright E2E" required status always reports.
- Computes `only_myapps` + `has_tdd` in a single detect step using `pull_request.base.sha` / `head.sha` (not `origin/main...HEAD`).
- Adds a green no-op "Skip — myapps-only PR" step.
- Gates all 5 heavy steps (setup-node, npm ci, playwright install, run, upload report) with `only_myapps != 'true' && has_tdd == 'yes'`.

## Key review observations

1. **Empty-diff edge case** — explicitly handled: `if [ -z "$changed" ]; then only_myapps="false"`. Prevents a zero-file PR from being silently treated as myapps-only.
2. **Required-check contract holds** — skip step uses `run: echo` (exit 0). Skipped steps don't fail the job; when the condition is true the echo runs and succeeds. Job conclusion is `success` in both paths.
3. **Pattern matches siblings** — `myapps-test.yml` uses identical `base.sha`/`head.sha` detection + green no-op skip step idiom. e2e.yml inverts the condition (`only_myapps`) which is semantically right since e2e.yml's domain is "everything except myapps."
4. **Deletions and renames** — `git diff --name-only` lists dest paths; deletions inside myapps keep `only_myapps=true` (correct — myapps-test.yml still owns that path).

## Self-approval blocked — operational note

PR author Duongntd == reviewer account. `gh pr review --approve` returns:
```
GraphQL: Review Can not approve your own pull request (addPullRequestReview)
```
Fell back to `gh pr comment` with a clearly labeled "advisory LGTM" header. This is the correct pattern per Rule 18 (no self-approve-and-merge).

## Minor non-blocking observations

- Detect loop now does double duty (TDD walk + myapps scope check). Denser but avoids iterating `$changed` twice.
- `for f in $changed` relies on word-splitting — unsafe for filenames containing spaces. Same behavior as sibling workflows, so consistent (not a regression).

# 2026-04-19 — PR #54 release/preview CI fixes review

## Context
PR #54 on `harukainguyen1411/strawberry-app`, branch `chore/ci-release-preview-fixes`.
Two small GitHub Actions workflow edits to fix live failures:

1. `release.yml`: `ref: ${{ github.event.inputs.ref || github.sha }}` → `... || github.ref_name }}`, plus new top-level `permissions: contents: write`.
2. `preview.yml`: `npx turbo run build --filter=...[origin/main]` → same + `--force`.

## Verdict
APPROVED. Posted as `strawberry-reviewers` via `scripts/reviewer-auth.sh gh pr review 54 --approve`.

## Key reasoning

### `github.sha` vs `github.ref_name` on checkout
- `actions/checkout` with `ref: <sha>` produces a detached HEAD. `git push --follow-tags` then fails with `fatal: You are not currently on a branch`. Confirmed against the failing run log.
- `github.ref_name` on a `push` event resolves to the branch name (`main`), so checkout lands on the branch — `git push` works.
- Trade-off I flagged as Important (non-blocking): `ref_name` fetches **current tip** rather than the triggering commit, so a concurrent push to main could cause the deploy to ship a newer tree than the one that triggered the workflow. `concurrency: release, cancel-in-progress: false` narrows but doesn't eliminate the window. The `deploy-portal-*` tag step uses `github.sha` (the triggering commit), so on race the tag lies about what was deployed.
- Safe mitigation: after the branch checkout, explicitly `git checkout ${{ github.sha }}` for the build, and `git push origin HEAD:main` with the `-f`-free fast-forward for the Changesets commit. Did not require this in the review — acceptable trade-off given main's cadence.

### `workflow_dispatch` rollback semantics
- `${{ inputs.ref || github.ref_name }}` still prefers the user-supplied rollback tag, which is what you want. Rollback checkouts stay detached (tags), but rollback paths don't push tags — harmless.

### `permissions: contents: write`
- Needed because modern repo-default `GITHUB_TOKEN` is read-only; the Changesets commit + tag push require `contents: write`.
- Workflow-level scope is a nit — only `deploy-portal` job needs it; `functions-deploy` and `rules-deploy` inherit write they don't need. Called out as a nit, not a blocker.

### `turbo --force` on preview
- Correct fix for stale-cache-replaying-empty-`VITE_FIREBASE_PROJECT_ID`. No security impact. Minor preview-build perf cost.

### Workflow injection surface check
- No new `run:` blocks. `ref:` input to `actions/checkout` is not shell-evaluated. No attacker-controlled string reaches a shell. Clean.

### Scope audit
- Only the two stated files touched. Line counts (5 additions / 2 deletions) match exactly. No stealth edits.

## Reusable lessons

- When reviewing `actions/checkout` `ref:` changes, always trace both `push` and `workflow_dispatch` paths. `ref_name` vs `sha` has very different semantics for push-race windows and `git push` feasibility.
- `permissions:` block audit: prefer job-scoped over workflow-scoped. Flag workflow-scoped as a nit when multiple jobs exist with differing needs, but don't block on it unless elevation is actually dangerous.
- Detached-HEAD from `ref: <sha>` is a well-known GitHub Actions footgun for workflows that need to `git push` back. The fix is either (a) branch ref for checkout + separate SHA pin for build, or (b) explicit `git switch -c <branch> && git branch -u origin/<branch>` after checkout.

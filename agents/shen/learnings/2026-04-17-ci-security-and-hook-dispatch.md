# CI Security Patterns and Hook Dispatch

Date: 2026-04-17

## Expression injection in GitHub Actions

Never interpolate `${{ github.event.* }}` or any user-controlled context directly in `run:` blocks — it is equivalent to shell injection. Always move to an `env:` stanza and reference the value as `$ENV_VAR` in the script body.

## Subshell exit code swallowing

`cmd | while read x; do ... exit 1; done` — the `exit 1` only exits the subshell, not the parent. Fix: write output to a temp file and read with `while IFS= read -r x; done < "$tmpfile"`, or collect a violation flag variable and check after the loop.

## Required CI check + paths: filter = permanent deadlock

If a workflow has `paths:` triggers and is also a required branch protection check, PRs outside those paths never trigger the workflow, so the required status never appears, and the PR can never merge. Solution: remove `paths:` and use in-job detection to emit a green no-op.

## Git hook naming — dispatcher required

Git fires hooks by exact verb name (`pre-commit`, `pre-push`). Sub-hook files named anything else (e.g. `pre-commit-unit-tests.sh`) never fire. A dispatcher script at the canonical name must iterate and invoke the sub-hooks explicitly.

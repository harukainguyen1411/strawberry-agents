# CI Release + Preview Fixes — 2026-04-19

## Context
PR #54 on harukainguyen1411/strawberry-app batching two CI workflow fixes.

## Fix 1 — release.yml detached-HEAD
- `actions/checkout@v6` with `ref: github.sha` checks out a commit SHA → detached HEAD
- `git push --follow-tags` then fails: "fatal: You are not currently on a branch"
- Fix: use `ref: github.ref_name` for push events (still falls back to `workflow_dispatch` input via `||`)
- `permissions: contents: write` was absent — added at workflow level (required for git push in Actions)

## Fix 2 — preview.yml turbo cache
- Stale Turborepo cache can replay a build where secrets (e.g. VITE_FIREBASE_PROJECT_ID) were empty
- Fix: add `--force` to the turbo build step to bypass cache
- This is a targeted fix for env-dependent builds where cache invalidation isn't guaranteed by content hash alone

## Procedure note
- `safe-checkout.sh` in strawberry-agents only handles existing branches (wraps `git checkout`)
- For new branches in strawberry-app, used `git worktree add /tmp/... -b <branch>` directly
- strawberry-app does not have its own safe-checkout.sh

# GitHub squash-merge UI autopopulates Co-authored-by from worktree git identity

**Date:** 2026-04-24
**Severity:** high
**Session:** 84b7ba50 (post-compact round 4)

## What happened

Three merged work-concern PRs (#114, #115, #117) landed on `missmp/company-os` main with `Co-authored-by: Viktor <viktor@strawberry.local>` trailers. The executor agent (Viktor) had configured a per-worktree `.git/config` with its own identity. When GitHub's UI performs a squash merge, it auto-derives `Co-authored-by` trailers from the commit author fields in the PR branch — including subagent-authored commits on that branch.

This produced AI-identity authoring references on main despite the commit-msg hook in strawberry-agents blocking them locally. The hook doesn't run in the GitHub merge path.

## Root cause

- Per-worktree `.git/config` sets `user.name = Viktor` / `user.email = viktor@strawberry.local`.
- Viktor's commits on the feature branch carry that identity.
- GitHub squash merge UI autopopulates `Co-authored-by` trailers for all unique authors on the branch.
- Result: agent identity lands on the squash commit on main, bypassing all local hooks.

## Fix

Forward-only — cannot rewrite protected main. Structural prevention options:
1. Agents must set `user.name` and `user.email` to the canonical executor account (`duongntd99`) in their worktree `.git/config`, not their own agent identity.
2. Add a `commit-msg` hook to `missmp/company-os` that strips `Co-authored-by: *@strawberry.local` lines.
3. Prefer `gh pr merge --squash --body` with a pre-crafted message that omits AI co-authors.

## Standing rule

Before dispatching any builder agent on a work-repo PR, verify the worktree `.git/config` identity will be `duongntd99`. Per-process `GIT_AUTHOR_NAME`/`GIT_AUTHOR_EMAIL` env vars are the safest binding.

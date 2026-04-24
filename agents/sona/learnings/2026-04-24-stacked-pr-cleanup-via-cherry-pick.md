# Stacked-PR cleanup via cherry-pick onto fresh main

**Date:** 2026-04-24
**Severity:** high
**last_used:** 2026-04-24

## What happened

Self-invite T1 PR #2108 carried 3 foreign commits from a stale base. Lucian REQUEST CHANGES. Rule 11 forbids `git rebase`. The clean fix was cherry-pick onto a fresh main branch.

## The pattern

```bash
# For a stacked PR with contaminated history:
git fetch origin
git checkout -b clean-branch origin/main          # fresh base
git cherry-pick <commit-sha-1> <commit-sha-2>     # pick only the target commits
git push --force-with-lease origin clean-branch   # force-push on non-main is allowed
gh pr edit <PR-N> --base main                     # re-point PR if needed
```

For stacked PRs, re-parent **each layer sequentially** — apply the same recipe to the next layer once the first is merged.

## Why this works under Rule 11

- Rule 11 forbids `git rebase`. Cherry-pick is not rebase — it creates new commits applying the same changes.
- Force-push on non-main branches is allowed (Rule 11 only restricts rebase, not force-push).
- Original commit authorship is preserved by cherry-pick. PR number and comment history are preserved (PR body still points to original PR, comments survive).
- Clean audit trail: old SHA vs new SHA documented in memory/task notes.

## Preflight discipline

Before dispatching any executor on a stacked-PR task:
1. `git fetch origin && git log --oneline origin/main..HEAD` — verify no foreign commits on the feature branch.
2. `gh pr diff --name-only` — confirm diff scope is appropriate.

If contamination is found, perform the cherry-pick cleanup BEFORE dispatching reviewers.

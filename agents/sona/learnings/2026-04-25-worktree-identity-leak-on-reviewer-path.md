# Worktree identity leak on personal-concern reviewer path — direct push variant

**Date:** 2026-04-25
**Session:** c1463e58 (f993d23d, hands-off normal track)
**Severity:** low — cosmetic commit-author leak; no security impact; existing open thread on Evelynn side

## What happened

PR #47 (T-new-E, `strawberry-agents` repo) was reviewed by Senna via the personal-concern reviewer path (`strawberry-reviewers-2` identity). Senna's review commit `d7d6793e` landed on `main` with author `Orianna <orianna@strawberry.local>` — not `strawberry-reviewers-2`.

This is a different variant from the previously documented squash-merge UI autopopulation. The commit was pushed directly to main (not via squash merge), yet the per-worktree `.git/config` agent identity (`orianna@strawberry.local`) leaked through.

## Root cause (same class, different trigger)

Per-worktree `.git/config` sets agent identity. When Senna runs inside a worktree where another agent (Orianna) previously ran and left a `.git/config` identity set, that identity persists for any commit made in that worktree — regardless of merge path (direct push or squash merge).

## Pattern

Any agent running in a "dirty" worktree inherited from a prior session can commit under the prior agent's identity without noticing. The pre-commit hook doesn't check author identity against the calling agent.

## Fix (Evelynn lane — existing open thread)

Per-process GIT_AUTHOR_NAME binding at dispatch time. Options:
1. Coordinator sets `GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL` before calling the agent.
2. Agent def boots with `git config user.name` / `git config user.email` wired to the canonical identity.
3. Pre-commit hook rejects commits where `git log -1 --format="%ae"` ends in `@strawberry.local`.

## What NOT to do

Do not amend the commit after the fact — if it's on a protected main branch, force-push is unavailable. Forward-only fix only.

## Cross-pointers

- `agents/sona/memory/open-threads.md` — "Co-authored-by Viktor leak on main" thread (same root cause class)
- `agents/sona/learnings/2026-04-24-github-squash-merge-coauthored-by-leak.md` — squash-merge UI variant
- Commit `d7d6793e` on `strawberry-agents` main — the instance

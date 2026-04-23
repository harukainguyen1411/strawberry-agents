# Concurrent-agent commit entanglement

**Date:** 2026-04-23
**Session:** c4af884e (hands-off auto mode)

## Pattern

When two or more subagents are dispatched in parallel and both write to the working tree, the pre-commit dispatcher can re-stage sibling files across hook invocations. This causes one agent's commit SHA to carry another agent's staged work — even when the two agents are writing to nominally disjoint files.

The result: commit messages lie about what the diff actually contains. Auditing by commit message becomes unreliable. Downstream agents acting on "what was in commit X" may act on the wrong information.

## Why nominal file disjointedness is insufficient

Git's staging area is global to the working tree, not per-process. Pre-commit hooks that call `git diff --cached` or `git add` see all staged content across all concurrent writers. Even with `STAGED_SCOPE` env var injection per commit, a hook that re-stages files (e.g., auto-formats, appends metadata) can pull in content staged by a sibling agent between the two hook invocations.

## Rule

Serialize any subagent dispatches that may commit to the working tree when both agents touch either:
- `scripts/hooks/` (pre-commit hooks themselves)
- the plans subtree (Orianna promotion commits are the highest-risk surface)

Parallel dispatch is safe only when both agents are isolated in separate git worktrees via `isolation: "worktree"`.

## Evidence

- Orianna plan-1 repair commit `8b9d258`: commit message described the plan-1 ghost repair; diff also carried Karma's xfail tests for plan 6 (staged by a concurrent Karma dispatch).
- Karma plan-6 impl commit: commit message described plan-6 implementation tasks; diff included collateral content staged by a concurrent Orianna dispatch.

Both incidents: no data corruption, but audit trail integrity compromised. Serialization discipline was established starting at approximately commit 105 in the hands-off run.

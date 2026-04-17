# GitHub OAuth Token Lacks `workflow` Scope for `.github/workflows/` Pushes

Date: 2026-04-17

## Lesson

When pushing commits that modify `.github/workflows/` files, GitHub requires the OAuth token
to have the `workflow` scope. The default agent token does NOT have this scope, so pushes
are rejected with "refusing to allow an OAuth App to create or update workflow ... without `workflow` scope".

## Fix

Duong must either:
1. Push manually from a terminal that has a PAT with `workflow` scope, or
2. Re-authenticate the agent token with `workflow` scope added.

## Implication

Any PR branch that includes CI workflow file changes cannot be pushed by the agent.
Communicate the local commit SHA and branch name to Evelynn/Duong so they can push.
Always report this blocker clearly rather than retrying.

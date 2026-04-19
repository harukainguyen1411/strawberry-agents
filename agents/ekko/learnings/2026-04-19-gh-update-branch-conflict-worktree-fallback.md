# gh pr update-branch conflict — worktree fallback

## Context
PR #26 had `mergeable: CONFLICTING` / `mergeStateStatus: DIRTY` even after a prior
manual merge commit (8631802) landed on the branch. `gh pr update-branch` refused with
"Cannot update PR branch due to conflicts."

## Pattern
When `gh pr update-branch` rejects due to conflicts:
1. Use the existing worktree (or add a new one) for the PR branch.
2. Run `git fetch origin main && git merge origin/main` manually.
3. Resolve conflicts in the worktree files directly — read both sides via `git show`.
4. `git add <file> && git commit` the resolution.
5. If the merge commit touches a TDD-enabled package, the pre-push hook will fire.
   Add an empty TDD-Waiver commit before pushing.
6. Push. GitHub's mergeable state refreshes within seconds.

## Conflict resolution rule for functions/package.json
`deploy` script was intentionally removed on main (PR #25 review I4 — bypasses pipeline).
Always drop `deploy`; keep `test` / `test:run` added by the PR branch.

## Last used
2026-04-19 (s10) — PR #26 chore/p1-4-vitest-proof-of-life

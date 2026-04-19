# 2026-04-19 — Kill auto-rebase cascade (PR #51)

## Context

Task: delete `.github/workflows/auto-rebase.yml` from `harukainguyen1411/strawberry-app` via PR.

## What was done

- Pulled latest `main` on the strawberry-app checkout (was 5 commits behind).
- Created worktree at `strawberry-app-worktrees/chore-kill-auto-rebase-cascade` (no safe-checkout.sh in strawberry-app; used raw `git worktree add` per precedent in 2026-04-18-raw-worktree-add-rule3-precedent.md).
- Deleted `.github/workflows/auto-rebase.yml` — the only file change.
- Committed and pushed. PR #51 opened against main.

## Learnings

- `strawberry-app` does not have `scripts/safe-checkout.sh` — raw `git worktree add` is acceptable (same precedent as B16a session).
- Cascade math for the PR body: ~9 PR workflows × ~30 open PRs = ~270 extra runs per merge to main.
- The replacement pattern is `gh pr update-branch <num>` on the single next-in-line PR — O(1) not O(N).
- This PR also closes a Rule 11 violation (workflow used `git rebase`).

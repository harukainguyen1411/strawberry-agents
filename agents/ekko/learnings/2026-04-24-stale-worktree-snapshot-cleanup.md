# 2026-04-24 — Stale Worktree and Snapshot Cleanup

## What was done

Removed 10 stale strawberry-agents git worktrees and 6 old repo snapshots from
`~/Documents/Personal/`.

## Worktrees removed (`git worktree remove`)

All 10 were clean (exit 0 on `git status --short`):

- strawberry-agents-feat-commit-msg-hook
- strawberry-agents-feat-rule4
- strawberry-agents-feat-taxonomy
- strawberry-agents-inbox-watch-v3
- strawberry-agents-orianna-gate-tests
- strawberry-agents-physical-guard
- strawberry-agents-plan-structure-prelint
- strawberry-agents-reviewer-auth-concern-split (PR #42 merged)
- strawberry-agents-subagent-identity-propagation
- strawberry-agents-talon-staged-scope

## Standalone clones removed (`rm -rf`)

None were registered worktrees. Two had ephemeral test-result artifacts only
(not uncommitted source work) — both safe to delete:

- strawberry-b11 (had `dashboards/server/.test-results/unit.json` modified — test artifact)
- strawberry-b11a (clean)
- strawberry-b11b (clean)
- strawberry-b12 (clean)
- strawberry-xfail-seed-cluster (had untracked `.test-results/` dir — test artifact)
- strawberry-app-t212 (clean)

## Skipped (per instructions)

- strawberry-agents-talon-rule19 — Talon #68 actively writing there, left untouched.
- strawberry-agents-worktrees/, strawberry-worktrees/, strawberry-app-worktrees/ — safe-checkout.sh parent dirs, left untouched.
- strawberry/, strawberry-agents/, strawberry-app/ — canonical repos, left untouched.

## Key notes

- `git -C <path>` with absolute path is the correct pattern for checking worktree
  status without cd (avoids shell PATH issues in for-loop contexts).
- `git worktree list` from the main repo is the canonical way to confirm which dirs
  are registered worktrees before deciding between `git worktree remove` vs `rm -rf`.
- Modified test-result JSON files and untracked `.test-results/` dirs in old clones
  are safe to discard — they are never-committed build artifacts.

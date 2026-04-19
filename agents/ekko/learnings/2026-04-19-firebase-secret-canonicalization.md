# Firebase Secret Canonicalization — 2026-04-19

## Task
Amend PR #56 to use `FIREBASE_SERVICE_ACCOUNT` instead of `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA`.

## What happened
- Worktree already existed at `.worktrees/chore-wire-firebase-service-account`.
- Remote was ahead by 3 commits (release.yml + tdd-gate.yml changes from s14). Required fetch + merge before push.
- Both secrets exist in the repo. `FIREBASE_SERVICE_ACCOUNT` was updated 2026-04-19T03:08Z — confirmed non-empty/canonical.
- Duplicate deletion gated on CI green per task spec — correctly deferred.

## Key learnings
- Always check `git worktree list` before running safe-checkout.sh — worktree may already exist.
- The GitHub Secrets API returns `created_at`/`updated_at` but NOT the value. "Updated recently" is the best proxy for "non-empty" without decrypting.
- When remote is ahead and rebase is forbidden, `git fetch + git merge --no-edit` is the correct flow.

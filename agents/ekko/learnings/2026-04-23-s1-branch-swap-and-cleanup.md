# 2026-04-23 — S1 Branch Swap + Branch Cleanup Pass

## S1 restart on feat/demo-studio-v3

- When the main worktree has diverged from origin (local has 2 commits, remote has 2 different commits), `git pull` fails. Use `git merge origin/<branch> --no-edit` (no-rebase rule).
- Merge conflicts on `test-results.json`/`test-run-history.json` are always safe to resolve with `--theirs` (ephemeral test artifacts, no semantic content).
- `run_in_background: true` spawns an isolated shell — env vars `source`d in the command string do NOT persist to that shell's uvicorn child process. Pattern: use a subshell `( set -a; source .env; source .env.local; set +a; cd appdir; uvicorn ... & echo $! )` and capture PID. This keeps the env export contained and returns the PID synchronously.
- `/auth/config` returning empty fields = env vars not propagated. Always verify with `/auth/config`, not just `/health`.

## Branch/worktree cleanup

- `git worktree prune` (no flags) safely removes stale admin entries for worktrees whose directories are gone (e.g. `/private/tmp` cleared by macOS). No files touched, no branch data lost.
- `git branch -d` respects the no-force boundary. When a PR was squash-merged, the local branch tip diverges from HEAD and `-d` fails. This is by design. Do NOT use `-D` — flag to Duong for manual cleanup.
- PR #75 (feat/firebase-auth-2c-impl) squash-merged: local branch has extra xfail-reconciliation commits not in the squash. `git branch -d` blocked. Left for Duong: `git branch -D feat/firebase-auth-2c-impl`.
- `fix/akali-qa-bugs-2-3-4` (PR #64), `test/s1-new-flow-xfails-wave2` (PR #62), `fix/s3-firestore-dep` (PR #60) were CLOSED not MERGED — kept.
- `feat/p1-t11-session-allowlist`: no upstream remote tracking, no PR, has implementation commits. NOT deleted — still needed for P1 task path.
- `feat/firebase-auth-2c-xfails`: still has active worktree at `feat-firebase-2c-xfails`. Not deleted.

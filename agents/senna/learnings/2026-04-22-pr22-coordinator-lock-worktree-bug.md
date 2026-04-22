# PR #22 — coordinator lock broken in worktrees

Date: 2026-04-22
PR: `feat/coordinator-race-closeout` (Talon)
Verdict: CHANGES_REQUESTED

## Critical finding

`scripts/_lib_coordinator_lock.sh` consumers pass `"$REPO_ROOT/.git/strawberry-promote.lock"`
as the lockfile path. In any git worktree, `$REPO_ROOT/.git` is a plain file
(contains `gitdir: ...`), not a directory. Result:
- flock branch: `exec 9>"$file"` fails with "Not a directory"
- mkdir fallback: `mkdir "$file.dir"` fails identically

Because bash doesn't abort on the exec redirection failure, flow falls through
to the flock contention branch. Every invocation from a worktree prints
"already running (pid unknown)" — a misleading, persistent-false-positive contention.

**Test blind spot:** all three test scripts use `git init` in a tmpdir (standard
repo layout, `.git` is a directory). None exercise a worktree. Given Rule 3
requires worktree-based branches, this is the actual deployment path.

**Fix:** use `git rev-parse --git-common-dir` for the lockfile parent. This
(a) works in both standard repos and worktrees, (b) gives the shared-across-
worktrees location that an advisory lock actually wants.

## Pattern: "`.git` may be a file, not a directory"

Anytime a script hardcodes `$REPO_ROOT/.git/<path>`, verify behaviour in a
worktree. Check by running the script against a worktree created via
`git worktree add`. The `.git` directory exists only at the main worktree;
secondary worktrees have a `.git` file.

Useful rev-parse flavours:
- `--git-dir` — may be relative, resolves `.git` file pointer
- `--absolute-git-dir` — worktree-local gitdir (e.g. `.git/worktrees/<name>/`)
- `--git-common-dir` — shared gitdir across all worktrees

## Secondary findings posted

- I1: `exec 9>"$file"` truncates before flock check → holder PID lost
- I2: mkdir-fallback has no stale-lock recovery (Git Bash on Windows)
- S1: `STAGED_SCOPE` validation allows `..`-traversal (defense-in-depth only;
  `git commit -- <pathspec>` blocks it anyway)

## Review URL

https://github.com/harukainguyen1411/strawberry-agents/pull/22#pullrequestreview-PRR_kwDOSGFeXc73klRj

## Identity

Posted under `strawberry-reviewers-2` via `scripts/reviewer-auth.sh --lane senna`.
Lucian's APPROVED review sits in a separate slot (`strawberry-reviewers`).
Both reviews coexist on the PR — no masking. The dual-lane architecture
(post-PR-#45 incident) holds.

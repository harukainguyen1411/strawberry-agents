# 2026-04-18 — Trap handling and lock hygiene in bash advisory locks

## Context

Reworked `scripts/evelynn-memory-consolidate.sh` (PR #144) to address 7 review findings from Jhin and Lux.

## Key learnings

### Unified EXIT trap must precede lock acquisition

The original script registered the lock-cleanup trap AFTER acquiring the lock, then replaced it with the tempfile-cleanup trap later. Bash only keeps the last registered handler per signal — so the lock was never cleaned on normal exit. Fix: register a single `_cleanup()` function covering all resources (lock + temps) as `trap '_cleanup' EXIT INT TERM` before any lock attempt.

### noclobber lock requires PID liveness check

`flock` is self-healing (process death releases the lock). noclobber is not — SIGKILL or crash leaves a stale lockfile forever. Before refusing a lock, read the PID from the file and run `kill -0 <pid>`. Dead PID = stale lock = safe to reclaim.

### git add -A in a shared working directory is dangerous

`git add -A <dir>` will stage anything in that directory tree, including temp files or decrypted outputs from concurrent sessions. Always build an explicit list of paths the script creates and stage only those.

### git mv resets mtime — embed date in filename for durable prune

When pruning archived files by age, mtime of the archive file reflects time-of-move, not time-of-session. Encode the session date into the filename (YYYY-MM-DD prefix) so prune logic is stable across moves. Fall back to `git log --follow --diff-filter=A` for files lacking a date prefix.

### UUID collision loops must be bounded with explicit rollback

An unbounded collision loop risks infinite iteration. A single -2 fallback risks silent partial state on a second collision. The right shape: loop with incrementing suffix up to a documented bound (100), exit 1 loud if exhausted before any further git operations.

### `command -v python3` guard belongs at the very top

Rule 10 requires POSIX portability including Git Bash on Windows. Scripts that depend on python3 must guard before any other work so the failure is clear, not a mid-run confusing error.

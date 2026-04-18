# Learning: noclobber lock race on macOS + trap-before-acquire ordering

**Date:** 2026-04-18
**Context:** PR #144 evelynn memory sharding — consolidation script

## Pattern

`set -o noclobber` in a subshell is the correct POSIX-portable fallback for `flock` (absent on stock macOS). However two bugs combine in the pattern used:

1. If the script aborts early via `set -euo pipefail`, the `trap 'rm -f "${LOCK_FILE}"' EXIT` fires immediately, releasing the lock before the critical section completes. A second concurrent process that was spinning will see the lock gone and proceed.

2. No PID verification: the lock file contains `$$` but nothing checks it after the critical section. A stale lock from a crash (without the trap firing) can block the script permanently.

## Correct Pattern

- Register the trap BEFORE acquiring the lock.
- In the trap handler, only remove the lock if the current PID matches the stored PID (or always remove — the advisory nature means a missed removal is worse than a spurious removal).
- On Linux with flock: close fd 9 explicitly at end of successful run.

## Application

Flag any shell script using noclobber as an advisory lock without PID verification or with the trap registered after the lock-acquire branch.

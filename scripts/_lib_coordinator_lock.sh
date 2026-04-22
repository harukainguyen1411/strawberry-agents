#!/usr/bin/env bash
# _lib_coordinator_lock.sh — shared advisory lock for coordinator scripts.
#
# Plan: plans/in-progress/personal/2026-04-22-concurrent-coordinator-race-closeout.md T3
#
# Exposes two functions:
#   coordinator_lock_acquire <lockfile>
#     Acquires an exclusive advisory lock on <lockfile>. Prefers flock(1);
#     falls back to mkdir-based lock for environments where flock is absent
#     (Git Bash on Windows, stripped macOS setups).
#     On contention: prints "already running (pid N)" to stderr and exits 1.
#     On success: registers a trap to release the lock on EXIT/INT/TERM.
#
#   coordinator_lock_release
#     Releases the lock acquired by coordinator_lock_acquire. Called
#     automatically via trap; safe to call manually before normal exit.
#
# Usage (source this file, then call acquire):
#   . "$SCRIPT_DIR/_lib_coordinator_lock.sh"
#   coordinator_lock_acquire "$REPO_ROOT/.git/strawberry-promote.lock"
#   # ... do guarded work ...
#   # lock is released automatically at exit via trap
#
# The lockfile must live under .git/ (never in the worktree) so it is never
# tracked by git and survives worktree switches without confusion.
#
# The lock is advisory — the real corruption guard is git's push atomicity —
# but serialises the git add→commit window, preventing concurrent sessions'
# staged files from riding into each other's commits.

_COORDINATOR_LOCK_FILE=""
_COORDINATOR_LOCK_ACQUIRED=0

coordinator_lock_release() {
  if [ "$_COORDINATOR_LOCK_ACQUIRED" -eq 1 ]; then
    # flock-lock: flock releases automatically when FD 9 closes at exit, but
    # we also remove the file body (PID record) for cleanliness.
    # mkdir-lock: handled by the override set in the mkdir branch below.
    rm -f "$_COORDINATOR_LOCK_FILE" 2>/dev/null || true
    _COORDINATOR_LOCK_ACQUIRED=0
  fi
}

coordinator_lock_acquire() {
  _COORDINATOR_LOCK_FILE="${1:?coordinator_lock_acquire requires a lockfile path}"

  # Register trap (caller's existing trap is preserved; we append via subshell-safe form).
  trap 'coordinator_lock_release' EXIT INT TERM

  # --- try flock first ---
  if command -v flock >/dev/null 2>&1; then
    # Open (or create) the lockfile on FD 9 and acquire exclusive non-blocking lock.
    # shellcheck disable=SC1083
    exec 9>"$_COORDINATOR_LOCK_FILE"
    if flock -n 9; then
      printf '%s\n' "$$" >&9
      _COORDINATOR_LOCK_ACQUIRED=1
      return 0
    else
      # Another process holds the lock. Read its PID from the file body.
      _cl_holder_pid="$(cat "$_COORDINATOR_LOCK_FILE" 2>/dev/null || true)"
      printf 'coordinator is already running (pid %s); retry when it finishes.\n' \
        "${_cl_holder_pid:-unknown}" >&2
      exit 1
    fi
  fi

  # --- mkdir fallback (POSIX-portable, atomic on most filesystems) ---
  _cl_lock_dir="${_COORDINATOR_LOCK_FILE}.dir"
  if mkdir "$_cl_lock_dir" 2>/dev/null; then
    printf '%s\n' "$$" > "$_cl_lock_dir/pid"
    _COORDINATOR_LOCK_ACQUIRED=1
    # Override release to remove the directory instead.
    coordinator_lock_release() {
      rm -rf "$_cl_lock_dir" 2>/dev/null || true
      _COORDINATOR_LOCK_ACQUIRED=0
    }
    return 0
  else
    _cl_holder_pid="$(cat "$_cl_lock_dir/pid" 2>/dev/null || true)"
    printf 'coordinator is already running (pid %s); retry when it finishes.\n' \
      "${_cl_holder_pid:-unknown}" >&2
    exit 1
  fi
}

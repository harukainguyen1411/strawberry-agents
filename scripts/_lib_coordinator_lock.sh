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
  local _cl_raw_path="${1:?coordinator_lock_acquire requires a lockfile path}"

  # C1 fix: if the path's parent component is a file (git worktree — .git is a
  # plain file, not a directory), resolve the shared gitdir via
  # git rev-parse --git-common-dir and rebase the lockfile filename onto it.
  local _cl_lock_parent
  _cl_lock_parent="$(dirname "$_cl_raw_path")"
  if [ -f "$_cl_lock_parent" ] && [ ! -d "$_cl_lock_parent" ]; then
    local _cl_common_dir
    _cl_common_dir="$(git rev-parse --git-common-dir 2>/dev/null)" || true
    if [ -n "$_cl_common_dir" ] && [ -d "$_cl_common_dir" ]; then
      _cl_raw_path="$_cl_common_dir/$(basename "$_cl_raw_path")"
    fi
  fi
  _COORDINATOR_LOCK_FILE="$_cl_raw_path"

  # Register trap (caller's existing trap is preserved; we append via subshell-safe form).
  trap 'coordinator_lock_release' EXIT INT TERM

  # --- try flock first ---
  if command -v flock >/dev/null 2>&1; then
    # I1 fix: use read-write open (9<>) instead of write-only (9>) so the file
    # is not truncated before flock completes. The holder writes its PID after
    # acquiring the lock; a contender reading the same file sees the PID intact.
    # shellcheck disable=SC1083
    exec 9<>"$_COORDINATOR_LOCK_FILE"
    if flock -n 9; then
      # Truncate then write our PID atomically now that we hold the lock.
      : > "$_COORDINATOR_LOCK_FILE"
      printf '%s\n' "$$" > "$_COORDINATOR_LOCK_FILE"
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
    # I2 fix: stale-lock recovery — if the holder PID no longer exists, reclaim.
    _cl_holder_pid="$(cat "$_cl_lock_dir/pid" 2>/dev/null || true)"
    if [ -n "$_cl_holder_pid" ] && ! kill -0 "$_cl_holder_pid" 2>/dev/null; then
      # Stale lock: holder process is gone. Remove and retry once.
      rm -rf "$_cl_lock_dir" 2>/dev/null || true
      if mkdir "$_cl_lock_dir" 2>/dev/null; then
        printf '%s\n' "$$" > "$_cl_lock_dir/pid"
        _COORDINATOR_LOCK_ACQUIRED=1
        coordinator_lock_release() {
          rm -rf "$_cl_lock_dir" 2>/dev/null || true
          _COORDINATOR_LOCK_ACQUIRED=0
        }
        return 0
      fi
    fi
    printf 'coordinator is already running (pid %s); retry when it finishes.\n' \
      "${_cl_holder_pid:-unknown}" >&2
    exit 1
  fi
}

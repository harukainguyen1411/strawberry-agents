#!/bin/sh
# xfail: T6 of plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md
#
# Test: stale git index.lock auto-recovery helper — three cases
# Plan task: T6 (kind: test) — precedes T7 (implementation) per Rule 12.
#
# Cases:
#   CASE_1_STALE_CLEARED    — stale lock older than 60s with no holder is cleared
#                             and the expected audit line is emitted to stderr
#   CASE_2_FRESH_NOT_CLEARED — fresh lock younger than 60s must NOT be cleared
#   CASE_3_HELD_NOT_CLEARED  — lock held by a live flock holder must NOT be cleared;
#                              skip gracefully when flock is unavailable
#
# xfail guard: all three cases report xfail and exit 0 when the helper script
# _lib_stale_lock.sh does not yet exist (T7 not implemented).
#
# Run: bash scripts/test-orianna-stale-lock-recovery.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HELPER="$SCRIPT_DIR/_lib_stale_lock.sh"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; FAIL=$((FAIL + 1)); }
skip() { printf 'SKIP  %s  (%s)\n' "$1" "$2"; }

# --- XFAIL guard ---
if [ ! -f "$HELPER" ]; then
  printf 'XFAIL  _lib_stale_lock.sh not present — all 3 cases xfail (T7 not yet implemented)\n'
  printf 'XFAIL  CASE_1_STALE_CLEARED\n'
  printf 'XFAIL  CASE_2_FRESH_NOT_CLEARED\n'
  printf 'XFAIL  CASE_3_HELD_NOT_CLEARED\n'
  printf '\nResults: 0 passed, 3 xfail (expected — implementation not present)\n'
  exit 0
fi

# Verify the helper exposes maybe_clear_stale_lock
# shellcheck disable=SC1090
. "$HELPER"
if ! command -v maybe_clear_stale_lock >/dev/null 2>&1; then
  printf 'XFAIL  maybe_clear_stale_lock function not found in _lib_stale_lock.sh — all 3 cases xfail\n'
  printf 'XFAIL  CASE_1_STALE_CLEARED\n'
  printf 'XFAIL  CASE_2_FRESH_NOT_CLEARED\n'
  printf 'XFAIL  CASE_3_HELD_NOT_CLEARED\n'
  printf '\nResults: 0 passed, 3 xfail (expected — function not exported)\n'
  exit 0
fi

# Helper: create a minimal git repo structure (just the .git dir)
make_git_dir() {
  r="$(mktemp -d)"
  mkdir -p "$r/.git"
  printf '%s' "$r"
}

# set_lock_age: given a lock file path, set its mtime to AGE seconds ago
# Uses touch -t on macOS/Linux portably via a calculated timestamp
set_lock_age() {
  lockfile="$1"
  age_seconds="$2"
  # Compute target timestamp: now minus age_seconds
  # Use perl if available (portable), else python3, else date arithmetic
  if command -v perl >/dev/null 2>&1; then
    ts="$(perl -e "use POSIX; print strftime('%Y%m%d%H%M.%S', localtime(time() - $age_seconds));")"
  elif command -v python3 >/dev/null 2>&1; then
    ts="$(python3 -c "import datetime, time; t=datetime.datetime.fromtimestamp(time.time()-${age_seconds}); print(t.strftime('%Y%m%d%H%M.%S'))")"
  else
    # Last resort: accept imprecision
    ts="$(date -r $(($(date +%s) - age_seconds)) '+%Y%m%d%H%M.%S' 2>/dev/null || date '+%Y%m%d%H%M.%S')"
  fi
  touch -t "$ts" "$lockfile"
}

# --- CASE 1: Stale lock (>60s old, no holder) — must be cleared with audit line ---
REPO="$(make_git_dir)"
LOCK="$REPO/.git/index.lock"
printf 'stale\n' > "$LOCK"
set_lock_age "$LOCK" 120  # 2 minutes old
stderr_out="$(mktemp)"
rc=0
GIT_DIR="$REPO/.git" maybe_clear_stale_lock 2>"$stderr_out" || rc=$?
if [ ! -f "$LOCK" ]; then
  # Check audit line emitted to stderr
  if grep -qi "stale\|cleared\|audit\|index.lock" "$stderr_out"; then
    pass "CASE_1_STALE_CLEARED"
  else
    fail "CASE_1_STALE_CLEARED" "lock was cleared but no audit line emitted to stderr"
  fi
else
  fail "CASE_1_STALE_CLEARED" "stale lock was not cleared (still present after maybe_clear_stale_lock)"
fi
rm -f "$stderr_out"
rm -rf "$REPO"

# --- CASE 2: Fresh lock (<60s old) — must NOT be cleared ---
REPO="$(make_git_dir)"
LOCK="$REPO/.git/index.lock"
printf 'fresh\n' > "$LOCK"
set_lock_age "$LOCK" 10  # 10 seconds old — below the 60s threshold
rc=0
GIT_DIR="$REPO/.git" maybe_clear_stale_lock 2>/dev/null || rc=$?
if [ -f "$LOCK" ]; then
  pass "CASE_2_FRESH_NOT_CLEARED"
else
  fail "CASE_2_FRESH_NOT_CLEARED" "fresh lock should NOT have been cleared (mtime < 60s)"
fi
rm -rf "$REPO"

# --- CASE 3: Lock held by live flock holder — must NOT be cleared ---
# Skip gracefully when flock is unavailable (e.g. macOS without util-linux)
if ! command -v flock >/dev/null 2>&1; then
  skip "CASE_3_HELD_NOT_CLEARED" "flock not available on this platform — skipped per plan spec"
else
  REPO="$(make_git_dir)"
  LOCK="$REPO/.git/index.lock"
  printf 'held\n' > "$LOCK"
  set_lock_age "$LOCK" 120  # would normally be cleared — but holder keeps it
  # Hold an exclusive lock on the file for the duration of this subshell
  (
    flock -x 9
    # Signal parent that lock is held then wait for it to finish checking
    printf 'held\n' > "$REPO/.lock-acquired"
    # Sleep long enough for the test to run
    sleep 5
  ) 9>"$LOCK" &
  FLOCK_PID=$!
  # Wait for the lock to be acquired
  waited=0
  while [ ! -f "$REPO/.lock-acquired" ] && [ "$waited" -lt 30 ]; do
    sleep 0.1 2>/dev/null || sleep 1
    waited=$((waited + 1))
  done
  rc=0
  GIT_DIR="$REPO/.git" maybe_clear_stale_lock 2>/dev/null || rc=$?
  if [ -f "$LOCK" ]; then
    pass "CASE_3_HELD_NOT_CLEARED"
  else
    fail "CASE_3_HELD_NOT_CLEARED" "lock held by live process should NOT have been cleared"
  fi
  kill "$FLOCK_PID" 2>/dev/null || true
  wait "$FLOCK_PID" 2>/dev/null || true
  rm -rf "$REPO"
fi

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

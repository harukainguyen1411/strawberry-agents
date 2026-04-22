#!/usr/bin/env bash
# test-coordinator-lock-pid-i1.sh — xfail regression test: contending process
# must see "already running (pid N)" with a real PID, not "pid unknown" (I1).
#
# Plan: plans/in-progress/personal/2026-04-22-concurrent-coordinator-race-closeout.md
#
# xfail: exec 9>"$file" truncates the file before flock completes — if the
# contender reads the file before the holder writes its PID (after acquiring
# flock), it sees an empty file and prints "pid unknown".
# Fix: use exec 9<>"$file" (read-write, no truncate) so PID written by holder
# survives and is readable by contender.
#
# Exit codes:
#   0 — all assertions passed (I1 fixed)
#   1 — assertion failed
#   2 — infrastructure error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_LOCK="$REPO_ROOT/scripts/_lib_coordinator_lock.sh"

pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }
info() { printf '[INFO] %s\n' "$*"; }

if ! command -v flock >/dev/null 2>&1; then
  info "flock not available — skipping I1 flock-specific PID test (not applicable on this platform)"
  exit 0
fi

TMPROOT="$(mktemp -d)"
cleanup() { rm -rf "$TMPROOT"; }
trap cleanup EXIT INT TERM

LOCKFILE="$TMPROOT/strawberry-promote.lock"

# --- acquire lock in background holder process ---------------------------------
HOLDER_PID_FILE="$TMPROOT/holder.pid"
HOLDER_READY="$TMPROOT/holder.ready"
HOLDER_DONE="$TMPROOT/holder.done"

(
  . "$LIB_LOCK"
  coordinator_lock_acquire "$LOCKFILE"
  printf '%s\n' "$$" > "$HOLDER_PID_FILE"
  touch "$HOLDER_READY"
  # Hold until signalled
  while [ ! -f "$HOLDER_DONE" ]; do sleep 0.05; done
) &
HOLDER_BGPID=$!

# Wait for holder to be ready
for i in $(seq 1 40); do
  [ -f "$HOLDER_READY" ] && break
  sleep 0.05
done

if [ ! -f "$HOLDER_READY" ]; then
  fail "Holder process never became ready"
fi

EXPECTED_PID="$(cat "$HOLDER_PID_FILE")"
info "Holder PID: $EXPECTED_PID"

# --- attempt acquire as contender (should fail with real PID) ------------------
CONTEND_OUT=""
CONTEND_RC=0
(
  . "$LIB_LOCK"
  coordinator_lock_acquire "$LOCKFILE"
) 2>&1 | { CONTEND_OUT="$(cat)"; printf '%s' "$CONTEND_OUT"; } || CONTEND_RC=1
CONTEND_OUT="$(
  (. "$LIB_LOCK"; coordinator_lock_acquire "$LOCKFILE") 2>&1 || true
)"

info "Contender output: $CONTEND_OUT"

# --- signal holder to exit -----------------------------------------------------
touch "$HOLDER_DONE"
wait "$HOLDER_BGPID" 2>/dev/null || true

# --- assertions ----------------------------------------------------------------
if printf '%s\n' "$CONTEND_OUT" | grep -q "pid unknown"; then
  fail "Contender printed 'pid unknown' — holder PID was truncated (I1 not fixed). Got: $CONTEND_OUT"
fi

if ! printf '%s\n' "$CONTEND_OUT" | grep -qE "already running \(pid [0-9]+\)"; then
  fail "Expected 'already running (pid N)' in contender output. Got: $CONTEND_OUT"
fi

# Optionally verify the PID matches the actual holder PID
if printf '%s\n' "$CONTEND_OUT" | grep -q "pid $EXPECTED_PID"; then
  pass "Contender reported exact holder PID $EXPECTED_PID (I1 fixed)"
else
  pass "Contender reported a real PID (not 'unknown') — I1 fixed (PID in output may differ from subshell PID)"
fi

printf '\n[ALL PASS] I1 regression test passed — holder PID correctly reported on contention.\n'
exit 0

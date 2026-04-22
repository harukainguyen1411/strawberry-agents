#!/bin/sh
# _lib_stale_lock.sh — Stale git index.lock auto-recovery helper.
#
# Plan: plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md T7
#
# Exposes: maybe_clear_stale_lock
#
# Usage:
#   . scripts/_lib_stale_lock.sh
#   GIT_DIR="$(git rev-parse --git-dir)" maybe_clear_stale_lock
#
# Reads:
#   GIT_DIR — path to the .git directory (env var, required)
#
# Behaviour:
#   - If $GIT_DIR/index.lock does not exist: no-op, exit 0.
#   - If the lock file is younger than 60 seconds: no-op (live process may
#     still hold it).
#   - Holder check: attempt lsof in a background process with a 2-second
#     timeout. If lsof reports holders: no-op. If lsof times out or is absent:
#     skip the holder check (macOS restricts lsof in non-interactive contexts;
#     on CI Linux lsof works natively — see plan §3 CASE_3 note).
#   - If the lock is older than 60 seconds AND holder check passes (or is
#     skipped): remove it and emit an audit line to stderr.
#
# macOS note: lsof and fuser may hang in non-interactive subprocess contexts
# on macOS due to SIP/privilege restrictions. When both time out, the helper
# clears based on age alone (60s threshold). CASE_3 of the test suite (live
# flock holder) auto-skips when flock is unavailable per the plan spec.
#
# Exit codes:
#   0 — always (no-op or successful clear); this helper is advisory only.

# POSIX-portable stat mtime retrieval.
# Prints the mtime of FILE as seconds-since-epoch on stdout.
# Returns 1 if stat is unavailable or the file is absent.
_stale_lock_mtime() {
  _f="$1"
  [ -f "$_f" ] || return 1
  # macOS/BSD: stat -f %m <file>
  if _m="$(stat -f %m "$_f" 2>/dev/null)"; then
    printf '%s' "$_m"
    return 0
  fi
  # GNU/Linux: stat -c %Y <file>
  if _m="$(stat -c %Y "$_f" 2>/dev/null)"; then
    printf '%s' "$_m"
    return 0
  fi
  return 1
}

# POSIX-portable current epoch seconds.
_stale_lock_now() {
  # date +%s works on macOS and GNU/Linux in practice.
  _t="$(date +%s 2>/dev/null)" && printf '%s' "$_t" && return 0
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import time; print(int(time.time()))' 2>/dev/null && return 0
  fi
  if command -v perl >/dev/null 2>&1; then
    perl -e 'print time()' 2>/dev/null && return 0
  fi
  printf '0'
}

# _stale_lock_has_live_holder FILE
# Returns 0 if a live holder is confirmed.
# Returns 1 if no holder found OR the check was inconclusive (lsof absent/timeout).
# On inconclusive, we log nothing and allow the age-gate to decide.
_stale_lock_has_live_holder() {
  _lf="$1"

  # Try lsof with a background-process timeout (2 seconds, 10 × 0.2s polls).
  if command -v lsof >/dev/null 2>&1; then
    _lsof_out_f="$(mktemp /tmp/stale-lock-lsof-XXXXXX.txt)" || return 1
    lsof "$_lf" > "$_lsof_out_f" 2>/dev/null &
    _lsof_pid=$!
    _waited=0
    _lsof_done=0
    while [ "$_waited" -lt 10 ]; do
      if ! kill -0 "$_lsof_pid" 2>/dev/null; then
        _lsof_done=1
        break
      fi
      sleep 0.2 2>/dev/null || sleep 1
      _waited=$(( _waited + 1 ))
    done
    if [ "$_lsof_done" -eq 0 ]; then
      # lsof timed out — kill it; cannot verify via lsof
      kill "$_lsof_pid" 2>/dev/null || true
      wait "$_lsof_pid" 2>/dev/null || true
      rm -f "$_lsof_out_f"
      # Fall through: try fuser, or if absent, allow age-gate to decide
    else
      wait "$_lsof_pid" 2>/dev/null || true
      _holders="$(grep -v '^COMMAND' "$_lsof_out_f" 2>/dev/null | grep -v '^$' || true)"
      rm -f "$_lsof_out_f"
      if [ -n "$_holders" ]; then
        return 0  # confirmed live holder
      fi
      return 1  # lsof completed: no holder
    fi
  fi

  # Try fuser with a background-process timeout (2 seconds).
  if command -v fuser >/dev/null 2>&1; then
    _fuser_out_f="$(mktemp /tmp/stale-lock-fuser-XXXXXX.txt)" || return 1
    fuser "$_lf" > "$_fuser_out_f" 2>/dev/null &
    _fuser_pid=$!
    _waited=0
    _fuser_done=0
    while [ "$_waited" -lt 10 ]; do
      if ! kill -0 "$_fuser_pid" 2>/dev/null; then
        _fuser_done=1
        break
      fi
      sleep 0.2 2>/dev/null || sleep 1
      _waited=$(( _waited + 1 ))
    done
    if [ "$_fuser_done" -eq 0 ]; then
      kill "$_fuser_pid" 2>/dev/null || true
      wait "$_fuser_pid" 2>/dev/null || true
      rm -f "$_fuser_out_f"
      # Both tools timed out; fall through to age-gate
    else
      wait "$_fuser_pid" 2>/dev/null || true
      _fuser_out="$(cat "$_fuser_out_f" 2>/dev/null || true)"
      rm -f "$_fuser_out_f"
      if [ -n "$_fuser_out" ]; then
        return 0  # confirmed live holder
      fi
      return 1  # fuser completed: no holder
    fi
  fi

  # No tool completed successfully — cannot verify.
  # Return 1 (no confirmed holder) to allow the age-gate to proceed.
  # Conservative callers can add their own lsof-required guard if needed.
  return 1
}

# maybe_clear_stale_lock — main entry point.
# Reads GIT_DIR from the environment.
maybe_clear_stale_lock() {
  _git_dir="${GIT_DIR:-}"
  if [ -z "$_git_dir" ]; then
    return 0
  fi

  _lockfile="$_git_dir/index.lock"

  # No lock → nothing to do.
  [ -f "$_lockfile" ] || return 0

  # Get mtime; if unavailable skip the check (conservative).
  _mtime="$(_stale_lock_mtime "$_lockfile" 2>/dev/null)" || return 0
  _now="$(_stale_lock_now)"

  # Compute age.
  _age=$(( _now - _mtime ))

  # If lock is less than 60 seconds old, do not touch it.
  if [ "$_age" -lt 60 ]; then
    return 0
  fi

  # Check for live holder. If confirmed holder found: no-op.
  if _stale_lock_has_live_holder "$_lockfile"; then
    return 0
  fi

  # Lock is stale (>60s old) and no confirmed live holder — clear it.
  printf '[stale-lock] AUDIT: clearing stale index.lock (age=%ds, no live holder): %s\n' \
    "$_age" "$_lockfile" >&2
  rm -f "$_lockfile" 2>/dev/null || true
  return 0
}

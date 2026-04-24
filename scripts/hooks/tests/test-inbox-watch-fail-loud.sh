#!/usr/bin/env bash
# test-inbox-watch-fail-loud.sh — xfail test for AC-6 / INV-6.
#
# With both CLAUDE_AGENT_NAME and STRAWBERRY_AGENT unset,
# inbox-watch.sh must:
#   - exit 0
#   - emit a stderr diagnostic containing "no CLAUDE_AGENT_NAME"
#   - produce EMPTY stdout (no silent fallback to Evelynn's inbox)
#
# XFAIL against C1 HEAD: current inbox-watch.sh falls back to the
# .claude/settings.json .agent field → may emit Evelynn inbox output
# on non-empty stdout. Will pass after C3/T17 removes the fallback.
#
# Plan: 2026-04-24-coordinator-boot-unification (T11)
# Exit 0 = pass; exit 1 = fail (xfail expected on C1).
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
WATCHER="$REPO_ROOT/scripts/hooks/inbox-watch.sh"

pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; FAIL_COUNT=$((FAIL_COUNT+1)); }
FAIL_COUNT=0

if [ ! -f "$WATCHER" ]; then
  printf '[SKIP] inbox-watch.sh not found\n' >&2
  exit 0
fi

# Create a tmpdir without .claude/settings.json so the fallback has nothing to read.
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT INT TERM

# Run with neither env var set, in a tmpdir with no git or settings.json.
STDOUT_OUT="$(mktemp)"
STDERR_OUT="$(mktemp)"

RC=0
(
  unset CLAUDE_AGENT_NAME 2>/dev/null || true
  unset STRAWBERRY_AGENT 2>/dev/null || true
  INBOX_WATCH_ONESHOT=1 REPO_ROOT="$TMPDIR_TEST" bash "$WATCHER" \
    >"$STDOUT_OUT" 2>"$STDERR_OUT"
) || RC=$?

# Assertion 1: exit code must be 0
if [ "$RC" -eq 0 ]; then
  pass "exit code is 0 (not a hard failure)"
else
  fail "exit code was $RC, expected 0"
fi

# Assertion 2: stdout must be EMPTY (no Evelynn inbox fallback)
STDOUT_CONTENT="$(cat "$STDOUT_OUT")"
if [ -z "$STDOUT_CONTENT" ]; then
  pass "stdout is empty — no silent Evelynn fallback"
else
  fail "stdout is non-empty (silent fallback still active): $STDOUT_CONTENT"
fi

# Assertion 3: stderr must contain a diagnostic about missing identity
STDERR_CONTENT="$(cat "$STDERR_OUT")"
if printf '%s' "$STDERR_CONTENT" | grep -qi 'no CLAUDE_AGENT_NAME'; then
  pass "stderr contains 'no CLAUDE_AGENT_NAME' diagnostic"
else
  fail "stderr does not contain expected diagnostic. Got: $STDERR_CONTENT"
fi

rm -f "$STDOUT_OUT" "$STDERR_OUT"

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf '\n[ALL PASS] inbox-watch fail-loud assertions passed.\n'
  exit 0
else
  printf '\n[FAILURES] %d assertion(s) failed (xfail expected on C1 HEAD).\n' "$FAIL_COUNT" >&2
  exit 1
fi

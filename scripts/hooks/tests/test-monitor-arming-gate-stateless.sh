#!/usr/bin/env bash
# test-monitor-arming-gate-stateless.sh — xfail test for INV-3 / AC-7.
#
# Asserts the stateless Monitor-arming gate:
#   - With sentinel absent AND CLAUDE_AGENT_NAME=Evelynn:
#     gate emits INBOX WATCHER NOT ARMED warning on EVERY PreToolUse.
#   - With sentinel present: gate is a silent no-op (empty output).
#   - With CLAUDE_AGENT_NAME=Kayn (non-coordinator): silent no-op even without sentinel.
#
# The gate script simulates PreToolUse JSON on stdin.
#
# XFAIL against C1 HEAD: pretooluse-monitor-arming-gate.sh does not yet exist.
# Will pass after C3/T21.
#
# Plan: 2026-04-24-coordinator-boot-unification (T13)
# Exit 0 = pass; exit 1 = fail (xfail on C1).
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GATE="$REPO_ROOT/scripts/hooks/pretooluse-monitor-arming-gate.sh"

pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; FAIL_COUNT=$((FAIL_COUNT+1)); }
FAIL_COUNT=0

# XFAIL guard: gate script must exist (does not exist until C3/T21)
if [ ! -f "$GATE" ]; then
  printf '[XFAIL] pretooluse-monitor-arming-gate.sh does not yet exist — expected failure on C1/C2 HEAD\n' >&2
  exit 1
fi

# Fake session ID for isolation
SESSION_ID="test-monitor-gate-$$"
SENTINEL="/tmp/claude-monitor-armed-${SESSION_ID}"

# Ensure sentinel is absent at start
rm -f "$SENTINEL"
trap 'rm -f "$SENTINEL"' EXIT INT TERM

# Minimal PreToolUse JSON payload
PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"echo hello"}}'

# ── Test 1: sentinel absent + Evelynn → MUST emit warning ────────────────────

OUT1="$(printf '%s' "$PAYLOAD" | CLAUDE_AGENT_NAME=Evelynn CLAUDE_SESSION_ID="$SESSION_ID" bash "$GATE" 2>/dev/null || true)"

if printf '%s' "$OUT1" | grep -q 'INBOX WATCHER NOT ARMED'; then
  pass "sentinel absent + Evelynn: warning emitted"
else
  fail "sentinel absent + Evelynn: expected NOT ARMED warning, got: $OUT1"
fi

# ── Test 2: repeat without sentinel → MUST still emit (stateless: every call) ─

OUT2="$(printf '%s' "$PAYLOAD" | CLAUDE_AGENT_NAME=Evelynn CLAUDE_SESSION_ID="$SESSION_ID" bash "$GATE" 2>/dev/null || true)"

if printf '%s' "$OUT2" | grep -q 'INBOX WATCHER NOT ARMED'; then
  pass "sentinel absent + Evelynn (second call): warning emitted again (stateless)"
else
  fail "sentinel absent + Evelynn (second call): expected repeated warning, got: $OUT2"
fi

# ── Test 3: create sentinel → gate must be silent ────────────────────────────

touch "$SENTINEL"
OUT3="$(printf '%s' "$PAYLOAD" | CLAUDE_AGENT_NAME=Evelynn CLAUDE_SESSION_ID="$SESSION_ID" bash "$GATE" 2>/dev/null || true)"

if [ -z "$OUT3" ]; then
  pass "sentinel present + Evelynn: silent no-op"
else
  fail "sentinel present + Evelynn: expected empty output, got: $OUT3"
fi

# ── Test 4: Sona with sentinel absent → MUST emit ────────────────────────────

rm -f "$SENTINEL"
SONA_SESSION_ID="test-monitor-gate-sona-$$"
SENTINEL_SONA="/tmp/claude-monitor-armed-${SONA_SESSION_ID}"
rm -f "$SENTINEL_SONA"
trap 'rm -f "$SENTINEL" "$SENTINEL_SONA"' EXIT INT TERM

OUT4="$(printf '%s' "$PAYLOAD" | CLAUDE_AGENT_NAME=Sona CLAUDE_SESSION_ID="$SONA_SESSION_ID" bash "$GATE" 2>/dev/null || true)"

if printf '%s' "$OUT4" | grep -q 'INBOX WATCHER NOT ARMED'; then
  pass "sentinel absent + Sona: warning emitted"
else
  fail "sentinel absent + Sona: expected NOT ARMED warning, got: $OUT4"
fi

# ── Test 5: non-coordinator (Kayn) → MUST be silent regardless of sentinel ───

rm -f "$SENTINEL"
OUT5="$(printf '%s' "$PAYLOAD" | CLAUDE_AGENT_NAME=Kayn CLAUDE_SESSION_ID="$SESSION_ID" bash "$GATE" 2>/dev/null || true)"

if [ -z "$OUT5" ]; then
  pass "sentinel absent + Kayn (non-coordinator): silent no-op"
else
  fail "sentinel absent + Kayn: expected empty output (not a coordinator), got: $OUT5"
fi

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf '\n[ALL PASS] monitor-arming gate stateless assertions passed.\n'
  exit 0
else
  printf '\n[FAILURES] %d assertion(s) failed (xfail expected on C1/C2 HEAD).\n' "$FAIL_COUNT" >&2
  exit 1
fi

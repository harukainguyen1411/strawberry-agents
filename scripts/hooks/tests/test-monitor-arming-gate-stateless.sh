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

# Shared tty key for tests 1-5 (simulates coordinator shell)
# T1 fix: gate now also checks /tmp/claude-coordinator-shell-<tty_key>; tests
# that simulate coordinator invocations must have that file present.
TTY_KEY_SHARED="fake_tty_shared_$$"
COORD_SENTINEL_SHARED="/tmp/claude-coordinator-shell-${TTY_KEY_SHARED}"
touch "$COORD_SENTINEL_SHARED"

# Shim dir: pgrep returns nothing — prevents the T3 rescue path from firing
# in tests that expect the warning (live inbox-watch.sh processes may exist).
SHIM_DIR_NOOP="$(mktemp -d /tmp/shim-noop-XXXXXX)"
cat > "$SHIM_DIR_NOOP/pgrep" <<'SHIM'
#!/usr/bin/env bash
exit 1
SHIM
chmod +x "$SHIM_DIR_NOOP/pgrep"

# Ensure sentinels are absent at start
rm -f "$SENTINEL"
trap 'rm -f "$SENTINEL" "$COORD_SENTINEL_SHARED"; rm -rf "$SHIM_DIR_NOOP"' EXIT INT TERM

# Minimal PreToolUse JSON payload
PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"echo hello"}}'

# ── Test 1: sentinel absent + Evelynn → MUST emit warning ────────────────────

OUT1="$(printf '%s' "$PAYLOAD" | CLAUDE_AGENT_NAME=Evelynn CLAUDE_SESSION_ID="$SESSION_ID" TALON_TEST_TTY_KEY="$TTY_KEY_SHARED" PATH="$SHIM_DIR_NOOP:$PATH" bash "$GATE" 2>/dev/null || true)"

if printf '%s' "$OUT1" | grep -q 'INBOX WATCHER NOT ARMED'; then
  pass "sentinel absent + Evelynn: warning emitted"
else
  fail "sentinel absent + Evelynn: expected NOT ARMED warning, got: $OUT1"
fi

# ── Test 2: repeat without sentinel → MUST still emit (stateless: every call) ─

OUT2="$(printf '%s' "$PAYLOAD" | CLAUDE_AGENT_NAME=Evelynn CLAUDE_SESSION_ID="$SESSION_ID" TALON_TEST_TTY_KEY="$TTY_KEY_SHARED" PATH="$SHIM_DIR_NOOP:$PATH" bash "$GATE" 2>/dev/null || true)"

if printf '%s' "$OUT2" | grep -q 'INBOX WATCHER NOT ARMED'; then
  pass "sentinel absent + Evelynn (second call): warning emitted again (stateless)"
else
  fail "sentinel absent + Evelynn (second call): expected repeated warning, got: $OUT2"
fi

# ── Test 3: create sentinel → gate must be silent ────────────────────────────

touch "$SENTINEL"
OUT3="$(printf '%s' "$PAYLOAD" | CLAUDE_AGENT_NAME=Evelynn CLAUDE_SESSION_ID="$SESSION_ID" TALON_TEST_TTY_KEY="$TTY_KEY_SHARED" bash "$GATE" 2>/dev/null || true)"

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

OUT4="$(printf '%s' "$PAYLOAD" | CLAUDE_AGENT_NAME=Sona CLAUDE_SESSION_ID="$SONA_SESSION_ID" TALON_TEST_TTY_KEY="$TTY_KEY_SHARED" PATH="$SHIM_DIR_NOOP:$PATH" bash "$GATE" 2>/dev/null || true)"

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

# ── Test C1 — Bug 1 (env-leak): subagent with CLAUDE_AGENT_NAME=Evelynn but different tty ──
# Plan: 2026-04-26-monitor-arming-gate-bugfixes (T4/C1)
# XFAIL on HEAD: gate trusts CLAUDE_AGENT_NAME alone, no tty sentinel check yet.
# After T1: gate requires /tmp/claude-coordinator-shell-<tty_key>; absent here → silent exit.

TTY_KEY_C1="fake_tty_coordinator_$$"
TTY_KEY_SUBAGENT_C1="fake_tty_subagent_$$"
COORD_SENTINEL_C1="/tmp/claude-coordinator-shell-${TTY_KEY_C1}"
SUBAGENT_SESSION_C1="test-c1-$$"
SENTINEL_C1="/tmp/claude-monitor-armed-${SUBAGENT_SESSION_C1}"
rm -f "$COORD_SENTINEL_C1" "$SENTINEL_C1"
trap 'rm -f "$COORD_SENTINEL_C1" "$SENTINEL_C1"' EXIT INT TERM

# Write coordinator-shell sentinel for COORDINATOR tty only
touch "$COORD_SENTINEL_C1"

# Invoke gate with Evelynn name but SUBAGENT tty key (simulating env-leak to subagent)
OUT_C1="$(printf '%s' "$PAYLOAD" | \
  CLAUDE_AGENT_NAME=Evelynn \
  CLAUDE_SESSION_ID="$SUBAGENT_SESSION_C1" \
  TALON_TEST_TTY_KEY="$TTY_KEY_SUBAGENT_C1" \
  bash "$GATE" 2>/dev/null || true)"

if [ -z "$OUT_C1" ]; then
  pass "C1: subagent with inherited Evelynn name but different tty: silent (correct)"
else
  fail "C1 [XFAIL]: subagent with inherited Evelynn name should be silent after T1; currently emits: $OUT_C1"
fi

rm -f "$COORD_SENTINEL_C1" "$SENTINEL_C1"

# ── Test C2 — Bug 2 (unset session id): tty-keyed sentinel must silence the gate ──
# Plan: 2026-04-26-monitor-arming-gate-bugfixes (T4/C2)
# XFAIL on HEAD: gate skips sentinel branch when CLAUDE_SESSION_ID empty → always fires.
# After T2: gate falls back to tty-keyed sentinel → silent.

TTY_KEY_C2="fake_tty_c2_$$"
COORD_SENTINEL_C2="/tmp/claude-coordinator-shell-${TTY_KEY_C2}"
TTY_ARMED_C2="/tmp/claude-monitor-armed-tty-${TTY_KEY_C2}"
rm -f "$COORD_SENTINEL_C2" "$TTY_ARMED_C2"
trap 'rm -f "$COORD_SENTINEL_C2" "$TTY_ARMED_C2"' EXIT INT TERM

touch "$COORD_SENTINEL_C2"
touch "$TTY_ARMED_C2"

OUT_C2="$(printf '%s' "$PAYLOAD" | \
  CLAUDE_AGENT_NAME=Evelynn \
  CLAUDE_SESSION_ID="" \
  TALON_TEST_TTY_KEY="$TTY_KEY_C2" \
  bash "$GATE" 2>/dev/null || true)"

if [ -z "$OUT_C2" ]; then
  pass "C2: CLAUDE_SESSION_ID unset + tty-keyed sentinel present: silent (correct)"
else
  fail "C2 [XFAIL]: gate should be silent via tty-keyed sentinel after T2; currently emits: $OUT_C2"
fi

rm -f "$COORD_SENTINEL_C2" "$TTY_ARMED_C2"

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf '\n[ALL PASS] monitor-arming gate stateless assertions passed.\n'
  exit 0
else
  printf '\n[FAILURES] %d assertion(s) failed (xfail expected on C1/C2 HEAD).\n' "$FAIL_COUNT" >&2
  exit 1
fi

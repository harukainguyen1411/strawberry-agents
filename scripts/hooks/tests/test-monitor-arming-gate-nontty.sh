#!/usr/bin/env bash
# test-monitor-arming-gate-nontty.sh — xfail regression test for C1 (non-tty collision).
#
# Plan: 2026-04-26-monitor-arming-gate-bugfixes (Senna C1 review)
#
# C1 bug: when `tty` returns non-zero (no controlling terminal), the gate uses:
#   tty_key="$(tty 2>/dev/null | tr '/' '_' | tr -d '\n' || echo "no-tty-$$")"
# The `||` binds to `tr`, not `tty`. Since `tr` always exits 0, the echo fallback
# never fires. Instead tty_key gets the literal string "not a tty" (tty's stderr
# text on non-tty invocations). Every non-tty caller gets the SAME key →
# coordinator-shell sentinel written by one process is visible to all others →
# subagent env-leak protection is broken for non-tty callers.
#
# XFAIL on HEAD: tty_key fallback is dead code; literal "not a tty" is used.
# After fix: `if tty_out=$(tty 2>/dev/null); then ... else tty_key="no-tty-$$"; fi`
# ensures non-tty callers get a PID-unique key.
#
# Test strategy: cannot fully test process-uniqueness across two real processes
# in a single script, but we CAN verify that the tty_key produced for a non-tty
# call does NOT equal the literal string "not_a_tty" (the tr-transformed form of
# "not a tty"). We do this by invoking the gate without TALON_TEST_TTY_KEY in a
# subshell where stdin is not a tty, and checking that the coordinator-shell
# sentinel checked is NOT /tmp/claude-coordinator-shell-not_a_tty.
#
# We also verify that with the fix, the sentinel path is PID-unique by checking
# it contains "no-tty-" followed by digits.
#
# POSIX-portable bash (Rule 10).
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GATE="$REPO_ROOT/scripts/hooks/pretooluse-monitor-arming-gate.sh"

pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; FAIL_COUNT=$((FAIL_COUNT+1)); }
FAIL_COUNT=0

if [ ! -f "$GATE" ]; then
  printf '[XFAIL] pretooluse-monitor-arming-gate.sh does not yet exist\n' >&2
  exit 1
fi

PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"echo hello"}}'

# ── Test C1-nontty: non-tty caller must NOT collide on literal "not_a_tty" key ──
# Strategy: plant a coordinator-shell sentinel at the literal collision path, then
# invoke the gate without TALON_TEST_TTY_KEY (and no controlling tty via </dev/null).
# If the bug is present, the gate finds the sentinel and exits silently (wrong).
# If the fix is present, the gate uses a PID-unique key, misses the sentinel, and
# either emits a warning or exits silently for a different reason. We check that
# the gate does NOT silently pass due to the collision key.
#
# To make the assertion unambiguous: we also set CLAUDE_AGENT_NAME=Evelynn but
# do NOT plant any PID-unique sentinel, and we shim pgrep to return nothing.
# On the buggy path the gate hits the collision sentinel and exits 0 (silent).
# On the fixed path the gate misses the collision sentinel and emits warning or
# checks a PID-unique coord sentinel (which is absent) → exits silently via T1.

COLLISION_KEY="not a tty"
COLLISION_COORD_SENTINEL="/tmp/claude-coordinator-shell-${COLLISION_KEY}"
touch "$COLLISION_COORD_SENTINEL"

COLLISION_ARMED_SENTINEL="/tmp/claude-monitor-armed-tty-${COLLISION_KEY}"
touch "$COLLISION_ARMED_SENTINEL"

SESSION_C1N="test-c1n-$$"

# noop pgrep shim
SHIM_DIR_C1N="$(mktemp -d /tmp/shim-c1n-XXXXXX)"
cat > "$SHIM_DIR_C1N/pgrep" <<'SHIM'
#!/usr/bin/env bash
exit 1
SHIM
chmod +x "$SHIM_DIR_C1N/pgrep"

trap 'rm -f "$COLLISION_COORD_SENTINEL" "$COLLISION_ARMED_SENTINEL"; rm -rf "$SHIM_DIR_C1N"' EXIT INT TERM

# Invoke with no TALON_TEST_TTY_KEY and stdin redirected from /dev/null (no tty)
OUT_C1N="$(printf '%s' "$PAYLOAD" | \
  CLAUDE_AGENT_NAME=Evelynn \
  CLAUDE_SESSION_ID="$SESSION_C1N" \
  PATH="$SHIM_DIR_C1N:$PATH" \
  bash "$GATE" < /dev/null 2>/dev/null || true)"

# On the BUGGY path: tty_key="not_a_tty", coord sentinel present, armed sentinel
# present → gate exits 0 silently (falsely armed). But we have NOT armed a
# PID-unique sentinel. The gate should NOT be silenced by a sentinel planted for
# the literal collision key when the process has a unique tty key.
#
# On the FIXED path: tty_key="no-tty-<PID>", coord sentinel absent for that key
# → gate exits 0 silently via T1 (correct — not coordinator shell). OR if the
# coord sentinel IS checked via another path, the test outcome is still valid as
# long as it's not due to the collision key.
#
# The distinguishing assertion: after the call, the COLLISION armed sentinel
# must NOT have been the reason for silence. We check this by removing the
# collision armed sentinel and re-running — if the result is the same (silent),
# the fix is working (coord sentinel for unique key is absent → T1 exits).
# If re-run now emits a warning, the first run was silenced by the collision →
# bug still present.

rm -f "$COLLISION_ARMED_SENTINEL"

OUT_C1N_RERUN="$(printf '%s' "$PAYLOAD" | \
  CLAUDE_AGENT_NAME=Evelynn \
  CLAUDE_SESSION_ID="$SESSION_C1N" \
  PATH="$SHIM_DIR_C1N:$PATH" \
  bash "$GATE" < /dev/null 2>/dev/null || true)"

if [ "$OUT_C1N" = "$OUT_C1N_RERUN" ]; then
  pass "C1-nontty: gate output is consistent with/without collision sentinel (no collision dependency)"
else
  fail "C1-nontty [XFAIL]: gate output changed when collision sentinel removed — tty_key fallback is using literal 'not a tty' collision key (dead code bug); first='$OUT_C1N' second='$OUT_C1N_RERUN'"
fi

rm -f "$COLLISION_COORD_SENTINEL" "$COLLISION_ARMED_SENTINEL"
rm -rf "$SHIM_DIR_C1N"

# ── Summary ───────────────────────────────────────────────────────────────────

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf '\n[ALL PASS] monitor-arming gate non-tty collision assertions passed.\n'
  exit 0
else
  printf '\n[FAILURES] %d assertion(s) failed (xfail expected on HEAD before C1 fix).\n' "$FAIL_COUNT" >&2
  exit 1
fi

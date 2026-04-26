#!/usr/bin/env bash
# test-monitor-arming-gate-rescue.sh — xfail regression test for Bug 3 (post-compact rescue).
#
# Plan: 2026-04-26-monitor-arming-gate-bugfixes (T4/C3)
#
# Asserts:
#   C3: gate self-heals when a live inbox-watch.sh process exists on the same tty
#       and no sentinel files exist (post-compact orphan scenario).
#
# XFAIL on HEAD: no pid-scan rescue logic in gate yet.
# After T3: pgrep shim found → touch sentinels → silent exit.
#
# Strategy: shim pgrep via PATH to return a fake matching pid, so no real
#   inbox-watch.sh process is required in CI. The shim prints a line only
#   when called with args matching "inbox-watch.sh".
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

# ── Test C3 — Bug 3 (post-compact rescue): live inbox-watch.sh on same tty ──────

TTY_KEY_C3="fake_tty_c3_$$"
SESSION_C3="test-c3-$$"
COORD_SENTINEL_C3="/tmp/claude-coordinator-shell-${TTY_KEY_C3}"
SESSION_SENTINEL_C3="/tmp/claude-monitor-armed-${SESSION_C3}"
TTY_SENTINEL_C3="/tmp/claude-monitor-armed-tty-${TTY_KEY_C3}"

rm -f "$COORD_SENTINEL_C3" "$SESSION_SENTINEL_C3" "$TTY_SENTINEL_C3"
trap 'rm -f "$COORD_SENTINEL_C3" "$SESSION_SENTINEL_C3" "$TTY_SENTINEL_C3" "${SHIM_DIR:-/tmp/shim-c3-nonexistent}/pgrep"' EXIT INT TERM

# Write coordinator-shell sentinel (identity passes)
touch "$COORD_SENTINEL_C3"
# No arming sentinels — simulates post-compact state

# Build a pgrep shim that returns a fake pid when queried for inbox-watch.sh
SHIM_DIR="$(mktemp -d /tmp/shim-c3-XXXXXX)"
cat > "$SHIM_DIR/pgrep" <<'SHIM'
#!/usr/bin/env bash
# Fake pgrep: returns a pid only when called with -f and pattern contains inbox-watch.sh
args="$*"
case "$args" in
  *inbox-watch*)
    echo "99999"
    exit 0
    ;;
  *)
    exit 1
    ;;
esac
SHIM
chmod +x "$SHIM_DIR/pgrep"

OUT_C3="$(printf '%s' "$PAYLOAD" | \
  CLAUDE_AGENT_NAME=Evelynn \
  CLAUDE_SESSION_ID="$SESSION_C3" \
  TALON_TEST_TTY_KEY="$TTY_KEY_C3" \
  PATH="$SHIM_DIR:$PATH" \
  bash "$GATE" 2>/dev/null || true)"

if [ -z "$OUT_C3" ]; then
  pass "C3: post-compact rescue via pid-scan: gate silent (correct)"
else
  fail "C3 [XFAIL]: gate should self-heal via pid-scan after T3; currently emits: $OUT_C3"
fi

# After T3: tty-keyed sentinel must have been written by the rescue path
if [ -f "$TTY_SENTINEL_C3" ]; then
  pass "C3: tty-keyed sentinel written by rescue path"
else
  fail "C3 [XFAIL]: tty-keyed sentinel not written; rescue path not yet implemented"
fi

rm -rf "$SHIM_DIR"
rm -f "$COORD_SENTINEL_C3" "$SESSION_SENTINEL_C3" "$TTY_SENTINEL_C3"

# ── Test I2 — cross-tty rescue: pgrep has no tty filter ───────────────────────
# Plan: 2026-04-26-monitor-arming-gate-bugfixes (Senna I2 review)
#
# The T3 rescue comment claims "tty-match" but pgrep has no tty filter — it
# rescues ANY live inbox-watch.sh, not just one on the same tty. This test
# asserts the ACTUAL behaviour (any-process rescue) so that if a tty filter
# is added later, this test will catch the behaviour change.
#
# XFAIL annotation: this test documents current behaviour. It passes after
# the comment is fixed to say "any live inbox-watch.sh" rather than "tty-match".
# There is no code change for I2 (comment-only fix) — the test asserts the
# observable rescue behaviour is cross-tty (i.e. rescue fires even when tty keys
# differ between the shim process and the gate's tty key).

TTY_KEY_I2_COORD="fake_tty_i2_coord_$$"
TTY_KEY_I2_WATCHER="fake_tty_i2_watcher_$$"  # different tty from coordinator
SESSION_I2="test-i2-$$"
COORD_SENTINEL_I2="/tmp/claude-coordinator-shell-${TTY_KEY_I2_COORD}"
TTY_SENTINEL_I2="/tmp/claude-monitor-armed-tty-${TTY_KEY_I2_COORD}"
SESSION_SENTINEL_I2="/tmp/claude-monitor-armed-${SESSION_I2}"

rm -f "$COORD_SENTINEL_I2" "$TTY_SENTINEL_I2" "$SESSION_SENTINEL_I2"
trap 'rm -f "$COORD_SENTINEL_I2" "$TTY_SENTINEL_I2" "$SESSION_SENTINEL_I2"; rm -rf "${SHIM_DIR_I2:-/tmp/shim-i2-nonexistent}"' EXIT INT TERM

touch "$COORD_SENTINEL_I2"

# pgrep shim: returns a pid regardless of tty context (simulating cross-tty watcher)
SHIM_DIR_I2="$(mktemp -d /tmp/shim-i2-XXXXXX)"
cat > "$SHIM_DIR_I2/pgrep" <<'SHIM'
#!/usr/bin/env bash
args="$*"
case "$args" in
  *inbox-watch*)
    echo "88888"
    exit 0
    ;;
  *)
    exit 1
    ;;
esac
SHIM
chmod +x "$SHIM_DIR_I2/pgrep"

OUT_I2="$(printf '%s' "$PAYLOAD" | \
  CLAUDE_AGENT_NAME=Evelynn \
  CLAUDE_SESSION_ID="$SESSION_I2" \
  TALON_TEST_TTY_KEY="$TTY_KEY_I2_COORD" \
  PATH="$SHIM_DIR_I2:$PATH" \
  bash "$GATE" 2>/dev/null || true)"

# Rescue fires for ANY inbox-watch.sh regardless of tty — gate must be silent
if [ -z "$OUT_I2" ]; then
  pass "I2: cross-tty rescue fires for any live inbox-watch.sh (no tty filter in pgrep)"
else
  fail "I2 [XFAIL]: gate should self-heal via cross-tty rescue; currently emits: $OUT_I2"
fi

rm -rf "$SHIM_DIR_I2"
rm -f "$COORD_SENTINEL_I2" "$TTY_SENTINEL_I2" "$SESSION_SENTINEL_I2"

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf '\n[ALL PASS] monitor-arming gate rescue assertions passed.\n'
  exit 0
else
  printf '\n[FAILURES] %d assertion(s) failed (xfail expected on HEAD before T3).\n' "$FAIL_COUNT" >&2
  exit 1
fi

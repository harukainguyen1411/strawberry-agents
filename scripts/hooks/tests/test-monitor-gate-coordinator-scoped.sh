#!/usr/bin/env bash
# test-monitor-gate-coordinator-scoped.sh — xfail test for INV-3 scope callout.
#
# Asserts that the Monitor-arming gate fires ONLY for coordinator agents
# (Evelynn, Sona) — NOT for subagents (Kayn, Jayce, Vi, Rakan, etc.).
#
# XFAIL against C1 HEAD: pretooluse-monitor-arming-gate.sh does not yet exist.
# Will pass after C3/T21.
#
# Plan: 2026-04-24-coordinator-boot-unification (T14)
# Exit 0 = pass; exit 1 = fail (xfail on C1/C2).
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GATE="$REPO_ROOT/scripts/hooks/pretooluse-monitor-arming-gate.sh"

pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; FAIL_COUNT=$((FAIL_COUNT+1)); }
FAIL_COUNT=0

# XFAIL guard: gate must exist
if [ ! -f "$GATE" ]; then
  printf '[XFAIL] pretooluse-monitor-arming-gate.sh does not yet exist — expected on C1/C2\n' >&2
  exit 1
fi

PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"ls"}}'

# Shared tty key for coordinator tests — T1 fix requires coordinator-shell sentinel.
TTY_KEY_COORD="fake_tty_coord_scope_$$"
COORD_SHELL_SENTINEL="/tmp/claude-coordinator-shell-${TTY_KEY_COORD}"
touch "$COORD_SHELL_SENTINEL"

# Noop pgrep shim — prevents T3 rescue from silencing tests that expect the warning.
# Live inbox-watch.sh processes may exist on the host; shim ensures they don't interfere.
SHIM_DIR_NOOP="$(mktemp -d /tmp/shim-scope-XXXXXX)"
cat > "$SHIM_DIR_NOOP/pgrep" <<'SHIM'
#!/usr/bin/env bash
exit 1
SHIM
chmod +x "$SHIM_DIR_NOOP/pgrep"

trap 'rm -f "$COORD_SHELL_SENTINEL"; rm -rf "$SHIM_DIR_NOOP"' EXIT INT TERM

# Subagents that MUST NOT trigger the warning (sentinel absent in all cases).
# These exit at the agent-name check before the tty check, so no coordinator
# sentinel needed here.
for agent in Kayn Jayce Vi Rakan Senna Lucian Akali Lissandra Orianna; do
  SESSION_ID="test-scope-$$-${agent}"
  SENTINEL="/tmp/claude-monitor-armed-${SESSION_ID}"
  rm -f "$SENTINEL"
  trap 'rm -f "$SENTINEL"' EXIT INT TERM

  OUT="$(printf '%s' "$PAYLOAD" | CLAUDE_AGENT_NAME="$agent" CLAUDE_SESSION_ID="$SESSION_ID" bash "$GATE" 2>/dev/null || true)"

  if [ -z "$OUT" ]; then
    pass "$agent (subagent): silent no-op (correct)"
  else
    fail "$agent (subagent): gate fired incorrectly for non-coordinator. Output: $OUT"
  fi

  rm -f "$SENTINEL"
done

# Coordinators that MUST trigger the warning (arming sentinel absent).
# T1 fix: coordinator-shell sentinel must be present for the gate to proceed
# past the tty check, so we inject TTY_KEY_COORD + the matching sentinel above.
for agent in Evelynn Sona; do
  SESSION_ID="test-scope-$$-${agent}"
  SENTINEL="/tmp/claude-monitor-armed-${SESSION_ID}"
  rm -f "$SENTINEL"
  trap 'rm -f "$SENTINEL"' EXIT INT TERM

  OUT="$(printf '%s' "$PAYLOAD" | \
    CLAUDE_AGENT_NAME="$agent" \
    CLAUDE_SESSION_ID="$SESSION_ID" \
    TALON_TEST_MODE=1 TALON_TEST_TTY_KEY="$TTY_KEY_COORD" \
    PATH="$SHIM_DIR_NOOP:$PATH" \
    bash "$GATE" 2>/dev/null || true)"

  if printf '%s' "$OUT" | grep -q 'INBOX WATCHER NOT ARMED'; then
    pass "$agent (coordinator): warning emitted (correct)"
  else
    fail "$agent (coordinator): expected NOT ARMED warning, got: $OUT"
  fi

  rm -f "$SENTINEL"
done

rm -f "$COORD_SHELL_SENTINEL"

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf '\n[ALL PASS] monitor-gate coordinator-scoped assertions passed.\n'
  exit 0
else
  printf '\n[FAILURES] %d assertion(s) failed (xfail expected on C1/C2 HEAD).\n' "$FAIL_COUNT" >&2
  exit 1
fi

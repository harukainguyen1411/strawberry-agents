#!/usr/bin/env bash
# pretooluse-monitor-arming-gate.sh — stateless Monitor-arming gate.
#
# Fires on every PreToolUse invocation for coordinator sessions.
# Implements INV-3 (Monitor arming is a gated step, not a nudge).
#
# Logic (updated — fixes Bugs 1, 2, 3):
#   1. Read CLAUDE_AGENT_NAME. If not Evelynn or Sona: silent exit 0.
#   2. Compute tty_key. Check /tmp/claude-coordinator-shell-<tty_key>.
#      If absent: this is a subagent that inherited the coordinator env-var
#      (Bug 1 fix) — silent exit 0.
#   3. Check session-keyed sentinel /tmp/claude-monitor-armed-<session_id>
#      (when session_id set) OR tty-keyed sentinel
#      /tmp/claude-monitor-armed-tty-<tty_key> (Bug 2 fix — fallback when
#      session_id unset or session-keyed sentinel absent).
#      Either hit → silent exit 0.
#   4. Pid-scan rescue: pgrep for live inbox-watch.sh whose tty matches.
#      If found, touch both sentinels and exit 0 silently (Bug 3 fix —
#      post-compact self-heal).
#   5. Otherwise emit hookSpecificOutput warning.
#
# Sentinel paths:
#   /tmp/claude-coordinator-shell-<tty_key>   — written by inbox-watch-bootstrap.sh
#   /tmp/claude-monitor-armed-<session_id>    — written by posttooluse-monitor-arm-sentinel.sh
#   /tmp/claude-monitor-armed-tty-<tty_key>  — written by posttooluse-monitor-arm-sentinel.sh
#
# TALON_TEST_TTY_KEY env var overrides tty detection in tests (only when
# TALON_TEST_MODE=1 is also set — I4 fix). Value is sanitized to [a-zA-Z0-9_-]
# to prevent path traversal in /tmp sentinel paths (I1 fix).
#
# POSIX-portable bash (Rule 10).
set -eu

# ────────────────────────────────────────────────────────────────
# Identity check — only coordinators have an inbox watcher requirement
# ────────────────────────────────────────────────────────────────

agent="${CLAUDE_AGENT_NAME:-}"

case "$agent" in
  Evelynn|Sona) ;;  # coordinator name — proceed to tty check
  *)
    # Not a coordinator name — silent no-op
    exit 0
    ;;
esac

# ────────────────────────────────────────────────────────────────
# Compute tty_key (stable to the controlling terminal)
# ────────────────────────────────────────────────────────────────

if [ -n "${TALON_TEST_MODE:-}" ] && [ -n "${TALON_TEST_TTY_KEY:-}" ]; then
  # Test override — allowed only when TALON_TEST_MODE=1 (I1+I4 fix)
  # Sanitize to prevent path traversal in /tmp sentinel paths
  case "$TALON_TEST_TTY_KEY" in
    *[!a-zA-Z0-9_-]*) tty_key="no-tty-$$" ;;  # reject unsafe chars
    *) tty_key="$TALON_TEST_TTY_KEY" ;;
  esac
else
  # C1 fix: capture tty output with explicit exit-code propagation.
  # The old pattern `tty 2>/dev/null | tr ... || echo fallback` bound ||
  # to tr (which always exits 0), so the fallback was dead code and
  # non-tty callers all got the literal string "not a tty" as tty_key,
  # causing every non-tty process to share one sentinel.
  if tty_out=$(tty 2>/dev/null); then
    tty_key=$(printf '%s' "$tty_out" | tr '/' '_' | tr -d '\n')
  else
    tty_key="no-tty-$$"
  fi
fi

# ────────────────────────────────────────────────────────────────
# T1 — Coordinator-shell sentinel check (Bug 1 fix)
# Subagents inherit CLAUDE_AGENT_NAME but have a different tty → file absent.
# ────────────────────────────────────────────────────────────────

coord_sentinel="/tmp/claude-coordinator-shell-${tty_key}"
if [ ! -f "$coord_sentinel" ]; then
  # Coordinator-shell sentinel absent: this process is not the coordinator
  # shell (it is a subagent inheriting the env-var). Silent exit.
  exit 0
fi

# ────────────────────────────────────────────────────────────────
# T2 — Sentinel check: session-keyed OR tty-keyed (Bug 2 fix)
# ────────────────────────────────────────────────────────────────

session_id="${CLAUDE_SESSION_ID:-}"
tty_sentinel="/tmp/claude-monitor-armed-tty-${tty_key}"

if [ -n "$session_id" ]; then
  session_sentinel="/tmp/claude-monitor-armed-${session_id}"
  if [ -f "$session_sentinel" ] || [ -f "$tty_sentinel" ]; then
    exit 0
  fi
else
  # session_id unset — fall back to tty-keyed sentinel only
  if [ -f "$tty_sentinel" ]; then
    exit 0
  fi
fi

# ────────────────────────────────────────────────────────────────
# T3 — Pid-scan rescue (Bug 3 fix — post-compact self-heal)
# ────────────────────────────────────────────────────────────────

# Consume stdin now (before the pgrep scan) to avoid broken pipe
cat >/dev/null 2>&1 || true

# Check for ANY live inbox-watch.sh process (no tty filter — rescue is
# intentionally cross-tty; any running watcher means this coordinator
# session is covered). Use pgrep if available, fall back to ps -A for
# portability (Git Bash / macOS both support ps -A).
watcher_found=0

if command -v pgrep >/dev/null 2>&1; then
  if pgrep -f 'scripts/hooks/inbox-watch\.sh' >/dev/null 2>&1; then
    watcher_found=1
  fi
else
  # Portable fallback: ps -A -o command
  if ps -A -o command= 2>/dev/null | grep -q 'scripts/hooks/inbox-watch\.sh'; then
    watcher_found=1
  fi
fi

if [ "$watcher_found" -eq 1 ]; then
  # Live watcher found — self-heal: touch both sentinels so subsequent
  # calls take the cheap silent path.
  touch "$tty_sentinel"
  if [ -n "$session_id" ]; then
    touch "/tmp/claude-monitor-armed-${session_id}"
  fi
  exit 0
fi

# ────────────────────────────────────────────────────────────────
# Emit warning — inbox watcher not yet armed
# ────────────────────────────────────────────────────────────────

warning="INBOX WATCHER NOT ARMED — invoke Monitor with: bash scripts/hooks/inbox-watch.sh — description: Watch ${agent}'s inbox. Arm the watcher before any other action."

if command -v jq >/dev/null 2>&1; then
  jq -cn \
    --arg w "$warning" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":$w}}'
else
  # jq not available — construct JSON manually
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' \
    "$(printf '%s' "$warning" | sed 's/\\/\\\\/g;s/"/\\"/g')"
fi

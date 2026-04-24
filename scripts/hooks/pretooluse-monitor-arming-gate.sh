#!/usr/bin/env bash
# pretooluse-monitor-arming-gate.sh — stateless Monitor-arming gate.
#
# Fires on every PreToolUse invocation for coordinator sessions.
# Implements INV-3 (Monitor arming is a gated step, not a nudge).
#
# Logic (stateless — no counter, single [ -f ] check):
#   1. Read CLAUDE_AGENT_NAME. If not Evelynn or Sona: silent exit 0 (subagents exempt).
#   2. Check sentinel /tmp/claude-monitor-armed-${CLAUDE_SESSION_ID}.
#      - Present: silent exit 0 (already armed — no-op).
#      - Absent: emit hookSpecificOutput additionalContext warning on EVERY call.
#
# The sentinel is created by posttooluse-monitor-arm-sentinel.sh when the
# Monitor tool is invoked with scripts/hooks/inbox-watch.sh.
#
# Input (stdin): PreToolUse JSON payload (not currently inspected — identity
#   comes from env var, not payload, for coordinator sessions).
# Output (stdout): JSON hookSpecificOutput, or nothing.
#
# POSIX-portable bash (Rule 10).
set -eu

# ────────────────────────────────────────────────────────────────
# Identity check — only coordinators have an inbox watcher requirement
# ────────────────────────────────────────────────────────────────

agent="${CLAUDE_AGENT_NAME:-}"

case "$agent" in
  Evelynn|Sona) ;;  # coordinator — proceed
  *)
    # Not a coordinator (subagent, unknown, unset) — silent no-op
    exit 0
    ;;
esac

# ────────────────────────────────────────────────────────────────
# Sentinel check (stateless — single [ -f ])
# ────────────────────────────────────────────────────────────────

session_id="${CLAUDE_SESSION_ID:-}"
if [ -n "$session_id" ]; then
  sentinel="/tmp/claude-monitor-armed-${session_id}"
  if [ -f "$sentinel" ]; then
    # Already armed — silent no-op (cheapest possible path)
    exit 0
  fi
fi

# ────────────────────────────────────────────────────────────────
# Emit warning — inbox watcher not yet armed
# ────────────────────────────────────────────────────────────────

# Consume stdin to avoid broken pipe (PreToolUse hook contract)
cat >/dev/null 2>&1 || true

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

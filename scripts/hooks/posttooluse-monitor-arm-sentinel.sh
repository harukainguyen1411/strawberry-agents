#!/usr/bin/env bash
# posttooluse-monitor-arm-sentinel.sh — PostToolUse hook: create Monitor-arming sentinel.
#
# Fires after the Monitor tool completes. If the Monitor was invoked with
# scripts/hooks/inbox-watch.sh, this hook creates the session-scoped sentinel
# that silences the pretooluse-monitor-arming-gate.sh warning.
#
# Logic:
#   1. Read tool_name from stdin JSON. If not "Monitor": exit 0.
#   2. Extract the tool_input.command value.
#   3. If command contains "inbox-watch.sh": touch sentinel and exit 0.
#   4. Otherwise: exit 0 (different Monitor invocation, not the watcher).
#
# Sentinel path: /tmp/claude-monitor-armed-${CLAUDE_SESSION_ID}
#
# Input (stdin): PostToolUse JSON payload.
# Output (stdout): nothing (this hook is informational only).
#
# POSIX-portable bash (Rule 10).
set -eu

# Read the full payload
payload="$(cat)"

# Extract tool name
tool_name=""
if command -v jq >/dev/null 2>&1; then
  tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null || true)"
else
  tool_name="$(printf '%s' "$payload" | grep -o '"tool_name":"[^"]*"' | sed 's/"tool_name":"//;s/"//' 2>/dev/null || true)"
fi

# Only handle Monitor tool invocations
if [ "$tool_name" != "Monitor" ]; then
  exit 0
fi

# Extract the command from tool_input
cmd=""
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
else
  cmd="$(printf '%s' "$payload" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"//' 2>/dev/null || true)"
fi

# Only arm if this Monitor invocation targets inbox-watch.sh
case "$cmd" in
  *inbox-watch.sh*)
    session_id="${CLAUDE_SESSION_ID:-}"
    if [ -n "$session_id" ]; then
      sentinel="/tmp/claude-monitor-armed-${session_id}"
      touch "$sentinel"
      # No stdout — hook is silent on success
    fi
    ;;
esac

exit 0

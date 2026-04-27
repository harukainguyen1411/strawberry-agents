#!/usr/bin/env bash
# scripts/hooks/posttooluse-teammate-idle-marker.sh
#
# PostToolUse hook — fires on the lead's session after idle_notification events.
# If a teammate went idle without emitting a completion marker in the current turn,
# logs a non-blocking warning for the lead to notice on the next turn.
#
# Non-blocking: exits 0 always. Never aborts a tool call.
#
# Env vars (for testing):
#   TEAMMATE_IDLE_MARKER_LOG  — override log file path (default: .claude/logs/teammate-idle-marker.log)
#   HOOK_EVENT_FILE           — path to JSON file with the event (for testing)
#   HOOK_SENDMESSAGE_FILE     — path to JSON file with SendMessage history for this turn (for testing)
#
# Plan: plans/approved/personal/2026-04-27-agent-team-mode-comms-discipline.md T9

set -euo pipefail

# Resolve log path
LOG_FILE="${TEAMMATE_IDLE_MARKER_LOG:-.claude/logs/teammate-idle-marker.log}"

# Read event from stdin or from HOOK_EVENT_FILE (testing override)
if [ -n "${HOOK_EVENT_FILE:-}" ] && [ -f "$HOOK_EVENT_FILE" ]; then
  event_json="$(cat "$HOOK_EVENT_FILE")"
else
  # Read from stdin (real hook invocation)
  event_json="$(cat /dev/stdin 2>/dev/null || echo '{}')"
fi

# Guard: only process idle_notification events
tool_name="$(printf '%s' "$event_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool',''))" 2>/dev/null || echo '')"
if [ "$tool_name" != "idle_notification" ]; then
  exit 0
fi

# Guard: only process teammate events (must have team_name in input)
team_name="$(printf '%s' "$event_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('input',{}).get('team_name',''))" 2>/dev/null || echo '')"
if [ -z "$team_name" ]; then
  # OQ6: ignore one-shot subagents (no team_name)
  exit 0
fi

agent_name="$(printf '%s' "$event_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('input',{}).get('agent_name','unknown'))" 2>/dev/null || echo 'unknown')"

# Read SendMessage history for this turn
if [ -n "${HOOK_SENDMESSAGE_FILE:-}" ] && [ -f "$HOOK_SENDMESSAGE_FILE" ]; then
  sendmessage_json="$(cat "$HOOK_SENDMESSAGE_FILE")"
else
  # Real invocation: no SendMessage stream available yet; treat as empty
  sendmessage_json="[]"
fi

# Check for completion marker in the SendMessage stream
MARKER_TYPES="task_done shutdown_ack blocked clarification_needed"
has_marker=false
for marker_type in $MARKER_TYPES; do
  if printf '%s' "$sendmessage_json" | python3 -c "
import sys, json
msgs = json.load(sys.stdin)
for m in msgs:
    if isinstance(m, dict) and m.get('type') == '$marker_type':
        sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
    has_marker=true
    break
  fi
done

if [ "$has_marker" = "true" ]; then
  # Conformant turn — stay silent
  exit 0
fi

# Violation detected — emit non-blocking warning
warning_msg="Teammate $agent_name went idle without a completion marker — consider pinging or escalating"

# Ensure log directory exists
log_dir="$(dirname "$LOG_FILE")"
mkdir -p "$log_dir" 2>/dev/null || true

# Append to log
timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo 'unknown')"
printf '%s [WARN] %s (team: %s)\n' "$timestamp" "$warning_msg" "$team_name" >> "$LOG_FILE" 2>/dev/null || true

# Emit to stderr (lead's prompt picks up on next turn)
printf '[idle-marker] %s\n' "$warning_msg" >&2

exit 0

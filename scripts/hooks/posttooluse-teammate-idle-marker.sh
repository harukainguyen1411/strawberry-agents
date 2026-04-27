#!/usr/bin/env bash
# scripts/hooks/posttooluse-teammate-idle-marker.sh
#
# TeammateIdle hook — fires on the lead's session when a teammate is about to go idle.
# If the teammate's transcript contains no completion marker in the last turn's
# SendMessage calls, logs a non-blocking warning for the lead.
#
# Non-blocking: exits 0 always. Never aborts the idle transition.
#
# Env vars (for testing):
#   TEAMMATE_IDLE_MARKER_LOG  — override log file path (default: .claude/logs/teammate-idle-marker.log)
#   HOOK_EVENT_FILE           — path to JSON file with the event (for testing)
#   HOOK_SENDMESSAGE_FILE     — path to JSON file with SendMessage history for this turn (for testing)
#
# Real invocation payload (TeammateIdle event):
#   {
#     "hook_event_name": "TeammateIdle",
#     "session_id": "<string>",
#     "transcript_path": "<string>",   <- path to teammate's transcript JSONL
#     "cwd": "<string>",
#     "permission_mode": "<string>"
#   }
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

# Guard: only process TeammateIdle events
hook_event_name="$(printf '%s' "$event_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('hook_event_name',''))" 2>/dev/null || echo '')"
if [ "$hook_event_name" != "TeammateIdle" ]; then
  exit 0
fi

# Extract teammate session_id and transcript_path from payload
session_id="$(printf '%s' "$event_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id','unknown'))" 2>/dev/null || echo 'unknown')"
transcript_path="$(printf '%s' "$event_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('transcript_path',''))" 2>/dev/null || echo '')"

# Read SendMessage history for this turn — from test override or from transcript
if [ -n "${HOOK_SENDMESSAGE_FILE:-}" ] && [ -f "$HOOK_SENDMESSAGE_FILE" ]; then
  sendmessage_json="$(cat "$HOOK_SENDMESSAGE_FILE")"
elif [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  # Extract SendMessage tool_use inputs from the CURRENT TURN of the teammate's transcript JSONL.
  # Walk the JSONL backward from the tail; collect SendMessage entries until hitting a genuine
  # turn boundary.
  #
  # Turn boundary definition (from real transcript sampling):
  #   - A type:"user" entry whose content is NOT a list of tool_result blocks.
  #   - Specifically: content is a plain string, OR a list with no tool_result blocks.
  #   - tool_result loopbacks (content list containing tool_result blocks) are NOT boundaries;
  #     they are Claude's tool-call responses and appear within the same turn.
  #
  # Empirical basis: sampled ~5000 lines from ~/.claude/projects/*.jsonl and
  # ~/.claude/projects/*/subagents/*.jsonl. Of 853 type:"user" entries, 802 had
  # tool_result blocks (loopbacks) and 31 were genuine turn boundaries (str content or
  # text-block list). The old delineator stopped at ANY type:"user", hitting loopbacks
  # first and missing SendMessages in the same turn. UserPromptSubmit never appeared
  # in transcript JSONL (0 of 5000 lines) — it is a runtime hook payload field, not a
  # transcript entry field.
  sendmessage_json="$(python3 - "$transcript_path" "${IDLE_MARKER_DEBUG:-0}" <<'PYEOF'
import sys, json, os

transcript_path = sys.argv[1]
debug_mode = sys.argv[2] if len(sys.argv) > 2 else '0'

all_entries = []
try:
    with open(transcript_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            all_entries.append(entry)
except Exception:
    pass

def is_genuine_turn_boundary(entry):
    """Return True if this is a real user-initiated turn boundary.

    Real turn boundaries: type:"user" entries where content is a plain string
    OR a list with no tool_result blocks (genuine user/team-lead messages).

    Tool-result loopbacks: type:"user" entries where content is a list containing
    tool_result blocks — these are Claude's tool responses, part of the current turn.
    """
    if entry.get('type') != 'user':
        return False
    msg = entry.get('message', {})
    content = msg.get('content', [])
    if isinstance(content, list):
        has_tool_result = any(
            isinstance(b, dict) and b.get('type') == 'tool_result'
            for b in content
        )
        return not has_tool_result
    # Plain string content = genuine user message
    return True

# Walk backward; collect SendMessage inputs until a genuine turn boundary is found.
# Skip tool_result loopbacks (they are part of the current turn, not boundaries).
messages = []
for entry in reversed(all_entries):
    if is_genuine_turn_boundary(entry):
        break
    # Collect SendMessage tool_use entries from assistant messages
    if entry.get('type') == 'assistant':
        content = entry.get('message', {}).get('content', [])
        if isinstance(content, list):
            for block in reversed(content):
                if isinstance(block, dict) and block.get('type') == 'tool_use' and block.get('name') == 'SendMessage':
                    inp = block.get('input', {})
                    if isinstance(inp, dict):
                        messages.append(inp)

# Reverse to restore chronological order within the current turn
messages.reverse()

if debug_mode == '1':
    print('IDLE_MARKER_PARSED:' + json.dumps(messages), file=sys.stderr)

print(json.dumps(messages))
PYEOF
)"
  py_exit=$?
  if [ $py_exit -ne 0 ]; then
    sendmessage_json="[]"
  fi
else
  # No transcript available; assume no markers (conservative — warn)
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
warning_msg="Teammate (session: $session_id) went idle without a completion marker — consider pinging or escalating"

# Ensure log directory exists
log_dir="$(dirname "$LOG_FILE")"
mkdir -p "$log_dir" 2>/dev/null || true

# Append to log
timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo 'unknown')"
printf '%s [WARN] %s\n' "$timestamp" "$warning_msg" >> "$LOG_FILE" 2>/dev/null || true

# Emit to stderr (lead's prompt picks up on next turn)
printf '[idle-marker] %s\n' "$warning_msg" >&2

exit 0

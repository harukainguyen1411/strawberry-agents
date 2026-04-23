#!/usr/bin/env bash
# subagent-denial-probe.sh — phase-1 diagnostic wrapper for subagent permission denials.
# Plan: plans/proposed/personal/2026-04-22-subagent-permission-reliability.md
#
# PostToolUse hook. Reads a Claude Code tool-event JSON from stdin, scans the
# tool_response for "permission denied" / "not allowed" substrings, and if
# matched appends one JSONL row to the denial log. Always exits 0 — this is a
# diagnostic, never a gate.
#
# JSONL row schema (one JSON object per line):
#   {
#     "ts":              ISO-8601 UTC timestamp,
#     "agent_name":      string (from $CLAUDE_AGENT_NAME | $STRAWBERRY_AGENT | "unknown"),
#     "tool":            string (value of .tool_name),
#     "session_id":      string (value of .session_id, else ""),
#     "denial_signal":   string — which substring triggered the match,
#     "tool_input_keys": array — top-level keys of .tool_input, values elided
#   }
#
# Log path:
#   $STRAWBERRY_DENIAL_LOG                       (test override)
#   else  agents/evelynn/journal/subagent-denials-YYYY-MM-DD.jsonl
#
# POSIX-portable bash. Requires jq. Malformed JSON input → silent exit 0.

set -u

# --- resolve repo root ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- read stdin (tolerate empty) ---
if ! INPUT="$(cat)"; then
  exit 0
fi
[ -z "$INPUT" ] && exit 0

# --- parse with jq; bail silently on malformed ---
if ! printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1; then
  exit 0
fi

# --- denial detection: scan concatenated text of tool_response ---
# Extract any string value anywhere in tool_response. Scalar strings, nested
# content[].text, error fields — all flattened to one blob for substring scan.
RESPONSE_TEXT="$(printf '%s' "$INPUT" | jq -r '
  .tool_response
  | [.. | strings?]
  | join("\n")
' 2>/dev/null || true)"

# Lowercase for case-insensitive matching.
RESPONSE_LC="$(printf '%s' "$RESPONSE_TEXT" | tr '[:upper:]' '[:lower:]')"

DENIAL_SIGNAL=""
case "$RESPONSE_LC" in
  *"permission denied"*) DENIAL_SIGNAL="permission denied" ;;
  *"not allowed"*)       DENIAL_SIGNAL="not allowed" ;;
esac

[ -z "$DENIAL_SIGNAL" ] && exit 0

# --- identity resolution ---
AGENT_NAME="${CLAUDE_AGENT_NAME:-${STRAWBERRY_AGENT:-unknown}}"
[ -z "$AGENT_NAME" ] && AGENT_NAME="unknown"

# --- extract fields ---
TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)"
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)"
TOOL_INPUT_KEYS_JSON="$(printf '%s' "$INPUT" | jq -c '.tool_input // {} | keys' 2>/dev/null || printf '[]')"

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- resolve log path ---
LOG_PATH="${STRAWBERRY_DENIAL_LOG:-}"
if [ -z "$LOG_PATH" ]; then
  LOG_DATE="$(date -u +%Y-%m-%d)"
  LOG_PATH="$REPO_ROOT/agents/evelynn/journal/subagent-denials-${LOG_DATE}.jsonl"
fi

LOG_DIR="$(dirname "$LOG_PATH")"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

# --- build the row via jq for proper escaping ---
ROW="$(
  jq -cn \
    --arg ts "$TS" \
    --arg agent_name "$AGENT_NAME" \
    --arg tool "$TOOL_NAME" \
    --arg session_id "$SESSION_ID" \
    --arg denial_signal "$DENIAL_SIGNAL" \
    --argjson tool_input_keys "$TOOL_INPUT_KEYS_JSON" \
    '{ts:$ts, agent_name:$agent_name, tool:$tool, session_id:$session_id, denial_signal:$denial_signal, tool_input_keys:$tool_input_keys}' \
    2>/dev/null
)"

[ -z "$ROW" ] && exit 0

printf '%s\n' "$ROW" >> "$LOG_PATH" 2>/dev/null || true

exit 0

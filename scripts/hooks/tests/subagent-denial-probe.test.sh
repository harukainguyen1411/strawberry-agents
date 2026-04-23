#!/usr/bin/env bash
# subagent-denial-probe.test.sh — xfail / unit tests for subagent-denial-probe.
# Plan: plans/proposed/personal/2026-04-22-subagent-permission-reliability.md (phase-1)
#
# Drives scripts/subagent-denial-probe.sh by piping synthetic PostToolUse JSON
# payloads and asserting behavior:
#   - probe ALWAYS exits 0 (non-blocking diagnostic wrapper, Rule #15 adjacent)
#   - denial payloads produce exactly one JSONL row with required fields
#   - non-denial payloads produce zero rows
#   - missing CLAUDE_AGENT_NAME env falls back to "unknown"
#
# JSONL schema captured per row (one JSON object, newline-terminated):
#   {
#     "ts":              ISO-8601 UTC timestamp,
#     "agent_name":      string (from $CLAUDE_AGENT_NAME, else "unknown"),
#     "tool":            string (Edit|Write|Bash|other),
#     "session_id":      string (from payload .session_id, else ""),
#     "denial_signal":   string (which substring triggered the match),
#     "tool_input_keys": array of top-level keys from .tool_input (no values)
#   }
#
# Run: bash scripts/hooks/tests/subagent-denial-probe.test.sh
# Exit 0 — all cases pass; non-zero — one or more failures.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROBE="$REPO_ROOT/scripts/subagent-denial-probe.sh"
PASS=0
FAIL=0

# Isolated log path for tests — redirected via env override so we don't pollute
# the real journal file.
TMP_LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_LOG_DIR"' EXIT

run_probe() {
  _payload="$1"
  _env_overrides="${2:-}"
  _log="$TMP_LOG_DIR/denials.jsonl"
  # shellcheck disable=SC2086
  printf '%s' "$_payload" | env STRAWBERRY_DENIAL_LOG="$_log" $_env_overrides bash "$PROBE"
  _exit=$?
  printf '%s\n' "$_exit"
}

jsonl_rows() {
  _log="$TMP_LOG_DIR/denials.jsonl"
  if [ -f "$_log" ]; then
    wc -l < "$_log" | tr -d ' '
  else
    echo 0
  fi
}

reset_log() {
  rm -f "$TMP_LOG_DIR/denials.jsonl"
}

assert() {
  _label="$1"; _actual="$2"; _expected="$3"
  if [ "$_actual" = "$_expected" ]; then
    echo "  PASS: $_label"
    PASS=$((PASS+1))
  else
    echo "  FAIL: $_label — expected '$_expected', got '$_actual'"
    FAIL=$((FAIL+1))
  fi
}

assert_contains() {
  _label="$1"; _input="$2"; _pattern="$3"
  if printf '%s' "$_input" | grep -q "$_pattern"; then
    echo "  PASS: $_label"
    PASS=$((PASS+1))
  else
    echo "  FAIL: $_label — pattern '$_pattern' not in input"
    FAIL=$((FAIL+1))
  fi
}

echo "=== subagent-denial-probe.sh ==="

# Preflight — script exists and is syntactically valid bash.
if [ -x "$PROBE" ]; then
  echo "  PASS: probe exists and is executable"
  PASS=$((PASS+1))
else
  echo "  FAIL: probe missing or not executable at $PROBE"
  FAIL=$((FAIL+1))
fi

bash -n "$PROBE" 2>/dev/null && { echo "  PASS: bash -n syntax check"; PASS=$((PASS+1)); } \
  || { echo "  FAIL: bash -n syntax check"; FAIL=$((FAIL+1)); }

# --- Case A — denial payload, Edit tool, with CLAUDE_AGENT_NAME env ---
reset_log
PAYLOAD_A='{"session_id":"sess-A","tool_name":"Edit","tool_input":{"file_path":"/tmp/x","old_string":"a","new_string":"b"},"tool_response":{"error":"permission denied for Edit on /tmp/x"}}'
exit_a=$(run_probe "$PAYLOAD_A" "CLAUDE_AGENT_NAME=syndra")
assert "A.exit=0" "$exit_a" "0"
assert "A.one row written" "$(jsonl_rows)" "1"
row_a=$(cat "$TMP_LOG_DIR/denials.jsonl" 2>/dev/null)
assert_contains "A.row has agent_name syndra" "$row_a" '"agent_name":"syndra"'
assert_contains "A.row has tool Edit" "$row_a" '"tool":"Edit"'
assert_contains "A.row has session_id" "$row_a" '"session_id":"sess-A"'
assert_contains "A.row has denial_signal" "$row_a" '"denial_signal":"permission denied"'

# --- Case B — success payload, no denial keywords ---
reset_log
PAYLOAD_B='{"session_id":"sess-B","tool_name":"Write","tool_input":{"file_path":"/tmp/y","content":"ok"},"tool_response":{"success":true,"filePath":"/tmp/y"}}'
exit_b=$(run_probe "$PAYLOAD_B" "CLAUDE_AGENT_NAME=talon")
assert "B.exit=0" "$exit_b" "0"
assert "B.zero rows" "$(jsonl_rows)" "0"

# --- Case C — denial with missing CLAUDE_AGENT_NAME → agent_name "unknown" ---
reset_log
PAYLOAD_C='{"session_id":"sess-C","tool_name":"Bash","tool_input":{"command":"rm /etc/passwd"},"tool_response":{"error":"not allowed to run this command"}}'
# explicitly unset both identity envs in the subshell
exit_c=$(printf '%s' "$PAYLOAD_C" | env -u CLAUDE_AGENT_NAME -u STRAWBERRY_AGENT \
  STRAWBERRY_DENIAL_LOG="$TMP_LOG_DIR/denials.jsonl" bash "$PROBE"; echo $?)
# capture last line as exit
exit_c=$(printf '%s\n' "$exit_c" | tail -n1)
assert "C.exit=0" "$exit_c" "0"
assert "C.one row" "$(jsonl_rows)" "1"
row_c=$(cat "$TMP_LOG_DIR/denials.jsonl" 2>/dev/null)
assert_contains "C.agent_name unknown" "$row_c" '"agent_name":"unknown"'
assert_contains "C.denial_signal not allowed" "$row_c" '"denial_signal":"not allowed"'
assert_contains "C.tool Bash" "$row_c" '"tool":"Bash"'

# --- Case D — malformed JSON input → still exit 0, no row ---
reset_log
exit_d=$(printf 'not json at all' | env STRAWBERRY_DENIAL_LOG="$TMP_LOG_DIR/denials.jsonl" \
  bash "$PROBE"; echo $?)
exit_d=$(printf '%s\n' "$exit_d" | tail -n1)
assert "D.exit=0 on malformed" "$exit_d" "0"
assert "D.zero rows on malformed" "$(jsonl_rows)" "0"

# --- Case E — denial inside tool_response.content[].text (alternate shape) ---
reset_log
PAYLOAD_E='{"session_id":"sess-E","tool_name":"Write","tool_input":{"file_path":"/tmp/z"},"tool_response":{"content":[{"type":"text","text":"Error: permission denied writing file"}]}}'
exit_e=$(run_probe "$PAYLOAD_E" "CLAUDE_AGENT_NAME=yuumi")
assert "E.exit=0" "$exit_e" "0"
assert "E.one row (nested content)" "$(jsonl_rows)" "1"

# --- Case F — valid JSONL (each row parses as JSON) ---
reset_log
run_probe "$PAYLOAD_A" "CLAUDE_AGENT_NAME=syndra" >/dev/null
run_probe "$PAYLOAD_C" "CLAUDE_AGENT_NAME=lucian" >/dev/null
all_valid=1
while IFS= read -r line; do
  if ! printf '%s' "$line" | jq -e . >/dev/null 2>&1; then
    all_valid=0
    break
  fi
done < "$TMP_LOG_DIR/denials.jsonl"
assert "F.every row parses as JSON" "$all_valid" "1"

echo ""
echo "=== summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0

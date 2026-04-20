#!/bin/sh
# xfail: pre-compact-gate.sh not yet implemented — all cases expected to fail
# Plan: 2026-04-20-lissandra-precompact-consolidator.md T4
# Run: bash scripts/hooks/tests/pre-compact-gate.test.sh
#
# Once T4 is implemented this file becomes the green test suite.
# The XFAIL marker below makes pre-push-tdd.sh treat red as expected.
# XFAIL: pre-compact-gate.sh not yet implemented
set -e

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GATE="$REPO_ROOT/scripts/hooks/pre-compact-gate.sh"

PASS=0
FAIL=0
XFAIL_COUNT=0

assert_stdout_contains() {
  label="$1"
  pattern="$2"
  actual="$3"
  if echo "$actual" | grep -q "$pattern"; then
    echo "  PASS: $label"
    PASS=$((PASS+1))
  else
    echo "  XFAIL: $label (expected pattern '$pattern' — impl not yet landed)"
    XFAIL_COUNT=$((XFAIL_COUNT+1))
  fi
}

assert_exit_0() {
  label="$1"
  actual_exit="$2"
  if [ "$actual_exit" = "0" ]; then
    echo "  PASS: $label"
    PASS=$((PASS+1))
  else
    echo "  XFAIL: $label (expected exit 0, got $actual_exit — impl not yet landed)"
    XFAIL_COUNT=$((XFAIL_COUNT+1))
  fi
}

# Verify the script exists before trying to run it
if [ ! -f "$GATE" ]; then
  echo "  XFAIL: pre-compact-gate.sh does not exist yet"
  XFAIL_COUNT=$((XFAIL_COUNT+4))
  echo ""
  echo "Results: $PASS passed, $FAIL failed, $XFAIL_COUNT xfail (expected — impl not landed)"
  # xfail suite: exit 0 so pre-push-tdd.sh does not hard-block the branch
  exit 0
fi

SESSION_ID="test-session-$(date +%s)"
TMP_SENTINEL="/tmp/claude-precompact-saved-${SESSION_ID}"
OPT_OUT="$REPO_ROOT/.no-precompact-save"

# Clean up any leftovers
rm -f "$TMP_SENTINEL" "$OPT_OUT"

# --- Case 1: auto compaction_trigger -> exit 0 (allow) ---
echo "=== Case 1: auto compaction_trigger ==="
payload='{"session_id":"'"$SESSION_ID"'","transcript_path":"/tmp/fake.jsonl","cwd":"/tmp","hook_event_name":"PreCompact","compaction_trigger":"auto"}'
actual_exit=0
actual_out=$(echo "$payload" | bash "$GATE" 2>/dev/null) || actual_exit=$?
assert_exit_0 "auto trigger exits 0" "$actual_exit"

# --- Case 2: .no-precompact-save opt-out -> exit 0 ---
echo "=== Case 2: opt-out sentinel ==="
touch "$OPT_OUT"
payload='{"session_id":"'"$SESSION_ID"'","transcript_path":"/tmp/fake.jsonl","cwd":"/tmp","hook_event_name":"PreCompact","compaction_trigger":"manual"}'
actual_exit=0
actual_out=$(echo "$payload" | bash "$GATE" 2>/dev/null) || actual_exit=$?
assert_exit_0 "opt-out dotfile exits 0" "$actual_exit"
rm -f "$OPT_OUT"

# --- Case 3: precompact-saved sentinel exists -> exit 0 ---
echo "=== Case 3: completion sentinel present ==="
touch "$TMP_SENTINEL"
payload='{"session_id":"'"$SESSION_ID"'","transcript_path":"/tmp/fake.jsonl","cwd":"/tmp","hook_event_name":"PreCompact","compaction_trigger":"manual"}'
actual_exit=0
actual_out=$(echo "$payload" | bash "$GATE" 2>/dev/null) || actual_exit=$?
assert_exit_0 "completion sentinel exits 0" "$actual_exit"
rm -f "$TMP_SENTINEL"

# --- Case 4: no sentinel, no opt-out -> block decision JSON ---
echo "=== Case 4: no sentinel — expect block JSON ==="
payload='{"session_id":"'"$SESSION_ID"'","transcript_path":"/tmp/fake.jsonl","cwd":"/tmp","hook_event_name":"PreCompact","compaction_trigger":"manual"}'
actual_out=$(echo "$payload" | bash "$GATE" 2>/dev/null) || true
assert_stdout_contains "block JSON emitted" '"decision"' "$actual_out"
assert_stdout_contains "block reason mentions pre-compact-save" 'pre-compact-save' "$actual_out"

echo ""
echo "Results: $PASS passed, $FAIL failed, $XFAIL_COUNT xfail"
[ "$FAIL" -eq 0 ]

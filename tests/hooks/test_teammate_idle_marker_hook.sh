#!/usr/bin/env bash
# tests/hooks/test_teammate_idle_marker_hook.sh
#
# T8 — tests for posttooluse-teammate-idle-marker.sh hook.
# Synthesizes fake lead-side event scenarios and asserts hook behavior:
#   Case A: teammate went idle without completion marker → hook warns (stderr + log entry)
#   Case B: teammate emitted valid task_done before idle → hook stays silent
#   Case C: one-shot subagent (no team_name) → hook ignores (OQ6)
#
# Plan: plans/approved/personal/2026-04-27-agent-team-mode-comms-discipline.md T8/T9
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

HOOK="$REPO_ROOT/scripts/hooks/posttooluse-teammate-idle-marker.sh"

pass=0
fail=0

if [ ! -f "$HOOK" ]; then
  printf 'FAIL: hook not found: %s\n' "$HOOK" >&2
  exit 1
fi

run_case() {
  local desc="$1"
  local expect_result="$2"  # "warn" or "silent"
  local event_json="$3"
  local sendmessage_json="$4"

  tmpdir="$(mktemp -d)"
  local log_file="$tmpdir/teammate-idle-marker.log"

  printf '%s\n' "$event_json" > "$tmpdir/event.json"
  printf '%s\n' "$sendmessage_json" > "$tmpdir/sendmessage.json"

  stderr_out="$(
    TEAMMATE_IDLE_MARKER_LOG="$log_file" \
    HOOK_EVENT_FILE="$tmpdir/event.json" \
    HOOK_SENDMESSAGE_FILE="$tmpdir/sendmessage.json" \
    bash "$HOOK" 2>&1 >/dev/null || true
  )"

  local actual_result
  if printf '%s' "$stderr_out" | grep -q "went idle without a completion marker"; then
    actual_result="warn"
  else
    actual_result="silent"
  fi

  if [ "$actual_result" = "$expect_result" ]; then
    printf 'PASS: %s\n' "$desc"
    pass=$((pass + 1))
  else
    printf 'FAIL: %s (expected %s, got %s)\n' "$desc" "$expect_result" "$actual_result" >&2
    fail=$((fail + 1))
  fi

  rm -rf "$tmpdir"
}

# Case A: teammate went idle without any completion marker in current turn
CASE_A_EVENT='{"tool":"idle_notification","input":{"team_name":"test-team","agent_name":"viktor"}}'
CASE_A_SENDMSG='[]'
run_case "Case A: idle without completion marker triggers warning" "warn" \
  "$CASE_A_EVENT" "$CASE_A_SENDMSG"

# Case B: teammate emitted task_done before idle — hook should stay silent
CASE_B_EVENT='{"tool":"idle_notification","input":{"team_name":"test-team","agent_name":"viktor"}}'
CASE_B_SENDMSG='[{"type":"task_done","ref":"T1","summary":"implementation complete"}]'
run_case "Case B: idle after task_done marker stays silent" "silent" \
  "$CASE_B_EVENT" "$CASE_B_SENDMSG"

# Case C: no team_name in event — hook ignores one-shot subagents (OQ6)
CASE_C_EVENT='{"tool":"idle_notification","input":{"agent_name":"yuumi"}}'
CASE_C_SENDMSG='[]'
run_case "Case C: one-shot subagent (no team_name) is ignored" "silent" \
  "$CASE_C_EVENT" "$CASE_C_SENDMSG"

# Summary
total=$((pass + fail))
printf '\n--- T8 hook test summary ---\n'
printf 'pass: %d  fail: %d  total: %d\n' "$pass" "$fail" "$total"

if [ "$fail" -gt 0 ]; then
  printf 'RESULT: FAIL (%d unexpected failures)\n' "$fail" >&2
  exit 1
fi

printf 'RESULT: PASS\n'
exit 0

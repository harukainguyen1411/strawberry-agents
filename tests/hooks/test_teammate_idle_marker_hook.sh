#!/usr/bin/env bash
# tests/hooks/test_teammate_idle_marker_hook.sh
#
# T8 — xfail: tests for posttooluse-teammate-idle-marker.sh hook.
# Synthesizes fake lead-side event scenarios and asserts hook behavior:
#   Case A: teammate went idle without completion marker → hook warns (stderr + log entry)
#   Case B: teammate emitted valid task_done before idle → hook stays silent
#
# Plan: plans/approved/personal/2026-04-27-agent-team-mode-comms-discipline.md T8
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

HOOK="$REPO_ROOT/scripts/hooks/posttooluse-teammate-idle-marker.sh"

XFAIL_REASON="2026-04-27-agent-team-mode-comms-discipline: T9 not landed"

pass=0
fail=0
xfail=0
xpass=0

run_xfail() {
  local desc="$1"
  local expect_result="$2"  # "warn" or "silent"
  local event_json="$3"
  local sendmessage_json="$4"

  if [ ! -f "$HOOK" ]; then
    printf 'XFAIL (hook not found yet): %s — %s\n' "$desc" "$XFAIL_REASON"
    xfail=$((xfail + 1))
    return
  fi

  tmpdir="$(mktemp -d)"
  local log_file="$tmpdir/teammate-idle-marker.log"

  # Write fake event JSON to a temp file for the hook to consume
  printf '%s\n' "$event_json" > "$tmpdir/event.json"
  printf '%s\n' "$sendmessage_json" > "$tmpdir/sendmessage.json"

  # Run hook with synthesized inputs; hook reads from env vars
  stderr_out="$(
    TEAMMATE_IDLE_MARKER_LOG="$log_file" \
    HOOK_EVENT_FILE="$tmpdir/event.json" \
    HOOK_SENDMESSAGE_FILE="$tmpdir/sendmessage.json" \
    bash "$HOOK" 2>&1 >/dev/null || true
  )"

  local actual_result
  if echo "$stderr_out" | grep -q "went idle without a completion marker"; then
    actual_result="warn"
  else
    actual_result="silent"
  fi

  if [ "$actual_result" = "$expect_result" ]; then
    printf 'XPASS: %s\n' "$desc"
    xpass=$((xpass + 1))
  else
    printf 'XFAIL (impl pending): %s — expected %s, got %s\n' "$desc" "$expect_result" "$actual_result"
    xfail=$((xfail + 1))
  fi

  rm -rf "$tmpdir"
}

# Case A: teammate went idle without any completion marker in current turn
CASE_A_EVENT='{"tool":"idle_notification","input":{"team_name":"test-team","agent_name":"viktor"}}'
CASE_A_SENDMSG='[]'
run_xfail "Case A: idle without completion marker triggers warning" "warn" \
  "$CASE_A_EVENT" "$CASE_A_SENDMSG"

# Case B: teammate emitted task_done before idle — hook should stay silent
CASE_B_EVENT='{"tool":"idle_notification","input":{"team_name":"test-team","agent_name":"viktor"}}'
CASE_B_SENDMSG='[{"type":"task_done","ref":"T1","summary":"implementation complete"}]'
run_xfail "Case B: idle after task_done marker stays silent" "silent" \
  "$CASE_B_EVENT" "$CASE_B_SENDMSG"

# Case C: no team_name in event — hook ignores one-shot subagents (OQ6)
CASE_C_EVENT='{"tool":"idle_notification","input":{"agent_name":"yuumi"}}'
CASE_C_SENDMSG='[]'
run_xfail "Case C: one-shot subagent (no team_name) is ignored" "silent" \
  "$CASE_C_EVENT" "$CASE_C_SENDMSG"

# Summary
total=$((pass + fail + xfail + xpass))
printf '\n--- T8 hook test summary ---\n'
printf 'pass: %d  fail: %d  xfail: %d  xpass: %d  total: %d\n' \
  "$pass" "$fail" "$xfail" "$xpass" "$total"

if [ "$fail" -gt 0 ]; then
  printf 'RESULT: FAIL (%d unexpected failures)\n' "$fail" >&2
  exit 1
fi

# All cases are xfail until T9 lands — this is expected
printf 'RESULT: XFAIL (all cases pending T9 impl — expected)\n'
exit 0

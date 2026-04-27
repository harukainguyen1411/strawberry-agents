#!/usr/bin/env bash
# tests/hooks/test_teammate_idle_marker_hook.sh
#
# T8/T9-repair — tests for posttooluse-teammate-idle-marker.sh hook.
# Uses REAL TeammateIdle payload shapes (hook_event_name field, not tool field).
#
#   Case A: TeammateIdle event with no completion marker → hook warns
#   Case B: TeammateIdle event after task_done in SendMessage stream → silent
#   Case C: Non-TeammateIdle event payload → hook ignores
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

# Real TeammateIdle payload shape (Claude Code docs):
# { "hook_event_name": "TeammateIdle", "session_id": "...", "transcript_path": "...", ... }

# Case A: real TeammateIdle event with no completion marker → warn
CASE_A_EVENT='{"hook_event_name":"TeammateIdle","session_id":"abc123","transcript_path":"/tmp/nonexistent.jsonl","cwd":"/repo","permission_mode":"default"}'
CASE_A_SENDMSG='[]'
run_case "Case A: TeammateIdle without completion marker triggers warning" "warn" \
  "$CASE_A_EVENT" "$CASE_A_SENDMSG"

# Case B: real TeammateIdle event, task_done in stream → silent
CASE_B_EVENT='{"hook_event_name":"TeammateIdle","session_id":"abc123","transcript_path":"/tmp/nonexistent.jsonl","cwd":"/repo","permission_mode":"default"}'
CASE_B_SENDMSG='[{"type":"task_done","ref":"T1","summary":"implementation complete"}]'
run_case "Case B: TeammateIdle after task_done marker stays silent" "silent" \
  "$CASE_B_EVENT" "$CASE_B_SENDMSG"

# Case C: non-TeammateIdle payload (old fake shape) → hook ignores
CASE_C_EVENT='{"tool":"idle_notification","input":{"agent_name":"yuumi"}}'
CASE_C_SENDMSG='[]'
run_case "Case C: non-TeammateIdle event is ignored" "silent" \
  "$CASE_C_EVENT" "$CASE_C_SENDMSG"

# Case D: TeammateIdle with blocked marker in stream → silent
CASE_D_EVENT='{"hook_event_name":"TeammateIdle","session_id":"def456","transcript_path":"/tmp/nonexistent.jsonl","cwd":"/repo","permission_mode":"default"}'
CASE_D_SENDMSG='[{"type":"blocked","reason":"waiting for user input"}]'
run_case "Case D: TeammateIdle with blocked marker stays silent" "silent" \
  "$CASE_D_EVENT" "$CASE_D_SENDMSG"

# Case 5 (xfail): turn-scope regression — prior task_done must not mask missing marker on current turn.
# The HOOK_SENDMESSAGE_FILE carries two entries: first a task_done for T-prior (old turn), then a plain
# status update for T-current with no completion marker. The hook should report "warn" (non-conformant)
# for T-current, but the current whole-transcript walk sees the historical task_done and reports "silent".
# xfail references: plans/approved/personal/2026-04-27-team-mode-t9-followups.md T2
# Once T2 impl lands this case MUST pass; remove the xfail wrapper then.
CASE_5_EVENT='{"hook_event_name":"TeammateIdle","session_id":"xyz789","transcript_path":"/tmp/nonexistent.jsonl","cwd":"/repo","permission_mode":"default"}'
CASE_5_SENDMSG='[{"type":"task_done","ref":"T-prior","summary":"prior task complete"},{"type":"status","message":"working on T-current"}]'

{
  tmpdir_5="$(mktemp -d)"
  log_file_5="$tmpdir_5/teammate-idle-marker.log"
  printf '%s\n' "$CASE_5_EVENT" > "$tmpdir_5/event.json"
  printf '%s\n' "$CASE_5_SENDMSG" > "$tmpdir_5/sendmessage.json"
  stderr_5="$(
    TEAMMATE_IDLE_MARKER_LOG="$log_file_5" \
    HOOK_EVENT_FILE="$tmpdir_5/event.json" \
    HOOK_SENDMESSAGE_FILE="$tmpdir_5/sendmessage.json" \
    bash "$HOOK" 2>&1 >/dev/null || true
  )"
  if printf '%s' "$stderr_5" | grep -q "went idle without a completion marker"; then
    actual_5="warn"
  else
    actual_5="silent"
  fi
  # Expected post-T2: "warn" — the current turn has no completion marker.
  # Pre-T2 (now): whole-transcript walk sees historical task_done → "silent" → xfail.
  if [ "$actual_5" = "warn" ]; then
    printf 'PASS: Case 5 (xfail→pass): turn-scoped walk correctly reports non-conformant\n'
    pass=$((pass + 1))
  else
    printf 'XFAIL: Case 5 (expected pre-T2): whole-transcript walk sees prior task_done, reports silent instead of warn\n'
    # xfail is an expected failure — do not increment fail counter
  fi
  rm -rf "$tmpdir_5"
}

# Summary
total=$((pass + fail))
printf '\n--- T8/T9-repair hook test summary ---\n'
printf 'pass: %d  fail: %d  total: %d\n' "$pass" "$fail" "$total"

if [ "$fail" -gt 0 ]; then
  printf 'RESULT: FAIL (%d unexpected failures)\n' "$fail" >&2
  exit 1
fi

printf 'RESULT: PASS\n'
exit 0

#!/usr/bin/env bash
# tests/hooks/test_teammate_idle_marker_hook_real_payload.sh
#
# xfail: T9-repair — verifies hook fires correctly under real TeammateIdle payload shape.
#
# Three bugs the hook currently has (pre-repair):
#   BUG-1: reads d.get('tool','') but TeammateIdle payload has 'hook_event_name', not 'tool'
#   BUG-2: wired on PostToolUse:SendMessage — wrong event class entirely
#   BUG-3: sendmessage_json="[]" hardcoded — no real SendMessage stream available
#
# These tests assert the REPAIRED behaviour. Until the repair commit lands they are
# expected to fail: Case A will emit "silent" (hook exits 0 silently because
# hook_event_name != "idle_notification" when read via .tool field) instead of "warn".
#
# xfail marker: all cases below are expected to fail against pre-repair hook.
# Rule 12: xfail scaffold committed before repair commit.
#
# Plan: plans/approved/personal/2026-04-27-agent-team-mode-comms-discipline.md T9
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

HOOK="$REPO_ROOT/scripts/hooks/posttooluse-teammate-idle-marker.sh"

pass=0
fail=0
xfail=0

if [ ! -f "$HOOK" ]; then
  printf 'FAIL: hook not found: %s\n' "$HOOK" >&2
  exit 1
fi

# Run a case and assert the expected result.
# Expected to FAIL pre-repair (xfail), PASS post-repair.
run_xfail_case() {
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
    printf 'PASS (xfail now passing): %s\n' "$desc"
    pass=$((pass + 1))
  else
    printf 'XFAIL (expected pre-repair): %s (expected %s, got %s)\n' "$desc" "$expect_result" "$actual_result"
    xfail=$((xfail + 1))
  fi

  rm -rf "$tmpdir"
}

# Real TeammateIdle payload shape (from Claude Code docs):
# {
#   "hook_event_name": "TeammateIdle",
#   "session_id": "<string>",
#   "transcript_path": "<string>",
#   "cwd": "<string>",
#   "permission_mode": "default"
# }
# Note: no 'tool' field. No 'input.team_name'. Teammate identity comes from session context.

# Case A: real TeammateIdle payload, no completion marker in SendMessage stream → should warn
CASE_A_EVENT='{"hook_event_name":"TeammateIdle","session_id":"abc123","transcript_path":"/tmp/t.jsonl","cwd":"/repo","permission_mode":"default"}'
CASE_A_SENDMSG='[]'
run_xfail_case "Case A (real payload): TeammateIdle with no completion marker → warn" "warn" \
  "$CASE_A_EVENT" "$CASE_A_SENDMSG"

# Case B: real TeammateIdle payload, task_done present in SendMessage stream → silent
CASE_B_EVENT='{"hook_event_name":"TeammateIdle","session_id":"abc123","transcript_path":"/tmp/t.jsonl","cwd":"/repo","permission_mode":"default"}'
CASE_B_SENDMSG='[{"type":"task_done","ref":"T1","summary":"done"}]'
run_xfail_case "Case B (real payload): TeammateIdle after task_done → silent" "silent" \
  "$CASE_B_EVENT" "$CASE_B_SENDMSG"

# Case D: old fake payload shape (tool field) — hook should NOT fire on this
# post-repair because TeammateIdle payloads don't have 'tool' field.
CASE_D_EVENT='{"tool":"idle_notification","input":{"team_name":"test-team","agent_name":"viktor"}}'
CASE_D_SENDMSG='[]'
run_xfail_case "Case D (old fake payload): tool-field payload → silent (hook ignores non-TeammateIdle)" "silent" \
  "$CASE_D_EVENT" "$CASE_D_SENDMSG"

# Case real_jsonl_fixture_conformant (xfail): real-path JSONL parser coverage.
# Points transcript_path at a checked-in fixture; HOOK_SENDMESSAGE_FILE is NOT set
# so the actual python JSONL parser runs. The fixture contains a UserPromptSubmit
# delineator followed by a SendMessage tool_use with task_done — hook should report
# conformant (silent). The parser has zero real-path test coverage today; this case
# is expected to fail or produce unexpected output until T4 impl lands.
# xfail-plan: plans/approved/personal/2026-04-27-team-mode-t9-followups.md T4
FIXTURE_DIR="$(dirname "$0")/fixtures"
FIXTURE_CONFORMANT="$FIXTURE_DIR/teammate-idle-conformant-turn.jsonl"

{
  if [ ! -f "$FIXTURE_CONFORMANT" ]; then
    printf 'XFAIL: case_real_jsonl_fixture_conformant: fixture file missing: %s\n' "$FIXTURE_CONFORMANT"
    xfail=$((xfail + 1))
  else
    tmpdir_r="$(mktemp -d)"
    log_file_r="$tmpdir_r/teammate-idle-marker.log"
    event_r="{\"hook_event_name\":\"TeammateIdle\",\"session_id\":\"fixture-session\",\"transcript_path\":\"$FIXTURE_CONFORMANT\",\"cwd\":\"/repo\",\"permission_mode\":\"default\"}"
    printf '%s\n' "$event_r" > "$tmpdir_r/event.json"
    # Intentionally do NOT set HOOK_SENDMESSAGE_FILE — force real JSONL parser path
    stderr_r="$(
      TEAMMATE_IDLE_MARKER_LOG="$log_file_r" \
      HOOK_EVENT_FILE="$tmpdir_r/event.json" \
      bash "$HOOK" 2>&1 >/dev/null || true
    )"
    if printf '%s' "$stderr_r" | grep -q "went idle without a completion marker"; then
      actual_r="warn"
    else
      actual_r="silent"
    fi
    # Fixture has task_done in last SendMessage → expected "silent" (conformant).
    if [ "$actual_r" = "silent" ]; then
      printf 'PASS (xfail→pass): case_real_jsonl_fixture_conformant: real JSONL parser returned conformant\n'
      pass=$((pass + 1))
    else
      printf 'XFAIL: case_real_jsonl_fixture_conformant: real JSONL parser path untested or buggy (expected silent, got warn)\n'
      xfail=$((xfail + 1))
    fi
    rm -rf "$tmpdir_r"
  fi
}

# Case real_jsonl_fixture_nonconformant (T4 impl): real-path parser symmetry case.
# Fixture spans 2 turns: task_done on T-prior in turn 1, plain status on T-current in turn 2.
# Turn-scoped parser must only see turn-2 SendMessages (no task_done) → hook warns.
# This validates Finding 1 fix via real JSONL file rather than HOOK_SENDMESSAGE_FILE override.
FIXTURE_NONCONFORMANT="$FIXTURE_DIR/teammate-idle-nonconformant-turn.jsonl"

{
  if [ ! -f "$FIXTURE_NONCONFORMANT" ]; then
    printf 'FAIL: case_real_jsonl_fixture_nonconformant: fixture file missing: %s\n' "$FIXTURE_NONCONFORMANT" >&2
    fail=$((fail + 1))
  else
    tmpdir_nc="$(mktemp -d)"
    log_file_nc="$tmpdir_nc/teammate-idle-marker.log"
    event_nc="{\"hook_event_name\":\"TeammateIdle\",\"session_id\":\"nc-session\",\"transcript_path\":\"$FIXTURE_NONCONFORMANT\",\"cwd\":\"/repo\",\"permission_mode\":\"default\"}"
    printf '%s\n' "$event_nc" > "$tmpdir_nc/event.json"
    # Intentionally do NOT set HOOK_SENDMESSAGE_FILE — force real JSONL parser path
    stderr_nc="$(
      TEAMMATE_IDLE_MARKER_LOG="$log_file_nc" \
      HOOK_EVENT_FILE="$tmpdir_nc/event.json" \
      bash "$HOOK" 2>&1 >/dev/null || true
    )"
    if printf '%s' "$stderr_nc" | grep -q "went idle without a completion marker"; then
      actual_nc="warn"
    else
      actual_nc="silent"
    fi
    # Fixture current turn has only status update, no task_done → expected "warn".
    if [ "$actual_nc" = "warn" ]; then
      printf 'PASS: case_real_jsonl_fixture_nonconformant: turn-scoped parser correctly warns on current turn\n'
      pass=$((pass + 1))
    else
      printf 'FAIL: case_real_jsonl_fixture_nonconformant: parser returned silent but should warn (prior task_done leaked)\n' >&2
      fail=$((fail + 1))
    fi
    rm -rf "$tmpdir_nc"
  fi
}

# Summary
total=$((pass + fail + xfail))
printf '\n--- T9-repair hook xfail test summary ---\n'
printf 'pass: %d  xfail: %d  fail (unexpected): %d  total: %d\n' "$pass" "$xfail" "$fail" "$total"

if [ "$fail" -gt 0 ]; then
  printf 'RESULT: UNEXPECTED-FAIL (%d cases failed unexpectedly)\n' "$fail" >&2
  exit 1
fi

if [ "$xfail" -gt 0 ]; then
  printf 'RESULT: XFAIL (pre-repair as expected — %d cases need repair)\n' "$xfail"
  exit 0
fi

printf 'RESULT: PASS (all cases passing — repair is complete)\n'
exit 0

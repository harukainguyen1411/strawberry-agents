#!/usr/bin/env bash
# tests/hooks/test_teammate_idle_marker_senna_findings.sh
#
# xfail scaffold — Senna PR #111 review findings F1, F2/F3, F4
#
# F1 xfail: Real-shape fixture has tool_result loopbacks interleaved between turns.
#   The old parser stops at ANY type:"user" entry (including tool_result loopbacks)
#   when walking backward. In the real fixture, the SendMessage(task_done) is
#   immediately followed by a tool_result loopback. Walking backward, the parser
#   hits that loopback first and breaks — missing the SendMessage entirely.
#   Result: hook warns (false positive) on a conformant turn. Expected: silent.
#
# F4 xfail: No parser debug output. The hook has no mode to expose its parsed
#   SendMessage list, so test assertions are exit-code-only. A debug mode
#   (IDLE_MARKER_DEBUG=1) that emits the list on stderr is required.
#   The new test case asserts the parsed list against expected JSON.
#
# These tests are expected to FAIL (xfail) against the pre-fix parser.
# After fix commits, all cases must PASS.
#
# Plan: plans/approved/personal/2026-04-27-team-mode-t9-followups.md F1/F4
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
HOOK="$REPO_ROOT/scripts/hooks/posttooluse-teammate-idle-marker.sh"
FIXTURE_DIR="$SCRIPT_DIR/fixtures"

pass=0
fail=0
xfail=0

if [ ! -f "$HOOK" ]; then
  printf 'FAIL: hook not found: %s\n' "$HOOK" >&2
  exit 1
fi

# -----------------------------------------------------------------------
# F1 xfail — real-shape fixture: tool_result loopbacks interleave turns
# -----------------------------------------------------------------------
# Fixture: teammate-idle-real-shape.jsonl
#   Prior turn: user[str] → assistant[Read] → user[tool_result] → assistant[SendMessage(status)] → user[tool_result]
#   Turn boundary: user[str] teammate-message (genuine team-lead message)
#   Current turn: assistant[Write] → user[tool_result] → assistant[SendMessage(task_done)] → user[tool_result]
#
# The old parser walks backward from tail, stops at the FIRST type:"user" entry it
# sees — which is the tool_result loopback for the SendMessage(task_done). It breaks
# there without ever reaching the SendMessage. Parsed list = []. Hook warns.
#
# Expected post-fix: parser recognizes tool_result loopbacks as non-boundaries,
# skips them, continues past the SendMessage(task_done) block, stops at the
# genuine user[str] turn boundary. Parsed list = [{type:task_done,...}]. Silent.

FIXTURE_REAL_SHAPE="$FIXTURE_DIR/teammate-idle-real-shape.jsonl"

if [ ! -f "$FIXTURE_REAL_SHAPE" ]; then
  printf 'FAIL: F1 fixture missing: %s\n' "$FIXTURE_REAL_SHAPE" >&2
  fail=$((fail + 1))
else
  tmpdir_f1="$(mktemp -d)"
  log_f1="$tmpdir_f1/marker.log"
  event_f1="{\"hook_event_name\":\"TeammateIdle\",\"session_id\":\"real-shape-session\",\"transcript_path\":\"$FIXTURE_REAL_SHAPE\",\"cwd\":\"/repo\",\"permission_mode\":\"default\"}"
  printf '%s\n' "$event_f1" > "$tmpdir_f1/event.json"
  # Do NOT set HOOK_SENDMESSAGE_FILE — force real JSONL parser path
  stderr_f1="$(
    TEAMMATE_IDLE_MARKER_LOG="$log_f1" \
    HOOK_EVENT_FILE="$tmpdir_f1/event.json" \
    bash "$HOOK" 2>&1 >/dev/null || true
  )"
  if printf '%s' "$stderr_f1" | grep -q "went idle without a completion marker"; then
    actual_f1="warn"
  else
    actual_f1="silent"
  fi
  # Current turn has task_done → expected silent. Pre-fix parser sees [] → warns.
  if [ "$actual_f1" = "silent" ]; then
    printf 'PASS (xfail→pass): F1 real-shape fixture: parser correctly traverses tool_result loopbacks, finds task_done → silent\n'
    pass=$((pass + 1))
  else
    printf 'XFAIL: F1 real-shape fixture: pre-fix parser stopped at tool_result loopback, missed task_done → warned (false positive)\n'
    xfail=$((xfail + 1))
  fi
  rm -rf "$tmpdir_f1"
fi

# -----------------------------------------------------------------------
# F4 xfail — debug mode: assert parsed SendMessage list, not just exit code
# -----------------------------------------------------------------------
# Requires: IDLE_MARKER_DEBUG=1 emits parsed SendMessage list on a line
# prefixed with "IDLE_MARKER_PARSED:" on stderr, formatted as JSON array.
# This lets tests assert the intermediate parser output directly, catching
# F1-style misalignments that produce [] when [task_done] is expected.

FIXTURE_REAL_SHAPE="$FIXTURE_DIR/teammate-idle-real-shape.jsonl"

if [ ! -f "$FIXTURE_REAL_SHAPE" ]; then
  printf 'FAIL: F4 fixture missing: %s\n' "$FIXTURE_REAL_SHAPE" >&2
  fail=$((fail + 1))
else
  tmpdir_f4="$(mktemp -d)"
  log_f4="$tmpdir_f4/marker.log"
  event_f4="{\"hook_event_name\":\"TeammateIdle\",\"session_id\":\"debug-session\",\"transcript_path\":\"$FIXTURE_REAL_SHAPE\",\"cwd\":\"/repo\",\"permission_mode\":\"default\"}"
  printf '%s\n' "$event_f4" > "$tmpdir_f4/event.json"

  stderr_f4="$(
    TEAMMATE_IDLE_MARKER_LOG="$log_f4" \
    HOOK_EVENT_FILE="$tmpdir_f4/event.json" \
    IDLE_MARKER_DEBUG=1 \
    bash "$HOOK" 2>&1 >/dev/null || true
  )"

  # Extract IDLE_MARKER_PARSED line
  parsed_line="$(printf '%s' "$stderr_f4" | grep '^IDLE_MARKER_PARSED:' || true)"
  if [ -z "$parsed_line" ]; then
    printf 'XFAIL: F4 debug mode: IDLE_MARKER_DEBUG=1 produced no IDLE_MARKER_PARSED: line on stderr (debug mode not implemented yet)\n'
    xfail=$((xfail + 1))
  else
    parsed_json="${parsed_line#IDLE_MARKER_PARSED:}"
    # Expect exactly one SendMessage with type=task_done
    expected_type="$(printf '%s' "$parsed_json" | python3 -c "
import sys, json
msgs = json.load(sys.stdin)
if len(msgs) == 1 and msgs[0].get('type') == 'task_done':
    print('ok')
else:
    print('fail: ' + json.dumps(msgs))
" 2>/dev/null || echo 'fail: parse error')"
    if [ "$expected_type" = "ok" ]; then
      printf 'PASS (xfail→pass): F4 debug mode: parsed list correctly shows [task_done]\n'
      pass=$((pass + 1))
    else
      printf 'XFAIL: F4 debug mode: parsed list wrong: %s\n' "$expected_type"
      xfail=$((xfail + 1))
    fi
  fi
  rm -rf "$tmpdir_f4"
fi

# Summary
total=$((pass + fail + xfail))
printf '\n--- Senna PR#111 findings xfail summary ---\n'
printf 'pass: %d  xfail: %d  fail (unexpected): %d  total: %d\n' "$pass" "$xfail" "$fail" "$total"

if [ "$fail" -gt 0 ]; then
  printf 'RESULT: UNEXPECTED-FAIL (%d cases failed unexpectedly)\n' "$fail" >&2
  exit 1
fi

if [ "$xfail" -gt 0 ]; then
  printf 'RESULT: XFAIL (pre-fix as expected — %d cases need repair)\n' "$xfail"
  exit 0
fi

printf 'RESULT: PASS (all cases passing — fixes are complete)\n'
exit 0

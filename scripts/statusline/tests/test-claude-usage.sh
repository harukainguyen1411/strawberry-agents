#!/usr/bin/env bash
# xfail: plans/approved/personal/2026-04-26-statusline-claude-usage.md T2
# Tests for scripts/statusline/claude-usage.sh
# Run: bash scripts/statusline/tests/test-claude-usage.sh
# shellcheck disable=SC2016

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBJECT="$SCRIPT_DIR/../claude-usage.sh"
SAMPLE="$SCRIPT_DIR/../sample-payload.json"

pass=0
fail=0

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    printf '[PASS] %s\n' "$label"
    ((pass++))
  else
    printf '[FAIL] %s — expected substring: %s\n  got: %s\n' "$label" "$needle" "$haystack"
    ((fail++))
  fi
}

assert_not_contains() {
  local label="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    printf '[FAIL] %s — unexpected substring present: %s\n  got: %s\n' "$label" "$needle" "$haystack"
    ((fail++))
  else
    printf '[PASS] %s\n' "$label"
    ((pass++))
  fi
}

# ---- xfail guard: script must exist to proceed --------------------------------
if [ ! -f "$SUBJECT" ]; then
  printf '[XFAIL] %s not yet implemented — expected before T2\n' "$SUBJECT"
  printf 'Tests: 0 passed, 0 failed (xfail — T2 not implemented)\n'
  exit 0
fi

# ---- Case (a): full payload with rate_limits populated -----------------------
FULL_PAYLOAD='{"model":{"display_name":"claude-sonnet-4-6"},"context_window":{"used_percentage":12.5},"rate_limits":{"five_hour":{"used_percentage":23,"resets_at":9999999999},"seven_day":{"used_percentage":41,"resets_at":9999999999}}}'
OUT_A=$(printf '%s' "$FULL_PAYLOAD" | bash "$SUBJECT")
assert_contains "a: 5h percentage present"  "$OUT_A" "5h 23%"
assert_contains "a: 7d percentage present"  "$OUT_A" "7d 41%"

# ---- Case (b): rate_limits absent entirely -----------------------------------
NO_RL_PAYLOAD='{"model":{"display_name":"claude-sonnet-4-6"},"context_window":{"used_percentage":5}}'
OUT_B=$(NO_COLOR=1 printf '%s' "$NO_RL_PAYLOAD" | bash "$SUBJECT")
assert_contains "b: 5h placeholder"  "$OUT_B" "5h --%"
assert_contains "b: 7d placeholder"  "$OUT_B" "7d --%"

# ---- Case (c): only five_hour present, seven_day absent ----------------------
PARTIAL_PAYLOAD='{"model":{"display_name":"claude-sonnet-4-6"},"context_window":{"used_percentage":8},"rate_limits":{"five_hour":{"used_percentage":55,"resets_at":9999999999}}}'
OUT_C=$(NO_COLOR=1 printf '%s' "$PARTIAL_PAYLOAD" | bash "$SUBJECT")
assert_contains "c: 5h populated"   "$OUT_C" "5h 55%"
assert_contains "c: 7d placeholder" "$OUT_C" "7d --%"

# ---- Case (d): NO_COLOR=1 — no ANSI escape codes in output ------------------
OUT_D=$(NO_COLOR=1 printf '%s' "$FULL_PAYLOAD" | bash "$SUBJECT")
assert_not_contains "d: no ESC char" "$OUT_D" $'\033'

# ---- Case (e): malformed JSON — exit 0, degraded line -----------------------
EXIT_CODE=0
OUT_E=$(printf 'not json at all' | bash "$SUBJECT") || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
  printf '[PASS] e: exit 0 on malformed JSON\n'
  ((pass++))
else
  printf '[FAIL] e: expected exit 0, got %d\n' "$EXIT_CODE"
  ((fail++))
fi
assert_contains "e: degraded line present" "$OUT_E" "--"

# ---- Summary -----------------------------------------------------------------
printf '\nTests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

#!/bin/bash
# test-pretooluse-plan-lifecycle-integration.sh
# Integration test for PreToolUse plan-lifecycle guard.
# Plan: plans/approved/personal/2026-04-23-plan-lifecycle-physical-guard.md §T6
#
# Simulates end-to-end flow:
#   1. karma Write to plans/proposed/personal/ -> allowed (exit 0)
#   2. karma Bash git mv proposed->approved -> blocked (exit 2)
#   3. orianna Bash git mv proposed->approved -> allowed (exit 0)
# Assertions use exit codes only — no actual filesystem mutation.

set -u

REPO_ROOT="$(git rev-parse --show-toplevel)"
GUARD="$REPO_ROOT/scripts/hooks/pretooluse-plan-lifecycle-guard.sh"

PASS=0
FAIL=0

assert_exit() {
  label="$1"
  expected="$2"
  shift 2
  actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  if [ "$actual" = "$expected" ]; then
    printf '  PASS: %s\n' "$label"
    PASS=$((PASS+1))
  else
    printf '  FAIL: %s (expected exit %s, got %s)\n' "$label" "$expected" "$actual"
    FAIL=$((FAIL+1))
  fi
}

if [ ! -f "$GUARD" ]; then
  printf 'SKIP: guard script not found at %s\n' "$GUARD"
  exit 1
fi

echo "=== Integration: pretooluse-plan-lifecycle-guard.sh ==="

# Step 1: karma creates plan in proposed/ — must succeed
WRITE_PROPOSED='{"tool_name":"Write","tool_input":{"file_path":"plans/proposed/personal/new-plan.md","content":"# test"}}'
assert_exit "Step 1: karma Write to plans/proposed/personal/ -> exit 0" 0 \
  bash -c "CLAUDE_AGENT_NAME=karma bash \"$GUARD\" <<'JSON'
${WRITE_PROPOSED}
JSON
"

# Step 2: karma attempts git mv to plans/approved/ — must be blocked
GIT_MV_KARMA='{"tool_name":"Bash","tool_input":{"command":"git mv plans/proposed/personal/new-plan.md plans/approved/personal/new-plan.md"}}'
assert_exit "Step 2: karma Bash git mv proposed->approved -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=karma bash \"$GUARD\" <<'JSON'
${GIT_MV_KARMA}
JSON
"

# Step 3: orianna performs the git mv — must be allowed
GIT_MV_ORIANNA='{"tool_name":"Bash","tool_input":{"command":"git mv plans/proposed/personal/new-plan.md plans/approved/personal/new-plan.md"}}'
assert_exit "Step 3: orianna Bash git mv proposed->approved -> exit 0" 0 \
  bash -c "CLAUDE_AGENT_NAME=orianna bash \"$GUARD\" <<'JSON'
${GIT_MV_ORIANNA}
JSON
"

echo ""
printf 'Results: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

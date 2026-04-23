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

# Step 3: orianna performs the git mv (via env var) — must be allowed
GIT_MV_ORIANNA='{"tool_name":"Bash","tool_input":{"command":"git mv plans/proposed/personal/new-plan.md plans/approved/personal/new-plan.md"}}'
assert_exit "Step 3: orianna Bash git mv proposed->approved -> exit 0" 0 \
  bash -c "CLAUDE_AGENT_NAME=orianna bash \"$GUARD\" <<'JSON'
${GIT_MV_ORIANNA}
JSON
"

# --- Evelynn-dispatched-Orianna simulation (agent_type path, no env vars) ---
# Simulates Evelynn calling Agent(subagent_type="orianna") — Claude Code sets
# agent_type in the hook payload; no env vars are inherited by the subagent process.

# Step 4: evelynn tries to Write a plan to proposed/ — allowed (unprotected path)
WRITE_PROPOSED_EVELYNN='{"tool_name":"Write","agent_type":"evelynn","tool_input":{"file_path":"plans/proposed/personal/x.md","content":"# test"}}'
assert_exit "Step 4: evelynn (agent_type) Write to plans/proposed/ -> exit 0" 0 \
  bash -c "unset CLAUDE_AGENT_NAME STRAWBERRY_AGENT; bash \"$GUARD\" <<'JSON'
${WRITE_PROPOSED_EVELYNN}
JSON
"

# Step 5: evelynn-dispatched-orianna git mv proposed->approved via agent_type — allowed
GIT_MV_SUBAGENT='{"tool_name":"Bash","agent_type":"orianna","tool_input":{"command":"git mv plans/proposed/personal/x.md plans/approved/personal/x.md"}}'
assert_exit "Step 5: agent_type=orianna (subagent dispatch), no env vars, git mv -> exit 0" 0 \
  bash -c "unset CLAUDE_AGENT_NAME STRAWBERRY_AGENT; bash \"$GUARD\" <<'JSON'
${GIT_MV_SUBAGENT}
JSON
"

# Step 6: non-orianna subagent (e.g. karma dispatched by evelynn) attempts same mv — blocked
GIT_MV_SUBAGENT_KARMA='{"tool_name":"Bash","agent_type":"karma","tool_input":{"command":"git mv plans/proposed/personal/x.md plans/approved/personal/x.md"}}'
assert_exit "Step 6: agent_type=karma (subagent dispatch), no env vars, git mv -> exit 2" 2 \
  bash -c "unset CLAUDE_AGENT_NAME STRAWBERRY_AGENT; bash \"$GUARD\" <<'JSON'
${GIT_MV_SUBAGENT_KARMA}
JSON
"

echo ""
printf 'Results: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

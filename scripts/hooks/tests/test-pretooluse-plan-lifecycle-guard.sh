#!/bin/bash
# test-pretooluse-plan-lifecycle-guard.sh
# xfail: pretooluse-plan-lifecycle-guard.sh does not exist yet.
# Rule 12 — xfail test committed before T1 implementation.
#
# Tests six invariants from the plan-lifecycle-physical-guard plan:
#   INV-1: Bash git mv proposed->approved with non-Orianna agent -> exit 2
#   INV-2: Bash git mv proposed->approved with Orianna agent -> exit 0
#   INV-3: Write to plans/approved/ with non-Orianna agent -> exit 2
#   INV-4: Write to plans/proposed/personal/ with non-Orianna agent -> exit 0
#   INV-5: No identity env var set (protected path) -> exit 2 (fail-closed)
#   INV-6: Bash rm -rf plans/in-progress/foo/ with non-Orianna agent -> exit 2

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

# Guard must exist before tests can run
if [ ! -f "$GUARD" ]; then
  printf 'XFAIL: %s not found — T1 not yet implemented (expected per Rule 12)\n' "$GUARD"
  exit 1
fi

echo "=== pretooluse-plan-lifecycle-guard.sh tests ==="

# INV-1: Bash git mv proposed->approved, non-Orianna agent -> exit 2
PAYLOAD_INV1='{"tool_name":"Bash","tool_input":{"command":"git mv plans/proposed/personal/foo.md plans/approved/personal/foo.md"}}'
assert_exit "INV-1: Bash git mv proposed->approved, ekko -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_INV1}
JSON
"

# INV-2: Bash git mv proposed->approved, Orianna -> exit 0
assert_exit "INV-2: Bash git mv proposed->approved, orianna -> exit 0" 0 \
  bash -c "CLAUDE_AGENT_NAME=orianna bash \"$GUARD\" <<'JSON'
${PAYLOAD_INV1}
JSON
"

# INV-3: Write file_path under plans/approved/, non-Orianna -> exit 2
PAYLOAD_INV3='{"tool_name":"Write","tool_input":{"file_path":"plans/approved/personal/new.md","content":"test"}}'
assert_exit "INV-3: Write to plans/approved/, karma -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=karma bash \"$GUARD\" <<'JSON'
${PAYLOAD_INV3}
JSON
"

# INV-4: Write file_path under plans/proposed/personal/, non-Orianna -> exit 0
PAYLOAD_INV4='{"tool_name":"Write","tool_input":{"file_path":"plans/proposed/personal/new-plan.md","content":"test"}}'
assert_exit "INV-4: Write to plans/proposed/personal/, karma -> exit 0" 0 \
  bash -c "CLAUDE_AGENT_NAME=karma bash \"$GUARD\" <<'JSON'
${PAYLOAD_INV4}
JSON
"

# INV-5: No identity env vars set, Write to protected path -> exit 2 (fail-closed)
PAYLOAD_INV5='{"tool_name":"Write","tool_input":{"file_path":"plans/in-progress/personal/plan.md","content":"test"}}'
assert_exit "INV-5: No identity env, Write to plans/in-progress/ -> exit 2 (fail-closed)" 2 \
  bash -c "unset CLAUDE_AGENT_NAME STRAWBERRY_AGENT; bash \"$GUARD\" <<'JSON'
${PAYLOAD_INV5}
JSON
"

# INV-6: Bash rm -rf plans/in-progress/foo/, non-Orianna -> exit 2
PAYLOAD_INV6='{"tool_name":"Bash","tool_input":{"command":"rm -rf plans/in-progress/foo/"}}'
assert_exit "INV-6: Bash rm -rf plans/in-progress/foo/, ekko -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_INV6}
JSON
"

# --- Senna C1-C4 bypass vectors (xfail until guard patched) ---

# C1: single-quoted path bypass — tokenizer must strip quotes before matching
PAYLOAD_C1='{"tool_name":"Bash","tool_input":{"command":"git mv plans/proposed/x.md '\''plans/approved/x.md'\''"}}'
assert_exit "C1: single-quoted dest path, ekko -> exit 2 (quote-strip required)" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_C1}
JSON
"

# C1b: double-quoted path bypass
PAYLOAD_C1B='{"tool_name":"Bash","tool_input":{"command":"git mv plans/proposed/x.md \"plans/approved/x.md\""}}'
assert_exit "C1b: double-quoted dest path, ekko -> exit 2 (quote-strip required)" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_C1B}
JSON
"

# C2: double-slash bypass — slash collapsing required
PAYLOAD_C2='{"tool_name":"Bash","tool_input":{"command":"git mv plans/proposed/x.md plans//approved/x.md"}}'
assert_exit "C2: double-slash in path, ekko -> exit 2 (slash-collapse required)" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_C2}
JSON
"

# C3: dot-dot traversal bypass — canonicalization required
PAYLOAD_C3='{"tool_name":"Bash","tool_input":{"command":"git mv plans/proposed/x.md plans/../plans/approved/x.md"}}'
assert_exit "C3: dotdot traversal in path, ekko -> exit 2 (canonicalize required)" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_C3}
JSON
"

# C4: malformed JSON must fail-closed (exit 2), not fall through
assert_exit "C4: malformed JSON input -> exit 2 (fail-closed)" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<<'NOT_JSON'"

echo ""
printf 'Results: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

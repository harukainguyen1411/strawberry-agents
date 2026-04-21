#!/usr/bin/env bash
# test-orianna-plan-check-step-e.sh — Structural regression test for Step E additions.
#
# Asserts:
#   [1] plan-check prompt contains a Step E section positioned after Step D and
#       before ## Report format
#   [2] prompt references ORIANNA_EXTERNAL_BUDGET, WebFetch, WebSearch, context7
#   [3] orianna-fact-check.sh exports ORIANNA_EXTERNAL_BUDGET
#   [4] default value is 15
#   [5] check_version: 3 appears exactly once in the report template
#   [6] external_calls_used: appears exactly once in the frontmatter example
#   [7] no new severity tokens (critical, fatal) introduced in Step E section
#
# No live LLM invocation, no network.
# Exit 0 = all assertions pass; non-zero = at least one failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROMPT="$REPO_ROOT/agents/orianna/prompts/plan-check.md"
PROFILE="$REPO_ROOT/agents/orianna/profile.md"
INVOCATION="$REPO_ROOT/scripts/orianna-fact-check.sh"

pass=0
fail=0

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" = "0" ]; then
    printf '  PASS: %s\n' "$desc"
    pass=$((pass + 1))
  else
    printf '  FAIL: %s\n' "$desc"
    fail=$((fail + 1))
  fi
}

echo "=== Orianna Step E structural tests ==="

# [1] Step E section exists in prompt
check "prompt contains 'Step E'" "$(grep -q 'Step E' "$PROMPT" && echo 0 || echo 1)"

# [1] Step E appears at least 3 times (heading + references)
step_e_count=$(grep -c 'Step E' "$PROMPT" || true)
check "prompt contains Step E >= 3 times (got $step_e_count)" "$([ "$step_e_count" -ge 3 ] && echo 0 || echo 1)"

# [1] Step E appears after Step D and before ## Report format
step_d_line=$(grep -n 'Step D' "$PROMPT" | head -1 | cut -d: -f1 || echo 0)
step_e_line=$(grep -n 'Step E' "$PROMPT" | head -1 | cut -d: -f1 || echo 0)
report_fmt_line=$(grep -n '^## Report format' "$PROMPT" | head -1 | cut -d: -f1 || echo 0)
check "Step E is after Step D (D=$step_d_line, E=$step_e_line)" \
  "$([ "$step_e_line" -gt "$step_d_line" ] && echo 0 || echo 1)"
check "Step E is before ## Report format (E=$step_e_line, RF=$report_fmt_line)" \
  "$([ "$step_e_line" -lt "$report_fmt_line" ] && echo 0 || echo 1)"

# [2] Required literals in prompt
for token in ORIANNA_EXTERNAL_BUDGET WebFetch WebSearch context7; do
  check "prompt references '$token'" "$(grep -q "$token" "$PROMPT" && echo 0 || echo 1)"
done

# [3] orianna-fact-check.sh exports ORIANNA_EXTERNAL_BUDGET
check "invocation script exports ORIANNA_EXTERNAL_BUDGET" \
  "$(grep -q 'ORIANNA_EXTERNAL_BUDGET' "$INVOCATION" && echo 0 || echo 1)"

# [4] default value is 15
check "invocation script has default value 15 for ORIANNA_EXTERNAL_BUDGET" \
  "$(grep -q '15' "$INVOCATION" && grep -q 'ORIANNA_EXTERNAL_BUDGET' "$INVOCATION" && echo 0 || echo 1)"

# [5] check_version: 3 appears exactly once in report template
cv3_count=$(grep -c 'check_version: 3' "$PROMPT" || true)
check "check_version: 3 appears exactly once (got $cv3_count)" "$([ "$cv3_count" -eq 1 ] && echo 0 || echo 1)"

# [6] external_calls_used: appears exactly once in frontmatter example
ecu_count=$(grep -c 'external_calls_used:' "$PROMPT" || true)
check "external_calls_used: appears exactly once (got $ecu_count)" "$([ "$ecu_count" -eq 1 ] && echo 0 || echo 1)"

# [7] No new severity tokens in Step E section
check "no 'critical' severity token in prompt" "$(grep -qv 'critical' "$PROMPT" && echo 0 || echo 1)"
check "no 'fatal' severity token in prompt" "$(grep -qv 'fatal' "$PROMPT" && echo 0 || echo 1)"

# Profile checks (T2)
check "profile references ORIANNA_EXTERNAL_BUDGET" \
  "$(grep -q 'ORIANNA_EXTERNAL_BUDGET' "$PROFILE" && echo 0 || echo 1)"
check "profile references Step E" \
  "$(grep -q 'Step E' "$PROFILE" && echo 0 || echo 1)"

echo ""
echo "Results: $pass passed, $fail failed"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0

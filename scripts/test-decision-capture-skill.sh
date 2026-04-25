#!/usr/bin/env bash
# xfail: tests for decision-capture skill shape per §5.1.
#
# Refs: plans/approved/personal/2026-04-21-coordinator-decision-feedback.md T5
# xfail: all assertions below are expected to fail until the skill file is
# created in T6. DECISION_TEST_MODE=1 per OQ-T1.
#
# Usage: bash scripts/test-decision-capture-skill.sh
# Exit 0 always in xfail state.

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_FILE="$REPO_ROOT/.claude/skills/decision-capture/SKILL.md"
export DECISION_TEST_MODE=1

PASS=0
FAIL=0
XFAIL_COUNT=0

xfail_assert() {
  local name="$1"
  local result="$2"
  if [ "$result" = "ok" ]; then
    echo "XFAIL $name — unexpectedly PASSED (impl landed?)"
    PASS=$((PASS+1))
  else
    echo "XFAIL $name"
    XFAIL_COUNT=$((XFAIL_COUNT+1))
  fi
}

# ── Guard: skill file missing ─────────────────────────────────────────────────
if [ ! -f "$SKILL_FILE" ]; then
  echo "XFAIL (expected — missing: .claude/skills/decision-capture/SKILL.md)"
  echo ""
  echo "XFAIL T5-skill-file-exists"
  echo "XFAIL T5-skill-disable-model-invocation"
  echo "XFAIL T5-skill-references-capture-script"
  echo "XFAIL T5-skill-coordinator-arg"
  echo "XFAIL T5-skill-stdin-pipe-documented"
  echo ""
  echo "Total: 0 pass, 0 fail, 5 xfail"
  exit 0
fi

# T5-skill-file-exists
xfail_assert "T5-skill-file-exists" "ok"

# T5-skill-disable-model-invocation: skill must have disable-model-invocation: true
if grep -q "disable-model-invocation: true" "$SKILL_FILE"; then
  xfail_assert "T5-skill-disable-model-invocation" "ok"
else
  xfail_assert "T5-skill-disable-model-invocation" "fail"
fi

# T5-skill-references-capture-script: skill references scripts/capture-decision.sh
if grep -q "capture-decision.sh" "$SKILL_FILE"; then
  xfail_assert "T5-skill-references-capture-script" "ok"
else
  xfail_assert "T5-skill-references-capture-script" "fail"
fi

# T5-skill-coordinator-arg: skill documents coordinator-name argument
if grep -q "coordinator" "$SKILL_FILE"; then
  xfail_assert "T5-skill-coordinator-arg" "ok"
else
  xfail_assert "T5-skill-coordinator-arg" "fail"
fi

# T5-skill-stdin-pipe-documented: skill documents stdin usage for the prepared
# decision markdown body (per §5.1 "reads stdin for the prepared decision markdown")
if grep -q "stdin" "$SKILL_FILE"; then
  xfail_assert "T5-skill-stdin-pipe-documented" "ok"
else
  xfail_assert "T5-skill-stdin-pipe-documented" "fail"
fi

echo ""
echo "Total: $PASS pass, $FAIL fail, $XFAIL_COUNT xfail"
exit 0

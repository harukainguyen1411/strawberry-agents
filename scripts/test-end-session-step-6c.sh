#!/usr/bin/env bash
# xfail: tests for /end-session Step 6c integration shape per §5.2.
#
# Refs: plans/approved/personal/2026-04-21-coordinator-decision-feedback.md T5
# xfail: all assertions below are expected to fail until Step 6c is added to
# .claude/skills/end-session/SKILL.md in T6. DECISION_TEST_MODE=1 per OQ-T1.
#
# Guards the ordering invariant: Step 6c MUST appear AFTER Step 6b and
# BEFORE Step 9 in the end-session skill file.
#
# Usage: bash scripts/test-end-session-step-6c.sh
# Exit 0 always in xfail state.

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_FILE="$REPO_ROOT/.claude/skills/end-session/SKILL.md"
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
  echo "XFAIL (expected — missing: .claude/skills/end-session/SKILL.md)"
  echo ""
  echo "XFAIL T5-end-session-step-6c-exists"
  echo "XFAIL T5-end-session-6c-after-6b"
  echo "XFAIL T5-end-session-6c-before-step-9"
  echo "XFAIL T5-end-session-6c-decisions-only-flag"
  echo "XFAIL T5-end-session-6c-stages-index-and-prefs"
  echo "XFAIL T5-end-session-not-eager-loading-log-dir"
  echo ""
  echo "Total: 0 pass, 0 fail, 6 xfail"
  exit 0
fi

# Check if Step 6c is present at all
if ! grep -q "6c\|Step 6c\|decisions-only" "$SKILL_FILE"; then
  echo "XFAIL (expected — Step 6c not yet added to end-session/SKILL.md)"
  echo ""
  echo "XFAIL T5-end-session-step-6c-exists"
  echo "XFAIL T5-end-session-6c-after-6b"
  echo "XFAIL T5-end-session-6c-before-step-9"
  echo "XFAIL T5-end-session-6c-decisions-only-flag"
  echo "XFAIL T5-end-session-6c-stages-index-and-prefs"
  echo "XFAIL T5-end-session-not-eager-loading-log-dir"
  echo ""
  echo "Total: 0 pass, 0 fail, 6 xfail"
  exit 0
fi

# T5-end-session-step-6c-exists
xfail_assert "T5-end-session-step-6c-exists" "ok"

# T5-end-session-6c-after-6b: Step 6c must appear on a line number AFTER Step 6b
step_6b_line="$(grep -n "6b\|Step 6b" "$SKILL_FILE" | head -1 | cut -d: -f1)"
step_6c_line="$(grep -n "6c\|Step 6c" "$SKILL_FILE" | head -1 | cut -d: -f1)"
if [ -n "$step_6b_line" ] && [ -n "$step_6c_line" ] && [ "$step_6c_line" -gt "$step_6b_line" ]; then
  xfail_assert "T5-end-session-6c-after-6b" "ok"
else
  xfail_assert "T5-end-session-6c-after-6b" "fail"
fi

# T5-end-session-6c-before-step-9: Step 6c must appear BEFORE Step 9
step_9_line="$(grep -n "^## Step 9\|^### Step 9\|Step 9 " "$SKILL_FILE" | head -1 | cut -d: -f1)"
if [ -n "$step_9_line" ] && [ -n "$step_6c_line" ] && [ "$step_6c_line" -lt "$step_9_line" ]; then
  xfail_assert "T5-end-session-6c-before-step-9" "ok"
else
  xfail_assert "T5-end-session-6c-before-step-9" "fail"
fi

# T5-end-session-6c-decisions-only-flag: Step 6c invokes memory-consolidate.sh
# with --decisions-only flag per §5.2 item 1
if grep -q "decisions-only" "$SKILL_FILE"; then
  xfail_assert "T5-end-session-6c-decisions-only-flag" "ok"
else
  xfail_assert "T5-end-session-6c-decisions-only-flag" "fail"
fi

# T5-end-session-6c-stages-index-and-prefs: Step 6c stages both INDEX.md and
# preferences.md (per §5.2 item 2)
if grep -q "decisions/INDEX.md" "$SKILL_FILE" && grep -q "decisions/preferences.md" "$SKILL_FILE"; then
  xfail_assert "T5-end-session-6c-stages-index-and-prefs" "ok"
else
  xfail_assert "T5-end-session-6c-stages-index-and-prefs" "fail"
fi

# T5-end-session-not-eager-loading-log-dir: the skill must NOT reference
# decisions/log/ in any eager-boot chain context (lazy-load boundary per §7.4)
# We check that decisions/log/ does not appear in a "Read:" or "Load:" context
if ! grep -q "Read.*decisions/log\|Load.*decisions/log" "$SKILL_FILE"; then
  xfail_assert "T5-end-session-not-eager-loading-log-dir" "ok"
else
  xfail_assert "T5-end-session-not-eager-loading-log-dir" "fail"
fi

echo ""
echo "Total: $PASS pass, $FAIL fail, $XFAIL_COUNT xfail"
exit 0

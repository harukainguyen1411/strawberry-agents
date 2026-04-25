#!/usr/bin/env bash
# xfail: tests for scripts/_lib_decision_capture.sh — frontmatter validation,
# slug inference, and match computation.
#
# Refs: plans/approved/personal/2026-04-21-coordinator-decision-feedback.md T1
# xfail: all assertions below are expected to fail until _lib_decision_capture.sh
# is implemented (T2). DECISION_TEST_MODE=1 suppresses the validator's
# production-path env-override hooks in T2's implementation per OQ-T1 resolution.
#
# Usage: bash scripts/test-decision-capture-lib.sh
# Exit 0 always in xfail state (assertions print XFAIL, not FAIL).

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="$REPO_ROOT/scripts/_lib_decision_capture.sh"
FIXTURE_DIR="$REPO_ROOT/scripts/__tests__/fixtures/decisions"
export DECISION_TEST_MODE=1

PASS=0
FAIL=0
XFAIL_COUNT=0

xfail_assert() {
  local name="$1"
  local result="$2"   # "ok" or "fail"
  if [ "$result" = "ok" ]; then
    echo "XFAIL $name — unexpectedly PASSED (impl landed?)"
    PASS=$((PASS+1))
  else
    echo "XFAIL $name"
    XFAIL_COUNT=$((XFAIL_COUNT+1))
  fi
}

lib_available() {
  [ -f "$LIB" ] && return 0 || return 1
}

# ── Guard: if lib not present, all tests are xfail ───────────────────────────
if ! lib_available; then
  echo "XFAIL (expected — missing: scripts/_lib_decision_capture.sh)"
  echo ""
  echo "XFAIL T1-validate-required-keys-pass"
  echo "XFAIL T1-validate-missing-decision-id"
  echo "XFAIL T1-validate-missing-coordinator-pick"
  echo "XFAIL T1-validate-missing-coordinator-confidence"
  echo "XFAIL T1-validate-missing-axes"
  echo "XFAIL T1-validate-malformed-axes-not-list"
  echo "XFAIL T1-validate-invalid-confidence-enum"
  echo "XFAIL T1-validate-mutually-exclusive-flags"
  echo "XFAIL T1-infer-slug-basic"
  echo "XFAIL T1-infer-slug-collision-suffix"
  echo "XFAIL T1-infer-slug-truncation"
  echo "XFAIL T1-compute-match-same-pick"
  echo "XFAIL T1-compute-match-different-pick"
  echo "XFAIL T1-compute-match-concurred-silently"
  echo "XFAIL T1-compute-match-autodecide-never-match"
  echo ""
  echo "Total: 0 pass, 0 fail, 15 xfail"
  exit 0
fi

# ── Source lib (only if present) ─────────────────────────────────────────────
# shellcheck source=/dev/null
. "$LIB"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Helper: write a minimal valid decision file
write_valid_decision() {
  local path="$1"
  cat > "$path" <<'YAML'
---
decision_id: 2026-04-21-test-decision
date: 2026-04-21
session_short_uuid: abcdef01
coordinator: evelynn
axes: [scope-vs-debt]
question: "Test question?"
options:
  - letter: a
    description: "Option a"
coordinator_pick: a
coordinator_confidence: medium
coordinator_rationale: "Test."
duong_pick: a
duong_concurred_silently: false
coordinator_autodecided: false
match: true
decision_source: /end-session-shard-abcdef01
---

## Context
Test context.

## Why this matters
Test mattering.
YAML
}

# ── Validation tests ──────────────────────────────────────────────────────────

# T1-validate-required-keys-pass: a valid file passes validate_decision_frontmatter
f="$TMPDIR_TEST/valid.md"
write_valid_decision "$f"
if validate_decision_frontmatter "$f" 2>/dev/null; then
  xfail_assert "T1-validate-required-keys-pass" "ok"
else
  xfail_assert "T1-validate-required-keys-pass" "fail"
fi

# T1-validate-missing-decision-id: file without decision_id is rejected
f="$TMPDIR_TEST/missing-id.md"
write_valid_decision "$f"
# Remove decision_id line
sed -i.bak '/^decision_id:/d' "$f"
if ! validate_decision_frontmatter "$f" 2>/dev/null; then
  xfail_assert "T1-validate-missing-decision-id" "ok"
else
  xfail_assert "T1-validate-missing-decision-id" "fail"
fi

# T1-validate-missing-coordinator-pick: file without coordinator_pick is rejected
f="$TMPDIR_TEST/missing-coord-pick.md"
write_valid_decision "$f"
sed -i.bak '/^coordinator_pick:/d' "$f"
if ! validate_decision_frontmatter "$f" 2>/dev/null; then
  xfail_assert "T1-validate-missing-coordinator-pick" "ok"
else
  xfail_assert "T1-validate-missing-coordinator-pick" "fail"
fi

# T1-validate-missing-coordinator-confidence: file without coordinator_confidence rejected
f="$TMPDIR_TEST/missing-coord-conf.md"
write_valid_decision "$f"
sed -i.bak '/^coordinator_confidence:/d' "$f"
if ! validate_decision_frontmatter "$f" 2>/dev/null; then
  xfail_assert "T1-validate-missing-coordinator-confidence" "ok"
else
  xfail_assert "T1-validate-missing-coordinator-confidence" "fail"
fi

# T1-validate-missing-axes: file without axes is rejected
f="$TMPDIR_TEST/missing-axes.md"
write_valid_decision "$f"
sed -i.bak '/^axes:/d' "$f"
if ! validate_decision_frontmatter "$f" 2>/dev/null; then
  xfail_assert "T1-validate-missing-axes" "ok"
else
  xfail_assert "T1-validate-missing-axes" "fail"
fi

# T1-validate-malformed-axes-not-list: axes as scalar (not YAML list) is rejected
f="$TMPDIR_TEST/malformed-axes.md"
write_valid_decision "$f"
sed -i.bak 's/^axes: \[scope-vs-debt\]/axes: scope-vs-debt/' "$f"
if ! validate_decision_frontmatter "$f" 2>/dev/null; then
  xfail_assert "T1-validate-malformed-axes-not-list" "ok"
else
  xfail_assert "T1-validate-malformed-axes-not-list" "fail"
fi

# T1-validate-invalid-confidence-enum: coordinator_confidence: very-high rejected with §3.5 cite
f="$TMPDIR_TEST/bad-enum.md"
write_valid_decision "$f"
sed -i.bak 's/^coordinator_confidence: medium/coordinator_confidence: very-high/' "$f"
err_out="$(validate_decision_frontmatter "$f" 2>&1 || true)"
if echo "$err_out" | grep -q "very-high" && ! validate_decision_frontmatter "$f" 2>/dev/null; then
  xfail_assert "T1-validate-invalid-confidence-enum" "ok"
else
  xfail_assert "T1-validate-invalid-confidence-enum" "fail"
fi

# T1-validate-mutually-exclusive-flags: duong_concurred_silently:true AND
# coordinator_autodecided:true in same file is rejected
f="$TMPDIR_TEST/mutually-exclusive.md"
write_valid_decision "$f"
sed -i.bak 's/^duong_concurred_silently: false/duong_concurred_silently: true/' "$f"
sed -i.bak 's/^coordinator_autodecided: false/coordinator_autodecided: true/' "$f"
if ! validate_decision_frontmatter "$f" 2>/dev/null; then
  xfail_assert "T1-validate-mutually-exclusive-flags" "ok"
else
  xfail_assert "T1-validate-mutually-exclusive-flags" "fail"
fi

# ── Slug inference tests ──────────────────────────────────────────────────────

# T1-infer-slug-basic: a simple question produces a normalised kebab slug
LOG_DIR="$TMPDIR_TEST/log"
mkdir -p "$LOG_DIR"
slug="$(infer_slug "Portfolio v0 scope: CSV handler stub" "$LOG_DIR" 2>/dev/null || echo "")"
expected="portfolio-v0-scope-csv-handler-stub"
# Accept prefix match (truncation may differ) or exact match
if echo "$slug" | grep -q "^portfolio-v0-scope"; then
  xfail_assert "T1-infer-slug-basic" "ok"
else
  xfail_assert "T1-infer-slug-basic" "fail"
fi

# T1-infer-slug-collision-suffix: when a slug already exists, suffix -2 is added
touch "$LOG_DIR/2026-04-21-portfolio-v0-scope-csv-handler-stub.md"
slug2="$(infer_slug "Portfolio v0 scope: CSV handler stub" "$LOG_DIR" 2>/dev/null || echo "")"
if echo "$slug2" | grep -q "\-2$"; then
  xfail_assert "T1-infer-slug-collision-suffix" "ok"
else
  xfail_assert "T1-infer-slug-collision-suffix" "fail"
fi

# T1-infer-slug-truncation: a question > 40 chars produces a slug truncated at 40 chars
long_question="This is a very long question that exceeds forty characters for slug truncation testing"
slug3="$(infer_slug "$long_question" "$LOG_DIR" 2>/dev/null || echo "")"
if [ "${#slug3}" -le 40 ]; then
  xfail_assert "T1-infer-slug-truncation" "ok"
else
  xfail_assert "T1-infer-slug-truncation" "fail"
fi

# ── Match computation tests ───────────────────────────────────────────────────

# T1-compute-match-same-pick: same picks → true
result="$(compute_match "a" "a" "false" 2>/dev/null || echo "")"
if [ "$result" = "true" ]; then
  xfail_assert "T1-compute-match-same-pick" "ok"
else
  xfail_assert "T1-compute-match-same-pick" "fail"
fi

# T1-compute-match-different-pick: different picks → false
result="$(compute_match "a" "b" "false" 2>/dev/null || echo "")"
if [ "$result" = "false" ]; then
  xfail_assert "T1-compute-match-different-pick" "ok"
else
  xfail_assert "T1-compute-match-different-pick" "fail"
fi

# T1-compute-match-concurred-silently: duong_concurred_silently=true → true regardless of picks
result="$(compute_match "a" "b" "true" 2>/dev/null || echo "")"
if [ "$result" = "true" ]; then
  xfail_assert "T1-compute-match-concurred-silently" "ok"
else
  xfail_assert "T1-compute-match-concurred-silently" "fail"
fi

# T1-compute-match-autodecide-never-match: hands-off-autodecide is not counted as
# a regular match (it is excluded from explicit-pick match-rate computation)
result="$(compute_match "a" "hands-off-autodecide" "false" 2>/dev/null || echo "")"
if [ "$result" = "hands-off" ]; then
  xfail_assert "T1-compute-match-autodecide-never-match" "ok"
else
  xfail_assert "T1-compute-match-autodecide-never-match" "fail"
fi

echo ""
echo "Total: $PASS pass, $FAIL fail, $XFAIL_COUNT xfail"
exit 0

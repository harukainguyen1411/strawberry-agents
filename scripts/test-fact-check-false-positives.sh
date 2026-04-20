#!/usr/bin/env bash
# Regression test — fact-check-plan.sh false-positive fixes
#
# Guards against three false-positive classes fixed in 2026-04-20:
#   FP1: inline backtick spans with whitespace (e.g. `scripts/foo.sh exists`)
#   FP2: path:line-number tokens (e.g. `scripts/plan-promote.sh:63-86`)
#   FP3: date templates with XX placeholder (e.g. `assessments/2026-04-XX-foo.md`)
#
# Also asserts that REAL stale-path claims (non-existent paths without any of the
# above patterns) still produce block findings.
#
# Run: bash scripts/test-fact-check-false-positives.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FACT_CHECK="$SCRIPT_DIR/fact-check-plan.sh"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

[ -f "$FACT_CHECK" ] || { printf 'SKIP  fact-check-plan.sh not found\n'; exit 0; }

# Plans are placed in a temp dir but fact-check-plan.sh resolves REPO_ROOT from its own
# script location and writes reports to REPO_ROOT/assessments/plan-fact-checks/.
SCRATCH="$(mktemp -d)"
REPORT_DIR="$REPO_ROOT/assessments/plan-fact-checks"
mkdir -p "$REPORT_DIR"

# Helper: write a plan with given body, run fact-check, return block count.
# Reports land in REPO_ROOT/assessments/plan-fact-checks/ (fact-check-plan.sh's
# own repo root), so we search there by the plan basename timestamp.
run_check() {
  local label="$1"
  local body="$2"
  local slug="fptest-${label}-$$"
  local plan_path="$SCRATCH/${slug}.md"
  printf '%s\n' "$body" > "$plan_path"
  local rc=0
  bash "$FACT_CHECK" "$plan_path" >/dev/null 2>&1 || rc=$?
  # Report written to REPO_ROOT/assessments/plan-fact-checks/<slug>-<timestamp>.md
  local report
  report="$(ls -t "$REPORT_DIR/${slug}-"*.md 2>/dev/null | head -1)"
  local blocks=0
  if [ -f "$report" ]; then
    blocks="$(awk '/^block_findings:/{print $2}' "$report" || echo 0)"
    rm -f "$report"
  fi
  rm -f "$plan_path"
  printf '%s' "$blocks"
}

# --- FP1: whitespace-in-backtick span should NOT be a block finding ---
# The token `scripts/nonexistent-for-fp1-test.sh exists` contains a space
# so the whole span should be skipped (not checked as a path).
FP1_BODY='---
title: FP1 Test
status: proposed
owner: test
created: 2026-04-20
tags: [test]
---

Plans should not claim `scripts/nonexistent-for-fp1-test.sh exists` without anchoring.
'
blocks="$(run_check FP1 "$FP1_BODY")"
if [ "$blocks" -eq 0 ]; then
  pass "FP1_WHITESPACE_BACKTICK_NO_BLOCK"
else
  fail "FP1_WHITESPACE_BACKTICK_NO_BLOCK" "expected 0 blocks, got $blocks (false positive)"
fi

# --- FP2: path:line-number token — after stripping :NN the base file exists ---
# scripts/fact-check-plan.sh definitely exists in this repo, so
# `scripts/fact-check-plan.sh:42-50` should not block after stripping the suffix.
FP2_BODY='---
title: FP2 Test
status: proposed
owner: test
created: 2026-04-20
tags: [test]
---

See `scripts/fact-check-plan.sh:42-50` for the token extraction logic.
'
blocks="$(run_check FP2 "$FP2_BODY")"
if [ "$blocks" -eq 0 ]; then
  pass "FP2_LINE_SUFFIX_STRIPPED"
else
  fail "FP2_LINE_SUFFIX_STRIPPED" "expected 0 blocks, got $blocks (false positive on :line suffix)"
fi

# --- FP3: XX date-template token should NOT produce a block finding ---
FP3_BODY='---
title: FP3 Test
status: proposed
owner: test
created: 2026-04-20
tags: [test]
---

Report will be written to `assessments/2026-04-XX-orianna-gate-smoke.md`.
'
blocks="$(run_check FP3 "$FP3_BODY")"
if [ "$blocks" -eq 0 ]; then
  pass "FP3_XX_DATE_TEMPLATE_NO_BLOCK"
else
  fail "FP3_XX_DATE_TEMPLATE_NO_BLOCK" "expected 0 blocks, got $blocks (false positive on XX template)"
fi

# --- REAL: a plain non-existent path in a backtick SHOULD still block ---
REAL_BODY='---
title: Real Test
status: proposed
owner: test
created: 2026-04-20
tags: [test]
---

This plan depends on `scripts/nonexistent-real-claim-xzqq.sh` being present.
'
blocks="$(run_check REAL "$REAL_BODY")"
if [ "$blocks" -ge 1 ]; then
  pass "REAL_STALE_PATH_STILL_BLOCKS"
else
  fail "REAL_STALE_PATH_STILL_BLOCKS" "expected >=1 block, got 0 (gate weakened)"
fi

rm -rf "$SCRATCH"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

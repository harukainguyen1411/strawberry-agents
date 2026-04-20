#!/bin/sh
# T5.6 — xfail tests for sibling-file grep logic in scripts/_lib_orianna_gate_inprogress.sh
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §T5.6
# Run: bash scripts/test-orianna-sibling-grep.sh
# 2 cases:
#   1. fixture plan with <basename>-tasks.md sibling present → approved gate blocks
#   2. sibling deleted → gate passes
# All cases xfail until T4.1 (_lib_orianna_gate_inprogress.sh check_sibling_absent) is implemented.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="$SCRIPT_DIR/_lib_orianna_gate_inprogress.sh"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (expected: %s, got rc=%d)\n' "$1" "$2" "$3"; FAIL=$((FAIL + 1)); }

# --- XFAIL guard ---
if [ ! -f "$LIB" ]; then
  printf 'XFAIL  _lib_orianna_gate_inprogress.sh not present — all 2 cases xfail (T4.1 not yet implemented)\n'
  printf 'XFAIL  SIBLING_PRESENT_BLOCK\n'
  printf 'XFAIL  SIBLING_DELETED_PASS\n'
  printf '\nResults: 0 passed, 2 xfail (expected — implementation not present)\n'
  exit 0
fi

. "$LIB"

# check_sibling_absent <plan_file> <plans_root>
# returns 0 when no <basename>-tasks.md or <basename>-tests.md sibling exists
# returns non-zero when a sibling is found

make_plans_dir() {
  d="$(mktemp -d)"
  mkdir -p "$d/proposed"
  printf '%s' "$d"
}

PLANS_DIR="$(make_plans_dir)"
PLAN_SLUG="2026-04-20-feature-plan"
PLAN_FILE="$PLANS_DIR/proposed/${PLAN_SLUG}.md"
cat > "$PLAN_FILE" << 'PLANEOF'
---
title: Feature Plan
status: proposed
---

# Body

Content.
PLANEOF

# --- CASE 1: Sibling tasks file present → block ---
SIBLING="$PLANS_DIR/proposed/${PLAN_SLUG}-tasks.md"
printf '# Tasks\n\n- [ ] T1\n' > "$SIBLING"

rc=0; check_sibling_absent "$PLAN_FILE" "$PLANS_DIR" 2>/dev/null || rc=$?
if [ "$rc" -ne 0 ]; then
  pass "SIBLING_PRESENT_BLOCK"
else
  fail "SIBLING_PRESENT_BLOCK" "non-zero" 0
fi

# --- CASE 2: Sibling deleted → pass ---
rm -f "$SIBLING"

rc=0; check_sibling_absent "$PLAN_FILE" "$PLANS_DIR" 2>/dev/null || rc=$?
if [ "$rc" -eq 0 ]; then
  pass "SIBLING_DELETED_PASS"
else
  fail "SIBLING_DELETED_PASS" "exit 0" "$rc"
fi

rm -rf "$PLANS_DIR"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

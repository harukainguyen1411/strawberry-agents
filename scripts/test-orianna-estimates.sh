#!/bin/sh
# T5.4 — xfail tests for scripts/_lib_orianna_estimates.sh
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §T5.4
# Run: bash scripts/test-orianna-estimates.sh
# 7 cases: missing field, zero, negative, 61 (above max), hours literal,
#          (d) literal, clean pass.
# All cases xfail until T4.3 (_lib_orianna_estimates.sh) is implemented.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="$SCRIPT_DIR/_lib_orianna_estimates.sh"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (expected: %s, got rc=%d)\n' "$1" "$2" "$3"; FAIL=$((FAIL + 1)); }

# --- XFAIL guard ---
if [ ! -f "$LIB" ]; then
  printf 'XFAIL  _lib_orianna_estimates.sh not present — all 7 cases xfail (T4.3 not yet implemented)\n'
  for c in MISSING_FIELD ZERO_VALUE NEGATIVE_VALUE ABOVE_MAX HOURS_LITERAL D_LITERAL CLEAN_PASS; do
    printf 'XFAIL  %s\n' "$c"
  done
  printf '\nResults: 0 passed, 7 xfail (expected — implementation not present)\n'
  exit 0
fi

# Source the lib so we can call check_estimate_minutes directly
# The lib must export a check_estimate_minutes <plan_file> function
# returning 0 on pass, non-zero (with stderr) on any violation.
. "$LIB"

# --- Fixture helper ---
make_plan_with_tasks() {
  tasks_body="$1"
  f="$(mktemp)"
  printf '---\ntitle: test\nstatus: proposed\n---\n\n# Body\n\n## Tasks\n\n%s\n' "$tasks_body" > "$f"
  printf '%s' "$f"
}

# --- CASE 1: Missing estimate_minutes field entirely → block ---
F="$(make_plan_with_tasks '- [ ] **T1. Do something.** `kind: impl`
  - files: `src/foo.sh`')"
rc=0; check_estimate_minutes "$F" 2>/dev/null || rc=$?
if [ "$rc" -ne 0 ]; then pass "MISSING_FIELD"; else fail "MISSING_FIELD" "non-zero" 0; fi
rm -f "$F"

# --- CASE 2: Zero value → block ---
F="$(make_plan_with_tasks '- [ ] **T1. Do something.** `kind: impl` | `estimate_minutes: 0`
  - files: `src/foo.sh`')"
rc=0; check_estimate_minutes "$F" 2>/dev/null || rc=$?
if [ "$rc" -ne 0 ]; then pass "ZERO_VALUE"; else fail "ZERO_VALUE" "non-zero" 0; fi
rm -f "$F"

# --- CASE 3: Negative value → block ---
F="$(make_plan_with_tasks '- [ ] **T1. Do something.** `kind: impl` | `estimate_minutes: -5`
  - files: `src/foo.sh`')"
rc=0; check_estimate_minutes "$F" 2>/dev/null || rc=$?
if [ "$rc" -ne 0 ]; then pass "NEGATIVE_VALUE"; else fail "NEGATIVE_VALUE" "non-zero" 0; fi
rm -f "$F"

# --- CASE 4: Above max (61) → block ---
F="$(make_plan_with_tasks '- [ ] **T1. Do something.** `kind: impl` | `estimate_minutes: 61`
  - files: `src/foo.sh`')"
rc=0; check_estimate_minutes "$F" 2>/dev/null || rc=$?
if [ "$rc" -ne 0 ]; then pass "ABOVE_MAX"; else fail "ABOVE_MAX" "non-zero" 0; fi
rm -f "$F"

# --- CASE 5: "hours" literal in Tasks section → block ---
F="$(make_plan_with_tasks '- [ ] **T1. Do something.** `kind: impl` | `estimate_minutes: 30`
  - detail: takes about 2 hours to complete')"
rc=0; check_estimate_minutes "$F" 2>/dev/null || rc=$?
if [ "$rc" -ne 0 ]; then pass "HOURS_LITERAL"; else fail "HOURS_LITERAL" "non-zero" 0; fi
rm -f "$F"

# --- CASE 6: "(d)" literal in Tasks section → block ---
F="$(make_plan_with_tasks '- [ ] **T1. Do something.** `kind: impl` | `estimate_minutes: 30`
  - detail: roughly 1(d) of work')"
rc=0; check_estimate_minutes "$F" 2>/dev/null || rc=$?
if [ "$rc" -ne 0 ]; then pass "D_LITERAL"; else fail "D_LITERAL" "non-zero" 0; fi
rm -f "$F"

# --- CASE 7: Clean conforming task list → pass (exit 0) ---
F="$(make_plan_with_tasks '- [ ] **T1. Write tests.** `kind: test` | `estimate_minutes: 25`
  - files: `scripts/test-foo.sh`
  - detail: assert function returns Y for input Z
- [ ] **T2. Implement foo.** `kind: impl` | `estimate_minutes: 30`
  - files: `scripts/foo.sh`
  - detail: minimal implementation to pass T1')"
rc=0; check_estimate_minutes "$F" 2>/dev/null || rc=$?
if [ "$rc" -eq 0 ]; then pass "CLEAN_PASS"; else fail "CLEAN_PASS" "exit 0" "$rc"; fi
rm -f "$F"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

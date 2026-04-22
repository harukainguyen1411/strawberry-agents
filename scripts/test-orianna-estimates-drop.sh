#!/usr/bin/env bash
# xfail — TG-2/TG-3/TG-4 estimate_minutes dropped from Orianna gate
# Plan: plans/in-progress/personal/2026-04-22-orianna-substance-vs-format-rescope.md §3.2 / §5.2 / OQ-3
#
# Behavioral contract:
#   After T7 (task-gate-check.md Step B deletion), Orianna must not block
#   or warn on estimate_minutes violations. The pre-commit linter
#   (scripts/hooks/pre-commit-zz-plan-structure.sh) is the sole enforcer.
#
# Three xfail cases:
#   D1 — task missing estimate_minutes entirely  → Orianna: 0 blocks (TG-2 dropped)
#   D2 — task with estimate_minutes: 0 (invalid) → Orianna: 0 blocks (TG-3 dropped)
#   D3 — task with "hours" literal               → Orianna: 0 blocks (TG-4 dropped)
#
# xfail guard: checks for absence of the "Step B dropped" marker in
# agents/orianna/prompts/task-gate-check.md. When T7 lands, the marker
# "estimate_minutes validation is handled by the pre-commit linter" appears
# in the prompt and the guard passes.
#
# Run: bash scripts/test-orianna-estimates-drop.sh

# xfail: task-gate-check.md Step B not yet removed (T7 not implemented)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FACT_CHECK="$SCRIPT_DIR/fact-check-plan.sh"
TASK_GATE_PROMPT="$REPO_ROOT/agents/orianna/prompts/task-gate-check.md"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# --- XFAIL guard ---
# T7 is implemented when the task-gate prompt no longer validates estimate_minutes.
# Detect by looking for the drop-marker phrase that T7 must insert.
T7_IMPLEMENTED=0
if grep -q 'pre-commit linter' "$TASK_GATE_PROMPT" 2>/dev/null && \
   ! grep -q 'estimate_minutes.*\[1.*60\]' "$TASK_GATE_PROMPT" 2>/dev/null; then
  T7_IMPLEMENTED=1
fi

if [ "$T7_IMPLEMENTED" -eq 0 ]; then
  printf 'XFAIL (expected — T7 not implemented: task-gate-check.md still validates estimate_minutes)\n'
  for c in D1_MISSING_ESTIMATE D2_ZERO_ESTIMATE D3_HOURS_LITERAL; do
    printf 'XFAIL  %s\n' "$c"
  done
  printf '\nResults: 0 passed, 3 xfail (expected — T7 not yet implemented)\n'
  exit 0
fi

[ -f "$FACT_CHECK" ] || { printf 'SKIP  fact-check-plan.sh not found\n'; exit 0; }

SCRATCH="$(mktemp -d)"
REPORT_DIR="$REPO_ROOT/assessments/plan-fact-checks"
mkdir -p "$REPORT_DIR"

run_check_blocks() {
  local label="$1"
  local body="$2"
  local slug="estdrop-${label}-$$"
  local plan_path="$SCRATCH/${slug}.md"
  printf '%s\n' "$body" > "$plan_path"
  local rc=0
  bash "$FACT_CHECK" "$plan_path" >/dev/null 2>&1 || rc=$?
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

BASE_FM='---
title: %s
status: proposed
concern: personal
owner: test
created: 2026-04-22
tags: [test]
---

## Tasks

'

# --- D1: task missing estimate_minutes entirely ---
D1_BODY="$(printf "$BASE_FM" "D1 Missing Estimate")- [ ] **T1** — do something without estimate field."
blocks="$(run_check_blocks D1 "$D1_BODY")"
if [ "$blocks" -eq 0 ]; then
  pass "D1_MISSING_ESTIMATE"
else
  fail "D1_MISSING_ESTIMATE" "expected 0 blocks (TG-2 dropped from Orianna), got $blocks"
fi

# --- D2: estimate_minutes: 0 (invalid per old TG-3) ---
D2_BODY="$(printf "$BASE_FM" "D2 Zero Estimate")- [ ] **T1** — do something. estimate_minutes: 0."
blocks="$(run_check_blocks D2 "$D2_BODY")"
if [ "$blocks" -eq 0 ]; then
  pass "D2_ZERO_ESTIMATE"
else
  fail "D2_ZERO_ESTIMATE" "expected 0 blocks (TG-3 dropped from Orianna), got $blocks"
fi

# --- D3: "hours" literal in task description (invalid per old TG-4) ---
D3_BODY="$(printf "$BASE_FM" "D3 Hours Literal")- [ ] **T1** — do something. estimate_minutes: 30.
  - detail: this takes about 2 hours of focused work."
blocks="$(run_check_blocks D3 "$D3_BODY")"
if [ "$blocks" -eq 0 ]; then
  pass "D3_HOURS_LITERAL"
else
  fail "D3_HOURS_LITERAL" "expected 0 blocks (TG-4 dropped from Orianna), got $blocks"
fi

rm -rf "$SCRATCH"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

#!/usr/bin/env bash
# xfail — Step-A frontmatter checks (status/created/tags) dropped from Orianna
# Plan: plans/in-progress/personal/2026-04-22-orianna-substance-vs-format-rescope.md §5.1 / OQ-4
#
# Behavioral contract (OQ-4 resolved: b — drop entirely):
#   Duong diverged from Swain's "warn" recommendation.
#   PA-1 (status:), PA-3 (created:), PA-4 (tags:) are removed from Orianna
#   completely. The pre-commit linter is the sole authority for these fields.
#   Orianna must not emit ANY finding (not block, not warn, not info) for
#   a missing status/created/tags field.
#
# NOTE: owner: (PA-2) is explicitly NOT dropped. SC5 in the main split test
# and case SA4 here confirm PA-2 remains at block severity.
#
# Four xfail cases:
#   SA1 — status: absent  → Orianna: 0 block, 0 warn findings
#   SA2 — created: absent → Orianna: 0 block, 0 warn findings
#   SA3 — tags: absent    → Orianna: 0 block, 0 warn findings
#   SA4 — owner: absent   → Orianna: >=1 block (PA-2 preserved)
#
# xfail guard: checks for the drop marker in plan-check.md Step A.
# T6 must insert a note that status/created/tags are not checked by Orianna.
#
# Run: bash scripts/test-orianna-plan-check-step-a-drop.sh

# xfail: plan-check.md Step A not yet updated (T6 not implemented)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FACT_CHECK="$SCRIPT_DIR/fact-check-plan.sh"
PLAN_CHECK_PROMPT="$REPO_ROOT/agents/orianna/prompts/plan-check.md"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# --- XFAIL guard ---
# T6 is implemented when plan-check.md Step A no longer checks status/created/tags.
# Detect by presence of a phrase indicating these are handled by the linter only.
# The marker phrase is: "pre-commit linter" AND absence of "status: proposed" as a block check.
T6_IMPLEMENTED=0
if [ -f "$PLAN_CHECK_PROMPT" ]; then
  if grep -q 'pre-commit linter' "$PLAN_CHECK_PROMPT" 2>/dev/null && \
     ! grep -q 'status.*block\|block.*status:' "$PLAN_CHECK_PROMPT" 2>/dev/null; then
    T6_IMPLEMENTED=1
  fi
fi

if [ "$T6_IMPLEMENTED" -eq 0 ]; then
  printf 'XFAIL (expected — T6 not implemented: plan-check.md Step A still checks status/created/tags)\n'
  for c in SA1_STATUS_NO_FINDING SA2_CREATED_NO_FINDING SA3_TAGS_NO_FINDING SA4_OWNER_STILL_BLOCKS; do
    printf 'XFAIL  %s\n' "$c"
  done
  printf '\nResults: 0 passed, 4 xfail (expected — T6 not yet implemented)\n'
  exit 0
fi

[ -f "$FACT_CHECK" ] || { printf 'SKIP  fact-check-plan.sh not found\n'; exit 0; }

SCRATCH="$(mktemp -d)"
REPORT_DIR="$REPO_ROOT/assessments/plan-fact-checks"
mkdir -p "$REPORT_DIR"

run_check_report() {
  local label="$1"
  local body="$2"
  local slug="stepa-${label}-$$"
  local plan_path="$SCRATCH/${slug}.md"
  printf '%s\n' "$body" > "$plan_path"
  local rc=0
  bash "$FACT_CHECK" "$plan_path" >/dev/null 2>&1 || rc=$?
  local report
  report="$(ls -t "$REPORT_DIR/${slug}-"*.md 2>/dev/null | head -1)"
  printf '%s' "$report"
}

read_count() {
  local report="$1"
  local key="$2"
  awk "/^${key}:/{print \$2}" "$report" 2>/dev/null | head -1 || printf '0'
}

cleanup() { local r="$1"; [ -n "$r" ] && rm -f "$r"; }

# --- SA1: status: absent → 0 block, 0 warn ---
SA1_BODY='---
title: SA1 Status Absent Test
concern: personal
owner: test
created: 2026-04-22
tags: [test]
---

Plan body. The status: field is absent.
'
r="$(run_check_report SA1 "$SA1_BODY")"
if [ -f "$r" ]; then
  blocks="$(read_count "$r" block_findings)"
  warns="$(read_count "$r" warn_findings)"
  cleanup "$r"
  if [ "$blocks" -eq 0 ] && [ "$warns" -eq 0 ]; then
    pass "SA1_STATUS_NO_FINDING"
  else
    fail "SA1_STATUS_NO_FINDING" "expected 0 blocks+warns for absent status: (PA-1 dropped), got blocks=$blocks warns=$warns"
  fi
else
  fail "SA1_STATUS_NO_FINDING" "report not generated"
fi

# --- SA2: created: absent → 0 block, 0 warn ---
SA2_BODY='---
title: SA2 Created Absent Test
status: proposed
concern: personal
owner: test
tags: [test]
---

Plan body. The created: field is absent.
'
r="$(run_check_report SA2 "$SA2_BODY")"
if [ -f "$r" ]; then
  blocks="$(read_count "$r" block_findings)"
  warns="$(read_count "$r" warn_findings)"
  cleanup "$r"
  if [ "$blocks" -eq 0 ] && [ "$warns" -eq 0 ]; then
    pass "SA2_CREATED_NO_FINDING"
  else
    fail "SA2_CREATED_NO_FINDING" "expected 0 blocks+warns for absent created: (PA-3 dropped), got blocks=$blocks warns=$warns"
  fi
else
  fail "SA2_CREATED_NO_FINDING" "report not generated"
fi

# --- SA3: tags: absent → 0 block, 0 warn ---
SA3_BODY='---
title: SA3 Tags Absent Test
status: proposed
concern: personal
owner: test
created: 2026-04-22
---

Plan body. The tags: field is absent.
'
r="$(run_check_report SA3 "$SA3_BODY")"
if [ -f "$r" ]; then
  blocks="$(read_count "$r" block_findings)"
  warns="$(read_count "$r" warn_findings)"
  cleanup "$r"
  if [ "$blocks" -eq 0 ] && [ "$warns" -eq 0 ]; then
    pass "SA3_TAGS_NO_FINDING"
  else
    fail "SA3_TAGS_NO_FINDING" "expected 0 blocks+warns for absent tags: (PA-4 dropped), got blocks=$blocks warns=$warns"
  fi
else
  fail "SA3_TAGS_NO_FINDING" "report not generated"
fi

# --- SA4: owner: absent → >=1 block (PA-2 preserved) ---
# This is the negative anchor: dropping status/created/tags must NOT weaken the
# owner check. Ownership is load-bearing for accountability (PA-2 kept at block).
SA4_BODY='---
title: SA4 Owner Absent Test
status: proposed
concern: personal
created: 2026-04-22
tags: [test]
---

Plan body. The owner: field is absent.
'
r="$(run_check_report SA4 "$SA4_BODY")"
if [ -f "$r" ]; then
  blocks="$(read_count "$r" block_findings)"
  cleanup "$r"
  if [ "$blocks" -ge 1 ]; then
    pass "SA4_OWNER_STILL_BLOCKS"
  else
    fail "SA4_OWNER_STILL_BLOCKS" "expected >=1 block when owner: absent (PA-2 must stay block), got 0 (substance gate regressed)"
  fi
else
  fail "SA4_OWNER_STILL_BLOCKS" "report not generated"
fi

rm -rf "$SCRATCH"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

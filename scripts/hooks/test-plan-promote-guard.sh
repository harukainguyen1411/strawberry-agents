#!/bin/sh
# Manual test script for pre-commit-plan-promote-guard.sh
# Run: bash scripts/hooks/test-plan-promote-guard.sh
# Exits 0 if all 3 tests behave as expected.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/pre-commit-plan-promote-guard.sh"

PASS=0
FAIL=0

make_repo() {
  r=$(mktemp -d)
  git -C "$r" init -q
  git -C "$r" commit --allow-empty -q -m "init"
  mkdir -p "$r/plans/proposed" "$r/plans/approved" "$r/assessments/plan-fact-checks"
  printf 'status: proposed\n' > "$r/plans/proposed/2026-04-19-test-plan.md"
  git -C "$r" add plans/proposed/2026-04-19-test-plan.md
  git -C "$r" commit -q -m "add proposed plan"
  printf '%s' "$r"
}

run_hook() {
  repo="$1"
  msg="${2:-}"
  if [ -n "$msg" ]; then
    printf '%s\n' "$msg" > "$repo/.git/COMMIT_EDITMSG"
  fi
  GIT_DIR="$repo/.git" GIT_WORK_TREE="$repo" bash "$HOOK" 2>&1
}

# --- TEST 1: fact-check report present → PASS ---
REPO=$(make_repo)
git -C "$REPO" mv plans/proposed/2026-04-19-test-plan.md plans/approved/2026-04-19-test-plan.md
printf '# fact check report\n' > "$REPO/assessments/plan-fact-checks/2026-04-19-test-plan-2026-04-19T10-00-00Z.md"
git -C "$REPO" add assessments/

output1=$(run_hook "$REPO" 2>&1); rc1=$?
if [ "$rc1" -eq 0 ]; then
  printf 'TEST 1 PASS (fact-check report present): hook exited 0\n'
  PASS=$((PASS+1))
else
  printf 'TEST 1 FAIL: expected exit 0, got %d\n' "$rc1"
  printf '%s\n' "$output1"
  FAIL=$((FAIL+1))
fi
rm -rf "$REPO"

# --- TEST 2: raw git mv, no report, no trailer → BLOCK ---
REPO=$(make_repo)
git -C "$REPO" mv plans/proposed/2026-04-19-test-plan.md plans/approved/2026-04-19-test-plan.md

output2=$(run_hook "$REPO" 2>&1); rc2=$?
if [ "$rc2" -ne 0 ]; then
  printf 'TEST 2 PASS (no report, no trailer → blocked): hook exited %d\n' "$rc2"
  printf '%s\n' "$output2"
  PASS=$((PASS+1))
else
  printf 'TEST 2 FAIL: expected non-zero exit, got 0\n'
  FAIL=$((FAIL+1))
fi
rm -rf "$REPO"

# --- TEST 3: raw git mv, no report, WITH bypass trailer → ALLOW with warning ---
REPO=$(make_repo)
git -C "$REPO" mv plans/proposed/2026-04-19-test-plan.md plans/approved/2026-04-19-test-plan.md
BYPASS_MSG="chore: promote test plan

Orianna-Bypass: testing the escape hatch"

output3=$(run_hook "$REPO" "$BYPASS_MSG" 2>&1); rc3=$?
if [ "$rc3" -eq 0 ]; then
  printf 'TEST 3 PASS (bypass trailer → allowed with warning): hook exited 0\n'
  printf '%s\n' "$output3"
  PASS=$((PASS+1))
else
  printf 'TEST 3 FAIL: expected exit 0, got %d\n' "$rc3"
  printf '%s\n' "$output3"
  FAIL=$((FAIL+1))
fi
rm -rf "$REPO"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

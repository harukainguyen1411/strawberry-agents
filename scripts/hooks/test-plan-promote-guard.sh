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

# --- TEST 3: raw git mv, no report, WITH bypass trailer from admin → ALLOW with warning ---
# The bypass must explicitly originate from the admin identity. Pass
# GIT_AUTHOR_EMAIL so the hook does not fall back to the agent git config.
REPO=$(make_repo)
git -C "$REPO" mv plans/proposed/2026-04-19-test-plan.md plans/approved/2026-04-19-test-plan.md
BYPASS_MSG="chore: promote test plan

Orianna-Bypass: testing the escape hatch"

output3=$(GIT_AUTHOR_EMAIL="harukainguyen1411@gmail.com" run_hook "$REPO" "$BYPASS_MSG" 2>&1); rc3=$?
if [ "$rc3" -eq 0 ]; then
  printf 'TEST 3 PASS (admin bypass trailer → allowed with warning): hook exited 0\n'
  printf '%s\n' "$output3"
  PASS=$((PASS+1))
else
  printf 'TEST 3 FAIL: expected exit 0, got %d\n' "$rc3"
  printf '%s\n' "$output3"
  FAIL=$((FAIL+1))
fi
rm -rf "$REPO"

# --- TEST 4: bypass trailer from AGENT identity → BLOCKED ---
# An agent account (103487096+Duongntd@...) must not be allowed to use
# Orianna-Bypass even with a valid reason (ADR §D9.1).
REPO=$(make_repo)
git -C "$REPO" mv plans/proposed/2026-04-19-test-plan.md plans/approved/2026-04-19-test-plan.md
BYPASS_MSG="chore: promote test plan

Orianna-Bypass: legitimate sounding reason for the bypass"

output4=$(GIT_AUTHOR_EMAIL="103487096+Duongntd@users.noreply.github.com" run_hook "$REPO" "$BYPASS_MSG" 2>&1); rc4=$?
if [ "$rc4" -ne 0 ]; then
  printf 'TEST 4 PASS (agent bypass attempt → blocked): hook exited %d\n' "$rc4"
  printf '%s\n' "$output4"
  PASS=$((PASS+1))
else
  printf 'TEST 4 FAIL: expected non-zero exit when agent uses bypass, got 0\n'
  printf '%s\n' "$output4"
  FAIL=$((FAIL+1))
fi
rm -rf "$REPO"

# --- TEST 5: bypass trailer from ADMIN identity → ALLOWED with warning ---
# Duong's admin account (harukainguyen1411@gmail.com) is permitted to use
# Orianna-Bypass. A warning banner must appear but the hook exits 0.
REPO=$(make_repo)
git -C "$REPO" mv plans/proposed/2026-04-19-test-plan.md plans/approved/2026-04-19-test-plan.md
BYPASS_MSG="chore: promote test plan

Orianna-Bypass: break-glass override by admin"

output5=$(GIT_AUTHOR_EMAIL="harukainguyen1411@gmail.com" run_hook "$REPO" "$BYPASS_MSG" 2>&1); rc5=$?
if [ "$rc5" -eq 0 ]; then
  printf 'TEST 5 PASS (admin bypass → allowed with warning): hook exited 0\n'
  printf '%s\n' "$output5"
  PASS=$((PASS+1))
else
  printf 'TEST 5 FAIL: expected exit 0 for admin bypass, got %d\n' "$rc5"
  printf '%s\n' "$output5"
  FAIL=$((FAIL+1))
fi
rm -rf "$REPO"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

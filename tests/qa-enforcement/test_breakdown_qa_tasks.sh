#!/bin/bash
# test_breakdown_qa_tasks.sh — xfail test for breakdown-qa-tasks linter
#
# XFAIL: T.QA.7 — implementation not yet landed
# References: plans/approved/personal/2026-04-27-qa-enforcement-and-breakdown-discipline.md §D5 Surface 2
#
# This test is RED (exits non-zero) until T.QA.7 creates
# scripts/hooks/pre-commit-breakdown-qa-tasks.sh.
#
# When T.QA.7 lands, this test should flip to GREEN (exit 0).

set -u

REPO_ROOT="$(git rev-parse --show-toplevel)"
LINTER="$REPO_ROOT/scripts/hooks/pre-commit-breakdown-qa-tasks.sh"
HARNESS="$REPO_ROOT/tests/fixtures/qa-enforcement/breakdowns/run-fixture.sh"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/qa-enforcement/breakdowns"

PASS=0
FAIL=0

# Check if the linter script exists at all — it doesn't yet (xfail state)
if [ ! -f "$LINTER" ]; then
  printf '=== test_breakdown_qa_tasks.sh ===\n'
  printf 'XFAIL: T.QA.7 — linter script not yet created: %s\n' "$LINTER"
  printf 'This test will flip GREEN when T.QA.7 implements the breakdown-qa-tasks linter.\n'
  exit 1
fi

run_fixture() {
  local fixture_name="$1"
  local identity="$2"
  local expected_exit="$3"  # 0=accept, 1=reject
  local fixture_file="$FIXTURE_DIR/$fixture_name"

  if [ ! -f "$fixture_file" ]; then
    printf 'MISSING fixture: %s\n' "$fixture_name"
    FAIL=$((FAIL + 1))
    return
  fi

  actual_exit=0
  STRAWBERRY_AGENT="$identity" bash "$LINTER" \
    --fixture-path "$fixture_file" \
    --staged-path "plans/proposed/test-fixture.md" \
    >/dev/null 2>&1 || actual_exit=$?

  if [ "$actual_exit" -eq "$expected_exit" ]; then
    printf 'PASS  [exit %s, identity=%s] %s\n' "$expected_exit" "$identity" "$fixture_name"
    PASS=$((PASS + 1))
  else
    printf 'FAIL  [expected exit %s, got %s, identity=%s] %s\n' \
      "$expected_exit" "$actual_exit" "$identity" "$fixture_name"
    FAIL=$((FAIL + 1))
  fi
}

printf '=== test_breakdown_qa_tasks.sh ===\n\n'

# Reject cases under aphelios identity
run_fixture "a-aphelios-tasks-no-qa-tasks.md"    "aphelios" 1
run_fixture "b-aphelios-tasks-empty-qa-tasks.md" "aphelios" 1

# Accept cases
run_fixture "c-aphelios-tasks-with-qa-tasks.md"  "aphelios" 0
run_fixture "d-evelynn-tasks-no-qa-tasks.md"     "evelynn"  0

printf '\n=== Results: %s passed, %s failed ===\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  printf 'XFAIL — %s fixture(s) did not behave as expected.\n' "$FAIL"
  printf 'This test will flip GREEN when T.QA.7 creates the breakdown-qa-tasks linter.\n'
  exit 1
fi

printf 'All fixtures passed — xfail resolved (T.QA.7 complete).\n'
exit 0

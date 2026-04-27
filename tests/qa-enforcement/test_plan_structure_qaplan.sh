#!/bin/bash
# test_plan_structure_qaplan.sh — xfail test for plan-structure linter §QA Plan extension
#
# XFAIL: T.QA.6 — implementation not yet landed
# References: plans/approved/personal/2026-04-27-qa-enforcement-and-breakdown-discipline.md §D5 Surface 1
#
# This test is RED (exits non-zero) until T.QA.6 extends
# scripts/hooks/pre-commit-zz-plan-structure.sh with the ## QA Plan check.
#
# When T.QA.6 lands, this test should flip to GREEN (exit 0).

set -u

REPO_ROOT="$(git rev-parse --show-toplevel)"
LINTER="$REPO_ROOT/scripts/hooks/pre-commit-zz-plan-structure.sh"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/qa-enforcement/plan-structure"
STAGED_PATH="plans/proposed/test-fixture.md"

PASS=0
FAIL=0

run_fixture() {
  local fixture_name="$1"
  local expected_exit="$2"  # 0=accept, 1=reject
  local fixture_file="$FIXTURE_DIR/$fixture_name"

  if [ ! -f "$fixture_file" ]; then
    printf 'MISSING fixture: %s\n' "$fixture_name"
    FAIL=$((FAIL + 1))
    return
  fi

  actual_exit=0
  bash "$LINTER" --fixture-path "$fixture_file" --staged-path "$STAGED_PATH" >/dev/null 2>&1 || actual_exit=$?

  if [ "$actual_exit" -eq "$expected_exit" ]; then
    printf 'PASS  [exit %s] %s\n' "$expected_exit" "$fixture_name"
    PASS=$((PASS + 1))
  else
    printf 'FAIL  [expected exit %s, got %s] %s\n' "$expected_exit" "$actual_exit" "$fixture_name"
    FAIL=$((FAIL + 1))
  fi
}

# run_fixture_modified: simulate status-M commit (existing file, not new)
# Passes --is-new 0 so the §QA Plan gate is skipped (forward-only enforcement).
run_fixture_modified() {
  local fixture_name="$1"
  local expected_exit="$2"
  local staged_path="${3:-plans/approved/test-fixture.md}"
  local fixture_file="$FIXTURE_DIR/$fixture_name"

  if [ ! -f "$fixture_file" ]; then
    printf 'MISSING fixture: %s\n' "$fixture_name"
    FAIL=$((FAIL + 1))
    return
  fi

  actual_exit=0
  bash "$LINTER" --fixture-path "$fixture_file" --staged-path "$staged_path" --is-new 0 >/dev/null 2>&1 || actual_exit=$?

  if [ "$actual_exit" -eq "$expected_exit" ]; then
    printf 'PASS  [exit %s, status-M] %s\n' "$expected_exit" "$fixture_name"
    PASS=$((PASS + 1))
  else
    printf 'FAIL  [expected exit %s, got %s, status-M] %s\n' "$expected_exit" "$actual_exit" "$fixture_name"
    FAIL=$((FAIL + 1))
  fi
}

printf '=== test_plan_structure_qaplan.sh ===\n'
printf 'XFAIL: T.QA.6 — ## QA Plan check not yet in linter\n\n'

# Reject cases (a–f): linter must exit non-zero (staged as new/added file)
run_fixture "a-missing-qa-plan-heading.md"            1
run_fixture "b-empty-qa-plan-body.md"                  1
run_fixture "c-missing-ui-involvement-line.md"         1
run_fixture "d-invalid-ui-involvement-value.md"        1
run_fixture "e-qa-plan-none-missing-justification.md"  1
run_fixture "f-qa-plan-none-missing-downstream-plan.md" 1

# Accept cases (g–h): linter must exit zero (staged as new/added file)
run_fixture "g-valid-ui-branch.md"    0
run_fixture "h-valid-non-ui-branch.md" 0

# Regression — forward-only enforcement (ADR §OQ#7(b)):
# A status-M modification to a pre-existing approved plan with no §QA Plan
# MUST be accepted (grandfathered). The --is-new 0 flag simulates status-M.
run_fixture_modified "i-pre-existing-no-qa-plan-grandfathered.md" 0 "plans/approved/personal/test-grandfathered.md"

# Fenced-block extension (Fix 4 — Senna IMPORTANT):
# Tilde fences (~~~) and longer backtick fences (4+) must be skipped.
run_fixture "j-tilde-fence-skipped.md"        0  # ## QA Plan inside ~~~ fence → skipped; real heading after → ACCEPT
run_fixture "k-long-backtick-fence-skipped.md" 0  # ## QA Plan inside ```` fence → skipped; real heading after → ACCEPT

printf '\n=== Results: %s passed, %s failed ===\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  printf 'XFAIL — %s fixture(s) did not behave as expected.\n' "$FAIL"
  printf 'This test will flip GREEN when T.QA.6 implements the ## QA Plan check.\n'
  exit 1
fi

printf 'All fixtures passed — xfail resolved (T.QA.6 complete).\n'
exit 0

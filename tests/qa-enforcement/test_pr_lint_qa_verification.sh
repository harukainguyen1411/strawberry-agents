#!/bin/bash
# test_pr_lint_qa_verification.sh — xfail test for PR-lint qa-verification helper
#
# XFAIL: T.QA.8 — implementation not yet landed
# References: plans/approved/personal/2026-04-27-qa-enforcement-and-breakdown-discipline.md §D6
#
# This test is RED (exits non-zero) until T.QA.8 creates
# scripts/ci/pr-lint-qa-verification.sh.
#
# When T.QA.8 lands, this test should flip to GREEN (exit 0).
#
# Key regression: fixture (a) reproduces the exact QA-Waiver string from PR #59
# (merged 2026-04-25). The helper must reject this body shape (D6/D1).

set -u

REPO_ROOT="$(git rev-parse --show-toplevel)"
HELPER="$REPO_ROOT/scripts/ci/pr-lint-qa-verification.sh"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/qa-enforcement/pr-bodies"

PASS=0
FAIL=0

# Check if the helper script exists at all — it doesn't yet (xfail state)
if [ ! -f "$HELPER" ]; then
  printf '=== test_pr_lint_qa_verification.sh ===\n'
  printf 'XFAIL: T.QA.8 — helper script not yet created: %s\n' "$HELPER"
  printf 'This test will flip GREEN when T.QA.8 implements the PR-lint qa-verification helper.\n'
  exit 1
fi

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
  bash "$HELPER" --pr-body-file "$fixture_file" >/dev/null 2>&1 || actual_exit=$?

  if [ "$actual_exit" -eq "$expected_exit" ]; then
    printf 'PASS  [exit %s] %s\n' "$expected_exit" "$fixture_name"
    PASS=$((PASS + 1))
  else
    printf 'FAIL  [expected exit %s, got %s] %s\n' "$expected_exit" "$actual_exit" "$fixture_name"
    FAIL=$((FAIL + 1))
  fi
}

printf '=== test_pr_lint_qa_verification.sh ===\n'
printf 'Key regression: fixture (a) = PR #59 false-waiver pattern\n\n'

# Reject cases
run_fixture "a-waiver-no-sign-off.txt"        1  # PR#59 regression: QA-Waiver without Duong-Sign-Off
run_fixture "c-non-ui-no-verification.txt"    1  # non-UI PR without QA-Verification

# Accept cases
run_fixture "b-waiver-with-sign-off.txt"               0  # valid escape hatch with sign-off
run_fixture "d-non-ui-with-verification.txt"           0  # non-UI with QA-Verification
run_fixture "e-ui-pr-with-qa-report-no-figma-ref.txt"  0  # UI PR with QA-Report, no Figma-Ref (Visual-Diff not required)

# Word-boundary regression fixtures (Fix 2 — Senna IMPORTANT):
# "svg" as a bare word classifies as UI; "csvg"/"msgsvg" substrings do not.
run_fixture "f-svg-in-prose-classifies-as-ui.txt"      0  # "svg" word → UI → QA-Report present → accept
run_fixture "g-no-svg-word-boundary-non-ui.txt"        0  # "csvg"/"msgsvg" → not UI → QA-Verification present → accept

printf '\n=== Results: %s passed, %s failed ===\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  printf 'XFAIL — %s fixture(s) did not behave as expected.\n' "$FAIL"
  printf 'This test will flip GREEN when T.QA.8 creates the PR-lint qa-verification helper.\n'
  exit 1
fi

printf 'All fixtures passed — xfail resolved (T.QA.8 complete).\n'
exit 0

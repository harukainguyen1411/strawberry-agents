#!/usr/bin/env bats
# tests/hooks/plan-structure/test_plan_structure_priority.bats
#
# xfail test suite for the pre-commit-zz-plan-structure.sh hook extension.
# Plan ref: plans/approved/personal/2026-04-25-plan-of-plans-and-parking-lot.md
# Task ref: T4 (xfail fixtures + tests), T6 (implementation)
#
# XFAIL MARKER — all tests in this file are expected to fail (skip) until T6 implements
# scripts/hooks/pre-commit-zz-plan-structure.sh. The hook_absent_guard() at the top of
# each test emits an XFAIL skip rather than a hard failure, keeping the suite green
# in the pre-implementation state.
#
# xfail: pre-commit-zz-plan-structure.sh absent — all cases expected to skip
# until T6 impl lands.
#
# Test contract (per plan §Tasks T4/T6):
#   (a) proposed-missing-priority.md staged under plans/proposed/ → hook exits non-zero,
#       stderr contains "priority:" and "required"
#   (b) proposed-bad-priority-value.md staged under plans/proposed/ → hook exits non-zero,
#       stderr names the offending value ("HIGH")
#   (c) proposed-stale-last-reviewed.md staged under plans/proposed/ → hook exits non-zero,
#       stderr mentions "last_reviewed"
#   (d) proposed-valid.md staged under plans/proposed/ → hook exits 0
#   (e) approved-plan without priority: (non-proposed) → hook exits 0 (only proposed/ is gated)
#   (f) hook passes bash -n syntax check
#
# bats test_tags=tag:plan-of-plans,tag:phase-b,tag:t4,tag:t6,tag:plan-structure

REPO_ROOT="$(git -C "$(dirname "$BATS_TEST_FILENAME")" rev-parse --show-toplevel)"
HOOK="$REPO_ROOT/scripts/hooks/pre-commit-zz-plan-structure.sh"
FIXTURES="$REPO_ROOT/tests/hooks/plan-structure/fixtures"

# ---------------------------------------------------------------------------
# Guard: skip all tests with an XFAIL message when hook is absent.
# ---------------------------------------------------------------------------
hook_absent_guard() {
  if [ ! -f "$HOOK" ]; then
    skip "XFAIL: pre-commit-zz-plan-structure.sh absent — xfail per plan 2026-04-25-plan-of-plans-and-parking-lot.md T4 (impl: T6)"
  fi
}

# ---------------------------------------------------------------------------
# Helper: run hook against a fixture simulating a staged path under plans/proposed/
#   $1 = fixture file path (on disk)
#   $2 = simulated staged path (e.g. "plans/proposed/personal/test.md")
#
# The hook must accept a path argument or read from PLAN_STRUCTURE_STAGED_PATH env var.
# Convention (matching pre-commit-zz-idea-structure.sh): the hook accepts staged paths
# as either positional arguments or reads them from stdin (one per line).
# ---------------------------------------------------------------------------
run_hook_on_fixture() {
  local fixture_path="$1"
  local staged_path="$2"
  run bash "$HOOK" --fixture-path "$fixture_path" --staged-path "$staged_path"
}

# ---------------------------------------------------------------------------
# (f) Syntax check — must pass before any functional test
# ---------------------------------------------------------------------------
@test "(f) hook passes bash -n syntax check" {
  hook_absent_guard
  run bash -n "$HOOK"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# (a) Missing priority: field → rejected
# ---------------------------------------------------------------------------
@test "(a) proposed-missing-priority: hook rejects (exit non-zero), stderr names priority required" {
  hook_absent_guard

  run bash "$HOOK" \
    --fixture-path "$FIXTURES/proposed-missing-priority.md" \
    --staged-path "plans/proposed/personal/proposed-missing-priority.md"

  [ "$status" -ne 0 ]
  [[ "$output" == *"priority"* ]] || [[ "$stderr" == *"priority"* ]]
  [[ "$output" == *"required"* ]] || [[ "$stderr" == *"required"* ]] || \
  [[ "$output" == *"P0"* ]]       || [[ "$stderr" == *"P0"* ]]
}

# ---------------------------------------------------------------------------
# (b) Bad priority value → rejected with offending value named
# ---------------------------------------------------------------------------
@test "(b) proposed-bad-priority-value: hook rejects (exit non-zero), stderr names offending value" {
  hook_absent_guard

  run bash "$HOOK" \
    --fixture-path "$FIXTURES/proposed-bad-priority-value.md" \
    --staged-path "plans/proposed/personal/proposed-bad-priority-value.md"

  [ "$status" -ne 0 ]
  # stderr or combined output must name the bad value "HIGH"
  [[ "$output" == *"HIGH"* ]] || [[ "$stderr" == *"HIGH"* ]]
}

# ---------------------------------------------------------------------------
# (c) Non-ISO last_reviewed → rejected
# ---------------------------------------------------------------------------
@test "(c) proposed-stale-last-reviewed: hook rejects (exit non-zero), stderr mentions last_reviewed" {
  hook_absent_guard

  run bash "$HOOK" \
    --fixture-path "$FIXTURES/proposed-stale-last-reviewed.md" \
    --staged-path "plans/proposed/personal/proposed-stale-last-reviewed.md"

  [ "$status" -ne 0 ]
  [[ "$output" == *"last_reviewed"* ]] || [[ "$stderr" == *"last_reviewed"* ]]
}

# ---------------------------------------------------------------------------
# (d) Valid proposed plan → accepted (exit 0)
# ---------------------------------------------------------------------------
@test "(d) proposed-valid: hook accepts (exit 0)" {
  hook_absent_guard

  run bash "$HOOK" \
    --fixture-path "$FIXTURES/proposed-valid.md" \
    --staged-path "plans/proposed/personal/proposed-valid.md"

  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# (e) Non-proposed path (approved/) → hook skips enforcement (exit 0)
# priority: and last_reviewed: are only required for plans/proposed/** per ADR D1.
# ---------------------------------------------------------------------------
@test "(e) approved-path without priority: hook does not gate non-proposed (exit 0)" {
  hook_absent_guard

  # Use the missing-priority fixture but stage it under plans/approved/ — must pass.
  run bash "$HOOK" \
    --fixture-path "$FIXTURES/proposed-missing-priority.md" \
    --staged-path "plans/approved/personal/some-plan.md"

  [ "$status" -eq 0 ]
}

#!/usr/bin/env bash
# tests/ci/pr-frontend-markers/run.sh
#
# T-E1 xfail integration harness for the `pr-frontend-markers` CI job.
#
# Plan: plans/approved/personal/2026-04-25-frontend-uiux-in-process.md T-E1
# xfail-for: plans/approved/personal/2026-04-25-frontend-uiux-in-process.md T-E2
#
# Tests the five PR-body fixture cases defined in D7 against
# scripts/ci/pr-lint-frontend-markers.sh (Viktor's T-E2 impl target).
#
# Case matrix:
#   (a) fail-no-markers.txt        — UI PR, no markers     → FAIL (exit 1)
#   (b) pass-all-markers.txt       — UI PR, all markers    → PASS (exit 0)
#   (c) pass-design-spec-only.txt  — UI PR, one marker     → PASS (exit 0)
#   (d) pass-with-waiver.txt       — UI PR, UX-Waiver      → PASS (exit 0)
#   (e) exempt-non-ui.txt          — non-UI PR, no markers → PASS/exempt (exit 0)
#   (f) fail-empty-marker.txt      — UI PR, empty values   → FAIL (exit 1)
#
# The harness passes changed-file lists via the $2 positional argument
# (space-separated filenames) so the impl script can classify UI vs non-UI
# without reading from $GITHUB_EVENT_PATH in unit-test mode.
#
# Exit codes:
#   0 — all cases matched expectations
#   1 — one or more cases diverged from expectations
#
# xfail: guard — remove when Viktor's impl lands.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

IMPL="$REPO_ROOT/scripts/ci/pr-lint-frontend-markers.sh"

# ---------------------------------------------------------------------------
# XFAIL guard — impl not yet present (T-E2 is Viktor's task)
# ---------------------------------------------------------------------------
if [ ! -f "$IMPL" ]; then
  printf 'XFAIL (expected — missing: scripts/ci/pr-lint-frontend-markers.sh)\n'
  printf 'XFAIL CASE_A: fail-no-markers — UI PR missing all markers\n'
  printf 'XFAIL CASE_B: pass-all-markers — UI PR with Design-Spec + Accessibility-Check + Visual-Diff\n'
  printf 'XFAIL CASE_C: pass-design-spec-only — UI PR with Design-Spec only (markers individually opt-in)\n'
  printf 'XFAIL CASE_D: pass-with-waiver — UI PR with UX-Waiver substituting Design-Spec\n'
  printf 'XFAIL CASE_E: exempt-non-ui — non-UI PR skips check\n'
  printf 'XFAIL CASE_F: fail-empty-marker — UI PR with empty marker values\n'
  exit 0
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
pass=0
fail=0

FIXTURE_DIR="$SCRIPT_DIR"

# UI files (trigger the frontend-markers gate)
UI_FILES="apps/strawberry-app/src/pages/profile.vue apps/strawberry-app/src/components/dashboard/ActivityFeed.vue apps/strawberry-app/src/components/settings/Button.vue"
# Non-UI files (exempt)
NON_UI_FILES="scripts/memory-consolidate.sh agents/evelynn/CLAUDE.md"

run_case() {
  local label="$1"
  local fixture="$2"
  local changed_files="$3"
  local expect_exit="$4"

  local body
  body="$(cat "$FIXTURE_DIR/$fixture")"

  actual_exit=0
  printf '%s' "$body" | bash "$IMPL" - "$changed_files" >/dev/null 2>&1 || actual_exit=$?

  if [ "$actual_exit" -eq "$expect_exit" ]; then
    printf 'PASS: %s\n' "$label"
    pass=$((pass + 1))
  else
    printf 'FAIL: %s (expected exit %d, got %d)\n' "$label" "$expect_exit" "$actual_exit" >&2
    fail=$((fail + 1))
  fi
}

# ---------------------------------------------------------------------------
# Case (a): UI PR missing all three markers — must FAIL
# ---------------------------------------------------------------------------
run_case \
  "CASE_A: UI PR missing all three markers fails" \
  "fail-no-markers.txt" \
  "$UI_FILES" \
  1

# ---------------------------------------------------------------------------
# Case (b): UI PR with all three markers — must PASS
# ---------------------------------------------------------------------------
run_case \
  "CASE_B: UI PR with Design-Spec + Accessibility-Check + Visual-Diff passes" \
  "pass-all-markers.txt" \
  "$UI_FILES" \
  0

# ---------------------------------------------------------------------------
# Case (c): UI PR with Design-Spec only — must PASS (markers individually opt-in)
# ---------------------------------------------------------------------------
run_case \
  "CASE_C: UI PR with Design-Spec only passes (markers individually opt-in)" \
  "pass-design-spec-only.txt" \
  "$UI_FILES" \
  0

# ---------------------------------------------------------------------------
# Case (d): UI PR with UX-Waiver substituting Design-Spec — must PASS
# ---------------------------------------------------------------------------
run_case \
  "CASE_D: UI PR with UX-Waiver accepted in lieu of Design-Spec" \
  "pass-with-waiver.txt" \
  "$UI_FILES" \
  0

# ---------------------------------------------------------------------------
# Case (e): Non-UI PR without any markers — must be EXEMPT (exit 0)
# ---------------------------------------------------------------------------
run_case \
  "CASE_E: non-UI PR is exempt from frontend-marker check" \
  "exempt-non-ui.txt" \
  "$NON_UI_FILES" \
  0

# ---------------------------------------------------------------------------
# Case (f): UI PR with empty marker values — must FAIL
# ---------------------------------------------------------------------------
run_case \
  "CASE_F: UI PR with empty marker values treated as absent (fails)" \
  "fail-empty-marker.txt" \
  "$UI_FILES" \
  1

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\nT-E1: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0

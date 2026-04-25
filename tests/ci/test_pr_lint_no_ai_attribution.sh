#!/usr/bin/env bash
# tests/ci/test_pr_lint_no_ai_attribution.sh
#
# T5 — xfail: shell-level test of the PR body/comment AI-marker lint helper.
#
# Plan: plans/approved/personal/2026-04-25-no-ai-attribution-defense-in-depth.md T5
#
# XFAIL: T6 (CI helper script + workflow) not yet implemented.
echo "XFAIL: T6 (pr-lint-no-ai-attribution helper + workflow) not yet implemented — plans/approved/personal/2026-04-25-no-ai-attribution-defense-in-depth.md"
exit 0

# --- Implementation (active after xfail sentinel removed) ---

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

HELPER="$REPO_ROOT/scripts/ci/pr-lint-no-ai-attribution.sh"

if [ ! -f "$HELPER" ]; then
  printf 'FAIL: helper not found: %s\n' "$HELPER" >&2
  exit 1
fi

pass=0
fail=0

run_case() {
  local desc="$1"
  local body="$2"
  local expect_exit="$3"

  actual_exit=0
  printf '%s' "$body" | bash "$HELPER" >/dev/null 2>&1 || actual_exit=$?

  if [ "$actual_exit" -eq "$expect_exit" ]; then
    printf 'PASS: %s\n' "$desc"
    pass=$((pass + 1))
  else
    printf 'FAIL: %s (expected exit %d, got %d)\n' "$desc" "$expect_exit" "$actual_exit" >&2
    fail=$((fail + 1))
  fi
}

# --- Cases that must PASS (exit 0) ---

run_case "Clean PR body" \
  "## Summary
- Fixed the widget" \
  0

run_case "Body with Human-Verified: yes overrides offending marker" \
  "## Summary
🤖 Generated with [Claude Code](https://claude.com/code)
Human-Verified: yes" \
  0

# --- Cases that must FAIL (exit 1) ---

run_case "Body containing robot emoji + Generated with Claude Code" \
  "## Summary
🤖 Generated with [Claude Code](https://claude.com/code)" \
  1

run_case "Body containing Co-Authored-By trailer (universal block)" \
  "## Summary
Co-Authored-By: Anyone <a@b>" \
  1

run_case "Comment payload containing Sonnet 4.6" \
  "This PR was reviewed by Sonnet 4.6" \
  1

# --- Summary ---

printf '\nT5: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0

#!/usr/bin/env bash
# tests/hooks/test_commit_msg_no_ai_coauthor.sh
#
# T3 — xfail: regression + new-coverage tests for commit-msg-no-ai-coauthor.sh
#
# Plan: plans/approved/personal/2026-04-25-no-ai-attribution-defense-in-depth.md T3
#
# XFAIL: T4 (tightened hook) not yet implemented.
echo "XFAIL: T4 (tightened commit-msg hook) not yet implemented — plans/approved/personal/2026-04-25-no-ai-attribution-defense-in-depth.md"
exit 0

# --- Implementation (active after xfail sentinel removed) ---

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

HOOK="$REPO_ROOT/scripts/hooks/commit-msg-no-ai-coauthor.sh"

if [ ! -f "$HOOK" ]; then
  printf 'FAIL: hook not found: %s\n' "$HOOK" >&2
  exit 1
fi

pass=0
fail=0

run_case() {
  local desc="$1"
  local msg="$2"
  local expect_exit="$3"  # 0=pass 1=reject

  tmpfile="$(mktemp)"
  printf '%s\n' "$msg" > "$tmpfile"
  actual_exit=0
  bash "$HOOK" "$tmpfile" >/dev/null 2>&1 || actual_exit=$?
  rm -f "$tmpfile"

  if [ "$actual_exit" -eq "$expect_exit" ]; then
    printf 'PASS: %s\n' "$desc"
    pass=$((pass + 1))
  else
    printf 'FAIL: %s (expected exit %d, got %d)\n' "$desc" "$expect_exit" "$actual_exit" >&2
    fail=$((fail + 1))
  fi
}

# --- Cases that must REJECT (exit 1) ---

# Current gap — would have caught b2b8944
run_case "Co-Authored-By: Claude Sonnet 4.6 noreply@anthropic.com" \
  "chore: some work

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>" \
  1

run_case "Co-Authored-By: Claude Opus 4.7 noreply@anthropic.com" \
  "chore: some work

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>" \
  1

# Universal block — any name in Co-Authored-By
run_case "Co-Authored-By: Random Human human@example.com (universal block)" \
  "chore: some work

Co-Authored-By: Random Human <human@example.com>" \
  1

# Body markers
run_case "Body containing robot emoji + Generated with Claude Code" \
  "chore: some work

🤖 Generated with [Claude Code](https://claude.com/code)" \
  1

run_case "Body containing AI-generated commit message" \
  "chore: some work

AI-generated commit message" \
  1

run_case "Body containing bare URL claude.com/code" \
  "chore: some work

See claude.com/code for details" \
  1

run_case "Body mentioning Sonnet 4.6 (model name is a marker)" \
  "chore: some work

This was written by Sonnet 4.6 model" \
  1

# --- Cases that must PASS (exit 0) ---

run_case "Clean message with no trailer" \
  "chore: fix the build" \
  0

run_case "Co-Authored-By: Random Human + Human-Verified: yes (override)" \
  "chore: pair session

Co-Authored-By: Random Human <human@example.com>
Human-Verified: yes" \
  0

# False-positive guard: word 'maintain' contains 'ai' — must not be blocked
run_case "Word 'maintain' does not trigger AI-marker scan" \
  "fix: maintain backward compat" \
  0

# --- Summary ---

printf '\nT3: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0

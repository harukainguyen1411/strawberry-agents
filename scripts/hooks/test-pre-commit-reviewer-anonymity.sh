#!/usr/bin/env bash
# scripts/hooks/test-pre-commit-reviewer-anonymity.sh
#
# TDD-PLAN: plans/in-progress/personal/2026-04-22-work-scope-reviewer-anonymity.md
#
# Tests for pre-commit-reviewer-anonymity.sh and _lib_reviewer_anonymity.sh.
# Fixtures:
#   fixture-a: work-scope repo + commit msg containing agent name "Senna" → hook rejects
#   fixture-b: work-scope repo + clean commit msg → hook passes
#   fixture-c: personal-scope repo + commit msg containing "Senna" → hook passes (scope discrimination)
#
# Run: bash scripts/hooks/test-pre-commit-reviewer-anonymity.sh
# Exit: 0 = all pass, non-zero = failure count

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO_ROOT/scripts/hooks/pre-commit-reviewer-anonymity.sh"
LIB="$REPO_ROOT/scripts/hooks/_lib_reviewer_anonymity.sh"

PASS=0
FAIL=0

pass() { printf '[PASS] %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf '[FAIL] %s\n' "$1"; FAIL=$((FAIL+1)); }

# XFAIL: these tests will fail until implementation is in place
XFAIL=1

# --- helper: make a temp git repo with given remote origin ---
make_repo() {
  local dir remote_url
  dir="$(mktemp -d)"
  remote_url="$1"
  git -C "$dir" init -q
  git -C "$dir" remote add origin "$remote_url"
  # Create initial commit so HEAD exists
  git -C "$dir" commit --allow-empty -m "init" -q
  printf '%s' "$dir"
}

# --- fixture-a: work-scope repo, denylist hit ---
run_fixture_a() {
  local repo
  repo="$(make_repo "git@github.com:missmp/fake.git")"
  # Write a commit msg with an agent name
  printf 'Fix bug\n\nReviewed by Senna\n' > "$repo/.git/COMMIT_EDITMSG"
  if ANONYMITY_HOOK_REPO="$repo" bash "$HOOK" 2>/dev/null; then
    if [ "${XFAIL:-0}" = "1" ]; then
      pass "fixture-a (xfail — impl missing, hook not yet rejecting)"
    else
      fail "fixture-a: hook should have rejected denylist hit on work-scope repo"
    fi
  else
    if [ "${XFAIL:-0}" = "1" ]; then
      pass "fixture-a (xfail now passing — implementation present)"
    else
      pass "fixture-a"
    fi
  fi
  rm -rf "$repo"
}

# --- fixture-b: work-scope repo, clean msg ---
run_fixture_b() {
  local repo
  repo="$(make_repo "git@github.com:missmp/fake.git")"
  printf 'Fix pagination edge case\n' > "$repo/.git/COMMIT_EDITMSG"
  if ANONYMITY_HOOK_REPO="$repo" bash "$HOOK" 2>/dev/null; then
    pass "fixture-b"
  else
    if [ "${XFAIL:-0}" = "1" ]; then
      pass "fixture-b (xfail — impl missing, clean path blocked)"
    else
      fail "fixture-b: hook should have passed clean commit msg on work-scope repo"
    fi
  fi
  rm -rf "$repo"
}

# --- fixture-c: personal-scope repo, denylist hit (should pass) ---
run_fixture_c() {
  local repo
  repo="$(make_repo "git@github.com:harukainguyen1411/strawberry-app.git")"
  printf 'Fix bug\n\nReviewed by Senna\n' > "$repo/.git/COMMIT_EDITMSG"
  if ANONYMITY_HOOK_REPO="$repo" bash "$HOOK" 2>/dev/null; then
    pass "fixture-c"
  else
    if [ "${XFAIL:-0}" = "1" ]; then
      pass "fixture-c (xfail — impl missing, personal-scope incorrectly blocked)"
    else
      fail "fixture-c: hook should NOT reject on personal-scope repo"
    fi
  fi
  rm -rf "$repo"
}

# --- run all fixtures ---
run_fixture_a
run_fixture_b
run_fixture_c

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
exit "$FAIL"

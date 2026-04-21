#!/usr/bin/env bash
# scripts/hooks/tests/pre-commit-staged-scope-guard.test.sh
# kind: test
# Regression test for scripts/hooks/pre-commit-staged-scope-guard.sh
#
# xfail guard: if the hook does not yet exist, print xfail and exit 0.
# Per Rule 12, this test commit must land BEFORE the hook implementation.
#
# Cases:
#   A — two staged files, STAGED_SCOPE declares only one → exit 1, stderr lists out-of-scope file
#   B — two staged files, no STAGED_SCOPE, below warn threshold → exit 0, no stderr
#   C — 12 files across 4 top-level dirs, no STAGED_SCOPE → exit 0, stderr contains warning
#   D — 12 files across 4 top-level dirs, STAGED_SCOPE='*' → exit 0, stderr contains "Escape hatch active"
#   E — one staged file, STAGED_SCOPE matches exactly → exit 0, .git/COMMIT_SCOPE absent after run

set -uo pipefail

HOOK="scripts/hooks/pre-commit-staged-scope-guard.sh"
REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK_ABS="$REPO_ROOT/$HOOK"

if [ ! -x "$HOOK_ABS" ]; then
  printf 'xfail — hook not yet implemented: %s\n' "$HOOK_ABS" >&2
  exit 0
fi

pass=0
fail=0

run_case() {
  local label="$1"
  shift
  if "$@"; then
    printf 'PASS %s\n' "$label"
    pass=$((pass + 1))
  else
    printf 'FAIL %s\n' "$label"
    fail=$((fail + 1))
  fi
}

# Helper: create a throwaway git repo and return its path
make_repo() {
  local d
  d="$(mktemp -d)"
  git -C "$d" init -q
  git -C "$d" config user.email "test@test.com"
  git -C "$d" config user.name "Test"
  # create initial commit so HEAD exists
  touch "$d/.gitkeep"
  git -C "$d" add .gitkeep
  git -C "$d" commit -q -m "init"
  printf '%s' "$d"
}

# Helper: create and stage a file in repo
stage_file() {
  local repo="$1" path="$2"
  mkdir -p "$repo/$(dirname "$path")"
  printf 'x' > "$repo/$path"
  git -C "$repo" add "$path"
}

########################################
# Case A — out-of-scope path → exit 1
########################################
case_A() {
  local repo
  repo="$(make_repo)"
  stage_file "$repo" "a.txt"
  stage_file "$repo" "b.txt"
  local stderr_out
  stderr_out="$(STAGED_SCOPE="a.txt" "$HOOK_ABS" 2>&1 >/dev/null)" || true
  local rc=0
  STAGED_SCOPE="a.txt" "$HOOK_ABS" >/dev/null 2>/dev/null; rc=$?
  stderr_out="$(STAGED_SCOPE="a.txt" GIT_DIR="$repo/.git" GIT_WORK_TREE="$repo" "$HOOK_ABS" 2>&1 >/dev/null || true)"
  local hook_rc=0
  (cd "$repo" && STAGED_SCOPE="a.txt" "$HOOK_ABS" >/dev/null 2>/dev/null) || hook_rc=$?
  local hook_stderr
  hook_stderr="$(cd "$repo" && STAGED_SCOPE="a.txt" "$HOOK_ABS" 2>&1 >/dev/null || true)"
  rm -rf "$repo"
  # Must exit 1
  if [ "$hook_rc" -ne 1 ]; then
    printf 'Case A: expected exit 1, got %d\n' "$hook_rc" >&2
    return 1
  fi
  # Must mention b.txt in stderr
  if ! printf '%s' "$hook_stderr" | grep -q 'b.txt'; then
    printf 'Case A: stderr did not mention b.txt\n' >&2
    printf 'stderr was: %s\n' "$hook_stderr" >&2
    return 1
  fi
  return 0
}

########################################
# Case B — no scope, 2 files, 1 dir → exit 0, no stderr
########################################
case_B() {
  local repo
  repo="$(make_repo)"
  stage_file "$repo" "a.txt"
  stage_file "$repo" "b.txt"
  local hook_rc=0
  local hook_stderr
  hook_stderr="$(cd "$repo" && unset STAGED_SCOPE; "$HOOK_ABS" 2>&1 >/dev/null || true)"
  (cd "$repo" && unset STAGED_SCOPE; "$HOOK_ABS" >/dev/null 2>/dev/null) || hook_rc=$?
  rm -rf "$repo"
  if [ "$hook_rc" -ne 0 ]; then
    printf 'Case B: expected exit 0, got %d\n' "$hook_rc" >&2
    return 1
  fi
  if [ -n "$hook_stderr" ]; then
    printf 'Case B: expected empty stderr, got: %s\n' "$hook_stderr" >&2
    return 1
  fi
  return 0
}

########################################
# Case C — no scope, 12 files across 4 dirs → exit 0, warning in stderr
########################################
case_C() {
  local repo
  repo="$(make_repo)"
  local i
  for i in $(seq 1 3); do stage_file "$repo" "dira/file${i}.txt"; done
  for i in $(seq 1 3); do stage_file "$repo" "dirb/file${i}.txt"; done
  for i in $(seq 1 3); do stage_file "$repo" "dirc/file${i}.txt"; done
  for i in $(seq 1 3); do stage_file "$repo" "dird/file${i}.txt"; done
  local hook_rc=0
  local hook_stderr
  hook_stderr="$(cd "$repo" && unset STAGED_SCOPE; "$HOOK_ABS" 2>&1 >/dev/null || true)"
  (cd "$repo" && unset STAGED_SCOPE; "$HOOK_ABS" >/dev/null 2>/dev/null) || hook_rc=$?
  rm -rf "$repo"
  if [ "$hook_rc" -ne 0 ]; then
    printf 'Case C: expected exit 0, got %d\n' "$hook_rc" >&2
    return 1
  fi
  if ! printf '%s' "$hook_stderr" | grep -q 'Staged-scope guard'; then
    printf 'Case C: expected warning in stderr, got: %s\n' "$hook_stderr" >&2
    return 1
  fi
  return 0
}

########################################
# Case D — STAGED_SCOPE=*, 12 files → exit 0, "Escape hatch active" in stderr
########################################
case_D() {
  local repo
  repo="$(make_repo)"
  local i
  for i in $(seq 1 3); do stage_file "$repo" "dira/file${i}.txt"; done
  for i in $(seq 1 3); do stage_file "$repo" "dirb/file${i}.txt"; done
  for i in $(seq 1 3); do stage_file "$repo" "dirc/file${i}.txt"; done
  for i in $(seq 1 3); do stage_file "$repo" "dird/file${i}.txt"; done
  local hook_rc=0
  local hook_stderr
  hook_stderr="$(cd "$repo" && STAGED_SCOPE='*' "$HOOK_ABS" 2>&1 >/dev/null || true)"
  (cd "$repo" && STAGED_SCOPE='*' "$HOOK_ABS" >/dev/null 2>/dev/null) || hook_rc=$?
  rm -rf "$repo"
  if [ "$hook_rc" -ne 0 ]; then
    printf 'Case D: expected exit 0, got %d\n' "$hook_rc" >&2
    return 1
  fi
  if ! printf '%s' "$hook_stderr" | grep -q 'Escape hatch active'; then
    printf 'Case D: expected "Escape hatch active" in stderr, got: %s\n' "$hook_stderr" >&2
    return 1
  fi
  return 0
}

########################################
# Case E — exact scope match, .git/COMMIT_SCOPE cleared
########################################
case_E() {
  local repo
  repo="$(make_repo)"
  stage_file "$repo" "a.txt"
  # Write a .git/COMMIT_SCOPE file to verify it gets cleared
  printf 'a.txt\n' > "$repo/.git/COMMIT_SCOPE"
  local hook_rc=0
  (cd "$repo" && STAGED_SCOPE="a.txt" "$HOOK_ABS" >/dev/null 2>/dev/null) || hook_rc=$?
  local scope_exists=0
  [ -f "$repo/.git/COMMIT_SCOPE" ] && scope_exists=1
  rm -rf "$repo"
  if [ "$hook_rc" -ne 0 ]; then
    printf 'Case E: expected exit 0, got %d\n' "$hook_rc" >&2
    return 1
  fi
  if [ "$scope_exists" -eq 1 ]; then
    printf 'Case E: expected .git/COMMIT_SCOPE to be removed, but it still exists\n' >&2
    return 1
  fi
  return 0
}

run_case "A (hard block on out-of-scope)" case_A
run_case "B (unscoped trivial commit silent)" case_B
run_case "C (unscoped bulk commit warns)" case_C
run_case "D (escape hatch *)" case_D
run_case "E (exact match, COMMIT_SCOPE cleared)" case_E

printf '\nResults: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

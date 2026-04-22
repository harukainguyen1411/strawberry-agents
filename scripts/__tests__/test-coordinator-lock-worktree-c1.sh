#!/usr/bin/env bash
# test-coordinator-lock-worktree-c1.sh — regression test: lock acquisition must
# work when the lockfile is specified as "$REPO_ROOT/.git/strawberry-promote.lock"
# and the script is called from inside a git worktree (C1 blocker from PR #22).
#
# Plan: plans/in-progress/personal/2026-04-22-concurrent-coordinator-race-closeout.md
#
# Before fix: _lib_coordinator_lock.sh opens the lockfile via exec 9>"$file" where
# the file's parent ($REPO_ROOT/.git) is a plain FILE in a worktree, not a directory.
# Result: "Not a directory" / fd open fails; every invocation sees false contention.
# After fix: lib auto-detects this via git rev-parse --git-common-dir and resolves
# the lockfile to the shared .git directory.
#
# Exit codes:
#   0 — all assertions passed (C1 fixed)
#   1 — assertion failed
#   2 — infrastructure error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_LOCK="$REPO_ROOT/scripts/_lib_coordinator_lock.sh"

pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }
info() { printf '[INFO] %s\n' "$*"; }

# --- setup a main repo + worktree -----------------------------------------

TMPROOT="$(mktemp -d)"
MAIN_REPO="$TMPROOT/main-repo"
WORKTREE_PATH="$TMPROOT/my-worktree"

cleanup() { rm -rf "$TMPROOT"; }
trap cleanup EXIT INT TERM

git init -q "$MAIN_REPO"
git -C "$MAIN_REPO" config user.email "test@test.local"
git -C "$MAIN_REPO" config user.name "Test"
git -C "$MAIN_REPO" commit -q --allow-empty -m "init"
git -C "$MAIN_REPO" branch feat/test-worktree
git -C "$MAIN_REPO" worktree add -q "$WORKTREE_PATH" feat/test-worktree

# Verify .git in worktree is a file — precondition for C1 bug reproduction
if [ -d "$WORKTREE_PATH/.git" ]; then
  fail "Expected .git to be a file in the worktree, but it is a directory. Test setup error."
fi
info "Confirmed: $WORKTREE_PATH/.git is a file (correct worktree precondition)"

# The lockfile path that callers use — hardcoded with .git/ as directory
LOCKFILE_PATH="$WORKTREE_PATH/.git/strawberry-promote.lock"
info "Lockfile path (as caller would pass): $LOCKFILE_PATH"

# Verify the parent is indeed a file, not a directory (this is the root of C1)
LOCKFILE_PARENT="$(dirname "$LOCKFILE_PATH")"
if [ -d "$LOCKFILE_PARENT" ]; then
  fail "Test precondition violated: $LOCKFILE_PARENT is a directory (should be a file in worktree)"
fi
pass "Confirmed: lockfile parent is a FILE (worktree .git) — C1 precondition met"

# --- attempt lock acquire from inside the worktree context --------------------
# The lib must auto-resolve --git-common-dir and succeed.
ACQUIRE_RC=0
ACQUIRE_OUT=""
ACQUIRE_OUT="$(
  cd "$WORKTREE_PATH"
  # shellcheck source=/dev/null
  . "$LIB_LOCK"
  coordinator_lock_acquire "$LOCKFILE_PATH"
  printf 'acquired\n'
) " || ACQUIRE_RC=$?

info "Acquire output: $ACQUIRE_OUT (RC=$ACQUIRE_RC)"

if [ "$ACQUIRE_RC" -ne 0 ]; then
  fail "coordinator_lock_acquire failed (RC=$ACQUIRE_RC) when called from worktree with .git-file parent. C1 not fixed."
fi
if ! printf '%s\n' "$ACQUIRE_OUT" | grep -q "acquired"; then
  fail "coordinator_lock_acquire did not complete successfully. Output: $ACQUIRE_OUT"
fi
pass "coordinator_lock_acquire succeeded from worktree context (C1 fixed)"

# --- verify no false contention when calling sequentially --------------------
# Second sequential acquire (after first subshell released) must also succeed
ACQUIRE2_RC=0
ACQUIRE2_OUT=""
ACQUIRE2_OUT="$(
  cd "$WORKTREE_PATH"
  # shellcheck source=/dev/null
  . "$LIB_LOCK"
  coordinator_lock_acquire "$LOCKFILE_PATH"
  printf 'acquired-2\n'
) " || ACQUIRE2_RC=$?

if [ "$ACQUIRE2_RC" -ne 0 ]; then
  fail "Sequential second acquire failed — false contention detected. C1 may not be fully fixed. Output: $ACQUIRE2_OUT"
fi
pass "Sequential acquire (no false contention) succeeded"

printf '\n[ALL PASS] C1 regression test passed — worktree lock works correctly.\n'
exit 0

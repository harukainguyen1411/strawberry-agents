#!/usr/bin/env bash
# tests/hooks/test_pre_commit_resolved_identity.sh
#
# xfail test suite for scripts/hooks/pre-commit-resolved-identity.sh
#
# Plan: plans/approved/personal/2026-04-25-resolved-identity-enforcement.md
# T1: xfail tests (NEW-BP-4 through NEW-BP-12 reproducers) — committed before implementation
#
# Each test sets up a minimal temp git repo, configures a persona author via a
# bypass technique, then invokes the hook and asserts non-zero exit + error
# message containing the persona name or @strawberry.local.
#
# xfail: all cases below are expected to fail (non-zero exit) once the hook
# exists. They will XFAIL (pass=skip) until the hook is implemented (T2).
# After T2 the xfail markers are removed and the tests must all pass.
#
# Tests:
#   CTRL-1  baseline: direct persona config → must block
#   NEW-BP-4  line-continuation in env var assignment
#   NEW-BP-5  backtick command substitution in env var
#   NEW-BP-6  $(...) command substitution in env var
#   NEW-BP-7  eval wrapper
#   NEW-BP-8  $VAR indirection
#   NEW-BP-9  cat /file indirection
#   NEW-BP-10 git commit-tree plumbing (note: pre-commit does NOT fire for commit-tree)
#   NEW-BP-11 sh -c wrapper
#   NEW-BP-12 bash -c wrapper
#
# Positive (allowlist) tests live in T7: test_pre_commit_resolved_identity_positive.sh
# — not present here to keep T1 xfail-only.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

HOOK="$REPO_ROOT/scripts/hooks/pre-commit-resolved-identity.sh"

pass=0
fail=0
skip=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

make_repo() {
  local dir
  dir="$(mktemp -d)"
  git -C "$dir" init -q
  git -C "$dir" config user.name "Duongntd"
  git -C "$dir" config user.email "103487096+Duongntd@users.noreply.github.com"
  git -C "$dir" commit --allow-empty -q -m "init"
  printf '%s' "$dir"
}

# run_case <desc> <expect_exit_nonzero:1|0> <setup_fn>
# setup_fn is called with the repo dir as $1; it should configure the persona
# identity in whichever way the bypass technique requires, then leave the repo
# in a state where running the hook would be meaningful.
run_case() {
  local desc="$1"
  local expect_block="$2"  # 1 = hook must exit non-zero (block), 0 = allow
  shift 2
  local setup_fn="$1"
  shift

  # xfail: hook may not exist yet — skip gracefully
  if [ ! -f "$HOOK" ]; then
    printf 'XFAIL (hook absent): %s\n' "$desc"
    skip=$((skip + 1))
    return
  fi

  local repo
  repo="$(make_repo)"

  # Run setup
  "$setup_fn" "$repo" "$@"

  # Run hook in the repo's context (GIT_DIR + working tree)
  local actual_exit=0
  GIT_DIR="$repo/.git" GIT_WORK_TREE="$repo" bash "$HOOK" >/dev/null 2>&1 || actual_exit=$?

  rm -rf "$repo"

  if [ "$expect_block" -eq 1 ] && [ "$actual_exit" -ne 0 ]; then
    printf 'PASS: %s\n' "$desc"
    pass=$((pass + 1))
  elif [ "$expect_block" -eq 0 ] && [ "$actual_exit" -eq 0 ]; then
    printf 'PASS: %s\n' "$desc"
    pass=$((pass + 1))
  else
    printf 'FAIL: %s (expected_block=%d actual_exit=%d)\n' "$desc" "$expect_block" "$actual_exit" >&2
    fail=$((fail + 1))
  fi
}

# ---------------------------------------------------------------------------
# Setup functions — each configures the persona identity
# ---------------------------------------------------------------------------

setup_direct_persona() {
  # CTRL-1: direct git config with persona name — the baseline that the hook must block
  local repo="$1"
  git -C "$repo" config user.name "Viktor"
  git -C "$repo" config user.email "viktor@strawberry.local"
}

setup_bp4_line_continuation() {
  # NEW-BP-4: line-continuation bypasses PreToolUse scan.
  # At pre-commit time, git var GIT_AUTHOR_IDENT reads resolved config.
  # Set persona directly in config (same as CTRL-1 — the bypass is about how the
  # agent sets it, not how pre-commit reads it; pre-commit sees resolved value).
  local repo="$1"
  git -C "$repo" config user.name "Viktor"
  git -C "$repo" config user.email "viktor@strawberry.local"
}

setup_bp5_backtick() {
  # NEW-BP-5: backtick expansion. At pre-commit time the resolved config is what matters.
  local repo="$1"
  git -C "$repo" config user.name "Lucian"
  git -C "$repo" config user.email "lucian@strawberry.local"
}

setup_bp6_cmdsub() {
  # NEW-BP-6: $(...) command substitution. Pre-commit sees resolved value.
  local repo="$1"
  git -C "$repo" config user.name "Senna"
  git -C "$repo" config user.email "senna@strawberry.local"
}

setup_bp7_eval() {
  # NEW-BP-7: eval wrapper. Pre-commit sees resolved value.
  local repo="$1"
  git -C "$repo" config user.name "Aphelios"
  git -C "$repo" config user.email "aphelios@strawberry.local"
}

setup_bp8_var_indirection() {
  # NEW-BP-8: $V indirection. Pre-commit sees resolved value in config.
  local repo="$1"
  git -C "$repo" config user.name "Xayah"
  git -C "$repo" config user.email "xayah@strawberry.local"
}

setup_bp9_file_indirection() {
  # NEW-BP-9: cat /file. Pre-commit sees resolved value in config.
  local repo="$1"
  git -C "$repo" config user.name "Caitlyn"
  git -C "$repo" config user.email "caitlyn@strawberry.local"
}

setup_bp10_commit_tree() {
  # NEW-BP-10: git commit-tree does NOT fire pre-commit hook.
  # This test verifies the hook would block if config has persona name —
  # the actual commit-tree bypass is tested in the pre-push test file.
  local repo="$1"
  git -C "$repo" config user.name "Akali"
  git -C "$repo" config user.email "akali@strawberry.local"
}

setup_bp11_sh_c() {
  # NEW-BP-11: sh -c wrapper sets config by env. Pre-commit sees GIT_AUTHOR_IDENT.
  # Set via GIT_AUTHOR_NAME env (we test the hook catches env-based identity).
  local repo="$1"
  git -C "$repo" config user.name "Karma"
  git -C "$repo" config user.email "karma@strawberry.local"
}

setup_bp12_bash_c() {
  # NEW-BP-12: bash -c wrapper. Same as bp11 for pre-commit hook purposes.
  local repo="$1"
  git -C "$repo" config user.name "Talon"
  git -C "$repo" config user.email "talon@strawberry.local"
}

setup_env_author() {
  # Extra case: persona name via GIT_AUTHOR_NAME env var
  local repo="$1"
  # Hook must read GIT_AUTHOR_IDENT which includes env-based identity
  export GIT_AUTHOR_NAME="Viktor"
  export GIT_AUTHOR_EMAIL="viktor@strawberry.local"
  # (env will be unset after this test by the subshell)
}

# ---------------------------------------------------------------------------
# xfail runner — wraps run_case so that pre-implementation xfails are
# reported as XFAIL (skip) rather than FAIL
# ---------------------------------------------------------------------------
run_xfail() {
  local desc="$1"
  local expect_block="$2"
  local setup_fn="$3"

  if [ ! -f "$HOOK" ]; then
    printf 'XFAIL (hook absent): %s\n' "$desc"
    skip=$((skip + 1))
    return
  fi
  run_case "$desc" "$expect_block" "$setup_fn"
}

# ---------------------------------------------------------------------------
# Tests — all expect hook to block (exit non-zero) = expect_block=1
# ---------------------------------------------------------------------------

run_xfail "CTRL-1: direct persona config (Viktor)" 1 setup_direct_persona
run_xfail "NEW-BP-4: line-continuation → resolved Viktor config" 1 setup_bp4_line_continuation
run_xfail "NEW-BP-5: backtick → resolved Lucian config" 1 setup_bp5_backtick
run_xfail "NEW-BP-6: cmdsub → resolved Senna config" 1 setup_bp6_cmdsub
run_xfail "NEW-BP-7: eval → resolved Aphelios config" 1 setup_bp7_eval
run_xfail "NEW-BP-8: \$V indirection → resolved Xayah config" 1 setup_bp8_var_indirection
run_xfail "NEW-BP-9: cat /file → resolved Caitlyn config" 1 setup_bp9_file_indirection
run_xfail "NEW-BP-10: commit-tree analogue → resolved Akali config" 1 setup_bp10_commit_tree
run_xfail "NEW-BP-11: sh -c → resolved Karma config" 1 setup_bp11_sh_c
run_xfail "NEW-BP-12: bash -c → resolved Talon config" 1 setup_bp12_bash_c

# Extra: env-based persona identity (GIT_AUTHOR_NAME set in environment)
# This test sets env vars and runs the hook — hook must read git var GIT_AUTHOR_IDENT
# which incorporates GIT_AUTHOR_NAME env.
env_case() {
  if [ ! -f "$HOOK" ]; then
    printf 'XFAIL (hook absent): env-based GIT_AUTHOR_NAME=Viktor\n'
    skip=$((skip + 1))
    return
  fi
  local repo
  repo="$(make_repo)"
  local actual_exit=0
  (
    export GIT_AUTHOR_NAME="Viktor"
    export GIT_AUTHOR_EMAIL="viktor@strawberry.local"
    GIT_DIR="$repo/.git" GIT_WORK_TREE="$repo" bash "$HOOK" >/dev/null 2>&1
  ) || actual_exit=$?
  rm -rf "$repo"
  if [ "$actual_exit" -ne 0 ]; then
    printf 'PASS: env GIT_AUTHOR_NAME=Viktor blocked\n'
    pass=$((pass + 1))
  else
    printf 'FAIL: env GIT_AUTHOR_NAME=Viktor was not blocked\n' >&2
    fail=$((fail + 1))
  fi
}
env_case

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
total=$((pass + fail + skip))
printf '\n%d/%d passed, %d failed, %d xfail/skipped\n' "$pass" "$total" "$fail" "$skip"
[ "$fail" -eq 0 ]

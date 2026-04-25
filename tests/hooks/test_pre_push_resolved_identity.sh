#!/usr/bin/env bash
# tests/hooks/test_pre_push_resolved_identity.sh
#
# xfail test suite for scripts/hooks/pre-push-resolved-identity.sh
#
# Plan: plans/approved/personal/2026-04-25-resolved-identity-enforcement.md
# T1: xfail tests (NEW-BP-4 through NEW-BP-12 reproducers for pre-push backstop)
#
# Each test creates a local "upstream" repo and a "downstream" repo,
# makes a commit with persona identity (using the bypass technique under test),
# then pipes the ref-update record to the hook and asserts non-zero exit.
#
# The pre-push hook reads `git cat-file commit <sha>` to inspect author/committer
# headers — it sees the resolved values in the commit object, bypassing every
# shell-expansion indirection.
#
# xfail: all cases below xfail until the hook is implemented (T3).
# After T3 the xfail markers are removed.
#
# Tests:
#   CTRL-1  baseline: direct persona config commit
#   NEW-BP-4..9  all produce the same observable (persona identity in commit object)
#   NEW-BP-10 git commit-tree plumbing — this is the key backstop case
#   NEW-BP-11 sh -c wrapper commit
#   NEW-BP-12 bash -c wrapper commit

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

HOOK="$REPO_ROOT/scripts/hooks/pre-push-resolved-identity.sh"

pass=0
fail=0
skip=0

ZERO_SHA="0000000000000000000000000000000000000000"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

make_upstream() {
  local dir
  dir="$(mktemp -d)"
  git -C "$dir" init -q --bare
  printf '%s' "$dir"
}

make_downstream() {
  local upstream="$1"
  local dir
  dir="$(mktemp -d)"
  git -C "$dir" init -q
  git -C "$dir" remote add origin "$upstream"
  git -C "$dir" config user.name "Duongntd"
  git -C "$dir" config user.email "103487096+Duongntd@users.noreply.github.com"
  # seed the upstream
  git -C "$dir" commit --allow-empty -q -m "init"
  git -C "$dir" push -q origin HEAD:refs/heads/main 2>/dev/null
  printf '%s' "$dir"
}

run_push_case() {
  local desc="$1"
  local setup_fn="$2"  # called with (downstream_dir upstream_dir), returns sha on stdout

  if [ ! -f "$HOOK" ]; then
    printf 'XFAIL (hook absent): %s\n' "$desc"
    skip=$((skip + 1))
    return
  fi

  local upstream downstream sha
  upstream="$(make_upstream)"
  downstream="$(make_downstream "$upstream")"

  sha="$("$setup_fn" "$downstream" "$upstream")"

  if [ -z "$sha" ]; then
    printf 'FAIL: %s (setup did not produce a sha)\n' "$desc" >&2
    fail=$((fail + 1))
    rm -rf "$upstream" "$downstream"
    return
  fi

  # Get the remote sha for refs/heads/main
  remote_sha="$(git -C "$downstream" ls-remote "$upstream" refs/heads/main 2>/dev/null | awk '{print $1}')"
  [ -z "$remote_sha" ] && remote_sha="$ZERO_SHA"

  # Pipe the ref-update line to the hook
  local actual_exit=0
  printf 'refs/heads/test-branch %s refs/heads/test-branch %s\n' "$sha" "$remote_sha" \
    | GIT_DIR="$downstream/.git" bash "$HOOK" origin "$upstream" >/dev/null 2>&1 \
    || actual_exit=$?

  rm -rf "$upstream" "$downstream"

  if [ "$actual_exit" -ne 0 ]; then
    printf 'PASS: %s\n' "$desc"
    pass=$((pass + 1))
  else
    printf 'FAIL: %s (hook exited 0, expected non-zero)\n' "$desc" >&2
    fail=$((fail + 1))
  fi
}

# ---------------------------------------------------------------------------
# Setup functions — each makes a persona-authored commit and echoes the sha
# ---------------------------------------------------------------------------

setup_direct_persona() {
  local repo="$1"
  git -C "$repo" config user.name "Viktor"
  git -C "$repo" config user.email "viktor@strawberry.local"
  git -C "$repo" commit --allow-empty -q -m "persona commit"
  git -C "$repo" rev-parse HEAD
}

setup_bp4_line_continuation() {
  local repo="$1"
  # The bypass technique (line-continuation) is in how the agent ran the commit;
  # the commit object itself carries the resolved persona identity.
  git -C "$repo" config user.name "Viktor"
  git -C "$repo" config user.email "viktor@strawberry.local"
  git -C "$repo" commit --allow-empty -q -m "bp4 line-cont commit"
  git -C "$repo" rev-parse HEAD
}

setup_bp5_backtick() {
  local repo="$1"
  git -C "$repo" config user.name "Lucian"
  git -C "$repo" config user.email "lucian@strawberry.local"
  git -C "$repo" commit --allow-empty -q -m "bp5 backtick commit"
  git -C "$repo" rev-parse HEAD
}

setup_bp6_cmdsub() {
  local repo="$1"
  git -C "$repo" config user.name "Senna"
  git -C "$repo" config user.email "senna@strawberry.local"
  git -C "$repo" commit --allow-empty -q -m "bp6 cmdsub commit"
  git -C "$repo" rev-parse HEAD
}

setup_bp7_eval() {
  local repo="$1"
  git -C "$repo" config user.name "Aphelios"
  git -C "$repo" config user.email "aphelios@strawberry.local"
  git -C "$repo" commit --allow-empty -q -m "bp7 eval commit"
  git -C "$repo" rev-parse HEAD
}

setup_bp8_var_indirection() {
  local repo="$1"
  git -C "$repo" config user.name "Xayah"
  git -C "$repo" config user.email "xayah@strawberry.local"
  git -C "$repo" commit --allow-empty -q -m "bp8 var-indirection commit"
  git -C "$repo" rev-parse HEAD
}

setup_bp9_file_indirection() {
  local repo="$1"
  git -C "$repo" config user.name "Caitlyn"
  git -C "$repo" config user.email "caitlyn@strawberry.local"
  git -C "$repo" commit --allow-empty -q -m "bp9 file-indirection commit"
  git -C "$repo" rev-parse HEAD
}

setup_bp10_commit_tree() {
  # NEW-BP-10: git commit-tree plumbing bypasses pre-commit.
  # This is the KEY backstop test — the pre-push hook must catch this.
  local repo="$1"
  # Make a tree from current HEAD
  local tree sha
  tree="$(git -C "$repo" rev-parse HEAD^{tree})"
  sha="$(GIT_AUTHOR_NAME="Akali" GIT_AUTHOR_EMAIL="akali@strawberry.local" \
    GIT_COMMITTER_NAME="Akali" GIT_COMMITTER_EMAIL="akali@strawberry.local" \
    git -C "$repo" commit-tree "$tree" -m "bp10 commit-tree" -p HEAD)"
  # Update the local branch ref to point at the plumbing commit
  git -C "$repo" update-ref refs/heads/test-branch "$sha"
  printf '%s' "$sha"
}

setup_bp11_sh_c() {
  local repo="$1"
  git -C "$repo" config user.name "Karma"
  git -C "$repo" config user.email "karma@strawberry.local"
  git -C "$repo" commit --allow-empty -q -m "bp11 sh-c commit"
  git -C "$repo" rev-parse HEAD
}

setup_bp12_bash_c() {
  local repo="$1"
  git -C "$repo" config user.name "Talon"
  git -C "$repo" config user.email "talon@strawberry.local"
  git -C "$repo" commit --allow-empty -q -m "bp12 bash-c commit"
  git -C "$repo" rev-parse HEAD
}

# ---------------------------------------------------------------------------
# Run all xfail cases
# ---------------------------------------------------------------------------

run_push_case "CTRL-1: direct persona config commit (Viktor)" setup_direct_persona
run_push_case "NEW-BP-4: line-continuation → persona commit object" setup_bp4_line_continuation
run_push_case "NEW-BP-5: backtick → persona commit object (Lucian)" setup_bp5_backtick
run_push_case "NEW-BP-6: cmdsub → persona commit object (Senna)" setup_bp6_cmdsub
run_push_case "NEW-BP-7: eval → persona commit object (Aphelios)" setup_bp7_eval
run_push_case "NEW-BP-8: \$V indirection → persona commit object (Xayah)" setup_bp8_var_indirection
run_push_case "NEW-BP-9: file indirection → persona commit object (Caitlyn)" setup_bp9_file_indirection
run_push_case "NEW-BP-10: git commit-tree plumbing (Akali) — pre-push backstop" setup_bp10_commit_tree
run_push_case "NEW-BP-11: sh -c → persona commit object (Karma)" setup_bp11_sh_c
run_push_case "NEW-BP-12: bash -c → persona commit object (Talon)" setup_bp12_bash_c

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
total=$((pass + fail + skip))
printf '\n%d/%d passed, %d failed, %d xfail/skipped\n' "$pass" "$total" "$fail" "$skip"
[ "$fail" -eq 0 ]

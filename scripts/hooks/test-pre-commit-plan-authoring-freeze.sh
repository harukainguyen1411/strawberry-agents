#!/usr/bin/env bash
# test-pre-commit-plan-authoring-freeze.sh
# Regression tests for pre-commit-plan-authoring-freeze.sh bypass logic.
#
# Run: bash scripts/hooks/test-pre-commit-plan-authoring-freeze.sh
# Requires: git, a throwaway test repo (created in /tmp)

set -euo pipefail

PASS=0
FAIL=0

HOOK="$(cd "$(dirname "$0")" && pwd)/pre-commit-plan-authoring-freeze.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_setup_repo() {
  local dir
  dir="$(mktemp -d /tmp/freeze-test-XXXXXX)"
  git -C "$dir" init -q
  git -C "$dir" config user.email "$1"
  git -C "$dir" config user.name "Test"
  # Seed an initial commit so HEAD exists
  touch "$dir/README"
  git -C "$dir" add README
  git -C "$dir" commit -q -m "init"
  echo "$dir"
}

_stage_new_proposed() {
  local dir="$1"
  mkdir -p "$dir/plans/proposed"
  echo "---" > "$dir/plans/proposed/test-plan.md"
  git -C "$dir" add "plans/proposed/test-plan.md"
}

_write_commit_msg() {
  local dir="$1" msg="$2"
  local git_dir
  git_dir="$(cd "$dir" && git rev-parse --absolute-git-dir 2>/dev/null || echo "$dir/.git")"
  printf '%s\n' "$msg" > "$git_dir/COMMIT_EDITMSG"
}

_run_hook() {
  local dir="$1"
  local git_dir author_email
  # Use absolute path for GIT_DIR so the hook can resolve COMMIT_EDITMSG correctly.
  git_dir="$(cd "$dir" && git rev-parse --absolute-git-dir 2>/dev/null || echo "$dir/.git")"
  author_email="$(git -C "$dir" config user.email)"
  # cd into the work tree so git diff --cached resolves against the right index.
  (cd "$dir" && GIT_DIR="$git_dir" GIT_WORK_TREE="$dir" GIT_AUTHOR_EMAIL="$author_email" \
    sh "$HOOK" 2>/dev/null)
}

_assert() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf 'PASS: %s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf 'FAIL: %s  (expected exit %s, got %s)\n' "$label" "$expected" "$actual"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# Test 1: No new proposed files — hook exits 0 regardless of identity
# ---------------------------------------------------------------------------
t1_dir="$(_setup_repo "nobody@example.com")"
_run_hook "$t1_dir" && rc=$? || rc=$?
_assert "no-new-proposed exits 0" 0 "$rc"
rm -rf "$t1_dir"

# ---------------------------------------------------------------------------
# Test 2: New proposed file, no bypass — hook exits 1
# ---------------------------------------------------------------------------
t2_dir="$(_setup_repo "nobody@example.com")"
_stage_new_proposed "$t2_dir"
_write_commit_msg "$t2_dir" "chore: add plan"
_run_hook "$t2_dir" && rc=$? || rc=$?
_assert "new-proposed no-bypass blocked (exit 1)" 1 "$rc"
rm -rf "$t2_dir"

# ---------------------------------------------------------------------------
# Test 3: New proposed file + Orianna-Bypass from ADMIN identity — exits 0
# ---------------------------------------------------------------------------
t3_dir="$(_setup_repo "harukainguyen1411@gmail.com")"
_stage_new_proposed "$t3_dir"
_write_commit_msg "$t3_dir" "$(printf 'chore: bulk demotion\n\nOrianna-Bypass: bulk demotion per §D8')"
_run_hook "$t3_dir" && rc=$? || rc=$?
_assert "admin bypass accepted (exit 0)" 0 "$rc"
rm -rf "$t3_dir"

# ---------------------------------------------------------------------------
# Test 4: New proposed file + Orianna-Bypass from AGENT identity (gmail) — exits 1
# ---------------------------------------------------------------------------
t4_dir="$(_setup_repo "duong.nguyen.thai.duy@gmail.com")"
_stage_new_proposed "$t4_dir"
_write_commit_msg "$t4_dir" "$(printf 'chore: bulk demotion\n\nOrianna-Bypass: bulk demotion per §D8')"
_run_hook "$t4_dir" && rc=$? || rc=$?
_assert "agent gmail bypass blocked (exit 1)" 1 "$rc"
rm -rf "$t4_dir"

# ---------------------------------------------------------------------------
# Test 5: New proposed file + Orianna-Bypass from AGENT identity (noreply) — exits 1
# ---------------------------------------------------------------------------
t5_dir="$(_setup_repo "103487096+Duongntd@users.noreply.github.com")"
_stage_new_proposed "$t5_dir"
_write_commit_msg "$t5_dir" "$(printf 'chore: bulk demotion\n\nOrianna-Bypass: bulk demotion per §D8')"
_run_hook "$t5_dir" && rc=$? || rc=$?
_assert "agent noreply bypass blocked (exit 1)" 1 "$rc"
rm -rf "$t5_dir"

# ---------------------------------------------------------------------------
# Test 6: Bypass reason too short (<10 chars) — treated as no bypass, exits 1
# ---------------------------------------------------------------------------
t6_dir="$(_setup_repo "harukainguyen1411@gmail.com")"
_stage_new_proposed "$t6_dir"
_write_commit_msg "$t6_dir" "$(printf 'chore: add plan\n\nOrianna-Bypass: short')"
_run_hook "$t6_dir" && rc=$? || rc=$?
_assert "bypass reason too short blocked (exit 1)" 1 "$rc"
rm -rf "$t6_dir"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

#!/usr/bin/env bash
# test-pre-commit-plan-structure.sh
# Regression tests for pre-commit-plan-structure.sh and _lib_plan_structure.sh.
#
# Rule 12: this file is committed BEFORE the implementation as an xfail test.
# All tests initially fail (hook does not exist yet); green after T3 impl commit.
#
# Run: bash scripts/hooks/test-pre-commit-plan-structure.sh
#
# Exit: 0 if all tests pass, 1 if any fail.

set -euo pipefail

PASS=0
FAIL=0
XFAIL=0  # expected failures before implementation lands

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO_ROOT/scripts/hooks/pre-commit-plan-structure.sh"
LIB="$REPO_ROOT/scripts/_lib_plan_structure.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

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

# Run the hook as if called from inside a git repo with a given set of staged files.
# Usage: _run_hook_with_staged <repo_dir> <file1> [file2 ...]
# Requires that the files already exist in <repo_dir>.
_run_hook_with_staged() {
  local dir="$1"; shift
  # Stage the given files
  for f in "$@"; do
    git -C "$dir" add "$f" 2>/dev/null || true
  done
  # Run hook; capture exit
  (cd "$dir" && bash "$HOOK" 2>/dev/null) && echo 0 || echo $?
}

# Setup a minimal git repo in /tmp
_setup_repo() {
  local dir
  dir="$(mktemp -d /tmp/plan-struct-test-XXXXXX)"
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  touch "$dir/README"
  git -C "$dir" add README
  git -C "$dir" commit -q -m "init"
  # Mirror the scripts dir so the hook can source libs
  mkdir -p "$dir/scripts/hooks"
  cp "$REPO_ROOT/scripts/_lib_plan_structure.sh" "$dir/scripts/"
  cp "$REPO_ROOT/scripts/_lib_orianna_estimates.sh" "$dir/scripts/"
  cp "$HOOK" "$dir/scripts/hooks/"
  echo "$dir"
}

_write_good_plan() {
  local dir="$1" path="$2"
  mkdir -p "$dir/$(dirname "$path")"
  cat > "$dir/$path" <<'PLAN'
---
status: proposed
concern: personal
owner: karma
created: 2026-04-20
orianna_gate_version: 2
tests_required: true
tags: [test]
---

# Good plan

## 1. Problem & motivation

This plan tests the linter.

## 2. Decision

Ship it.

## 6. Tasks

- [ ] **T1** — Do the thing. estimate_minutes: 10. DoD: done.

## Test plan

This plan is covered by the unit test suite.

## Rollback

Revert the commit.

## Open questions

None.
PLAN
}

_write_plan_missing_key() {
  local dir="$1" path="$2"
  mkdir -p "$dir/$(dirname "$path")"
  cat > "$dir/$path" <<'PLAN'
---
status: proposed
owner: karma
created: 2026-04-20
orianna_gate_version: 2
tests_required: true
tags: [test]
---

# Missing concern

## 1. Problem & motivation

Missing concern field.

## 6. Tasks

- [ ] **T1** — Do it. estimate_minutes: 5. DoD: done.

## Test plan

Tests here.

## Rollback

Revert.

## Open questions

None.
PLAN
}

_write_plan_missing_estimate() {
  local dir="$1" path="$2"
  mkdir -p "$dir/$(dirname "$path")"
  cat > "$dir/$path" <<'PLAN'
---
status: proposed
concern: personal
owner: karma
created: 2026-04-20
orianna_gate_version: 2
tests_required: true
tags: [test]
---

# Missing estimate

## 6. Tasks

- [ ] **T1** — No estimate field. DoD: done.

## Test plan

Tests here.

## Rollback

Revert.

## Open questions

None.
PLAN
}

_write_plan_banned_literal() {
  local dir="$1" path="$2"
  mkdir -p "$dir/$(dirname "$path")"
  cat > "$dir/$path" <<'PLAN'
---
status: proposed
concern: personal
owner: karma
created: 2026-04-20
orianna_gate_version: 2
tests_required: true
tags: [test]
---

# Banned literal

## 6. Tasks

- [ ] **T1** — Takes about 2(d) to complete. estimate_minutes: 10. DoD: done.

## Test plan

Tests here.

## Rollback

Revert.

## Open questions

None.
PLAN
}

_write_plan_missing_test_plan() {
  local dir="$1" path="$2"
  mkdir -p "$dir/$(dirname "$path")"
  cat > "$dir/$path" <<'PLAN'
---
status: proposed
concern: personal
owner: karma
created: 2026-04-20
orianna_gate_version: 2
tests_required: true
tags: [test]
---

# Missing test plan section

## 6. Tasks

- [ ] **T1** — Do it. estimate_minutes: 5. DoD: done.

## Rollback

Revert.

## Open questions

None.
PLAN
}

# ---------------------------------------------------------------------------
# Guard: hook must exist (xfail if absent)
# ---------------------------------------------------------------------------

if [ ! -f "$HOOK" ]; then
  printf 'XFAIL (expected): hook not yet implemented at %s\n' "$HOOK"
  XFAIL=$((XFAIL + 1))
  printf '\n%d passed, %d failed, %d xfail (pre-impl)\n' "$PASS" "$FAIL" "$XFAIL"
  # Exit 0 during xfail phase so CI does not red before implementation
  exit 0
fi

# ---------------------------------------------------------------------------
# Test (a): clean plan passes — exit 0
# ---------------------------------------------------------------------------
ta_dir="$(_setup_repo)"
_write_good_plan "$ta_dir" "plans/proposed/good-plan.md"
rc="$(_run_hook_with_staged "$ta_dir" "plans/proposed/good-plan.md")"
_assert "(a) clean plan passes" 0 "$rc"
rm -rf "$ta_dir"

# ---------------------------------------------------------------------------
# Test (b): missing frontmatter key fails with specific message — exit 1
# ---------------------------------------------------------------------------
tb_dir="$(_setup_repo)"
_write_plan_missing_key "$tb_dir" "plans/proposed/missing-key.md"
git -C "$tb_dir" add "plans/proposed/missing-key.md"
tb_stderr="$( (cd "$tb_dir" && bash "$HOOK") 2>&1 >/dev/null || true )"
tb_rc="$( (cd "$tb_dir" && bash "$HOOK") && echo 0 || echo $? )"
_assert "(b) missing frontmatter key blocks (exit 1)" 1 "$tb_rc"
# Check message contains the expected key name
if printf '%s' "$tb_stderr" | grep -q 'concern'; then
  _assert "(b) error message names the missing key" "yes" "yes"
else
  _assert "(b) error message names the missing key" "yes" "no"
fi
rm -rf "$tb_dir"

# ---------------------------------------------------------------------------
# Test (c): task missing estimate_minutes fails — exit 1
# ---------------------------------------------------------------------------
tc_dir="$(_setup_repo)"
_write_plan_missing_estimate "$tc_dir" "plans/proposed/no-estimate.md"
rc="$(_run_hook_with_staged "$tc_dir" "plans/proposed/no-estimate.md")"
_assert "(c) missing estimate_minutes blocks (exit 1)" 1 "$rc"
rm -rf "$tc_dir"

# ---------------------------------------------------------------------------
# Test (d): banned literal (d) fails — exit 1
# ---------------------------------------------------------------------------
td_dir="$(_setup_repo)"
_write_plan_banned_literal "$td_dir" "plans/proposed/banned.md"
rc="$(_run_hook_with_staged "$td_dir" "plans/proposed/banned.md")"
_assert "(d) banned literal (d) blocks (exit 1)" 1 "$rc"
rm -rf "$td_dir"

# ---------------------------------------------------------------------------
# Test (e): tests_required: true + missing ## Test plan fails — exit 1
# ---------------------------------------------------------------------------
te_dir="$(_setup_repo)"
_write_plan_missing_test_plan "$te_dir" "plans/proposed/no-test-plan.md"
rc="$(_run_hook_with_staged "$te_dir" "plans/proposed/no-test-plan.md")"
_assert "(e) missing Test plan section blocks (exit 1)" 1 "$rc"
rm -rf "$te_dir"

# ---------------------------------------------------------------------------
# Test (f): plans/_template.md is skipped — exit 0
# ---------------------------------------------------------------------------
tf_dir="$(_setup_repo)"
# Copy the real template (which has placeholder values that would fail lint)
mkdir -p "$tf_dir/plans"
cp "$REPO_ROOT/plans/_template.md" "$tf_dir/plans/_template.md"
rc="$(_run_hook_with_staged "$tf_dir" "plans/_template.md")"
_assert "(f) plans/_template.md is skipped (exit 0)" 0 "$rc"
rm -rf "$tf_dir"

# ---------------------------------------------------------------------------
# Test (g): plans/archived/** is skipped — exit 0
# ---------------------------------------------------------------------------
tg_dir="$(_setup_repo)"
# Write a broken plan under archived/ — should not be checked
_write_plan_missing_key "$tg_dir" "plans/archived/old-plan.md"
rc="$(_run_hook_with_staged "$tg_dir" "plans/archived/old-plan.md")"
_assert "(g) plans/archived/** is skipped (exit 0)" 0 "$rc"
rm -rf "$tg_dir"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

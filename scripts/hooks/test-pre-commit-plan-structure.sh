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
HOOK="$REPO_ROOT/scripts/hooks/pre-commit-zz-plan-structure.sh"
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
  local local_hook="$dir/scripts/hooks/pre-commit-zz-plan-structure.sh"
  # Stage the given files
  for f in "$@"; do
    git -C "$dir" add "$f" 2>/dev/null || true
  done
  # Run the hook copy local to the test repo so REPO_ROOT resolves correctly
  (cd "$dir" && bash "$local_hook" 2>/dev/null) && echo 0 || echo $?
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
  cp "$HOOK" "$dir/scripts/hooks/pre-commit-zz-plan-structure.sh"
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
tb_local_hook="$tb_dir/scripts/hooks/pre-commit-zz-plan-structure.sh"
tb_stderr="$( (cd "$tb_dir" && bash "$tb_local_hook") 2>&1 1>/dev/null || true )"
tb_rc="$( (cd "$tb_dir" && bash "$tb_local_hook") 2>/dev/null && echo 0 || echo $? )"
_assert "(b) missing frontmatter key blocks (exit 1)" 1 "$tb_rc"
# Check message contains the expected key name (tightened to actual message format)
if printf '%s' "$tb_stderr" | grep -q 'missing required frontmatter field: .concern'; then
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
# Test (h): tests_required: false skips ## Test plan check — exit 0
# ---------------------------------------------------------------------------
th_dir="$(_setup_repo)"
mkdir -p "$th_dir/plans/proposed"
cat > "$th_dir/plans/proposed/no-test-needed.md" <<'PLAN'
---
status: proposed
concern: personal
owner: karma
created: 2026-04-20
orianna_gate_version: 2
tests_required: false
tags: [test]
---

# No test plan needed

## 1. Problem & motivation

Infra-only change.

## 6. Tasks

- [ ] **T1** — Do the thing. estimate_minutes: 10. DoD: done.

## Rollback

Revert.

## Open questions

None.
PLAN
rc="$(_run_hook_with_staged "$th_dir" "plans/proposed/no-test-needed.md")"
_assert "(h) tests_required: false skips Test plan check (exit 0)" 0 "$rc"
rm -rf "$th_dir"

# ---------------------------------------------------------------------------
# Test (i): empty-value frontmatter key fails (B3 regression lock)
# ---------------------------------------------------------------------------
ti_dir="$(_setup_repo)"
mkdir -p "$ti_dir/plans/proposed"
cat > "$ti_dir/plans/proposed/empty-concern.md" <<'PLAN'
---
status: proposed
concern:
owner: karma
created: 2026-04-20
orianna_gate_version: 2
tests_required: true
tags: [test]
---

# Empty concern value

## 1. Problem & motivation

Tests empty value detection.

## 6. Tasks

- [ ] **T1** — Do it. estimate_minutes: 5. DoD: done.

## Test plan

Tests here.

## Rollback

Revert.

## Open questions

None.
PLAN
git -C "$ti_dir" add "plans/proposed/empty-concern.md"
ti_stderr="$( (cd "$ti_dir" && bash "$ti_dir/scripts/hooks/pre-commit-zz-plan-structure.sh") 2>&1 1>/dev/null || true )"
ti_rc="$( (cd "$ti_dir" && bash "$ti_dir/scripts/hooks/pre-commit-zz-plan-structure.sh") 2>/dev/null && echo 0 || echo $? )"
_assert "(i) empty-value frontmatter key blocks (exit 1)" 1 "$ti_rc"
if printf '%s' "$ti_stderr" | grep -q 'missing required frontmatter field: .concern'; then
  _assert "(i) error message names the empty key" "yes" "yes"
else
  _assert "(i) error message names the empty key" "yes" "no"
fi
rm -rf "$ti_dir"

# ---------------------------------------------------------------------------
# Test (j): multi-file staged batch — both files checked
# ---------------------------------------------------------------------------
tj_dir="$(_setup_repo)"
_write_good_plan "$tj_dir" "plans/proposed/good1.md"
_write_plan_missing_estimate "$tj_dir" "plans/proposed/bad1.md"
git -C "$tj_dir" add "plans/proposed/good1.md" "plans/proposed/bad1.md"
tj_local_hook="$tj_dir/scripts/hooks/pre-commit-zz-plan-structure.sh"
tj_rc="$( (cd "$tj_dir" && bash "$tj_local_hook") 2>/dev/null && echo 0 || echo $? )"
_assert "(j) multi-file batch: bad file blocks even with good file present (exit 1)" 1 "$tj_rc"
rm -rf "$tj_dir"

# ---------------------------------------------------------------------------
# Test (k): estimate boundary — 0 is rejected, 61 is rejected, negative rejected
# ---------------------------------------------------------------------------
tk_dir="$(_setup_repo)"
mkdir -p "$tk_dir/plans/proposed"
cat > "$tk_dir/plans/proposed/bad-estimate-zero.md" <<'PLAN'
---
status: proposed
concern: personal
owner: karma
created: 2026-04-20
orianna_gate_version: 2
tests_required: false
tags: [test]
---

# Zero estimate

## 6. Tasks

- [ ] **T1** — Zero estimate. estimate_minutes: 0. DoD: done.

## Rollback

Revert.

## Open questions

None.
PLAN
rc_zero="$(_run_hook_with_staged "$tk_dir" "plans/proposed/bad-estimate-zero.md")"
_assert "(k1) estimate_minutes: 0 blocks (exit 1)" 1 "$rc_zero"
rm -rf "$tk_dir"

tk2_dir="$(_setup_repo)"
mkdir -p "$tk2_dir/plans/proposed"
cat > "$tk2_dir/plans/proposed/bad-estimate-61.md" <<'PLAN'
---
status: proposed
concern: personal
owner: karma
created: 2026-04-20
orianna_gate_version: 2
tests_required: false
tags: [test]
---

# Over-limit estimate

## 6. Tasks

- [ ] **T1** — Too long. estimate_minutes: 61. DoD: done.

## Rollback

Revert.

## Open questions

None.
PLAN
rc_61="$(_run_hook_with_staged "$tk2_dir" "plans/proposed/bad-estimate-61.md")"
_assert "(k2) estimate_minutes: 61 blocks (exit 1)" 1 "$rc_61"
rm -rf "$tk2_dir"

tk3_dir="$(_setup_repo)"
mkdir -p "$tk3_dir/plans/proposed"
cat > "$tk3_dir/plans/proposed/bad-estimate-neg.md" <<'PLAN'
---
status: proposed
concern: personal
owner: karma
created: 2026-04-20
orianna_gate_version: 2
tests_required: false
tags: [test]
---

# Negative estimate

## 6. Tasks

- [ ] **T1** — Negative. estimate_minutes: -5. DoD: done.

## Rollback

Revert.

## Open questions

None.
PLAN
rc_neg="$(_run_hook_with_staged "$tk3_dir" "plans/proposed/bad-estimate-neg.md")"
_assert "(k3) estimate_minutes: -5 blocks (exit 1)" 1 "$rc_neg"
rm -rf "$tk3_dir"

# ---------------------------------------------------------------------------
# Test (l): OQ hardening — check_task_estimates on the approved plan (quirk lock)
# Calls check_task_estimates from the lib directly on the approved plan.
# The approved plan contains (d) enumeration labels in its DoD prose; verify
# the current behaviour (pass or fail) is locked in.
# ---------------------------------------------------------------------------
tl_plan="$REPO_ROOT/plans/approved/personal/2026-04-20-plan-structure-prelint.md"
if [ -f "$tl_plan" ]; then
  # Source the lib to get check_task_estimates (which delegates to check_estimate_minutes)
  # shellcheck source=scripts/_lib_plan_structure.sh
  . "$LIB"
  tl_rc=0
  check_task_estimates "$tl_plan" 2>/dev/null || tl_rc=$?
  # Document current behaviour: the plan uses (d) enumeration labels inside DoD prose,
  # but those appear in non-task lines so check_estimate_minutes passes (exit 0) today.
  # This test locks that behaviour in with eyes open (OQ hardening option b).
  # If this starts failing, a new task line with a literal (d) must have been added.
  _assert "(l) OQ: check_task_estimates on approved plan passes today (quirk lock)" 0 "$tl_rc"
else
  printf 'SKIP: (l) approved plan not found at %s\n' "$tl_plan"
fi

# ---------------------------------------------------------------------------
# Rule 1 — canonical ## Tasks heading
# (1a) plan with only ## Task breakdown (Foo) variant → BLOCK (exit 1)
# (1b) plan with both variant and canonical heading → PASS (exit 0)
# ---------------------------------------------------------------------------

# (1a) variant-only heading
t1a_dir="$(_setup_repo)"
mkdir -p "$t1a_dir/plans/proposed"
cat > "$t1a_dir/plans/proposed/variant-heading.md" <<'PLAN'
---
status: proposed
concern: personal
owner: karma
created: 2026-04-21
orianna_gate_version: 2
tests_required: false
tags: [test]
---

# Variant heading only

## Task breakdown (Aphelios)

- [ ] **T1** — Do the thing. estimate_minutes: 10. DoD: done.

## Rollback

Revert.

## Open questions

None.
PLAN
rc="$(_run_hook_with_staged "$t1a_dir" "plans/proposed/variant-heading.md")"
_assert "(1a) variant-only ## Task breakdown heading blocks (exit 1)" 1 "$rc"
rm -rf "$t1a_dir"

# (1b) both variant AND canonical heading → PASS
t1b_dir="$(_setup_repo)"
mkdir -p "$t1b_dir/plans/proposed"
cat > "$t1b_dir/plans/proposed/both-headings.md" <<'PLAN'
---
status: proposed
concern: personal
owner: karma
created: 2026-04-21
orianna_gate_version: 2
tests_required: false
tags: [test]
---

# Both headings

## Task breakdown (notes)

Some prose here.

## Tasks

- [ ] **T1** — Do the thing. estimate_minutes: 10. DoD: done.

## Rollback

Revert.

## Open questions

None.
PLAN
rc="$(_run_hook_with_staged "$t1b_dir" "plans/proposed/both-headings.md")"
_assert "(1b) plan with both variant and canonical heading passes (exit 0)" 0 "$rc"
rm -rf "$t1b_dir"

# ---------------------------------------------------------------------------
# Rule 2 regression pin — table-column estimate (no key:value) → BLOCK
# ---------------------------------------------------------------------------
t2r_dir="$(_setup_repo)"
mkdir -p "$t2r_dir/plans/proposed"
cat > "$t2r_dir/plans/proposed/table-estimate.md" <<'PLAN'
---
status: proposed
concern: personal
owner: karma
created: 2026-04-21
orianna_gate_version: 2
tests_required: false
tags: [test]
---

# Table estimate only

## Tasks

| Task | estimate_minutes |
|------|-----------------|
| T1   | 10              |

- [ ] **T1** — Do the thing. DoD: done.

## Rollback

Revert.

## Open questions

None.
PLAN
rc="$(_run_hook_with_staged "$t2r_dir" "plans/proposed/table-estimate.md")"
_assert "(2r) task row with table-column estimate but no key:value blocks (exit 1)" 1 "$rc"
rm -rf "$t2r_dir"

# ---------------------------------------------------------------------------
# Rule 3 — test-task title qualifier
# (3a) task titled "**T1** — xfail hook behaviour" (no kind:test, no approved verb) → BLOCK
# (3b) same task with kind: test on line → PASS
# (3c) task titled "**T1** — Write xfail for hook" → PASS
# ---------------------------------------------------------------------------

# (3a) xfail qualifier, no kind:test, no approved verb → BLOCK
t3a_dir="$(_setup_repo)"
mkdir -p "$t3a_dir/plans/proposed"
cat > "$t3a_dir/plans/proposed/test-task-no-verb.md" <<'PLAN'
---
status: proposed
concern: personal
owner: karma
created: 2026-04-21
orianna_gate_version: 2
tests_required: false
tags: [test]
---

# Test task no approved verb

## Tasks

- [ ] **T1** — xfail hook behaviour. estimate_minutes: 10. DoD: done.

## Rollback

Revert.

## Open questions

None.
PLAN
rc="$(_run_hook_with_staged "$t3a_dir" "plans/proposed/test-task-no-verb.md")"
_assert "(3a) xfail-qualified task without kind:test or approved verb blocks (exit 1)" 1 "$rc"
rm -rf "$t3a_dir"

# (3b) xfail qualifier with kind: test → PASS
t3b_dir="$(_setup_repo)"
mkdir -p "$t3b_dir/plans/proposed"
cat > "$t3b_dir/plans/proposed/test-task-kind-test.md" <<'PLAN'
---
status: proposed
concern: personal
owner: karma
created: 2026-04-21
orianna_gate_version: 2
tests_required: false
tags: [test]
---

# Test task with kind:test

## Tasks

- [ ] **T1** — xfail hook behaviour. kind: test. estimate_minutes: 10. DoD: done.

## Rollback

Revert.

## Open questions

None.
PLAN
rc="$(_run_hook_with_staged "$t3b_dir" "plans/proposed/test-task-kind-test.md")"
_assert "(3b) xfail-qualified task with kind: test passes (exit 0)" 0 "$rc"
rm -rf "$t3b_dir"

# (3c) task titled with Write as first word after qualifier → PASS
t3c_dir="$(_setup_repo)"
mkdir -p "$t3c_dir/plans/proposed"
cat > "$t3c_dir/plans/proposed/test-task-write-verb.md" <<'PLAN'
---
status: proposed
concern: personal
owner: karma
created: 2026-04-21
orianna_gate_version: 2
tests_required: false
tags: [test]
---

# Test task with Write verb

## Tasks

- [ ] **T1** — Write xfail for hook. estimate_minutes: 10. DoD: done.

## Rollback

Revert.

## Open questions

None.
PLAN
rc="$(_run_hook_with_staged "$t3c_dir" "plans/proposed/test-task-write-verb.md")"
_assert "(3c) Write-prefixed xfail task passes (exit 0)" 0 "$rc"
rm -rf "$t3c_dir"

# ---------------------------------------------------------------------------
# Rule 4 — cited backtick paths must exist
# (4a) plan citing scripts/does-not-exist.sh without suppression → BLOCK
# (4b) same with <!-- orianna: ok --> on same line → PASS
# ---------------------------------------------------------------------------

# (4a) missing path, no suppression → BLOCK
t4a_dir="$(_setup_repo)"
mkdir -p "$t4a_dir/plans/proposed"
# Create a real file so repo root is populated for path checks
mkdir -p "$t4a_dir/scripts"
touch "$t4a_dir/scripts/real-file.sh"
git -C "$t4a_dir" add scripts/real-file.sh && git -C "$t4a_dir" commit -q -m "add real file"
cat > "$t4a_dir/plans/proposed/cite-missing-path.md" <<'PLAN'
---
status: proposed
concern: personal
owner: karma
created: 2026-04-21
orianna_gate_version: 2
tests_required: false
tags: [test]
---

# Cite missing path

## 1. Problem

See `scripts/does-not-exist.sh` for details.

## Tasks

- [ ] **T1** — Do the thing. estimate_minutes: 10. DoD: done.

## Rollback

Revert.

## Open questions

None.
PLAN
rc="$(_run_hook_with_staged "$t4a_dir" "plans/proposed/cite-missing-path.md")"
_assert "(4a) cited backtick path that does not exist blocks (exit 1)" 1 "$rc"
rm -rf "$t4a_dir"

# (4b) missing path with orianna:ok suppression → PASS
t4b_dir="$(_setup_repo)"
mkdir -p "$t4b_dir/plans/proposed"
mkdir -p "$t4b_dir/scripts"
touch "$t4b_dir/scripts/real-file.sh"
git -C "$t4b_dir" add scripts/real-file.sh && git -C "$t4b_dir" commit -q -m "add real file"
cat > "$t4b_dir/plans/proposed/cite-missing-suppressed.md" <<'PLAN'
---
status: proposed
concern: personal
owner: karma
created: 2026-04-21
orianna_gate_version: 2
tests_required: false
tags: [test]
---

# Cite missing path suppressed

## 1. Problem

See `scripts/does-not-exist.sh` for details. <!-- orianna: ok -->

## Tasks

- [ ] **T1** — Do the thing. estimate_minutes: 10. DoD: done.

## Rollback

Revert.

## Open questions

None.
PLAN
rc="$(_run_hook_with_staged "$t4b_dir" "plans/proposed/cite-missing-suppressed.md")"
_assert "(4b) missing backtick path with orianna:ok suppression passes (exit 0)" 0 "$rc"
rm -rf "$t4b_dir"

# ---------------------------------------------------------------------------
# Rule 5 — forward self-reference
# (5a) plan in plans/proposed/personal/2026-04-21-foo.md citing
#      plans/approved/personal/2026-04-21-foo.md without suppression → BLOCK
# (5b) same with suppression → PASS
# ---------------------------------------------------------------------------

# (5a) forward self-reference, no suppression → BLOCK
t5a_dir="$(_setup_repo)"
mkdir -p "$t5a_dir/plans/proposed/personal"
cat > "$t5a_dir/plans/proposed/personal/2026-04-21-foo.md" <<'PLAN'
---
status: proposed
concern: personal
owner: karma
created: 2026-04-21
orianna_gate_version: 2
tests_required: false
tags: [test]
---

# Foo plan

## 1. Problem

This plan will be promoted to `plans/approved/personal/2026-04-21-foo.md`.

## Tasks

- [ ] **T1** — Do the thing. estimate_minutes: 10. DoD: done.

## Rollback

Revert.

## Open questions

None.
PLAN
rc="$(_run_hook_with_staged "$t5a_dir" "plans/proposed/personal/2026-04-21-foo.md")"
_assert "(5a) forward self-reference without suppression blocks (exit 1)" 1 "$rc"
rm -rf "$t5a_dir"

# (5b) forward self-reference with suppression → PASS
t5b_dir="$(_setup_repo)"
mkdir -p "$t5b_dir/plans/proposed/personal"
cat > "$t5b_dir/plans/proposed/personal/2026-04-21-foo.md" <<'PLAN'
---
status: proposed
concern: personal
owner: karma
created: 2026-04-21
orianna_gate_version: 2
tests_required: false
tags: [test]
---

# Foo plan

## 1. Problem

This plan will be promoted to `plans/approved/personal/2026-04-21-foo.md`. <!-- orianna: ok -->

## Tasks

- [ ] **T1** — Do the thing. estimate_minutes: 10. DoD: done.

## Rollback

Revert.

## Open questions

None.
PLAN
rc="$(_run_hook_with_staged "$t5b_dir" "plans/proposed/personal/2026-04-21-foo.md")"
_assert "(5b) forward self-reference with orianna:ok suppression passes (exit 0)" 0 "$rc"
rm -rf "$t5b_dir"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

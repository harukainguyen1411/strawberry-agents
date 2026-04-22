#!/usr/bin/env bash
# test-orianna-sign-snapshot-trap-coverage.sh — xfail test for snapshot/restore
# trap coverage in scripts/orianna-sign.sh.
#
# PR #23 fast-follow (Senna residual): the T2 snapshot restore only fired on
# block_count>0 or claude_exit==1; other exit-2 paths and SIGINT/SIGTERM left
# pre-fix mutations on disk, violating Rule 1 (never leave uncommitted changes).
#
# xfail: against unpatched orianna-sign.sh the "claude not found" path (exit 1
# after pre-fix has mutated) does NOT restore the plan. Once the fix lands the
# plan must be restored on ALL non-zero exits and signals.
#
# Usage:
#   bash scripts/__tests__/test-orianna-sign-snapshot-trap-coverage.sh
#
# Exit codes:
#   0 — all assertions passed (trap covers all exit paths)
#   1 — test assertion failed
#   2 — test setup/infrastructure error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ORIANNA_SIGN="$REPO_ROOT/scripts/orianna-sign.sh"

pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }
info() { printf '[INFO] %s\n' "$*"; }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Run orianna-sign.sh with claude removed from PATH (simulates offline/missing
# claude CLI). This exercises the "claude not found → exit 1" branch which comes
# AFTER pre-fix has already run and mutated the plan.
run_without_claude() {
  local plan_file="$1" phase="$2"
  # Build a PATH that excludes every directory containing a 'claude' binary,
  # so the `command -v claude` check in orianna-sign.sh fails.
  local tmpbin
  tmpbin="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpbin'" RETURN

  # Collect all dirs on PATH that contain a 'claude' executable
  local bad_dirs=""
  local dir
  for dir in $(echo "$PATH" | tr ':' ' '); do
    [ -x "$dir/claude" ] && bad_dirs="$bad_dirs $dir"
  done

  # Build safe path excluding those dirs
  local safe_path="$tmpbin"
  for dir in $(echo "$PATH" | tr ':' ' '); do
    local bad=0
    local bd
    for bd in $bad_dirs; do
      [ "$dir" = "$bd" ] && bad=1 && break
    done
    [ "$bad" -eq 0 ] && safe_path="$safe_path:$dir"
  done

  # Run with --pre-fix forced so pre-fix always runs regardless of concern field
  PATH="$safe_path" \
    REPO="$REPO_ROOT" \
    bash "$ORIANNA_SIGN" --pre-fix "$plan_file" "$phase" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Test 1: "claude not found" path — pre-fix mutates, then claude check fails
#
# Scenario:
#   - Plan contains a `https://github.com/...` URL → real orianna-pre-fix.sh
#     appends a <!-- orianna: ok --> suppressor (Pass B).
#   - Then orianna-sign.sh cannot find claude CLI → exit 1.
#   - BEFORE fix: plan retains the mutation on disk.
#   - AFTER fix: plan is restored to original state.
# ---------------------------------------------------------------------------

info "=== Test 1: plan restored after 'claude not found' + pre-fix mutation ==="

TMPDIR1="$(mktemp -d)"
trap "rm -rf '$TMPDIR1'" EXIT

PLAN1="$TMPDIR1/test-plan.md"
ORIGINAL1='---
title: Test Plan
status: proposed
concern: personal
orianna_gate_version: 2
---
# Body

See `https://github.com/foo/bar` for details.
'
printf '%s' "$ORIGINAL1" > "$PLAN1"

# We need the plan inside a git repo because orianna-sign.sh resolves REPO_ROOT
# from the script location (not from REPO env). But we can override via REPO env.
# Set up a minimal git repo under TMPDIR1 so git commands don't touch the real repo.
git -C "$TMPDIR1" init -q
git -C "$TMPDIR1" config user.email "test@test.local"
git -C "$TMPDIR1" config user.name "Test"
git -C "$TMPDIR1" commit -q --allow-empty -m "init"

# orianna-sign.sh needs REPO to find REPO_ROOT; it also derives ORIANNA_PRE_FIX
# and other helper paths from $SCRIPT_DIR (the real scripts/ dir) — which is fine
# because we want the real orianna-pre-fix.sh to run.
# The PLAN_PATH must resolve inside REPO_ROOT per the script's phase-dir check.
# We'll set REPO to the real repo root but point to a plan in a temp location via
# an absolute PLAN_ARG (the script handles absolute plan paths).
#
# However, the phase-dir check validates PLAN_DIR against expected dir relative to
# REPO_ROOT. If we use an absolute path outside REPO_ROOT, the strip won't work.
# Strategy: use the real REPO_ROOT and place the temp plan inside plans/proposed/.

# Place temp plan in a real proposed dir but with a unique name
REAL_PROPOSED="$REPO_ROOT/plans/proposed/personal"
UNIQUE_PLAN="$REAL_PROPOSED/_talon-test-snapshot-trap-$$.md"

printf '%s' "$ORIGINAL1" > "$UNIQUE_PLAN"

cleanup_plan() {
  rm -f "$UNIQUE_PLAN"
}
trap cleanup_plan EXIT

ORIGINAL_CONTENT="$(cat "$UNIQUE_PLAN")"

info "plan before: $(wc -l < "$UNIQUE_PLAN") lines"

# Run with claude absent from PATH → exit 1 after pre-fix mutation
run_without_claude "$UNIQUE_PLAN" approved

ACTUAL_CONTENT="$(cat "$UNIQUE_PLAN")"

if [ "$ACTUAL_CONTENT" = "$ORIGINAL_CONTENT" ]; then
  pass "Test 1: plan restored to original after 'claude not found' exit path"
else
  fail "Test 1: plan NOT restored after 'claude not found' — pre-fix mutation leaked.
Lines expected: $(printf '%s' "$ORIGINAL_CONTENT" | wc -l)
Lines actual:   $(printf '%s' "$ACTUAL_CONTENT" | wc -l)
Diff (first 20 lines):
$(diff <(printf '%s\n' "$ORIGINAL_CONTENT") <(printf '%s\n' "$ACTUAL_CONTENT") | head -20)"
fi

# ---------------------------------------------------------------------------
# Test 2: SIGINT path — pre-fix mutates, process receives SIGINT
#
# We send SIGINT to orianna-sign.sh after pre-fix has run but before the claude
# invocation completes. We do this by using a claude stub that kills its parent
# with SIGINT. The stub is a script placed ahead of real claude in PATH.
# ---------------------------------------------------------------------------

info "=== Test 2: plan restored after SIGINT during claude invocation ==="

UNIQUE_PLAN2="$REAL_PROPOSED/_talon-test-snapshot-trap-sigint-$$.md"
printf '%s' "$ORIGINAL1" > "$UNIQUE_PLAN2"

cleanup_plan2() {
  rm -f "$UNIQUE_PLAN2"
}
# Append to EXIT trap
trap "cleanup_plan; cleanup_plan2" EXIT

ORIGINAL_CONTENT2="$(cat "$UNIQUE_PLAN2")"

# Build a tmpbin with a claude stub that SIGINTs the orianna-sign.sh parent
TMPBIN2="$(mktemp -d)"
cat > "$TMPBIN2/claude" <<'STUBEOF'
#!/usr/bin/env bash
# Kill the parent (orianna-sign.sh) with SIGINT to simulate user interrupt
kill -INT "$PPID" 2>/dev/null || true
sleep 5
STUBEOF
chmod +x "$TMPBIN2/claude"

info "plan before: $(wc -l < "$UNIQUE_PLAN2") lines"

PATH="$TMPBIN2:$PATH" REPO="$REPO_ROOT" \
  bash "$ORIANNA_SIGN" --pre-fix "$UNIQUE_PLAN2" approved 2>/dev/null || true

rm -rf "$TMPBIN2"
ACTUAL_CONTENT2="$(cat "$UNIQUE_PLAN2")"

if [ "$ACTUAL_CONTENT2" = "$ORIGINAL_CONTENT2" ]; then
  pass "Test 2: plan restored to original after SIGINT"
else
  fail "Test 2: plan NOT restored after SIGINT — pre-fix mutation leaked.
Lines expected: $(printf '%s' "$ORIGINAL_CONTENT2" | wc -l)
Lines actual:   $(printf '%s' "$ACTUAL_CONTENT2" | wc -l)"
fi

info "all assertions passed"
exit 0

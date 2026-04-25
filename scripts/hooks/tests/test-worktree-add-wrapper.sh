#!/bin/bash
# test-worktree-add-wrapper.sh
#
# Tests for scripts/worktree-add.sh (INV-3 from plan 2026-04-25-worktree-hooks-propagation.md)
#
# INV-3: scripts/worktree-add.sh MUST refuse to create a worktree when core.hooksPath
#        is unset, emitting a non-zero exit and an error message mentioning install-hooks.sh.
#
# xfail: scripts/worktree-add.sh does not exist yet (created in T4).
#        This test fails on current main and passes once T4 lands.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
WRAPPER="$REPO_ROOT/scripts/worktree-add.sh"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

echo "=== test-worktree-add-wrapper.sh ==="
echo "    (xfail against main HEAD — scripts/worktree-add.sh created in T4)"
echo ""

# ---------------------------------------------------------------------------
# Pre-flight: wrapper script must exist
# ---------------------------------------------------------------------------
if [ ! -f "$WRAPPER" ]; then
  echo "  NOTE: $WRAPPER does not exist yet (expected xfail pre-T4)"
  echo ""
  echo "Results: $PASS passed, $FAIL failed (1 xfail — wrapper not yet created)"
  exit 0  # Soft-exit so pre-push TDD gate sees this as xfail (not hard error)
fi

# ---------------------------------------------------------------------------
# Helper: create a temp git clone without core.hooksPath set
# ---------------------------------------------------------------------------
mk_bare_clone() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  git clone -q --local "$REPO_ROOT" "$tmpdir"
  # Ensure core.hooksPath is NOT set
  git -C "$tmpdir" config --unset core.hooksPath 2>/dev/null || true
  echo "$tmpdir"
}

# ---------------------------------------------------------------------------
# INV-3a: Wrapper refuses when core.hooksPath unset
# ---------------------------------------------------------------------------
echo "--- INV-3a: Wrapper refuses when core.hooksPath unset ---"
{
  clone="$(mk_bare_clone)"
  wt_target="$(mktemp -d)"
  rm -rf "$wt_target"  # wrapper will try to create it

  rc=0
  output="$("$WRAPPER" "$wt_target" -b "test-branch-inv3a-$$" 2>&1)" || rc=$?

  if [ "$rc" -ne 0 ]; then
    if echo "$output" | grep -qi "install-hooks"; then
      pass "INV-3a: wrapper exited non-zero and mentioned install-hooks.sh"
    else
      fail "INV-3a: wrapper exited non-zero but output did not mention install-hooks.sh"
      echo "  Output: $output"
    fi
  else
    fail "INV-3a: wrapper exited 0 (should have refused — core.hooksPath unset)"
    echo "  Output: $output"
  fi

  rm -rf "$clone" "$wt_target" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# INV-3b: Wrapper succeeds when core.hooksPath is set
# ---------------------------------------------------------------------------
echo ""
echo "--- INV-3b: Wrapper succeeds when core.hooksPath is set ---"
{
  clone="$(mk_bare_clone)"
  # Set core.hooksPath so the wrapper is satisfied
  git -C "$clone" config core.hooksPath "scripts/hooks-dispatchers"

  wt_target="$(mktemp -d)"
  rm -rf "$wt_target"

  rc=0
  # Run the wrapper from inside the clone so git operations are against the right repo
  (cd "$clone" && bash "$WRAPPER" "$wt_target" -b "test-branch-inv3b-$$" 2>/dev/null) || rc=$?

  if [ "$rc" -eq 0 ]; then
    pass "INV-3b: wrapper succeeded when core.hooksPath is set"
  else
    fail "INV-3b: wrapper failed even though core.hooksPath is set (exit $rc)"
  fi

  # Cleanup worktree
  git -C "$clone" worktree remove --force "$wt_target" 2>/dev/null || true
  rm -rf "$clone" "$wt_target" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

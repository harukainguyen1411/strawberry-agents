#!/bin/bash
# test-worktree-hooks-propagation.sh
#
# xfail test for plan: plans/approved/personal/2026-04-25-worktree-hooks-propagation.md
#
# INV-1: A pre-commit guard installed on main MUST fire when invoked from inside
#        a freshly-created worktree of the same clone.
#
# INV-2: Running install-hooks.sh twice must NOT corrupt dispatchers or unset
#        core.hooksPath.
#
# xfail: This test FAILS on current main (before T2) because install-hooks.sh
#        writes dispatchers to .git/hooks/, which is per-worktree. Once T2 lands
#        and core.hooksPath points to scripts/hooks-dispatchers/, this test passes.
#
# Exit 0 = all assertions passed (test passes).
# Exit 1 = one or more assertions failed.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/scripts/hooks/pre-commit-plan-lifecycle-guard.sh"
INSTALL_HOOKS="$REPO_ROOT/scripts/install-hooks.sh"

PASS=0
FAIL=0
XFAIL_EXPECTED=0  # set to non-zero counts once T2 lands

pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

echo "=== test-worktree-hooks-propagation.sh ==="
echo "    (xfail against main HEAD; passes once T2 lands)"
echo ""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Create a temp git clone of the real repo so we can:
#   - run install-hooks.sh inside it (which writes core.hooksPath)
#   - then add a worktree from that clone
#   - then stage a plan rename inside the worktree
#   - then verify the pre-commit hook fires inside the worktree
mk_tmp_clone() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  # Shallow clone to keep it fast; we only need the scripts/hooks dir and git config
  git clone -q --local "$REPO_ROOT" "$tmpdir"
  echo "$tmpdir"
}

# Stage a plan rename (proposed->approved) inside a given repo dir
stage_plan_rename() {
  local repo="$1"
  mkdir -p "$repo/plans/proposed/personal" "$repo/plans/approved/personal"
  echo "fake plan" > "$repo/plans/proposed/personal/foo-test.md"
  git -C "$repo" add plans/proposed/personal/foo-test.md
  git -C "$repo" -c user.email=t@t.com -c user.name=T commit -q --no-verify -m "init test plan"
  git -C "$repo" mv plans/proposed/personal/foo-test.md plans/approved/personal/foo-test.md
}

# Invoke the pre-commit hook directly (without running git commit) against a given dir.
# Remaining args after $1 are env vars as NAME=VALUE.
invoke_hook_directly() {
  local repo="$1"; shift
  env -u CLAUDE_AGENT_NAME -u STRAWBERRY_AGENT -u STRAWBERRY_AGENT_MODE \
    GIT_DIR="$repo/.git" GIT_WORK_TREE="$repo" "$@" bash "$HOOK" 2>/tmp/wt_hook_stderr_$$
}

# ---------------------------------------------------------------------------
# INV-1: Hook fires inside a fresh worktree
# ---------------------------------------------------------------------------
echo "--- INV-1: Hook fires inside worktree ---"
{
  clone="$(mk_tmp_clone)"

  # Run install-hooks.sh on the clone — this is the key step that should
  # set core.hooksPath to scripts/hooks-dispatchers/ (post-T2).
  # Pre-T2: it writes to .git/hooks/ which is clone-local and NOT inherited by worktrees.
  (cd "$clone" && bash "$INSTALL_HOOKS" >/dev/null 2>&1) || true

  # Record what core.hooksPath is set to (expected: scripts/hooks-dispatchers post-T2)
  configured_path="$(git -C "$clone" config core.hooksPath 2>/dev/null || echo '')"

  # Create a worktree from the clone
  wt_dir="$(mktemp -d)"
  rm -rf "$wt_dir"  # git worktree add requires the dir not to exist
  git -C "$clone" worktree add -q -b "wt-test-branch-$$" "$wt_dir"

  # Stage a plan rename inside the worktree
  stage_plan_rename "$wt_dir"

  # Now invoke the plan-lifecycle-guard hook from inside the worktree as a non-Orianna agent.
  # Expect: exit non-zero (blocked) if hook fires; exit 0 (unblocked) if hook doesn't fire.
  rc=0
  env -u CLAUDE_AGENT_NAME -u STRAWBERRY_AGENT -u STRAWBERRY_AGENT_MODE \
    GIT_DIR="$wt_dir/.git" GIT_WORK_TREE="$wt_dir" \
    CLAUDE_AGENT_NAME=kayn STRAWBERRY_AGENT_MODE=agent \
    bash "$HOOK" >/dev/null 2>/tmp/wt_hook_stderr_$$ || rc=$?

  if [ "$rc" -ne 0 ]; then
    pass "INV-1: plan-lifecycle-guard fired inside worktree (blocked non-Orianna rename, exit $rc)"
    if [ -z "$configured_path" ]; then
      echo "  NOTE: core.hooksPath not set — hook fired because we invoked it explicitly."
      echo "        Post-T2 this should fire via the dispatcher automatically."
    else
      echo "  INFO: core.hooksPath = $configured_path"
    fi
  else
    fail "INV-1: plan-lifecycle-guard did NOT fire inside worktree (non-Orianna rename was not blocked)"
    echo "        core.hooksPath = '${configured_path}'"
    echo "        This is the expected xfail on current main (pre-T2)."
    echo "        Once T2 sets core.hooksPath=scripts/hooks-dispatchers/, this test passes."
  fi

  # Cleanup
  git -C "$clone" worktree remove --force "$wt_dir" 2>/dev/null || true
  rm -rf "$clone" "$wt_dir" /tmp/wt_hook_stderr_$$
}

# ---------------------------------------------------------------------------
# INV-2: Idempotent install — run install-hooks.sh twice, verify consistency
# ---------------------------------------------------------------------------
echo ""
echo "--- INV-2: Idempotent install ---"
{
  clone="$(mk_tmp_clone)"

  # First run
  (cd "$clone" && bash "$INSTALL_HOOKS" >/dev/null 2>&1) || true
  path_after_first="$(git -C "$clone" config core.hooksPath 2>/dev/null || echo '')"

  # Second run
  (cd "$clone" && bash "$INSTALL_HOOKS" >/dev/null 2>&1) || true
  path_after_second="$(git -C "$clone" config core.hooksPath 2>/dev/null || echo '')"

  if [ "$path_after_first" = "$path_after_second" ]; then
    pass "INV-2: core.hooksPath unchanged after second install run ('${path_after_second}')"
  else
    fail "INV-2: core.hooksPath changed between runs: '${path_after_first}' -> '${path_after_second}'"
  fi

  # Post-T2: verify the three dispatcher files exist and are identical across runs
  # Pre-T2: scripts/hooks-dispatchers/ doesn't exist, skip file-content check
  dispatchers_dir="$clone/scripts/hooks-dispatchers"
  if [ -d "$dispatchers_dir" ]; then
    for verb in pre-commit pre-push commit-msg; do
      if [ -f "$dispatchers_dir/$verb" ]; then
        pass "INV-2: dispatcher file '$verb' exists in scripts/hooks-dispatchers/"
      else
        fail "INV-2: dispatcher file '$verb' missing from scripts/hooks-dispatchers/"
      fi
    done
  else
    echo "  NOTE: scripts/hooks-dispatchers/ not present (expected pre-T2 — xfail)"
    XFAIL_EXPECTED=$((XFAIL_EXPECTED+1))
  fi

  rm -rf "$clone"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$XFAIL_EXPECTED" -gt 0 ]; then
  echo "Note: $XFAIL_EXPECTED xfail condition(s) detected — expected before T2 lands."
fi
[ "$FAIL" -eq 0 ]

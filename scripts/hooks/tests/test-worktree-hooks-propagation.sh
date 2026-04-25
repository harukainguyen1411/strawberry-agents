#!/bin/bash
# test-worktree-hooks-propagation.sh
#
# xfail test for plan: plans/approved/personal/2026-04-25-worktree-hooks-propagation.md
#
# INV-1: A pre-commit guard installed on main MUST fire when `git commit` is run
#        from inside a freshly-created worktree — exercising core.hooksPath and the
#        dispatcher, not the guard directly.
#
# Soundness contract:
#   - Assert commit is BLOCKED when core.hooksPath=scripts/hooks-dispatchers (T2 in effect).
#   - Assert commit SUCCEEDS when core.hooksPath is unset (proves it was the hook blocking it).
#   Both assertions must hold for INV-1 to be considered tested.
#
# INV-2: Running install-hooks.sh twice must NOT corrupt dispatchers or unset
#        core.hooksPath.
#
# Exit 0 = all assertions passed.
# Exit 1 = one or more assertions failed.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
INSTALL_HOOKS="$REPO_ROOT/scripts/install-hooks.sh"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

echo "=== test-worktree-hooks-propagation.sh ==="
echo ""

# ---------------------------------------------------------------------------
# Helper: shallow-clone the repo into a temp dir
# ---------------------------------------------------------------------------
mk_tmp_clone() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  git clone -q --local "$REPO_ROOT" "$tmpdir"
  echo "$tmpdir"
}

# Helper: stage a plan rename (proposed->approved) inside a repo dir and
# leave it staged (not committed).
stage_plan_rename() {
  local repo="$1"
  mkdir -p "$repo/plans/proposed/personal" "$repo/plans/approved/personal"
  printf 'fake plan\n' > "$repo/plans/proposed/personal/inv1-test.md"
  git -C "$repo" add plans/proposed/personal/inv1-test.md
  # Commit the seed so we can then stage the rename
  git -C "$repo" \
    -c user.email=t@t.com -c user.name=T \
    commit -q --no-verify \
    -m "seed: add test plan"
  git -C "$repo" mv \
    plans/proposed/personal/inv1-test.md \
    plans/approved/personal/inv1-test.md
  # Staged rename is now waiting in the index.
}

# ---------------------------------------------------------------------------
# INV-1a: commit from worktree IS blocked when core.hooksPath is set (T2)
# ---------------------------------------------------------------------------
echo "--- INV-1a: git commit from worktree blocked via core.hooksPath dispatcher ---"
{
  clone="$(mk_tmp_clone)"

  # Install hooks — sets core.hooksPath = scripts/hooks-dispatchers (T2)
  (cd "$clone" && bash "$INSTALL_HOOKS" >/dev/null 2>&1) || true

  configured="$(git -C "$clone" config core.hooksPath 2>/dev/null || echo '')"

  wt_dir="$(mktemp -d)"
  rm -rf "$wt_dir"
  git -C "$clone" worktree add -q -b "inv1a-branch-$$" "$wt_dir"

  # Stage a non-Orianna plan rename inside the worktree
  stage_plan_rename "$wt_dir"

  # Attempt git commit from inside the worktree (NO --no-verify).
  # CLAUDE_AGENT_NAME=kayn + STRAWBERRY_AGENT_MODE=agent => pre-commit guard should block.
  rc=0
  ( cd "$wt_dir" && \
    CLAUDE_AGENT_NAME=kayn STRAWBERRY_AGENT_MODE=agent \
    git -c user.email=t@t.com -c user.name=T \
      commit -m "should be blocked by plan-lifecycle-guard" \
      >/dev/null 2>&1 \
  ) || rc=$?

  if [ "$rc" -ne 0 ]; then
    pass "INV-1a: commit blocked (exit $rc) — dispatcher fired via core.hooksPath='$configured'"
  else
    fail "INV-1a: commit SUCCEEDED (exit 0) — dispatcher did NOT fire; core.hooksPath='$configured'"
  fi

  # Cleanup
  git -C "$clone" worktree remove --force "$wt_dir" 2>/dev/null || true
  rm -rf "$clone" "$wt_dir"
}

# ---------------------------------------------------------------------------
# INV-1b: commit from worktree SUCCEEDS when core.hooksPath is unset
#         (proves the hook was what was blocking — not git or env)
# ---------------------------------------------------------------------------
echo ""
echo "--- INV-1b: git commit from worktree succeeds when core.hooksPath unset ---"
{
  clone="$(mk_tmp_clone)"

  # Ensure core.hooksPath is NOT set in this clone
  git -C "$clone" config --unset core.hooksPath 2>/dev/null || true

  wt_dir="$(mktemp -d)"
  rm -rf "$wt_dir"
  git -C "$clone" worktree add -q -b "inv1b-branch-$$" "$wt_dir"

  stage_plan_rename "$wt_dir"

  # Attempt git commit — hooks will NOT fire (no local core.hooksPath and we
  # override any global core.hooksPath by pointing it at a non-existent dir).
  # This proves the blockage in INV-1a came from the dispatcher, not from something else.
  rc=0
  ( cd "$wt_dir" && \
    CLAUDE_AGENT_NAME=kayn STRAWBERRY_AGENT_MODE=agent \
    git -c user.email=t@t.com -c user.name=T \
      -c core.hooksPath=/dev/null/no-hooks \
      commit -m "should succeed with no hooks path" \
      >/dev/null 2>&1 \
  ) || rc=$?

  if [ "$rc" -eq 0 ]; then
    pass "INV-1b: commit succeeded (exit 0) when core.hooksPath unset — confirms INV-1a isolation"
  else
    fail "INV-1b: commit failed (exit $rc) even with core.hooksPath unset — unexpected; check git env"
  fi

  # Cleanup
  git -C "$clone" worktree remove --force "$wt_dir" 2>/dev/null || true
  rm -rf "$clone" "$wt_dir"
}

# ---------------------------------------------------------------------------
# INV-2: Idempotent install
# ---------------------------------------------------------------------------
echo ""
echo "--- INV-2: Idempotent install ---"
{
  clone="$(mk_tmp_clone)"

  (cd "$clone" && bash "$INSTALL_HOOKS" >/dev/null 2>&1) || true
  path_after_first="$(git -C "$clone" config core.hooksPath 2>/dev/null || echo '')"

  (cd "$clone" && bash "$INSTALL_HOOKS" >/dev/null 2>&1) || true
  path_after_second="$(git -C "$clone" config core.hooksPath 2>/dev/null || echo '')"

  if [ "$path_after_first" = "$path_after_second" ]; then
    pass "INV-2: core.hooksPath unchanged after second install ('${path_after_second}')"
  else
    fail "INV-2: core.hooksPath changed between runs: '${path_after_first}' -> '${path_after_second}'"
  fi

  dispatchers_dir="$clone/scripts/hooks-dispatchers"
  if [ -d "$dispatchers_dir" ]; then
    for verb in pre-commit pre-push commit-msg; do
      if [ -f "$dispatchers_dir/$verb" ]; then
        pass "INV-2: dispatcher '$verb' exists in scripts/hooks-dispatchers/"
      else
        fail "INV-2: dispatcher '$verb' missing from scripts/hooks-dispatchers/"
      fi
    done
  else
    fail "INV-2: scripts/hooks-dispatchers/ directory not present in clone"
  fi

  rm -rf "$clone"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

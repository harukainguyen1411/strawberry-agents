#!/bin/bash
# test-pre-commit-plan-lifecycle-guard.sh
# Tests for pre-commit-plan-lifecycle-guard.sh
#
# Rule 12 — xfail test committed before T2 implementation.
# Refs: plans/approved/personal/2026-04-24-rule-19-guard-hole-pre-staged-moves.md T1
#
# Test cases:
#   Case 1 — non-Orianna agent (CLAUDE_AGENT_NAME=kayn) stages a plan rename
#             proposed->approved → git commit must fail with [plan-lifecycle-guard] stderr.
#   Case 2 — Orianna agent (CLAUDE_AGENT_NAME=orianna) stages same rename → commit must succeed.
#   Case 3 — no agent env vars at all (admin/human path) → commit must succeed.
#   Case 4 — non-Orianna agent modifies (not renames) an existing plans/in-progress/ file
#             → commit must succeed (edit-in-place is permitted).
#
# xfail-skip guard: if the hook does not yet exist, skip with "xfail" exit 0.
# (Matches repo convention in test-pretooluse-plan-lifecycle-guard.sh.)

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/scripts/hooks/pre-commit-plan-lifecycle-guard.sh"

# ---- xfail guard -------------------------------------------------------
if [ ! -x "$HOOK" ]; then
  echo "xfail: $HOOK not yet implemented — skipping (Rule 12 xfail pattern)"
  exit 0
fi

# ---- helpers -----------------------------------------------------------
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

echo "=== pre-commit-plan-lifecycle-guard.sh tests ==="

# Build a temp git repo to stage changes in, then invoke the hook directly.
# The hook is called as a pre-commit hook, so we set GIT_DIR / GIT_WORK_TREE
# to point at the temp repo's .git, then run the hook from the temp worktree.

run_case() {
  local label="$1"      # human label
  local want_rc="$2"    # expected exit code (0 = permit, non-zero = block)
  shift 2
  # Remaining args: environment assignments passed as NAME=VALUE pairs,
  # then the staged-path setup command (a shell snippet to run inside the temp repo).
  # We receive them as: env_vars (array), staged_setup_fn (function name)
  # — for simplicity, caller sets up the repo externally and just runs the hook.
  # Actual caller protocol: run_hook_in_repo <tmpdir> <env...> -> exit code
  :
}

# Helper: create a temp git repo, configure it, and return its path.
mk_tmp_repo() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  git -C "$tmpdir" init -q
  git -C "$tmpdir" config user.email "test@example.com"
  git -C "$tmpdir" config user.name "Test"
  # Install our hook
  mkdir -p "$tmpdir/.git/hooks"
  cp "$HOOK" "$tmpdir/.git/hooks/pre-commit"
  chmod +x "$tmpdir/.git/hooks/pre-commit"
  echo "$tmpdir"
}

# Helper: stage a rename from plans/proposed/personal/foo.md to plans/approved/personal/foo.md
# using a tracked add + remove (git rename simulation via two-file add).
stage_plan_rename() {
  local repo="$1"
  mkdir -p "$repo/plans/proposed/personal" "$repo/plans/approved/personal"
  echo "fake plan" > "$repo/plans/proposed/personal/foo.md"
  git -C "$repo" add plans/proposed/personal/foo.md
  # Commit it so it's tracked
  git -C "$repo" -c user.email=t@t.com -c user.name=T commit -q --no-verify -m "init"
  # Now do the rename in the index
  git -C "$repo" mv plans/proposed/personal/foo.md plans/approved/personal/foo.md
}

# Helper: stage a pure modification to an existing plans/in-progress/ file
stage_plan_inprogress_edit() {
  local repo="$1"
  mkdir -p "$repo/plans/in-progress/personal"
  echo "original content" > "$repo/plans/in-progress/personal/bar.md"
  git -C "$repo" add plans/in-progress/personal/bar.md
  git -C "$repo" -c user.email=t@t.com -c user.name=T commit -q --no-verify -m "init"
  # Modify (not rename)
  echo "updated content" > "$repo/plans/in-progress/personal/bar.md"
  git -C "$repo" add plans/in-progress/personal/bar.md
}

# Helper: invoke git commit in the repo (calls the pre-commit hook).
# Returns the git commit exit code.
attempt_commit() {
  local repo="$1"
  shift
  # env vars passed as NAME=VALUE args via env
  env "$@" git -C "$repo" -c user.email=t@t.com -c user.name=T \
    commit --no-verify=false -q -m "test commit" 2>/tmp/hook_stderr_$$ </dev/null
}

# We can't call `git commit` without --no-verify because the hook runs automatically.
# Instead, run the hook directly against the repo's git index using GIT_DIR.
invoke_hook_directly() {
  local repo="$1"
  shift  # remaining: env vars as NAME=VALUE
  env GIT_DIR="$repo/.git" GIT_WORK_TREE="$repo" "$@" bash "$HOOK" 2>/tmp/hook_stderr_$$
}

# ---- Case 1: non-Orianna agent, plan rename proposed->approved → block ----
{
  tmpdir="$(mk_tmp_repo)"
  stage_plan_rename "$tmpdir"
  rc=0
  invoke_hook_directly "$tmpdir" CLAUDE_AGENT_NAME=kayn STRAWBERRY_AGENT_MODE=agent \
    2>/tmp/hook_stderr_$$ || rc=$?
  if [ "$rc" -ne 0 ]; then
    # Also verify [plan-lifecycle-guard] prefix in stderr
    if grep -q "\[plan-lifecycle-guard\]" /tmp/hook_stderr_$$ 2>/dev/null; then
      pass "Case 1: non-Orianna (kayn) rename blocked with [plan-lifecycle-guard] prefix"
    else
      fail "Case 1: exit was non-zero but missing [plan-lifecycle-guard] prefix in stderr"
    fi
  else
    fail "Case 1: non-Orianna (kayn) rename should have been blocked (exit 0)"
  fi
  rm -rf "$tmpdir" /tmp/hook_stderr_$$
}

# ---- Case 2: Orianna agent, plan rename → permit ----
{
  tmpdir="$(mk_tmp_repo)"
  stage_plan_rename "$tmpdir"
  rc=0
  invoke_hook_directly "$tmpdir" CLAUDE_AGENT_NAME=orianna \
    2>/tmp/hook_stderr_$$ || rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "Case 2: Orianna rename permitted (exit 0)"
  else
    fail "Case 2: Orianna rename should have been permitted (got exit $rc)"
    cat /tmp/hook_stderr_$$ >&2 2>/dev/null || true
  fi
  rm -rf "$tmpdir" /tmp/hook_stderr_$$
}

# ---- Case 3: no agent env vars (admin/human path) → permit ----
{
  tmpdir="$(mk_tmp_repo)"
  stage_plan_rename "$tmpdir"
  rc=0
  # Unset agent env vars explicitly; also unset STRAWBERRY_AGENT_MODE
  invoke_hook_directly "$tmpdir" \
    2>/tmp/hook_stderr_$$ || rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "Case 3: admin/human (no env vars) rename permitted (exit 0)"
  else
    fail "Case 3: admin/human rename should have been permitted (got exit $rc)"
    cat /tmp/hook_stderr_$$ >&2 2>/dev/null || true
  fi
  rm -rf "$tmpdir" /tmp/hook_stderr_$$
}

# ---- Case 4 (added in T3): non-Orianna modifies existing in-progress file → permit ----
{
  tmpdir="$(mk_tmp_repo)"
  stage_plan_inprogress_edit "$tmpdir"
  rc=0
  invoke_hook_directly "$tmpdir" CLAUDE_AGENT_NAME=kayn STRAWBERRY_AGENT_MODE=agent \
    2>/tmp/hook_stderr_$$ || rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "Case 4: non-Orianna pure edit of in-progress file permitted (exit 0)"
  else
    fail "Case 4: pure edit of in-progress file should be permitted (got exit $rc)"
    cat /tmp/hook_stderr_$$ >&2 2>/dev/null || true
  fi
  rm -rf "$tmpdir" /tmp/hook_stderr_$$
}

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

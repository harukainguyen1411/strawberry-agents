#!/usr/bin/env bash
# xfail against current opt-in hook; passes after C3 flip.
#
# Tests for scripts/hooks/agent-default-isolation.sh — nested-dispatch guard.
# ADR: plans/approved/personal/2026-04-24-universal-worktree-isolation.md §Nested-dispatch policy
#
# Covers:
#   INV-4 — Parent-worktree nested-dispatch guard: when the hook runs inside a
#            worktree (git rev-parse --git-dir != --git-common-dir), it must
#            skip injection and exit 0 for any subagent.
#
# Detection signal: git rev-parse --git-dir returns the worktree-specific .git
# file/dir, while --git-common-dir returns the shared common repo .git dir.
# These paths differ when running inside a worktree.
#
# Test approach: create a real temp git repo, commit an agent def with
# default_isolation: worktree (so the files ARE present in the worktree checkout),
# add a linked worktree, invoke the hook from the worktree cwd.
# Under the current opt-in hook (no guard) the hook WILL inject isolation for
# this agent from the worktree — so the test FAILs (xfail). After C3 the bash
# wrapper detects --git-dir != --git-common-dir and short-circuits before Python.
#
# XFAIL against current opt-in hook: no nested-dispatch guard exists yet.

set -eu

REPO_ROOT_REAL="$(git rev-parse --show-toplevel)"
# Allow HOOK env var override for development testing (e.g. pointing at a worktree copy).
HOOK="${HOOK:-$REPO_ROOT_REAL/scripts/hooks/agent-default-isolation.sh}"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

if [ ! -x "$HOOK" ]; then
    fail "hook script $HOOK not present or not executable"
    echo "Results: $PASS passed, $FAIL failed"
    exit 1
fi

# ── set up a temporary git repo with committed agent def and a linked worktree ─

TMPDIR_REPO="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_REPO"' EXIT

MAIN_REPO="$TMPDIR_REPO/main-repo"
WORKTREE_PATH="$TMPDIR_REPO/sub-worktree"

# Init main repo, commit the agent def (so it's present in worktree checkout too).
mkdir -p "$MAIN_REPO/.claude/agents"
git -C "$TMPDIR_REPO" init -q "$MAIN_REPO"
git -C "$MAIN_REPO" config user.email "test@test.local"
git -C "$MAIN_REPO" config user.name "Test"

cat > "$MAIN_REPO/.claude/agents/fixture-isolated-agent.md" <<'AGEOF'
---
model: sonnet
default_isolation: worktree
---
# fixture-isolated-agent — used by test-nested-dispatch-guard.sh INV-4
AGEOF

touch "$MAIN_REPO/README.md"
git -C "$MAIN_REPO" add README.md ".claude/agents/fixture-isolated-agent.md"
git -C "$MAIN_REPO" commit -q -m "init with agent def"

# Add a linked worktree — the worktree checkout will contain .claude/agents/ too.
git -C "$MAIN_REPO" worktree add -q "$WORKTREE_PATH" -b wt-test-branch

# Confirm the agent file exists in the worktree.
if [ ! -f "$WORKTREE_PATH/.claude/agents/fixture-isolated-agent.md" ]; then
    fail "INV-4 setup — agent def not present in worktree checkout; test setup broken"
    echo "Results: $PASS passed, $FAIL failed"
    exit 1
fi
pass "INV-4 setup — agent def present in worktree checkout"

# Verify --git-dir != --git-common-dir inside the worktree (the ADR detection signal).
WT_GIT_DIR="$(git -C "$WORKTREE_PATH" rev-parse --git-dir 2>/dev/null || true)"
WT_GIT_COMMON_DIR="$(git -C "$WORKTREE_PATH" rev-parse --git-common-dir 2>/dev/null || true)"

if [ -z "$WT_GIT_DIR" ] || [ -z "$WT_GIT_COMMON_DIR" ]; then
    fail "INV-4 setup — could not determine --git-dir or --git-common-dir inside worktree"
    echo "Results: $PASS passed, $FAIL failed"
    exit 1
fi

if [ "$WT_GIT_DIR" = "$WT_GIT_COMMON_DIR" ]; then
    fail "INV-4 setup — worktree setup broken: --git-dir == --git-common-dir ($WT_GIT_DIR)"
    echo "Results: $PASS passed, $FAIL failed"
    exit 1
fi

pass "INV-4 setup — worktree shows --git-dir ($WT_GIT_DIR) != --git-common-dir ($WT_GIT_COMMON_DIR)"

_input='{"tool_name":"Agent","tool_input":{"subagent_type":"fixture-isolated-agent"}}'

# Control check: confirm the hook DOES inject from main repo cwd.
_out_main="$(printf '%s' "$_input" | (cd "$MAIN_REPO" && bash "$HOOK") 2>/dev/null || true)"
if printf '%s' "$_out_main" | grep -q '"isolation"[[:space:]]*:[[:space:]]*"worktree"'; then
    pass "INV-4 control — hook DOES inject from main repo cwd (confirms agent file reachable)"
else
    fail "INV-4 control — hook does NOT inject from main repo cwd; test setup may be broken. Got: $_out_main"
fi
unset _out_main

# ── INV-4: run hook with cwd inside the worktree ──────────────────────────────
# In the worktree: git rev-parse --show-toplevel → WORKTREE_PATH (not MAIN_REPO).
# The agent def IS present at WORKTREE_PATH/.claude/agents/fixture-isolated-agent.md.
# The hook's Python WILL find the file and, with no nested-dispatch guard,
# WILL inject isolation. The test asserts NO mutation (which fails against current hook).
#
# After C3: the bash wrapper detects --git-dir != --git-common-dir and exits 0
# before Python runs. Test then passes.
#
# INV-4 reference: ADR §INV-4 — Parent-worktree nested-dispatch guard.

_out="$(printf '%s' "$_input" | (cd "$WORKTREE_PATH" && bash "$HOOK") 2>/dev/null || true)"

if printf '%s' "$_out" | grep -q '"isolation"'; then
    fail "INV-4 fixture-isolated-agent from worktree — hook injected isolation when it should skip (expected xfail; will pass after C3 guard); got: $_out"
else
    pass "INV-4 fixture-isolated-agent from worktree — no mutation (nested-dispatch guard respected)"
fi
unset _input _out

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo "(Expected: INV-4 assertion FAILs against current opt-in hook; PASSes after C3 flip)"
[ "$FAIL" -eq 0 ]

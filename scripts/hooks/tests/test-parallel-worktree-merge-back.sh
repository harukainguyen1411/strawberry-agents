#!/usr/bin/env bash
# xfail against current state (helper exists post-C1, but parallel --no-ff path is new).
#
# Tests for scripts/subagent-merge-back.sh — parallel worktree merge-back.
# ADR: plans/approved/personal/2026-04-24-universal-worktree-isolation.md §INV-6
#
# Covers:
#   INV-6 — Parallel independent worktrees do not race. Mock two writer subagent
#            dispatches producing two distinct branches; run subagent-merge-back.sh
#            serially against each; assert both commits end up on main after
#            one ff-merge and one --no-ff merge.
#
# Deferral note (per ADR §Test plan): a full harness mock of the Agent dispatch
# layer is out of scope. This test instead creates two real throwaway branches on
# a temp git repo and exercises the merge-back helper directly. That exercises
# the (b) ff-only + (c) no-ff code paths — the exact parallel scenario described
# in ADR §INV-6.
#
# XFAIL: post-C1 state has the helper but it requires being run from the main
# branch. This test creates a local temp repo so it is self-contained and does
# not require the live repo. The test itself will pass after C1 is committed
# (since the helper exists), but is committed in C2 as xfail evidence per Rule 12.
# The C3 hook flip does not affect this test's correctness; it stays green.

set -eu

REPO_ROOT_REAL="$(git rev-parse --show-toplevel)"
MERGE_BACK="$REPO_ROOT_REAL/scripts/subagent-merge-back.sh"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

if [ ! -x "$MERGE_BACK" ]; then
    fail "merge-back script not present or not executable: $MERGE_BACK"
    echo "Results: $PASS passed, $FAIL failed"
    exit 1
fi

# ── set up a temp git repo ─────────────────────────────────────────────────────

TMPDIR_REPO="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_REPO"' EXIT

REPO="$TMPDIR_REPO/test-repo"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email "test@test.local"
git -C "$REPO" config user.name "Test"

# Initial commit on main.
echo "base" > "$REPO/base.txt"
git -C "$REPO" add base.txt
git -C "$REPO" commit -q -m "init: base commit"
BASE_SHA="$(git -C "$REPO" rev-parse HEAD)"

# Simulate a remote by using the repo itself as its own remote.
git -C "$REPO" remote add origin "$REPO" 2>/dev/null || true
git -C "$REPO" push -q origin main 2>/dev/null || true

# ── create two "subagent" branches off main ────────────────────────────────────

# Branch A (simulates subagent-A's work)
git -C "$REPO" checkout -q -b worktree-agent-A
echo "work from A" >> "$REPO/base.txt"
git -C "$REPO" add base.txt
git -C "$REPO" commit -q -m "feat: subagent-A work"
SHA_A="$(git -C "$REPO" rev-parse HEAD)"
git -C "$REPO" checkout -q main

# Branch B (simulates subagent-B's work on a different file)
git -C "$REPO" checkout -q -b worktree-agent-B
echo "work from B" > "$REPO/b.txt"
git -C "$REPO" add b.txt
git -C "$REPO" commit -q -m "feat: subagent-B work"
SHA_B="$(git -C "$REPO" rev-parse HEAD)"
git -C "$REPO" checkout -q main

# Push both branches to "origin" (itself).
git -C "$REPO" push -q origin worktree-agent-A 2>/dev/null || true
git -C "$REPO" push -q origin worktree-agent-B 2>/dev/null || true

# ── merge-back subagent-A (case b: ff-only expected) ──────────────────────────

# Run merge-back for A from main. Because main hasn't advanced, this should ff.
(
    cd "$REPO"
    bash "$MERGE_BACK" worktree-agent-A 2>&1
) || {
    fail "INV-6 merge-back A — helper exited non-zero"
}

MAIN_AFTER_A="$(git -C "$REPO" rev-parse HEAD)"

# After ff-only merge, HEAD should equal SHA_A.
if [ "$MAIN_AFTER_A" = "$SHA_A" ]; then
    pass "INV-6 merge-back A — ff-only succeeded, main advanced to subagent-A tip ($SHA_A)"
else
    fail "INV-6 merge-back A — expected HEAD=$SHA_A after ff, got $MAIN_AFTER_A"
fi

# Branch A should be deleted locally.
if git -C "$REPO" rev-parse --verify "refs/heads/worktree-agent-A" >/dev/null 2>&1; then
    fail "INV-6 merge-back A — local branch worktree-agent-A not deleted after merge"
else
    pass "INV-6 merge-back A — local branch deleted"
fi

# ── merge-back subagent-B (case c: --no-ff expected since main advanced) ───────

# At this point main is at SHA_A; branch B diverges from BASE_SHA.
# This triggers the --no-ff path.

(
    cd "$REPO"
    bash "$MERGE_BACK" worktree-agent-B 2>&1
) || {
    fail "INV-6 merge-back B — helper exited non-zero (conflict or error)"
}

MAIN_AFTER_B="$(git -C "$REPO" rev-parse HEAD)"

# After --no-ff merge, HEAD should be a NEW merge commit (not SHA_B or SHA_A).
if [ "$MAIN_AFTER_B" = "$SHA_A" ] || [ "$MAIN_AFTER_B" = "$SHA_B" ] || [ "$MAIN_AFTER_B" = "$BASE_SHA" ]; then
    fail "INV-6 merge-back B — expected a new merge commit, got existing SHA $MAIN_AFTER_B"
else
    pass "INV-6 merge-back B — --no-ff merge created new commit ($MAIN_AFTER_B)"
fi

# Both A and B work should be present on main.
if git -C "$REPO" show HEAD:base.txt 2>/dev/null | grep -q "work from A"; then
    pass "INV-6 merge-back B — subagent-A content present on main"
else
    fail "INV-6 merge-back B — subagent-A content missing from main"
fi

if git -C "$REPO" show HEAD:b.txt 2>/dev/null | grep -q "work from B"; then
    pass "INV-6 merge-back B — subagent-B content present on main"
else
    fail "INV-6 merge-back B — subagent-B content missing from main"
fi

# Branch B should be deleted locally.
if git -C "$REPO" rev-parse --verify "refs/heads/worktree-agent-B" >/dev/null 2>&1; then
    fail "INV-6 merge-back B — local branch worktree-agent-B not deleted after merge"
else
    pass "INV-6 merge-back B — local branch deleted"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

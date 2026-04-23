#!/bin/bash
# test-cleanup-merged-branches.sh — hermetic tests for cleanup-merged-branches.sh
#
# Uses a throwaway bare git repo + PATH-shadowed gh stub.
# No real gh calls. No real git remotes. Runs green on macOS bash and Git Bash.
#
# Run with: bash scripts/test-cleanup-merged-branches.sh

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="$REPO_ROOT/scripts/cleanup-merged-branches.sh"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

assert_contains() {
    local label="$1" pattern="$2" text="$3"
    if echo "$text" | grep -q "$pattern"; then
        pass "$label"
    else
        fail "$label (pattern '$pattern' not found in output)"
    fi
}

assert_not_contains() {
    local label="$1" pattern="$2" text="$3"
    if echo "$text" | grep -q "$pattern"; then
        fail "$label (unexpected pattern '$pattern' found in output)"
    else
        pass "$label"
    fi
}

# ---------------------------------------------------------------------------
# Setup: create a hermetic git repo with two branches and two worktrees
# ---------------------------------------------------------------------------
TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

REPO="$TMPDIR_BASE/repo"
WT_MERGED="$TMPDIR_BASE/wt-merged"
WT_ACTIVE="$TMPDIR_BASE/wt-active"
WT_DIRTY="$TMPDIR_BASE/wt-dirty"
GH_STUB="$TMPDIR_BASE/bin/gh"

# Initialise repo
git init -q "$REPO"
git -C "$REPO" config user.email "test@test.local"
git -C "$REPO" config user.name "Test"
git -C "$REPO" commit --allow-empty -q -m "init"
git -C "$REPO" branch -M main

# Create branches all from main so git branch -d (safe form) will succeed after merging
git -C "$REPO" checkout -q -b feature/merged-pr
git -C "$REPO" commit --allow-empty -q -m "merged pr work"
# Merge into main so local graph knows it's merged (simulates what GitHub does on its side)
git -C "$REPO" checkout -q main
git -C "$REPO" merge --no-ff -q feature/merged-pr -m "merge feature/merged-pr"
git -C "$REPO" checkout -q -b feature/active-pr
git -C "$REPO" commit --allow-empty -q -m "active pr work"
git -C "$REPO" checkout -q main
git -C "$REPO" checkout -q -b feature/dirty-pr
git -C "$REPO" commit --allow-empty -q -m "dirty pr work"
git -C "$REPO" checkout -q main

# Create worktrees for the branches
git -C "$REPO" worktree add -q "$WT_MERGED" feature/merged-pr
git -C "$REPO" worktree add -q "$WT_ACTIVE" feature/active-pr
git -C "$REPO" worktree add -q "$WT_DIRTY"  feature/dirty-pr

# Make dirty-pr worktree dirty
echo "dirty" > "$WT_DIRTY/uncommitted.txt"

# Create gh stub that reports only feature/merged-pr as merged
mkdir -p "$(dirname "$GH_STUB")"
cat > "$GH_STUB" <<'STUB'
#!/bin/sh
# gh stub — emits exactly one merged PR
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '[{"headRefName":"feature/merged-pr"}]\n'
    exit 0
fi
# Passthrough for any other gh command (auth checks etc.)
exit 0
STUB
chmod +x "$GH_STUB"

# Prepend stub dir to PATH for all test invocations
export PATH="$TMPDIR_BASE/bin:$PATH"

echo "=== cleanup-merged-branches.sh — 5 invariants ==="
echo ""

# ---------------------------------------------------------------------------
# INV-1: Dry-run mutates nothing (worktree list and branch list unchanged)
# ---------------------------------------------------------------------------
echo "--- INV-1: dry-run mutates nothing ---"
wt_before="$(git -C "$REPO" worktree list --porcelain | grep '^worktree')"
br_before="$(git -C "$REPO" branch --list)"

bash "$SCRIPT" --repo "$REPO" --dry-run >/dev/null 2>&1

wt_after="$(git -C "$REPO" worktree list --porcelain | grep '^worktree')"
br_after="$(git -C "$REPO" branch --list)"

if [ "$wt_before" = "$wt_after" ] && [ "$br_before" = "$br_after" ]; then
    pass "INV-1: dry-run leaves worktrees and branches unchanged"
else
    fail "INV-1: dry-run mutated repo state"
fi

# ---------------------------------------------------------------------------
# INV-2: --apply removes merged worktree + branch but leaves other intact
# ---------------------------------------------------------------------------
echo ""
echo "--- INV-2: --apply removes merged branch/worktree, leaves active ---"
output="$(bash "$SCRIPT" --repo "$REPO" --apply 2>&1)"

if [ ! -d "$WT_MERGED" ] && ! git -C "$REPO" rev-parse --verify "refs/heads/feature/merged-pr" >/dev/null 2>&1; then
    pass "INV-2a: merged worktree + branch removed"
else
    fail "INV-2a: merged worktree or branch still exists after --apply"
fi

if [ -d "$WT_ACTIVE" ] && git -C "$REPO" rev-parse --verify "refs/heads/feature/active-pr" >/dev/null 2>&1; then
    pass "INV-2b: active worktree + branch untouched"
else
    fail "INV-2b: active worktree or branch was incorrectly removed"
fi

# ---------------------------------------------------------------------------
# INV-3: dirty worktree is skipped, exit 0
# ---------------------------------------------------------------------------
echo ""
echo "--- INV-3: dirty worktree skipped, exit 0 ---"

# Re-add the merged branch so we can re-test dirty (use dirty-pr which is still around)
# The stub reports only feature/merged-pr as merged, and feature/dirty-pr is not in the
# stub's list — so dirty-pr won't be targeted. Let's update stub to also include dirty-pr.
cat > "$GH_STUB" <<'STUB'
#!/bin/sh
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '[{"headRefName":"feature/dirty-pr"}]\n'
    exit 0
fi
exit 0
STUB

dirty_output="$(bash "$SCRIPT" --repo "$REPO" --apply 2>&1)"
dirty_exit=$?

assert_contains "INV-3a: dirty skip message present" "SKIP (dirty worktree)" "$dirty_output"
if [ "$dirty_exit" -eq 0 ]; then
    pass "INV-3b: exit 0 when dirty worktree skipped"
else
    fail "INV-3b: non-zero exit when dirty worktree skipped (got $dirty_exit)"
fi

if [ -d "$WT_DIRTY" ] && git -C "$REPO" rev-parse --verify "refs/heads/feature/dirty-pr" >/dev/null 2>&1; then
    pass "INV-3c: dirty worktree + branch still present (not deleted)"
else
    fail "INV-3c: dirty worktree or branch was incorrectly removed"
fi

# Restore stub to report feature/merged-pr for remaining tests
cat > "$GH_STUB" <<'STUB'
#!/bin/sh
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '[{"headRefName":"feature/merged-pr"}]\n'
    exit 0
fi
exit 0
STUB

# ---------------------------------------------------------------------------
# INV-4: currently checked-out branch is never deleted
# ---------------------------------------------------------------------------
echo ""
echo "--- INV-4: current branch never deleted ---"

# Create a fresh repo where the branch to be cleaned is currently checked out
REPO2="$TMPDIR_BASE/repo2"
git init -q "$REPO2"
git -C "$REPO2" config user.email "test@test.local"
git -C "$REPO2" config user.name "Test"
git -C "$REPO2" commit --allow-empty -q -m "init"
git -C "$REPO2" branch -M main
git -C "$REPO2" checkout -q -b feature/merged-pr

# Stub reports feature/merged-pr as merged — but it is the current branch in REPO2
output_inv4="$(bash "$SCRIPT" --repo "$REPO2" --apply 2>&1)"

assert_contains "INV-4a: current-branch skip message present" "SKIP (current checkout)" "$output_inv4"
if git -C "$REPO2" rev-parse --verify "refs/heads/feature/merged-pr" >/dev/null 2>&1; then
    pass "INV-4b: current branch still exists after --apply"
else
    fail "INV-4b: current branch was deleted"
fi

# ---------------------------------------------------------------------------
# INV-5: script never uses `git branch -D` (only safe -d form)
# ---------------------------------------------------------------------------
echo ""
echo "--- INV-5: script uses only 'git branch -d' (never -D) ---"
if grep -qE "branch[[:space:]]+-D" "$SCRIPT"; then
    fail "INV-5: found 'git branch -D' in script (unsafe force-delete)"
else
    pass "INV-5: no 'git branch -D' found — only safe -d used"
fi

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

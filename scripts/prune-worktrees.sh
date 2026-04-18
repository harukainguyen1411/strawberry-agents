#!/bin/bash
# prune-worktrees.sh — identify and remove stale git worktrees
#
# A worktree is stale if its branch is merged into main OR its remote branch
# has been deleted. Worktrees with uncommitted changes are always skipped.
#
# Usage:
#   bash scripts/prune-worktrees.sh           # dry-run: list stale worktrees
#   bash scripts/prune-worktrees.sh --prune   # remove stale worktrees

set -euo pipefail

PRUNE=0
if [ "${1:-}" = "--prune" ]; then
    PRUNE=1
fi

# Resolve the main repo root (works even if called from inside a worktree)
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || git rev-parse --show-toplevel)"

STALE_COUNT=0
SKIPPED_COUNT=0

# Parse `git worktree list --porcelain` output
# Each worktree block is separated by a blank line.
# Fields: worktree <path>, HEAD <sha>, branch refs/heads/<name>, or "bare"/"detached"

parse_worktrees() {
    git -C "$REPO_ROOT" worktree list --porcelain
}

# Collect main worktree path (first entry)
MAIN_WORKTREE="$(parse_worktrees | head -1 | sed 's/^worktree //')"

echo "=== prune-worktrees.sh ==="
echo "Mode: $([ "$PRUNE" -eq 1 ] && echo PRUNE || echo dry-run)"
echo "Main worktree: $MAIN_WORKTREE"
echo ""

# Read worktrees into temp file for processing
TMPFILE="$(mktemp)"
trap 'rm -f "$TMPFILE"' EXIT
parse_worktrees > "$TMPFILE"

# Process each worktree block
WORKTREE_PATH=""
BRANCH_NAME=""
IS_DETACHED=0

process_block() {
    local path="$1"
    local branch="$2"
    local detached="$3"

    # Skip main worktree
    if [ "$path" = "$MAIN_WORKTREE" ]; then
        return
    fi

    # Skip detached HEAD (can't determine branch status)
    if [ "$detached" -eq 1 ] || [ -z "$branch" ]; then
        echo "  SKIP (detached HEAD or no branch): $path"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        return
    fi

    # Skip worktrees with uncommitted changes
    if [ -d "$path" ]; then
        DIRTY="$(git -C "$path" status --porcelain 2>/dev/null || true)"
        if [ -n "$DIRTY" ]; then
            echo "  SKIP (dirty working tree): $path  [$branch]"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            return
        fi
    fi

    # Check if merged into main
    MERGED=""
    if git -C "$REPO_ROOT" branch --merged main 2>/dev/null | grep -qE "^[[:space:]]*${branch}$"; then
        MERGED="yes (merged into main)"
    fi

    # Check if remote branch still exists
    REMOTE_EXISTS=""
    if git -C "$REPO_ROOT" ls-remote --heads origin "$branch" 2>/dev/null | grep -q "$branch"; then
        REMOTE_EXISTS="yes"
    fi

    # Determine if stale
    IS_STALE=0
    REASON=""
    if [ -n "$MERGED" ]; then
        IS_STALE=1
        REASON="branch merged into main"
    elif [ -z "$REMOTE_EXISTS" ]; then
        IS_STALE=1
        REASON="remote branch deleted"
    fi

    if [ "$IS_STALE" -eq 1 ]; then
        STALE_COUNT=$((STALE_COUNT + 1))
        echo "  STALE: $path  [$branch]  ($REASON)"
        if [ "$PRUNE" -eq 1 ]; then
            echo "    -> removing worktree..."
            git -C "$REPO_ROOT" worktree remove "$path" --force 2>&1 || echo "    WARNING: worktree remove failed (may already be gone)"
            echo "    -> deleting branch $branch..."
            git -C "$REPO_ROOT" branch -d "$branch" 2>&1 || echo "    WARNING: branch delete failed (may already be deleted)"
            echo "    -> done."
        fi
    else
        echo "  OK:    $path  [$branch]"
    fi
}

# Parse porcelain output block by block
while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" == worktree\ * ]]; then
        # Start of new block — process previous block if any
        if [ -n "$WORKTREE_PATH" ]; then
            process_block "$WORKTREE_PATH" "$BRANCH_NAME" "$IS_DETACHED"
        fi
        WORKTREE_PATH="${line#worktree }"
        BRANCH_NAME=""
        IS_DETACHED=0
    elif [[ "$line" == branch\ * ]]; then
        # refs/heads/<name>
        REF="${line#branch }"
        BRANCH_NAME="${REF#refs/heads/}"
    elif [[ "$line" == "detached" ]]; then
        IS_DETACHED=1
    fi
done < "$TMPFILE"

# Process final block
if [ -n "$WORKTREE_PATH" ]; then
    process_block "$WORKTREE_PATH" "$BRANCH_NAME" "$IS_DETACHED"
fi

echo ""
echo "=== Summary ==="
echo "Stale: $STALE_COUNT  |  Skipped: $SKIPPED_COUNT"
if [ "$PRUNE" -eq 0 ] && [ "$STALE_COUNT" -gt 0 ]; then
    echo "Run with --prune to remove stale worktrees."
fi

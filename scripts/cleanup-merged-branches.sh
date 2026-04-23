#!/bin/bash
# cleanup-merged-branches.sh — remove local branches and worktrees for GitHub-merged PRs
#
# Uses `gh pr list --state merged` to identify merged branches, avoiding false positives
# from squash/rebase merges that `git branch --merged` would miss.
#
# Usage:
#   bash scripts/cleanup-merged-branches.sh [--repo <dir>] [--dry-run] [--apply] [--limit N]
#
# Flags:
#   --repo <dir>   Target git repo directory (default: current working directory)
#   --dry-run      Show planned cleanup without acting (default)
#   --apply        Perform cleanup (opposite of --dry-run)
#   --limit N      Maximum merged PRs to fetch (default: 50)
#   --help         Show this help message
#
# NOTE: --apply vs --dry-run is the inverse of scripts/prune-worktrees.sh which uses
#       --prune to activate (dry-run is the default there too, but activation flag differs).

set -euo pipefail

REPO_DIR=""
DRY_RUN=1
LIMIT=50

usage() {
    grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
    exit 0
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --repo)
            shift
            REPO_DIR="$1"
            ;;
        --dry-run)
            DRY_RUN=1
            ;;
        --apply)
            DRY_RUN=0
            ;;
        --limit)
            shift
            LIMIT="$1"
            ;;
        --help|-h)
            usage
            ;;
        *)
            die "Unknown argument: $1. Run with --help for usage."
            ;;
    esac
    shift
done

# Resolve repo directory
if [ -z "$REPO_DIR" ]; then
    REPO_DIR="$(pwd)"
fi

# Validate prerequisites
command -v gh >/dev/null 2>&1 || die "gh (GitHub CLI) is not installed or not on PATH"
command -v jq >/dev/null 2>&1 || die "jq is not installed or not on PATH"
git -C "$REPO_DIR" rev-parse --show-toplevel >/dev/null 2>&1 || die "Not a git repository: $REPO_DIR"

REPO_ROOT="$(git -C "$REPO_DIR" rev-parse --show-toplevel)"

echo "=== cleanup-merged-branches.sh ==="
echo "Mode: $([ "$DRY_RUN" -eq 1 ] && echo dry-run || echo APPLY)"
echo "Repo: $REPO_ROOT"
echo "Limit: $LIMIT merged PRs"
echo ""

# Determine currently checked-out branch in the primary worktree
CURRENT_BRANCH="$(git -C "$REPO_ROOT" symbolic-ref --short HEAD 2>/dev/null || true)"

# Fetch from remote to refresh remote tracking state
echo "Fetching from remote..."
git -C "$REPO_ROOT" fetch --all --prune 2>&1 || echo "WARNING: git fetch failed (continuing anyway)"
echo ""

# Get merged PR branch names from GitHub
echo "Querying GitHub for merged PRs (limit $LIMIT)..."
MERGED_BRANCHES="$(
    cd "$REPO_ROOT"
    gh pr list --state merged --limit "$LIMIT" --json headRefName \
        | jq -r '.[].headRefName'
)" || die "gh pr list failed — ensure you are authenticated (gh auth login)"

if [ -z "$MERGED_BRANCHES" ]; then
    echo "No merged PRs found."
    echo ""
    echo "=== Summary ==="
    echo "Removed: 0  |  Skipped-dirty: 0  |  Skipped-current: 0  |  Not-found: 0"
    exit 0
fi

echo "Found merged PR branches:"
echo "$MERGED_BRANCHES" | sed 's/^/  /'
echo ""

# Build a map of branch -> worktree path from porcelain output
# Stored as lines: "<branch> <worktree_path>"
WORKTREE_MAP="$(
    git -C "$REPO_ROOT" worktree list --porcelain \
    | awk '
        /^worktree / { wt = substr($0, 10) }
        /^branch /   { br = substr($0, 8); sub(/^refs\/heads\//, "", br); print br " " wt }
    '
)"

COUNT_REMOVED=0
COUNT_DIRTY=0
COUNT_CURRENT=0
COUNT_NOT_FOUND=0

process_branch() {
    local branch="$1"

    # Skip current branch
    if [ "$branch" = "$CURRENT_BRANCH" ]; then
        echo "  SKIP (current checkout): $branch"
        COUNT_CURRENT=$((COUNT_CURRENT + 1))
        return
    fi

    # Find associated worktree path (if any)
    local wt_path=""
    wt_path="$(echo "$WORKTREE_MAP" | awk -v br="$branch" '$1 == br { print $2; exit }')"

    # If there is a worktree, check for dirty state before doing anything
    if [ -n "$wt_path" ] && [ -d "$wt_path" ]; then
        local dirty=""
        dirty="$(git -C "$wt_path" status --porcelain 2>/dev/null || true)"
        if [ -n "$dirty" ]; then
            echo "  SKIP (dirty worktree): $branch  [$wt_path]"
            COUNT_DIRTY=$((COUNT_DIRTY + 1))
            return
        fi
    fi

    # Check if local branch actually exists
    if ! git -C "$REPO_ROOT" rev-parse --verify "refs/heads/$branch" >/dev/null 2>&1; then
        echo "  NOT-FOUND (no local branch): $branch"
        COUNT_NOT_FOUND=$((COUNT_NOT_FOUND + 1))
        return
    fi

    echo "  STALE: $branch$([ -n "$wt_path" ] && echo "  [worktree: $wt_path]" || true)"

    if [ "$DRY_RUN" -eq 0 ]; then
        # Remove worktree first if one exists
        if [ -n "$wt_path" ] && [ -d "$wt_path" ]; then
            echo "    -> removing worktree $wt_path ..."
            git -C "$REPO_ROOT" worktree remove "$wt_path" 2>&1 \
                || echo "    WARNING: worktree remove failed (may already be gone)"
        fi
        # Delete local branch (safe form only — never -D)
        echo "    -> deleting branch $branch ..."
        git -C "$REPO_ROOT" branch -d "$branch" 2>&1 \
            || echo "    WARNING: branch -d refused (branch not fully merged in local graph — skipping)"
        echo "    -> done."
    fi

    COUNT_REMOVED=$((COUNT_REMOVED + 1))
}

# Process each merged branch
while IFS= read -r branch; do
    [ -z "$branch" ] && continue
    process_branch "$branch"
done <<EOF
$MERGED_BRANCHES
EOF

echo ""
echo "=== Summary ==="
if [ "$DRY_RUN" -eq 1 ]; then
    echo "Candidates: $COUNT_REMOVED  |  Skipped-dirty: $COUNT_DIRTY  |  Skipped-current: $COUNT_CURRENT  |  Not-found: $COUNT_NOT_FOUND"
    if [ "$COUNT_REMOVED" -gt 0 ]; then
        echo "Run with --apply to perform cleanup."
    fi
else
    echo "Removed: $COUNT_REMOVED  |  Skipped-dirty: $COUNT_DIRTY  |  Skipped-current: $COUNT_CURRENT  |  Not-found: $COUNT_NOT_FOUND"
fi

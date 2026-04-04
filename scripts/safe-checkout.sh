#!/usr/bin/env bash
# Safe branch checkout — checks for uncommitted changes before switching.
# Use this instead of raw `git checkout` to prevent data loss in shared workdir.
# Usage: bash scripts/safe-checkout.sh <branch>

set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: bash scripts/safe-checkout.sh <branch>"
    exit 1
fi

TARGET_BRANCH="$1"

# Check for uncommitted changes (staged or unstaged)
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "BLOCKED: Uncommitted changes detected."
    echo "Commit or stash your changes before switching branches."
    echo ""
    echo "Changed files:"
    git diff --name-only
    git diff --cached --name-only
    exit 1
fi

# Check for untracked files that might be overwritten
UNTRACKED=$(git ls-files --others --exclude-standard)
if [ -n "$UNTRACKED" ]; then
    echo "WARNING: Untracked files detected. These may be lost on checkout:"
    echo "$UNTRACKED"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

git checkout "$TARGET_BRANCH"
echo "Switched to $TARGET_BRANCH"

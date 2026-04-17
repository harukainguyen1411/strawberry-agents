#!/usr/bin/env bash
# scripts/pre-commit-artifact-guard.sh
#
# Block accidental commits of build artifacts and generated output directories.
# Run from .git/hooks/pre-commit.
#
# Exit codes:
#   0  ok, allow commit
#   1  blocked — staged file matches a build artifact pattern

set -uo pipefail

BUILD_ARTIFACT_PATTERNS=(
    "node_modules/"
    ".turbo/"
    ".firebase/"
    "__pycache__/"
    "apps/functions/lib/"
)

BLOCKED=0

while IFS= read -r staged_file; do
    [ -z "$staged_file" ] && continue
    for pattern in "${BUILD_ARTIFACT_PATTERNS[@]}"; do
        if [[ "$staged_file" == *"$pattern"* ]]; then
            echo "BLOCKED: Staged file matches build artifact pattern: $staged_file"
            echo "  Pattern matched: $pattern"
            echo "  Add to .gitignore or use 'git add --force' if intentional."
            BLOCKED=1
        fi
    done
done < <(git diff --cached --name-only 2>/dev/null)

if [ "$BLOCKED" -eq 1 ]; then
    exit 1
fi
exit 0

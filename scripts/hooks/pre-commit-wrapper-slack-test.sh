#!/usr/bin/env bash
# scripts/hooks/pre-commit-wrapper-slack-test.sh
# Plan: plans/in-progress/work/2026-04-24-sona-secretary-mcp-suite.md / T-new-D-smoke
#
# Pre-commit hook: runs scripts/tests/wrapper-slack-launcher.bats when
# mcps/wrappers/slack-launcher.sh or tools/decrypt.sh is staged.
#
# Skipped silently when:
#   - bats is not installed (not a hard blocker — CI still catches it)
#   - age / age-keygen not installed (test self-skips)
#
# Exit codes: 0 = pass/skip, 1 = fail.

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

# Only trigger when wrapper or decrypt surface is staged
staged="$(git diff --cached --name-only --diff-filter=ACMR)"
if ! printf '%s\n' "$staged" | grep -qE '^(mcps/wrappers/slack-launcher\.sh|tools/decrypt\.sh|scripts/tests/wrapper-slack-launcher\.bats|scripts/tests/probe-upstream-slack\.sh|scripts/hooks/pre-commit-wrapper-slack-test\.sh)$'; then
    exit 0
fi

if ! command -v bats >/dev/null 2>&1; then
    printf '[pre-commit-wrapper-slack-test] bats not installed — skipping wrapper smoke test\n' >&2
    exit 0
fi

TEST_FILE="$REPO_ROOT/scripts/tests/wrapper-slack-launcher.bats"
if [ ! -f "$TEST_FILE" ]; then
    printf '[pre-commit-wrapper-slack-test] test file not found: %s — skipping\n' "$TEST_FILE" >&2
    exit 0
fi

printf '[pre-commit-wrapper-slack-test] running wrapper-slack-launcher smoke test\n' >&2
if bats "$TEST_FILE" >&2; then
    printf '[pre-commit-wrapper-slack-test] PASS\n' >&2
    exit 0
else
    printf '[pre-commit-wrapper-slack-test] FAIL — commit blocked. fix the wrapper smoke test first.\n' >&2
    exit 1
fi

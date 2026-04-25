#!/usr/bin/env bash
# scripts/hooks/pre-commit-decrypt-exec-test.sh
# Plan: plans/approved/work/2026-04-24-sona-secretary-mcp-suite.md T-new-E
#
# Pre-commit hook: runs scripts/tests/decrypt-exec.sh when tools/decrypt.sh
# (or this test itself) is staged, so refactors to the decrypt surface can't
# silently break the --exec contract.
#
# Skipped silently when secrets/age-key.txt is absent (CI or machines that
# have no key) — the test self-guards on key presence.
#
# Exit codes mirror the dispatcher convention: 0 = pass, 1 = fail.

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

# Only trigger when tools/decrypt.sh or the test itself is staged.
staged="$(git diff --cached --name-only --diff-filter=ACMR)"
if ! printf '%s\n' "$staged" | grep -qE '^(tools/decrypt\.sh|scripts/tests/decrypt-exec\.sh|scripts/hooks/pre-commit-decrypt-exec-test\.sh)$'; then
  exit 0
fi

TEST_SCRIPT="$REPO_ROOT/scripts/tests/decrypt-exec.sh"
KEY_FILE="$REPO_ROOT/secrets/age-key.txt"

if [ ! -f "$TEST_SCRIPT" ]; then
  printf '[pre-commit-decrypt-exec-test] test script not found: %s — skipping\n' "$TEST_SCRIPT" >&2
  exit 0
fi

if [ ! -f "$KEY_FILE" ]; then
  printf '[pre-commit-decrypt-exec-test] secrets/age-key.txt absent — skipping decrypt-exec test\n' >&2
  exit 0
fi

printf '[pre-commit-decrypt-exec-test] running decrypt-exec integration test (tools/decrypt.sh staged)\n' >&2
if bash "$TEST_SCRIPT" >&2; then
  printf '[pre-commit-decrypt-exec-test] PASS\n' >&2
  exit 0
else
  printf '[pre-commit-decrypt-exec-test] FAIL — commit blocked. fix the --exec integration test first.\n' >&2
  exit 1
fi

#!/usr/bin/env bash
# scripts/reviewer-auth.sh — Run a gh subcommand as the strawberry-reviewers identity.
#
# Usage:
#   scripts/reviewer-auth.sh gh pr review <PR> --approve --body "-- Senna"
#   scripts/reviewer-auth.sh gh api user --jq .login
#
# Contract:
#   - Decrypts secrets/encrypted/reviewer-github-token.age via tools/decrypt.sh
#     (the only sanctioned decryption path per Rule 6).
#   - Exports GH_TOKEN into the child gh process env only — never echoed,
#     never written to a parent-shell variable, never in shell history.
#   - All args are passed through to gh unchanged.
#   - Only gh subcommands are permitted. The first arg after any leading "gh"
#     word must be a gh subcommand token (no raw shell injection).
#
# Reviewer agents (Senna, Lucian) MUST use this script for every
# `gh pr review --approve` call. Executor agents MUST NOT source this script.
#
# Rule 6 compliance: no raw `age -d`; uses tools/decrypt.sh --exec exclusively.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGE_FILE="$REPO_ROOT/secrets/encrypted/reviewer-github-token.age"
DECRYPT="$REPO_ROOT/tools/decrypt.sh"

if [[ ! -f "$AGE_FILE" ]]; then
    echo "reviewer-auth.sh: encrypted PAT not found at $AGE_FILE" >&2
    exit 1
fi

if [[ $# -eq 0 ]]; then
    echo "reviewer-auth.sh: no command supplied" >&2
    echo "Usage: $0 gh <subcommand> [args...]" >&2
    exit 2
fi

# Strip leading "gh" token if caller wrote: scripts/reviewer-auth.sh gh pr review ...
if [[ "$1" == "gh" ]]; then
    shift
fi

# Decrypt and exec gh with GH_TOKEN in env only. tools/decrypt.sh --exec places
# the plaintext in the child process env via `exec env KEY=val cmd...`.
# The plaintext never surfaces in this shell's variable space, argv, or stdout.
# The --target file (mode 600, gitignored under secrets/) is a decrypt.sh
# implementation requirement; it is not echoed or logged anywhere.
cat "$AGE_FILE" | "$DECRYPT" \
    --target secrets/reviewer-auth.env \
    --var GH_TOKEN \
    --exec -- gh "$@"

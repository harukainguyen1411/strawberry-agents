#!/usr/bin/env bash
# scripts/reviewer-auth.sh — Run a gh subcommand as the strawberry-reviewers identity.
#
# Usage:
#   scripts/reviewer-auth.sh gh pr review <PR> --approve --body "-- Lucian"
#   scripts/reviewer-auth.sh --lane senna gh pr review <PR> --approve --body "-- Senna"
#   scripts/reviewer-auth.sh gh api user --jq .login
#
# --lane lucian  (default) uses reviewer-github-token.age
# --lane senna           uses reviewer-github-token-senna.age
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
DECRYPT="$REPO_ROOT/tools/decrypt.sh"
LIB_ANONYMITY="$REPO_ROOT/scripts/hooks/_lib_reviewer_anonymity.sh"

# Parse optional --lane <name> flag before any other arguments.
LANE="lucian"
if [[ $# -ge 2 && "$1" == "--lane" ]]; then
    LANE="$2"
    shift 2
fi

case "$LANE" in
    lucian)
        AGE_FILE="$REPO_ROOT/secrets/encrypted/reviewer-github-token.age"
        ENV_TARGET="secrets/reviewer-auth.env"
        ;;
    senna)
        AGE_FILE="$REPO_ROOT/secrets/encrypted/reviewer-github-token-senna.age"
        ENV_TARGET="secrets/reviewer-auth-senna.env"
        ;;
    *)
        echo "reviewer-auth.sh: unknown lane '$LANE' (valid: lucian, senna)" >&2
        exit 2
        ;;
esac

if [[ ! -f "$AGE_FILE" ]]; then
    echo "reviewer-auth.sh: encrypted PAT not found at $AGE_FILE" >&2
    exit 1
fi

if [[ $# -eq 0 ]]; then
    echo "reviewer-auth.sh: no command supplied" >&2
    echo "Usage: $0 [--lane <lucian|senna>] gh <subcommand> [args...]" >&2
    exit 2
fi

# Strip leading "gh" token if caller wrote: scripts/reviewer-auth.sh gh pr review ...
if [[ "$1" == "gh" ]]; then
    shift
fi

# ---------------------------------------------------------------------------
# Work-scope anonymity scan (T3)
# Runs before any gh exec when subcommand is "pr review" or "pr comment".
# Sources _lib_reviewer_anonymity.sh for scope detection + token scanning.
#
# ANONYMITY_DRY_RUN=1  — skip actual gh exec after scan (for tests)
# ANONYMITY_MOCK_REPO_URL — inject fake head-repo nameWithOwner for scope (for tests)
# ---------------------------------------------------------------------------
if [[ -f "$LIB_ANONYMITY" ]]; then
    # shellcheck source=hooks/_lib_reviewer_anonymity.sh
    . "$LIB_ANONYMITY"

    _anon_subcommand="${1:-}"
    _anon_subcommand2="${2:-}"
    _is_review_or_comment=0
    if [[ "$_anon_subcommand" == "pr" ]] && \
       [[ "$_anon_subcommand2" == "review" || "$_anon_subcommand2" == "comment" ]]; then
        _is_review_or_comment=1
    fi

    if [[ "$_is_review_or_comment" == "1" ]]; then
        # Resolve head repo — use mock for tests, else query gh
        _head_repo=""
        if [[ -n "${ANONYMITY_MOCK_REPO_URL:-}" ]]; then
            _head_repo="$ANONYMITY_MOCK_REPO_URL"
        else
            # Find PR number from args (first numeric arg after subcommand pair)
            _pr_num=""
            _look_next=0
            for _arg in "$@"; do
                if [[ "$_look_next" == "1" ]]; then
                    _pr_num="$_arg"
                    break
                fi
                if [[ "$_arg" == "review" || "$_arg" == "comment" ]]; then
                    _look_next=1
                fi
            done
            if [[ -n "$_pr_num" && "$_pr_num" =~ ^[0-9]+$ ]]; then
                _head_repo="$(gh pr view "$_pr_num" --json headRepository -q '.headRepository.nameWithOwner' 2>/dev/null || true)"
            fi
        fi

        # Only enforce when head repo is work-scope (matches missmp/)
        _is_work=0
        if printf '%s' "$_head_repo" | grep -qE '[:/]missmp/|^missmp/'; then
            _is_work=1
        fi

        if [[ "$_is_work" == "1" ]]; then
            # Extract --body / -b value from args
            _body=""
            _prev_arg=""
            for _arg in "$@"; do
                if [[ "$_prev_arg" == "--body" || "$_prev_arg" == "-b" ]]; then
                    _body="$_arg"
                    break
                fi
                _prev_arg="$_arg"
            done

            if [[ -n "$_body" ]]; then
                if ! printf '%s' "$_body" | anonymity_scan_text; then
                    cat >&2 <<REJECT

[anonymity] Work-scope PR review/comment rejected: body contains agent-system
identifiers that must not appear in MMP-visible surfaces.

Remove the flagged tokens and retry. Use "-- reviewer" instead of an agent name.
Reference: architecture/pr-rules.md #work-scope-anonymity
REJECT
                    exit 3
                fi
            fi
        fi
    fi

    # ANONYMITY_DRY_RUN=1: skip actual gh exec (used by test fixtures d/e/f)
    if [[ "${ANONYMITY_DRY_RUN:-0}" == "1" ]]; then
        exit 0
    fi
fi

# Decrypt and exec gh with GH_TOKEN in env only. tools/decrypt.sh --exec places
# the plaintext in the child process env via `exec env KEY=val cmd...`.
# The plaintext never surfaces in this shell's variable space, argv, or stdout.
# The --target file (mode 600, gitignored under secrets/) is a decrypt.sh
# implementation requirement; it is not echoed or logged anywhere.
cat "$AGE_FILE" | "$DECRYPT" \
    --target "$ENV_TARGET" \
    --var GH_TOKEN \
    --exec -- gh "$@"

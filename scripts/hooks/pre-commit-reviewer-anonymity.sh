#!/usr/bin/env bash
# scripts/hooks/pre-commit-reviewer-anonymity.sh
#
# Pre-commit hook: work-scope reviewer anonymity guard.
# Scans the commit message for agent-system internals that must not leak
# into work-visible surfaces (MMP teammates / colleagues can see those PRs).
#
# Only enforces when the current repo's origin matches [:/]missmp/
# (canonical work-scope signal). Personal-concern repos are unaffected.
#
# Exit codes: 0 = pass (or non-work-scope), 1 = denylist hit
# All diagnostic output goes to stderr.
#
# Plan: 2026-04-22-work-scope-reviewer-anonymity.md T2

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source shared anonymity library
# shellcheck source=_lib_reviewer_anonymity.sh
. "$SCRIPT_DIR/_lib_reviewer_anonymity.sh"

# Resolve repo root — support ANONYMITY_HOOK_REPO override for testing
REPO_DIR="${ANONYMITY_HOOK_REPO:-$(git rev-parse --show-toplevel 2>/dev/null || echo ".")}"

# Only enforce on work-scope repos
if ! anonymity_is_work_scope "$REPO_DIR"; then
  exit 0
fi

# Read the commit message
COMMIT_MSG_FILE="${REPO_DIR}/.git/COMMIT_EDITMSG"
if [ ! -f "$COMMIT_MSG_FILE" ]; then
  # Fallback: if invoked as commit-msg hook with path as $1
  COMMIT_MSG_FILE="${1:-}"
fi

if [ -z "$COMMIT_MSG_FILE" ] || [ ! -f "$COMMIT_MSG_FILE" ]; then
  # Nothing to scan
  exit 0
fi

# Run the scan
if ! anonymity_scan_text < "$COMMIT_MSG_FILE"; then
  cat >&2 <<REJECT

[anonymity] Work-scope commit rejected: commit message contains agent-system
identifiers that must not appear in MMP-visible surfaces.

Remove the flagged tokens and retry. Generic alternatives:
  - Replace agent names with a role description (e.g. "reviewer")
  - Remove "Co-Authored-By: Claude" trailers entirely
  - Replace internal handles with a generic author attribution

Reference: architecture/pr-rules.md #work-scope-anonymity
REJECT
  exit 1
fi

exit 0

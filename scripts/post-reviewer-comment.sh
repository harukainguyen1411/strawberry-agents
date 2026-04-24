#!/usr/bin/env bash
# scripts/post-reviewer-comment.sh
#
# Sanctioned path for Yuumi fallback: post a reviewer verdict as a PR comment
# with anonymity enforcement.
#
# Usage:
#   scripts/post-reviewer-comment.sh --pr <N> --repo <owner>/<repo> --file <path>
#
# What it does:
#   1. Strips a trailing "— AgentName" / "-- AgentName" signature line.
#   2. Runs the stripped body through anonymity_scan_text from the shared library.
#   3. On scan hit: exits 3 (same contract as scripts/reviewer-auth.sh). Nothing posted.
#   4. On pass: exec `gh pr comment <N> --repo <r> -F <tmpfile>`.
#
# Environment:
#   ANONYMITY_DRY_RUN=1  — skip the actual gh call (for tests)
#
# Exit codes:
#   0 = posted successfully (or dry-run pass)
#   1 = usage / file error
#   2 = scan library unavailable
#   3 = anonymity scan hit — body rejected
#
# POSIX-portable bash per Rule 10.
# Plan: plans/approved/personal/2026-04-24-subagent-identity-leak-fix.md T3

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="$SCRIPT_DIR/hooks/_lib_reviewer_anonymity.sh"

if [ ! -f "$LIB" ]; then
  printf '[post-reviewer-comment] ERROR: anonymity library not found at %s\n' "$LIB" >&2
  exit 2
fi

# shellcheck source=hooks/_lib_reviewer_anonymity.sh
. "$LIB"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
PR_NUM=""
REPO=""
FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --pr)    PR_NUM="$2"; shift 2 ;;
    --repo)  REPO="$2";   shift 2 ;;
    --file)  FILE="$2";   shift 2 ;;
    *)
      printf '[post-reviewer-comment] Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$PR_NUM" ] || [ -z "$REPO" ] || [ -z "$FILE" ]; then
  printf 'Usage: %s --pr <N> --repo <owner>/<repo> --file <path>\n' "$0" >&2
  exit 1
fi

if [ ! -f "$FILE" ]; then
  printf '[post-reviewer-comment] ERROR: file not found: %s\n' "$FILE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Strip trailing signature lines using python3 (write via temp script file)
# Agent names are mirrored from _lib_reviewer_anonymity.sh inside the Python
# script below — single source of truth is the lib; update both together.
# ---------------------------------------------------------------------------
TMPFILE="$(mktemp)"
PYFILE="$(mktemp /tmp/post-reviewer-strip-XXXXXX.py)"
trap 'rm -f "$TMPFILE" "$PYFILE"' EXIT

cat > "$PYFILE" << 'PYEOF'
import sys, re

fpath = sys.argv[1]
outpath = sys.argv[2]

# Agent names (single source of truth mirrors _lib_reviewer_anonymity.sh denylist)
AGENT_NAMES = (
    "Senna", "Lucian", "Evelynn", "Sona", "Viktor", "Jayce", "Azir", "Swain",
    "Orianna", "Karma", "Talon", "Ekko", "Heimerdinger", "Syndra", "Akali", "Ahri", "Ori"
)
# Match trailing signature lines: "-- Senna" or "— Lucian" (em-dash or double-hyphen)
names_re = "|".join(re.escape(n) for n in AGENT_NAMES)
SIG_RE = re.compile(r'^(?:—|--)\s*(?:' + names_re + r')\s*$', re.UNICODE)

with open(fpath, 'r', encoding='utf-8') as f:
    lines = f.read().splitlines()

# Remove trailing blank lines, then one signature line if present
while lines and lines[-1].strip() == '':
    lines.pop()
if lines and SIG_RE.match(lines[-1].strip()):
    lines.pop()

with open(outpath, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
    if lines:
        f.write('\n')
PYEOF

python3 "$PYFILE" "$FILE" "$TMPFILE"

# ---------------------------------------------------------------------------
# Anonymity scan on stripped body
# ---------------------------------------------------------------------------
if ! anonymity_scan_text < "$TMPFILE"; then
  cat >&2 << 'REJECT'

[post-reviewer-comment] Work-scope PR comment rejected: body contains agent-system
identifiers that must not appear in MMP-visible surfaces.

Remove the flagged tokens and retry. Use "-- reviewer" instead of an agent name.
Reference: architecture/pr-rules.md #work-scope-anonymity
REJECT
  exit 3
fi

# ---------------------------------------------------------------------------
# Post comment (skip if dry-run)
# ---------------------------------------------------------------------------
if [ "${ANONYMITY_DRY_RUN:-0}" = "1" ]; then
  printf '[post-reviewer-comment] DRY-RUN: would post comment on PR %s in %s\n' "$PR_NUM" "$REPO" >&2
  exit 0
fi

exec gh pr comment "$PR_NUM" --repo "$REPO" -F "$TMPFILE"

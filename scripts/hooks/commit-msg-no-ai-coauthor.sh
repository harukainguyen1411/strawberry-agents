#!/usr/bin/env bash
# scripts/hooks/commit-msg-no-ai-coauthor.sh
# commit-msg hook: rejects commits whose message contains AI co-author trailers.
#
# Installed via: scripts/install-hooks.sh (commit-msg dispatcher)
# Plan: plans/in-progress/personal/2026-04-21-commit-msg-no-ai-coauthor-hook.md
#
# Rule: "Never include AI authoring references in commits" (global CLAUDE.md)
#
# Rejection patterns (case-insensitive POSIX ERE, §3 of plan):
#   ^Co-Authored-By:.*\b(claude|anthropic|ai|bot|assistant)\b
#   ^Co-Authored-By:.*@(anthropic\.com|claude\.com|noreply\.anthropic\.com)
#
# Escape hatch: add  Human-Verified: yes  (exact case, exact value) anywhere in
# the commit message to suppress the check for that commit only.
#
# Exit codes:
#   0 — message is clean (or escape hatch active)
#   1 — AI co-author trailer detected; message printed to stderr

set -uo pipefail

COMMIT_MSG_FILE="${1:-}"

if [ -z "$COMMIT_MSG_FILE" ]; then
  printf 'commit-msg-no-ai-coauthor.sh: missing argument (path to COMMIT_EDITMSG)\n' >&2
  exit 1
fi

if [ ! -f "$COMMIT_MSG_FILE" ]; then
  printf 'commit-msg-no-ai-coauthor.sh: file not found: %s\n' "$COMMIT_MSG_FILE" >&2
  exit 1
fi

# Escape hatch: Human-Verified: yes (exact case, exact value) anywhere in the message.
if grep -qF 'Human-Verified: yes' "$COMMIT_MSG_FILE"; then
  exit 0
fi

# Scan for AI co-author trailers.
# Pattern A: keyword in the name/display portion (word-boundary to avoid false matches
#             like "Kai" matching "ai").
# Pattern B: AI-associated email domain.
PATTERN_A='^Co-Authored-By:.*[[:space:](](claude|anthropic|ai|bot|assistant)[[:space:])>]'
PATTERN_B='^Co-Authored-By:.*@(anthropic\.com|claude\.com|noreply\.anthropic\.com)'

# Collect all offending lines (both patterns, deduplicated).
offending="$(grep -iE "$PATTERN_A|$PATTERN_B" "$COMMIT_MSG_FILE" 2>/dev/null || true)"

if [ -z "$offending" ]; then
  exit 0
fi

# Print rejection message to stderr.
printf '\n\342\234\230 AI co-author trailer detected in commit message:\n' >&2
while IFS= read -r line; do
  printf '    %s\n' "$line" >&2
done <<EOF
$offending
EOF

cat >&2 <<'REJECTION'

Per global CLAUDE.md: "Never include AI authoring references in commits."

Remove the trailer and retry. If a human collaborator's name legitimately
contains a blocked keyword, add a `Human-Verified: yes` trailer to override.
REJECTION

exit 1

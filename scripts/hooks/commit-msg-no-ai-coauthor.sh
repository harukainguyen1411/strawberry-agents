#!/usr/bin/env bash
# scripts/hooks/commit-msg-no-ai-coauthor.sh
# commit-msg hook: rejects commits whose message contains AI attribution or
# Co-Authored-By trailers of any kind.
#
# Installed via: scripts/install-hooks.sh (commit-msg dispatcher)
# Plans:
#   plans/in-progress/personal/2026-04-21-commit-msg-no-ai-coauthor-hook.md
#   plans/approved/personal/2026-04-25-no-ai-attribution-defense-in-depth.md
#
# Rules:
#   "Never include AI authoring references in commits" (global CLAUDE.md)
#   "Never write any Co-Authored-By: trailer" (_shared/no-ai-attribution.md)
#
# Rejection patterns:
#   PATTERN_A: ANY Co-Authored-By: trailer (universal block)
#   PATTERN_B: AI email domains (belt-and-suspenders)
#   PATTERN_C: AI markers in body — Claude, Anthropic, model names (Sonnet/Opus/Haiku),
#              robot emoji, "Generated with", "AI-generated", claude.com
#              Anchored to avoid false positives (e.g. "maintain" contains "ai").
#
# Escape hatch: add  Human-Verified: yes  (exact case, exact value) anywhere in
# the commit message to suppress all checks for that commit.
#
# Exit codes:
#   0 — message is clean (or escape hatch active)
#   1 — violation detected; message printed to stderr

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

offending=""

# --- Pattern A: ANY Co-Authored-By: trailer (universal block) ---
coauthor_lines="$(grep -iE '^Co-Authored-By:' "$COMMIT_MSG_FILE" 2>/dev/null || true)"
if [ -n "$coauthor_lines" ]; then
  offending="$offending
$coauthor_lines"
fi

# --- Pattern B: AI-associated email domain (belt-and-suspenders) ---
domain_lines="$(grep -iE '@(anthropic\.com|claude\.com|noreply\.anthropic\.com)' "$COMMIT_MSG_FILE" 2>/dev/null || true)"
if [ -n "$domain_lines" ]; then
  offending="$offending
$domain_lines"
fi

# --- Pattern C: AI markers in message body ---
# Markers (non-exhaustive per plan): Claude, Anthropic, Sonnet, Opus, Haiku,
# AI-generated, Generated with [Claude Code], robot emoji (🤖), claude.com.
#
# Anchoring: marker must be preceded by start-of-line, whitespace, (, [, backtick, :
# AND followed by end-of-line, whitespace, ), ], backtick, comma, period, >, /.
# This prevents matching substrings inside unrelated words (e.g. "maintain").
#
# Note: The robot emoji 🤖 and "Generated with" are caught verbatim without
# word-boundary anchoring (they are unambiguous markers).

# Anchoring uses two-pass approach: first grep for marker keywords with broad
# pattern, then validate surrounding context to avoid false positives.
# BSD grep (macOS) ERE does not support complex nested character classes reliably,
# so we use a simple word-boundary simulation: require whitespace or start/end of
# line on at least one side of the marker. The "maintain" false-positive is avoided
# because "ai" alone is not in the marker list — only full tokens are.
BODY_MARKERS='(^|[[:space:]])(claude|anthropic|sonnet|opus|haiku|AI-generated)([[:space:]]|[[:punct:]]|$)'
body_marker_lines="$(grep -iE "$BODY_MARKERS" "$COMMIT_MSG_FILE" 2>/dev/null || true)"
if [ -n "$body_marker_lines" ]; then
  offending="$offending
$body_marker_lines"
fi

# Additional verbatim markers (no anchoring needed — unambiguous)
verbatim_lines="$(grep -iE '🤖|Generated with \[Claude Code\]|claude\.com' "$COMMIT_MSG_FILE" 2>/dev/null || true)"
if [ -n "$verbatim_lines" ]; then
  offending="$offending
$verbatim_lines"
fi

# Deduplicate and strip leading blank line from concatenation
offending="$(printf '%s\n' "$offending" | grep -v '^[[:space:]]*$' | sort -u || true)"

if [ -z "$offending" ]; then
  exit 0
fi

printf '\n\342\234\230 AI attribution or Co-Authored-By trailer detected in commit message:\n' >&2
while IFS= read -r line; do
  [ -n "$line" ] && printf '    %s\n' "$line" >&2
done <<EOF
$offending
EOF

cat >&2 <<'REJECTION'

Per global CLAUDE.md and _shared/no-ai-attribution.md:
  - Never write any Co-Authored-By: trailer (universal block).
  - Never write AI markers in commit messages: Claude, Anthropic, Sonnet, Opus,
    Haiku, AI-generated, 🤖, "Generated with [Claude Code]", claude.com, etc.
    (Non-exhaustive — when in doubt, omit attribution.)

Remove the offending content and retry.

If a human collaborator legitimately needs attribution, add:
  Human-Verified: yes
trailer to the commit message to override this check for that commit only.
REJECTION

exit 1

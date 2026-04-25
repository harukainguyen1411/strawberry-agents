#!/usr/bin/env bash
# scripts/ci/pr-lint-no-ai-attribution.sh
#
# Scans PR body or comment text (passed via stdin) for AI attribution markers.
# Used by .github/workflows/pr-lint.yml (pr-no-ai-attribution job).
#
# Plan: plans/approved/personal/2026-04-25-no-ai-attribution-defense-in-depth.md T6
#
# Rules (from _shared/no-ai-attribution.md, non-exhaustive):
#   - Co-Authored-By: trailer (universal block)
#   - Claude, Anthropic, Sonnet, Opus, Haiku (word-boundary anchored)
#   - AI-generated, 🤖, Generated with [Claude Code], claude.com
#
# Override: a line containing exactly  Human-Verified: yes  suppresses the check.
#
# Usage:
#   printf '%s' "$PR_BODY" | bash scripts/ci/pr-lint-no-ai-attribution.sh
#
# Exit codes:
#   0 — clean (or Human-Verified: yes override present)
#   1 — AI attribution marker found

set -uo pipefail

# Read stdin into a temp file for multi-pass scanning
tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT INT TERM HUP
cat > "$tmpfile"

# Escape hatch
if grep -qF 'Human-Verified: yes' "$tmpfile"; then
  exit 0
fi

offending=""

# Co-Authored-By: trailer (any name)
coauthor="$(grep -iE '^Co-Authored-By:' "$tmpfile" 2>/dev/null || true)"
[ -n "$coauthor" ] && offending="$offending
$coauthor"

# AI markers (word-boundary anchored — same logic as commit-msg hook)
body_markers="$(grep -iE '(^|[[:space:]])(claude|anthropic|sonnet|opus|haiku|AI-generated)([[:space:]]|[[:punct:]]|$)' "$tmpfile" 2>/dev/null || true)"
[ -n "$body_markers" ] && offending="$offending
$body_markers"

# Verbatim unambiguous markers
verbatim="$(grep -iE '🤖|Generated with \[Claude Code\]|claude\.com' "$tmpfile" 2>/dev/null || true)"
[ -n "$verbatim" ] && offending="$offending
$verbatim"

# AI email domains
domains="$(grep -iE '@(anthropic\.com|claude\.com|noreply\.anthropic\.com)' "$tmpfile" 2>/dev/null || true)"
[ -n "$domains" ] && offending="$offending
$domains"

# Deduplicate
offending="$(printf '%s\n' "$offending" | grep -v '^[[:space:]]*$' | sort -u || true)"

if [ -z "$offending" ]; then
  exit 0
fi

printf '\n✘ AI attribution marker detected in PR body or comment:\n' >&2
while IFS= read -r line; do
  [ -n "$line" ] && printf '    %s\n' "$line" >&2
done <<EOF
$offending
EOF

cat >&2 <<'REJECTION'

Per _shared/no-ai-attribution.md (non-exhaustive marker list):
  - No Co-Authored-By: trailers in PR body or comments.
  - No AI markers: Claude, Anthropic, Sonnet, Opus, Haiku, AI-generated,
    🤖, "Generated with [Claude Code]", claude.com, etc.

Remove the offending content. If the attribution is legitimately from a human,
add a line  Human-Verified: yes  to the PR body to override this check.
REJECTION

exit 1

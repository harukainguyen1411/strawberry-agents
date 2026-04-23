#!/bin/sh
# orianna-hash-body.sh — Compute SHA-256 of a plan file's body (content after frontmatter).
#
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §D1, §D9.4, T1.1
#
# Normalization rules applied before hashing (per §D9.4):
#   1. Strip frontmatter — content between first two '---' lines is excluded.
#   2. Normalize line endings: CRLF → LF.
#   3. Strip trailing whitespace from each line.
#
# Usage:
#   bash scripts/orianna-hash-body.sh <plan.md>
#
# Output:
#   SHA-256 hex string on stdout (64 hex chars, no newline suffix).
#
# Exit codes:
#   0 — success
#   1 — usage error (wrong number of args, file not found)

set -eu

die() { printf '[orianna-hash-body] ERROR: %s\n' "$*" >&2; exit 1; }

[ $# -eq 1 ] || die "Usage: $0 <plan.md>"
PLAN="$1"
[ -f "$PLAN" ] || die "file not found: $PLAN"

# Extract body: skip from start through the second '---' line (frontmatter).
# Then normalize: strip CR, strip trailing whitespace.
extract_and_normalize() {
  awk '
    BEGIN { dashes = 0; past_fm = 0 }
    {
      # Normalize CR before any pattern matching
      gsub(/\r/, "")
    }
    /^---$/ && dashes < 2 {
      dashes++
      if (dashes == 2) { past_fm = 1 }
      next
    }
    past_fm {
      # Strip trailing whitespace
      sub(/[[:space:]]+$/, "")
      print
    }
  ' "$PLAN"
}

# Hash using sha256sum (Linux) or shasum -a 256 (macOS).
if command -v sha256sum >/dev/null 2>&1; then
  extract_and_normalize | sha256sum | awk '{print $1}'
elif command -v shasum >/dev/null 2>&1; then
  extract_and_normalize | shasum -a 256 | awk '{print $1}'
else
  die "no SHA-256 tool found (tried sha256sum, shasum)"
fi

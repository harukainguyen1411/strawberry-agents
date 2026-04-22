#!/bin/sh
# orianna-pre-fix.sh — Mechanical pre-pass rewrites on a plan before Orianna signing.
#
# Plan: plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md T9
#
# Applies three targeted rewrite passes to a plan file:
#   Pass A (work-concern only): requalify bare tools/demo-studio-v3/<path>
#             tokens to the workspace-prefixed form.
#   Pass B: append <!-- orianna: ok -- URL-shaped prose token (<host>) -->
#             to lines carrying backticked URL tokens from the known allowlist
#             (docs.anthropic.com, claude.ai, github.com) that do not already
#             have a suppressor.
#   Pass C: detect ? markers inside §10 (Open questions) or §11 (References)
#             and emit a WARNING to stderr; no file change.
#
# Usage:
#   bash scripts/orianna-pre-fix.sh <plan.md> [--concern work|personal]
#
# Concern inference:
#   If --concern is not given, the script reads the 'concern:' frontmatter field.
#   Pass A runs only for concern: work.
#
# Output:
#   stdout: one-line summary of rewrites applied (empty if no rewrites needed).
#   stderr: warnings from Pass C.
#   Exit 0 always (invocation errors also exit 0 with a stderr message).
#
# Idempotent: re-running on an already-fixed plan produces a zero-diff no-op.

set -eu

PLAN=""
CONCERN_FLAG=""

# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --concern)
      shift
      CONCERN_FLAG="$1"
      shift
      ;;
    --concern=*)
      CONCERN_FLAG="${1#--concern=}"
      shift
      ;;
    -*)
      printf '[orianna-pre-fix] ERROR: unknown flag: %s\n' "$1" >&2
      exit 0
      ;;
    *)
      if [ -z "$PLAN" ]; then
        PLAN="$1"
        shift
      else
        printf '[orianna-pre-fix] ERROR: unexpected argument: %s\n' "$1" >&2
        exit 0
      fi
      ;;
  esac
done

if [ -z "$PLAN" ]; then
  printf '[orianna-pre-fix] ERROR: no plan file specified\n' >&2
  exit 0
fi

if [ ! -f "$PLAN" ]; then
  printf '[orianna-pre-fix] ERROR: plan file not found: %s\n' "$PLAN" >&2
  exit 0
fi

# Determine concern
if [ -n "$CONCERN_FLAG" ]; then
  CONCERN="$CONCERN_FLAG"
else
  # Read from frontmatter
  CONCERN="$(awk '
    BEGIN { dashes=0 }
    /^---[[:space:]]*$/ { dashes++; if (dashes == 2) exit; next }
    dashes == 1 && /^concern:/ { sub(/^concern:[[:space:]]*/,""); print; exit }
  ' "$PLAN" 2>/dev/null || echo '')"
fi

REWRITES=""

# ---------------------------------------------------------------------------
# Pass A — workspace-prefix rewrite (work-concern plans only)
# ---------------------------------------------------------------------------
# Requalify bare `tools/demo-studio-v3/<path>` tokens to the workspace-
# prefixed form `mmp/workspace/tools/demo-studio-v3/<path>`.
# Only applies to inline backtick spans. Lines already having the workspace
# prefix are left unchanged (idempotency).
# ---------------------------------------------------------------------------
if [ "$CONCERN" = "work" ]; then
  TMP_A="$(mktemp /tmp/orianna-pre-fix-a-XXXXXX.md)"
  # Use perl for reliable in-place substitution of backtick spans.
  # Replace `tools/demo-studio-v3/ with `mmp/workspace/tools/demo-studio-v3/
  # only when NOT already preceded by mmp/workspace/ in the same token.
  if command -v perl >/dev/null 2>&1; then
    perl -pe 's/(`(?!mmp\/workspace\/)(tools\/demo-studio-v3\/[^`]*)`)/"$1" eq $& ? "`mmp\/workspace\/$2`" : $&/ge' \
      "$PLAN" > "$TMP_A"
  else
    # Fallback: sed-based rewrite (may miss edge cases with multi-backtick lines)
    sed 's/`tools\/demo-studio-v3\/\([^`]*\)`/`mmp\/workspace\/tools\/demo-studio-v3\/\1`/g' \
      "$PLAN" > "$TMP_A"
  fi

  if ! diff -q "$PLAN" "$TMP_A" >/dev/null 2>&1; then
    mv "$TMP_A" "$PLAN"
    REWRITES="${REWRITES}pass-A:workspace-prefix-rewrite "
  else
    rm -f "$TMP_A"
  fi
fi

# ---------------------------------------------------------------------------
# Pass B — URL suppressor insertion
# ---------------------------------------------------------------------------
# For lines containing backtick-quoted URL tokens from the known allowlist
# that do NOT already carry an orianna: ok suppressor, append a canned
# suppressor comment.
# Allowlist hosts: docs.anthropic.com, claude.ai, claude.com, github.com
# ---------------------------------------------------------------------------
TMP_B="$(mktemp /tmp/orianna-pre-fix-b-XXXXXX.md)"

if command -v perl >/dev/null 2>&1; then
  perl -pe '
    # Skip lines that already have a suppressor
    next if /orianna:\s*ok/;
    # Match backtick spans containing a known URL host
    if (/`https?:\/\/(docs\.anthropic\.com|claude\.ai|claude\.com|github\.com)[^`]*`/) {
      my $host = $1;
      # Determine a short label for the canned reason
      my $label = $host;
      $label =~ s/^docs\.//;  # docs.anthropic.com -> anthropic.com
      chomp;
      $_ .= " <!-- orianna: ok -- URL-shaped prose token ($label) -->\n";
    }
  ' "$PLAN" > "$TMP_B"
else
  # Pure awk fallback (no lookahead — simpler pattern match)
  awk '
    /orianna: ok/ { print; next }
    /`https?:\/\/(docs\.anthropic\.com|claude\.ai|claude\.com|github\.com)[^`]*`/ {
      # Extract the host from the URL
      match($0, /`https?:\/\/([^/`]+)/, arr)
      host = arr[1]
      # Strip leading docs.
      sub(/^docs\./, "", host)
      printf "%s <!-- orianna: ok -- URL-shaped prose token (%s) -->\n", $0, host
      next
    }
    { print }
  ' "$PLAN" > "$TMP_B" 2>/dev/null || \
  awk '
    /orianna: ok/ { print; next }
    /`https?:\/\// {
      printf "%s <!-- orianna: ok -- URL-shaped prose token (external-URL) -->\n", $0
      next
    }
    { print }
  ' "$PLAN" > "$TMP_B"
fi

if ! diff -q "$PLAN" "$TMP_B" >/dev/null 2>&1; then
  mv "$TMP_B" "$PLAN"
  REWRITES="${REWRITES}pass-B:url-suppressor-insertion "
else
  rm -f "$TMP_B"
fi

# ---------------------------------------------------------------------------
# Pass C — question-mark marker detection (report-only, no file change)
# ---------------------------------------------------------------------------
# Detect lines with bare ? markers inside §10 (Open questions) or §11
# (References) and emit a WARNING to stderr.
# ---------------------------------------------------------------------------
IN_SECTION_10_11=0
while IFS= read -r line; do
  # Detect section headings for §10 and §11
  case "$line" in
    "## 10."*|"## 11."*)
      IN_SECTION_10_11=1
      ;;
    "## "[0-9]*"."*)
      # Any other numbered section — exit §10/§11 scope
      if [ "$IN_SECTION_10_11" -eq 1 ]; then
        IN_SECTION_10_11=0
      fi
      ;;
    "#"*)
      # Higher-level heading — exit §10/§11 scope
      IN_SECTION_10_11=0
      ;;
  esac
  if [ "$IN_SECTION_10_11" -eq 1 ]; then
    case "$line" in
      *"?"*)
        printf '[orianna-pre-fix] WARNING: question-marker detected in §10/§11 (section 10 or 11) — human review needed: %s\n' "$line" >&2
        ;;
    esac
  fi
done < "$PLAN"

# Output summary
if [ -n "$REWRITES" ]; then
  # Trim trailing space
  REWRITES="$(printf '%s' "$REWRITES" | sed 's/ *$//')"
  printf '%s\n' "$REWRITES"
fi

exit 0

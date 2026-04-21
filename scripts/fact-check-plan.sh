#!/usr/bin/env bash
# fact-check-plan.sh — Pure-bash mechanical fallback for plan fact-checking.
#
# Used when the claude CLI is unavailable. Performs deterministic grep/ls
# checks for path-shaped tokens found in backtick spans and fenced code blocks.
#
# Contract: agents/orianna/claim-contract.md (v1)
# Allowlist: agents/orianna/allowlist.md
#
# Usage:
#   ./scripts/fact-check-plan.sh <plan-path.md>
#
# Exit codes:
#   0 — no block findings
#   1 — one or more block findings
#   2 — invocation error (bad args, missing file, etc.)
#
# Report written to: assessments/plan-fact-checks/<basename>-<ISO-timestamp>.md
# Report is always written, even on exit 1.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---- helpers ---------------------------------------------------------------

log_stderr() { printf '[fact-check-plan] %s\n' "$*" >&2; }

die() {
  log_stderr "ERROR: $*"
  exit 2
}

usage() {
  cat >&2 <<EOF
Usage: $0 <plan-path.md>

Pure-bash mechanical fact-check fallback. Checks path-shaped tokens found in
backtick spans and fenced-code blocks against the applicable repo checkout.
Used when the claude CLI is unavailable (does not check integration names —
that is LLM-only in v1).

Exit codes: 0=clean, 1=block findings, 2=invocation error
Report: assessments/plan-fact-checks/<basename>-<ISO-timestamp>.md
EOF
  exit 2
}

# ---- argument validation ---------------------------------------------------

[ $# -eq 1 ] || usage
PLAN_PATH="$1"

# Accept absolute or relative path.
case "$PLAN_PATH" in
  /*) ;;
  *)  PLAN_PATH="$REPO_ROOT/$PLAN_PATH" ;;
esac

[ -f "$PLAN_PATH" ] || die "plan file not found: $PLAN_PATH"
case "$PLAN_PATH" in
  *.md) ;;
  *)    die "plan file must end in .md (got $PLAN_PATH)" ;;
esac

# ---- constants -------------------------------------------------------------

STRAWBERRY_APP="${STRAWBERRY_APP:-$HOME/Documents/Personal/strawberry-app}"
# WORK_CONCERN_ROOT: default resolution root for all work-concern path tokens.
# Overridable via env for testing. WORK_CONCERN_REPO kept as alias for callers
# that set the old name; WORK_CONCERN_ROOT takes precedence when set explicitly.
WORK_CONCERN_ROOT="${WORK_CONCERN_ROOT:-$HOME/Documents/Work/mmp/workspace}"
WORK_CONCERN_REPO="$WORK_CONCERN_ROOT"
REPORT_DIR="$REPO_ROOT/assessments/plan-fact-checks"
PLAN_BASENAME="$(basename "$PLAN_PATH" .md)"
TIMESTAMP="$(date -u '+%Y-%m-%dT%H-%M-%SZ' 2>/dev/null || date '+%Y-%m-%dT%H-%M-%SZ')"
CHECKED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%SZ')"
REPORT_PATH="$REPORT_DIR/${PLAN_BASENAME}-${TIMESTAMP}.md"

mkdir -p "$REPORT_DIR"

# ---- frontmatter concern parsing -------------------------------------------
# Extract the concern: field from YAML frontmatter (between first two --- lines).
# Result is stored in PLAN_CONCERN; defaults to empty string (personal/legacy behavior).

PLAN_CONCERN=""
PLAN_CONCERN="$(awk '
  /^---/ { count++; if (count == 2) exit; next }
  count == 1 && /^concern:/ {
    val = $0
    sub(/^concern:[[:space:]]*/, "", val)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
    gsub(/^["'"'"']|["'"'"']$/, "", val)
    print val
    exit
  }
' "$PLAN_PATH")"

# ---- allowlist loading -----------------------------------------------------
# Build a simple lookup from agents/orianna/allowlist.md Section 1.
# We read lines under "## Section 1" that start with "- " and strip the prefix.

ALLOWLIST_FILE="$REPO_ROOT/agents/orianna/allowlist.md"
_allowlist=""
if [ -f "$ALLOWLIST_FILE" ]; then
  in_section1=0
  while IFS= read -r line; do
    case "$line" in
      "## Section 1"*) in_section1=1 ;;
      "## Section 2"*) in_section1=0 ;;
      "## "*) [ "$in_section1" -eq 1 ] && in_section1=0 ;;
    esac
    if [ "$in_section1" -eq 1 ]; then
      case "$line" in
        "- "*)
          entry="${line#- }"
          # Strip trailing whitespace
          entry="${entry%"${entry##*[![:space:]]}"}"
          _allowlist="${_allowlist}
${entry}"
          ;;
      esac
    fi
  done < "$ALLOWLIST_FILE"
fi

is_allowlisted() {
  local token="$1"
  # Case-insensitive prefix match — token must exactly match an allowlist entry
  local entry
  printf '%s\n' "$_allowlist" | while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    if [ "$(printf '%s' "$token" | tr '[:upper:]' '[:lower:]')" = "$(printf '%s' "$entry" | tr '[:upper:]' '[:lower:]')" ]; then
      echo "yes"
      return 0
    fi
  done
}

# ---- concern-aware routing -------------------------------------------------

# Opt-back list: these prefixes and exact file tokens always resolve against
# REPO_ROOT (strawberry-agents), even when PLAN_CONCERN is "work".
# Must match the list in agents/orianna/claim-contract.md §5 and
# agents/orianna/prompts/plan-check.md Step C.
_is_optback() {
  local tok="$1"
  case "$tok" in
    agents/*|plans/*|scripts/*|architecture/*|assessments/*|.claude/*|secrets/*)
      return 0 ;;
    tools/decrypt.sh|tools/encrypt.sh)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# Given a path token, return the repo root to check against, or "unknown".
#
# Resolution-root flip (concern: work):
#   - Tokens on the opt-back list (strawberry-agents infra) always resolve
#     against REPO_ROOT.
#   - Every other path-shaped token resolves against WORK_CONCERN_ROOT.
#     A miss there is a block finding (not an "unknown prefix" info finding).
#
# Non-work plans (concern: personal, unlabeled, or any other value):
#   - Original two-repo routing applies unchanged (backward-compatible default).
route_path() {
  local tok="$1"

  if [ "$PLAN_CONCERN" = "work" ]; then
    # Opt-back list: strawberry-agents infra paths always stay local.
    if _is_optback "$tok"; then
      printf '%s' "$REPO_ROOT"
      return
    fi
    # Root flip: all other paths resolve against the work monorepo root.
    printf '%s' "$WORK_CONCERN_ROOT"
    return
  fi

  # Non-work (personal / unlabeled): original two-repo routing.
  case "$tok" in
    agents/*|plans/*|scripts/*|architecture/*|assessments/*|.claude/*|tools/*)
      printf '%s' "$REPO_ROOT"
      ;;
    apps/*|dashboards/*|.github/workflows/*)
      printf '%s' "$STRAWBERRY_APP"
      ;;
    *)
      printf '%s' "unknown"
      ;;
  esac
}

# ---- token extraction ------------------------------------------------------
# Extract backtick spans and fenced-code lines from the plan.
# Strategy:
#   1. Strip orianna-suppressed tokens (<!-- orianna: ok --> pattern).
#   2. Extract inline backtick spans: `...`.
#   3. Extract fenced code block lines (between ``` fences).
#
# For each token, check if it is path-shaped (contains '/' or ends in a
# recognized extension). Flags (starting with '-') are skipped — not verifiable
# by bash. Integration names are not checked (LLM-only in v1).

extract_tokens() {
  local plan="$1"
  # Use awk to extract inline backticks and fenced code content.
  # Output one token per line.
  #
  # Suppression rule: a line is suppressed (all its tokens skipped) if:
  #   (a) the line itself contains the marker <!-- orianna: ok --> (at end or anywhere), OR
  #   (b) the immediately preceding line was a standalone <!-- orianna: ok --> marker.
  # This implements the escape hatch documented in agents/orianna/claim-contract.md
  # "Suppression syntax" section.
  awk '
    /^```/ {
      if (in_fence) { in_fence=0 } else { in_fence=1 }
      suppress_next = 0
      next
    }

    {
      # Determine if this line is suppressed.
      # suppress_next is set when the previous line was a standalone marker.
      suppressed = suppress_next
      suppress_next = 0

      # If this line itself contains the marker, suppress it too.
      if (index($0, "<!-- orianna: ok -->") > 0) {
        suppressed = 1
        # If the line IS only the marker (possibly with whitespace), the next
        # line is also suppressed (marker on preceding line case).
        stripped = $0
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", stripped)
        if (stripped == "<!-- orianna: ok -->") {
          suppress_next = 1
        }
      }

      if (suppressed) next
    }

    in_fence {
      # Emit each whitespace-separated word from fenced lines
      n = split($0, words, /[[:space:]]+/)
      for (i=1; i<=n; i++) {
        if (words[i] != "") print words[i]
      }
      next
    }

    {
      # Extract inline backtick spans
      # Skip spans that contain whitespace — those are prose examples ("scripts/foo.sh exists"),
      # not bare path claims. Bare path claims are single tokens without spaces.
      line = $0
      while (match(line, /`[^`]+`/)) {
        tok = substr(line, RSTART+1, RLENGTH-2)
        if (tok !~ /[[:space:]]/) print tok
        line = substr(line, RSTART+RLENGTH)
      }
    }
  ' "$plan"
}

# Check if a token looks like a path.
is_path_shaped() {
  local tok="$1"
  case "$tok" in
    */*) return 0 ;;   # contains slash
    *.sh|*.md|*.ts|*.js|*.tsx|*.jsx|*.json|*.yml|*.yaml|*.env|*.bats) return 0 ;;
    *) return 1 ;;
  esac
}

# ---- main check loop -------------------------------------------------------

block_findings=""
warn_findings=""
info_findings=""
block_count=0
warn_count=0
info_count=0
cross_repo_missing_count=0
cross_repo_missing_root=""
app_checkout_present=0
[ -d "$STRAWBERRY_APP" ] && app_checkout_present=1
work_concern_checkout_present=0
[ -d "$WORK_CONCERN_ROOT" ] && work_concern_checkout_present=1

# Process each extracted token
while IFS= read -r token; do
  # Skip empty tokens
  [ -z "$token" ] && continue

  # Strip leading/trailing punctuation that got included (quotes, parens, etc.)
  token="${token#\"}"
  token="${token%\"}"
  token="${token#\'}"
  token="${token%\'}"
  token="${token%(}"
  token="${token%,}"
  token="${token%.}"

  [ -z "$token" ] && continue

  # Skip flags
  case "$token" in
    -*) continue ;;
  esac

  # Strip :line-number suffix — e.g. "scripts/plan-promote.sh:63-86" is a cross-reference
  # annotation, not a distinct path. Strip the colon and everything after it so we check
  # the bare file path only.
  case "$token" in
    *:[0-9]*) token="${token%%:*}" ;;
  esac

  [ -z "$token" ] && continue

  # Skip glob patterns and template placeholders — these are documentation
  # examples, not real paths to verify.
  case "$token" in
    *\**) continue ;;       # glob patterns: agents/*/memory/**, *.md, etc.
    *\<*\>*) continue ;;    # template placeholders: <name>, <timestamp>, etc.
    *\[*\]*) continue ;;    # bracket expressions
    *YYYY*|*MM-DD*) continue ;;   # date template patterns
    *-XX-*|*-XX.*) continue ;;    # date templates with XX placeholder (e.g. 2026-04-XX-foo.md)
    *\{*|*\}*) continue ;;  # brace-expansion shorthand: agents/orianna/{a,b,c}
  esac

  # Only process path-shaped tokens
  is_path_shaped "$token" || continue

  # Route the path
  repo_root="$(route_path "$token")"

  if [ "$repo_root" = "unknown" ]; then
    info_count=$((info_count + 1))
    info_findings="${info_findings}
$((info_count)). **Claim:** \`${token}\` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info"
    continue
  fi

  # Cross-repo checkout guard — skip verification if the required checkout is absent.
  if [ "$repo_root" = "$STRAWBERRY_APP" ]; then
    if [ "$app_checkout_present" -eq 0 ]; then
      cross_repo_missing_count=$((cross_repo_missing_count + 1))
      cross_repo_missing_root="$STRAWBERRY_APP"
      continue
    fi
  fi
  if [ "$repo_root" = "$WORK_CONCERN_ROOT" ]; then
    if [ "$work_concern_checkout_present" -eq 0 ]; then
      cross_repo_missing_count=$((cross_repo_missing_count + 1))
      cross_repo_missing_root="$WORK_CONCERN_ROOT"
      continue
    fi
  fi

  # Check existence
  if test -e "$repo_root/$token"; then
    # Exists — info finding (clean pass)
    info_count=$((info_count + 1))
    info_findings="${info_findings}
$((info_count)). **Claim:** \`${token}\` | **Anchor:** \`test -e ${repo_root}/${token}\` | **Result:** exists | **Severity:** info"
  else
    # Does not exist — block finding
    block_count=$((block_count + 1))
    if [ "$repo_root" = "$STRAWBERRY_APP" ]; then
      checkout_note=" (checked against strawberry-app checkout at ${STRAWBERRY_APP})"
    elif [ "$repo_root" = "$WORK_CONCERN_ROOT" ]; then
      checkout_note=" (checked against work-concern checkout at ${WORK_CONCERN_ROOT})"
    else
      checkout_note=""
    fi
    block_findings="${block_findings}
$((block_count)). **Claim:** \`${token}\` | **Anchor:** \`test -e ${repo_root}/${token}\`${checkout_note} | **Result:** path not found | **Severity:** block"
  fi

done < <(extract_tokens "$PLAN_PATH")

# Emit a warn finding if cross-repo paths could not be verified (names the absent repo)
if [ "$cross_repo_missing_count" -gt 0 ]; then
  warn_count=$((warn_count + 1))
  _missing_repo="${cross_repo_missing_root:-$STRAWBERRY_APP}"
  if [ "$_missing_repo" = "$WORK_CONCERN_ROOT" ]; then
    _repo_label="work-concern checkout"
  else
    _repo_label="strawberry-app checkout"
  fi
  warn_findings="${warn_findings}
1. **Claim:** (cross-repo path check) | **Anchor:** \`test -d ${_missing_repo}\` | **Result:** could not verify ${cross_repo_missing_count} cross-repo path(s); ${_repo_label} not found at \`${_missing_repo}\` | **Severity:** warn"
fi

# ---- write report ----------------------------------------------------------

{
  cat <<FRONTMATTER
---
plan: ${PLAN_PATH#"$REPO_ROOT/"}
checked_at: ${CHECKED_AT}
auditor: orianna
claude_cli: absent
block_findings: ${block_count}
warn_findings: ${warn_count}
info_findings: ${info_count}
---

FRONTMATTER

  echo "## Block findings"
  echo ""
  if [ -n "$block_findings" ]; then
    printf '%s\n' "$block_findings" | sed '/^$/d'
  else
    echo "None."
  fi
  echo ""

  echo "## Warn findings"
  echo ""
  if [ -n "$warn_findings" ]; then
    printf '%s\n' "$warn_findings" | sed '/^$/d'
  else
    echo "None."
  fi
  echo ""

  echo "## Info findings"
  echo ""
  if [ -n "$info_findings" ]; then
    printf '%s\n' "$info_findings" | sed '/^$/d'
  else
    echo "None."
  fi
} > "$REPORT_PATH"

log_stderr "report written to: $REPORT_PATH"
log_stderr "block: ${block_count}  warn: ${warn_count}  info: ${info_count}"

if [ "$block_count" -gt 0 ]; then
  log_stderr "BLOCK findings present — promotion halted"
  exit 1
fi

exit 0

#!/bin/bash
# pr-lint-qa-verification.sh — QA verification marker enforcement (D6)
#
# Plan: plans/approved/personal/2026-04-27-qa-enforcement-and-breakdown-discipline.md §D6
# Task: T.QA.8
#
# Enforces QA markers in PR bodies per Rule 16 (amended):
#   - UI-involving PRs: require QA-Report:
#   - Non-UI PRs: require QA-Verification: (free-form non-empty)
#   - QA-Waiver: accepted only with paired Duong-Sign-Off: <iso8601> line
#
# UI classification uses body-keyword matching (path-glob classification is
# handled by the CI workflow that calls this helper; this helper does body-keyword
# and explicit-marker classification).
#
# UI keywords (extended from original Rule 16 per D1):
#   - route, form, state transition, auth flow, session lifecycle, user flow
#   - dashboard, static html, rendered output, visual inspection
#   - browser-renderable, html page, svg, pdf report
#
# Interface:
#   --pr-body-file <file>   Read PR body from file
#   (stdin fallback)        If no --pr-body-file, read from stdin
#
# Exit codes:
#   0 — PR body satisfies QA marker requirements
#   1 — violation detected
#
# POSIX-portable bash (Rule 10).

set -u

SCRIPT_NAME="pr-lint-qa-verification"
FAIL_PREFIX="[$SCRIPT_NAME]"

ADR_REF="plans/approved/personal/2026-04-27-qa-enforcement-and-breakdown-discipline.md"
RULE_REF="CLAUDE.md Rule 16"

# ---------------------------------------------------------------------------
# Read PR body
# ---------------------------------------------------------------------------

pr_body=""

if [ "${1:-}" = "--pr-body-file" ]; then
  body_file="${2:-}"
  if [ -z "$body_file" ]; then
    printf '%s usage: --pr-body-file <file>\n' "$FAIL_PREFIX" >&2
    exit 1
  fi
  if [ ! -f "$body_file" ]; then
    printf '%s PR body file not found: %s\n' "$FAIL_PREFIX" "$body_file" >&2
    exit 1
  fi
  pr_body="$(cat "$body_file")"
else
  # Read from stdin
  pr_body="$(cat)"
fi

if [ -z "$pr_body" ]; then
  printf '%s PR body is empty. Non-UI PRs require QA-Verification:; UI PRs require QA-Report:. See %s.\n' \
    "$FAIL_PREFIX" "$RULE_REF" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# UI classification (body-keyword based)
# ---------------------------------------------------------------------------

body_lower="$(printf '%s' "$pr_body" | tr '[:upper:]' '[:lower:]')"

is_ui=0
case "$body_lower" in
  *"new route"*|*"new form"*|*"state transition"*|*"auth flow"*|*"session lifecycle"*|*"user flow"*)
    is_ui=1 ;;
esac

if [ "$is_ui" -eq 0 ]; then
  case "$body_lower" in
    *"dashboard"*|*"static html"*|*"rendered output"*|*"visual inspection"*)
      is_ui=1 ;;
  esac
fi

if [ "$is_ui" -eq 0 ]; then
  case "$body_lower" in
    *"browser-renderable"*|*"html page"*|*"svg"*|*"pdf report"*)
      is_ui=1 ;;
  esac
fi

if [ "$is_ui" -eq 0 ]; then
  case "$body_lower" in
    *"ui-involving"*|*"ui involving"*)
      is_ui=1 ;;
  esac
fi

# Also classify as UI if body explicitly states QA-Report: marker
case "$pr_body" in
  *"QA-Report:"*) is_ui=1 ;;
esac

# ---------------------------------------------------------------------------
# Marker extraction
# ---------------------------------------------------------------------------

# Check for QA-Waiver: line
has_waiver=0
case "$pr_body" in
  *"QA-Waiver:"*) has_waiver=1 ;;
esac

# Check for Duong-Sign-Off: <iso8601> line
# Pattern: Duong-Sign-Off: YYYY-MM-DDTHH:MM:SSZ
has_duong_signoff=0
if printf '%s' "$pr_body" | grep -qE '^Duong-Sign-Off: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'; then
  has_duong_signoff=1
fi

# Check for QA-Report: line (non-empty)
has_qa_report=0
_qa_report_val="$(printf '%s' "$pr_body" | grep -m1 '^QA-Report:' | sed 's/^QA-Report://' || true)"
_qa_report_val="${_qa_report_val#"${_qa_report_val%%[![:space:]]*}"}"
_qa_report_val="${_qa_report_val%"${_qa_report_val##*[![:space:]]}"}"
if [ -n "$_qa_report_val" ]; then
  has_qa_report=1
fi

# Check for QA-Verification: line (non-empty — free-form per OQ#1b)
has_qa_verification=0
_qa_verif_val="$(printf '%s' "$pr_body" | grep -m1 '^QA-Verification:' | sed 's/^QA-Verification://' || true)"
_qa_verif_val="${_qa_verif_val#"${_qa_verif_val%%[![:space:]]*}"}"
_qa_verif_val="${_qa_verif_val%"${_qa_verif_val##*[![:space:]]}"}"
if [ -n "$_qa_verif_val" ]; then
  has_qa_verification=1
fi

# Check for QA-Verification-Skipped: (with paired sign-off)
has_qa_verif_skipped=0
case "$pr_body" in
  *"QA-Verification-Skipped:"*) has_qa_verif_skipped=1 ;;
esac

# ---------------------------------------------------------------------------
# Waiver validation (shared path)
# Waiver accepted only with paired Duong-Sign-Off: <iso8601>
# ---------------------------------------------------------------------------

if [ "$has_waiver" -eq 1 ]; then
  if [ "$has_duong_signoff" -eq 1 ]; then
    printf 'QA-Waiver accepted — Duong-Sign-Off present. PR body satisfies %s.\n' "$RULE_REF"
    exit 0
  else
    printf '%s QA-Waiver: present but missing required Duong-Sign-Off: <YYYY-MM-DDTHH:MM:SSZ> line.\n' \
      "$FAIL_PREFIX" >&2
    printf '%s A blanket QA-Waiver is no longer accepted without explicit Duong sign-off.\n' \
      "$FAIL_PREFIX" >&2
    printf '%s Add a line: Duong-Sign-Off: <iso8601-timestamp> to the PR body.\n' \
      "$FAIL_PREFIX" >&2
    printf '%s See %s §D1 and %s.\n' "$FAIL_PREFIX" "$ADR_REF" "$RULE_REF" >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# UI-involving PR rules
# ---------------------------------------------------------------------------

if [ "$is_ui" -eq 1 ]; then
  if [ "$has_qa_report" -eq 1 ]; then
    printf 'UI PR: QA-Report present. PR body satisfies %s.\n' "$RULE_REF"
    exit 0
  fi

  printf '%s UI-involving PR is missing QA-Report: marker.\n' "$FAIL_PREFIX" >&2
  printf '%s This PR touches a browser-renderable artifact (route, dashboard, static HTML, etc.).\n' \
    "$FAIL_PREFIX" >&2
  printf '%s Required: run Akali Playwright flow, then add QA-Report: <path> to the PR body.\n' \
    "$FAIL_PREFIX" >&2
  printf '%s See %s §D1 and %s.\n' "$FAIL_PREFIX" "$ADR_REF" "$RULE_REF" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Non-UI PR rules
# ---------------------------------------------------------------------------

if [ "$has_qa_verification" -eq 1 ]; then
  printf 'Non-UI PR: QA-Verification present. PR body satisfies %s.\n' "$RULE_REF"
  exit 0
fi

if [ "$has_qa_verif_skipped" -eq 1 ] && [ "$has_duong_signoff" -eq 1 ]; then
  printf 'Non-UI PR: QA-Verification-Skipped with Duong-Sign-Off accepted. PR body satisfies %s.\n' \
    "$RULE_REF"
  exit 0
fi

printf '%s Non-UI PR is missing QA-Verification: marker.\n' "$FAIL_PREFIX" >&2
printf '%s Required: add "QA-Verification: <commands-run-and-results>" to the PR body.\n' \
  "$FAIL_PREFIX" >&2
printf '%s The value should describe what verification commands were run and that they passed.\n' \
  "$FAIL_PREFIX" >&2
printf '%s Alternatively, use "QA-Waiver: <reason>" paired with "Duong-Sign-Off: <iso8601>".\n' \
  "$FAIL_PREFIX" >&2
printf '%s See %s §D6 and %s.\n' "$FAIL_PREFIX" "$ADR_REF" "$RULE_REF" >&2
exit 1

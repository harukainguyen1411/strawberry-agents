#!/usr/bin/env bash
# scripts/plan-structure-lint.sh
#
# Promote-time §UX Spec linter (T-B4)
# Plan: plans/approved/personal/2026-04-25-frontend-uiux-in-process.md T-B4
#
# Usage: bash scripts/plan-structure-lint.sh <plan-file>
#
# Exit codes:
#   0  — plan passes all checks (or is exempt)
#   1  — plan fails a check (error message on stderr)
#   2  — usage error or unreadable file
#
# Checks (§UX Spec rule):
#   - If the plan's tasks reference UI path-glob files (see UI_GLOBS below)
#     AND the plan does not have a UX-Waiver: frontmatter line:
#       * The plan body must contain the header "## UX Spec"
#       * The §UX Spec section must have non-empty body (not heading-only)
#   - Non-UI plans skip the check and exit 0.
#   - Malformed YAML frontmatter: exit 1 with a clean error message (no crash).
#
# UI path-glob (D1 of plans/approved/personal/2026-04-25-frontend-uiux-in-process.md):
#   apps/**/src/**/*.{vue,tsx,jsx,ts,js,css,scss}
#   apps/**/components/**
#   apps/**/pages/**
#   apps/**/routes/**
#
# Bypass: UX-Waiver: <reason> in plan frontmatter exits 0 without checking §UX Spec.

set -uo pipefail

PLAN_FILE="${1:-}"

# ---------------------------------------------------------------------------
# Usage guard
# ---------------------------------------------------------------------------

if [ -z "$PLAN_FILE" ]; then
  printf 'plan-structure-lint: ERROR: no plan file specified\n' >&2
  printf 'Usage: %s <plan-file>\n' "$0" >&2
  exit 2
fi

if [ ! -f "$PLAN_FILE" ]; then
  printf 'plan-structure-lint: ERROR: plan file not found: %s\n' "$PLAN_FILE" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# UI path-glob patterns (single source of truth — matches D1 globs)
# POSIX extended regex form (for grep -E).
#
# NOTE: Must use ERE syntax — no BRE escapes (\( \| \)).
# BSD grep (macOS, Rule 10) does not support \b; use ([^[:alnum:]]|$) anchor.
# ---------------------------------------------------------------------------

UI_GLOBS_RE='apps/[^[:space:]]*/src/[^[:space:]]*\.(vue|tsx|jsx|ts|js|css|scss)([^[:alnum:]]|$)|apps/[^[:space:]]*/components/|apps/[^[:space:]]*/pages/|apps/[^[:space:]]*/routes/'

# ---------------------------------------------------------------------------
# Extract frontmatter block (content between first two --- delimiters)
# Returns empty string if frontmatter is missing or malformed.
# ---------------------------------------------------------------------------

_extract_frontmatter() {
  awk '
    /^---/ {
      count++
      if (count == 1) { next }
      if (count == 2) { exit }
    }
    count == 1 { print }
  ' "$1"
}

# ---------------------------------------------------------------------------
# Check if frontmatter is present and parseable (heuristic: has at least one
# key: value line). Returns 0 if parseable, 1 if malformed/absent.
# ---------------------------------------------------------------------------

_frontmatter_is_valid() {
  local fm
  fm="$(_extract_frontmatter "$1")"

  if [ -z "$fm" ]; then
    printf 'plan-structure-lint: ERROR: no valid YAML frontmatter found in %s\n' "$1" >&2
    return 1
  fi

  # Detect obviously broken YAML: unclosed brackets, multiple colons in value
  # that look like nested keys on the same line, etc. We use a simple heuristic:
  # if a line has the form "  key: value: value" that is a sign of broken YAML.
  # We're not a full YAML parser — treat as "parseable enough" if at least one
  # clean key: value line exists.
  local clean_lines
  clean_lines="$(printf '%s\n' "$fm" | grep -c '^[a-zA-Z_][a-zA-Z0-9_-]*:' 2>/dev/null || true)"

  if [ "${clean_lines:-0}" -eq 0 ]; then
    printf 'plan-structure-lint: ERROR: frontmatter in %s has no parseable key:value lines\n' "$1" >&2
    return 1
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Check for UX-Waiver in frontmatter. Returns 0 if waiver is present.
# ---------------------------------------------------------------------------

_has_ux_waiver() {
  local fm
  fm="$(_extract_frontmatter "$1")"
  printf '%s\n' "$fm" | grep -q '^UX-Waiver:' 2>/dev/null
}

# ---------------------------------------------------------------------------
# Extract complexity value from frontmatter.
# Returns the raw value string (e.g. "complex", "standard", "trivial").
# ---------------------------------------------------------------------------

_get_complexity() {
  local fm
  fm="$(_extract_frontmatter "$1")"
  printf '%s\n' "$fm" | grep '^complexity:' | head -1 | sed 's/^complexity:[[:space:]]*//' | tr -d '[:space:]'
}

# ---------------------------------------------------------------------------
# OQ-2: UX-Waiver is not permitted for complexity: complex plans.
# Returns 0 (violation found) if plan is complex AND has a waiver.
# ---------------------------------------------------------------------------

_waiver_complexity_violation() {
  local complexity
  complexity="$(_get_complexity "$1")"
  case "$complexity" in
    complex)
      # Waiver not allowed on complex plans (OQ-2)
      if _has_ux_waiver "$1"; then
        return 0
      fi
      ;;
  esac
  return 1
}

# ---------------------------------------------------------------------------
# Check if the plan body (non-frontmatter) references UI path-glob files.
#
# Scans ONLY the "## Tasks" section for "Files:" lines. Scanning the entire
# body risks false-positives when a non-UI plan pastes the canonical template
# verbatim — the <!-- path-glob ... --> comment block inside §UX Spec contains
# the same glob patterns and would trip a whole-body scan.
#
# Returns 0 if a UI path-glob match is found in Tasks Files: lines.
# ---------------------------------------------------------------------------

_is_ui_plan() {
  # Extract post-frontmatter body, then narrow to ## Tasks section Files: lines.
  awk '
    /^---/ { count++; next }
    count >= 2 { print }
  ' "$1" | awk '
    /^## Tasks/ { in_tasks=1; next }
    /^## /      { in_tasks=0 }
    in_tasks && /[Ff]iles:/ { print }
  ' | grep -qE "$UI_GLOBS_RE" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Check that §UX Spec section exists AND has non-empty body.
# Returns 0 if §UX Spec is present with body, 1 otherwise.
# ---------------------------------------------------------------------------

_has_uxspec_with_body() {
  local plan_body
  plan_body="$(awk '
    /^---/ { count++; next }
    count >= 2 { print }
  ' "$1")"

  # Check header is present
  if ! printf '%s\n' "$plan_body" | grep -q '^## UX Spec' 2>/dev/null; then
    return 1
  fi

  # Extract the body of the §UX Spec section: lines between "## UX Spec"
  # and the next "## " heading (or end of file). Count as "body" only lines
  # that are:
  #   - non-blank
  #   - not an HTML comment opener (<!-- ...) or closer (...-->)
  #   - not a markdown heading (### ... or ## ...)
  # This ensures a section containing only subheadings + comment scaffolding
  # is treated as heading-only (no narrative body).
  local in_section=0
  local in_html_comment=0
  local found_body=0

  while IFS= read -r line; do
    # Detect start of §UX Spec
    case "$line" in
      '## UX Spec'*)
        in_section=1
        continue
        ;;
    esac

    if [ "$in_section" -eq 1 ]; then
      # A new level-2 heading ends the section (must check BEFORE comment/blank skip)
      case "$line" in
        '## '*)
          break
          ;;
      esac

      # Track multi-line HTML comments: a line containing <!-- starts a block;
      # a line containing --> closes it. Single-line <!-- ... --> handled too.
      case "$line" in
        *'<!--'*)
          in_html_comment=1
          # Check if comment also closes on the same line
          case "$line" in *'-->'*) in_html_comment=0 ;; esac
          continue
          ;;
        *'-->'*)
          in_html_comment=0
          continue
          ;;
      esac

      # Skip lines inside a multi-line HTML comment
      if [ "$in_html_comment" -eq 1 ]; then
        continue
      fi

      # Skip blank lines — handle truly empty string first, then whitespace-only
      if [ -z "$line" ]; then
        continue
      fi
      if printf '%s' "$line" | grep -qE '^[[:space:]]+$' 2>/dev/null; then
        continue
      fi

      # Skip markdown headings of any level (###, ####, etc.) — subheadings
      # within §UX Spec are scaffolding, not narrative body
      case "$line" in
        '#'*)
          continue
          ;;
      esac

      # Non-blank, non-comment, non-heading — counts as narrative body
      found_body=1
      break
    fi
  done <<EOF
$(printf '%s\n' "$plan_body")
EOF

  if [ "$found_body" -eq 1 ]; then
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# Main logic
# ---------------------------------------------------------------------------

# Step 1: Validate frontmatter is parseable
if ! _frontmatter_is_valid "$PLAN_FILE"; then
  exit 1
fi

# Step 2: OQ-2 — reject UX-Waiver on complexity: complex plans
if _waiver_complexity_violation "$PLAN_FILE"; then
  printf 'plan-structure-lint: FAIL: %s\n' "$PLAN_FILE" >&2
  printf '  UX-Waiver is not permitted on plans with complexity: complex (OQ-2).\n' >&2
  printf '  Complex UI plans must include a full §UX Spec section.\n' >&2
  printf '  To resolve: remove UX-Waiver from frontmatter and author §UX Spec,\n' >&2
  printf '  or downgrade complexity to standard/trivial if the scope warrants it.\n' >&2
  exit 1
fi

# Step 3: Check for UX-Waiver bypass (standard/trivial only after OQ-2 gate)
if _has_ux_waiver "$PLAN_FILE"; then
  # Waiver present — exempt from §UX Spec requirement
  exit 0
fi

# Step 4: Determine if this is a UI-touching plan
if ! _is_ui_plan "$PLAN_FILE"; then
  # Non-UI plan — exempt from §UX Spec requirement
  exit 0
fi

# Step 5: UI plan — require §UX Spec with non-empty body
if _has_uxspec_with_body "$PLAN_FILE"; then
  exit 0
fi

# Check if at least the header is present (heading-only case)
plan_body_check="$(awk '/^---/{count++; next} count>=2{print}' "$PLAN_FILE")"

if printf '%s\n' "$plan_body_check" | grep -q '^## UX Spec' 2>/dev/null; then
  printf 'plan-structure-lint: FAIL: %s\n' "$PLAN_FILE" >&2
  printf '  UI-touching plan has "## UX Spec" header but section body is empty.\n' >&2
  printf '  All six subsections (User flow, Component states, Responsive behavior,\n' >&2
  printf '  Accessibility, Figma link, Out of scope) must have content.\n' >&2
  printf '  To bypass: add "UX-Waiver: <reason>" to plan frontmatter.\n' >&2
else
  printf 'plan-structure-lint: FAIL: %s\n' "$PLAN_FILE" >&2
  printf '  UI-touching plan is missing the "## UX Spec" section.\n' >&2
  printf '  Plans touching apps/**/src/**, apps/**/components/**, apps/**/pages/**,\n' >&2
  printf '  or apps/**/routes/** require a UX Spec section authored by Lulu (normal-track)\n' >&2
  printf '  or Neeko (complex-track) before implementation dispatch.\n' >&2
  printf '  To bypass: add "UX-Waiver: <reason>" to plan frontmatter.\n' >&2
fi

exit 1

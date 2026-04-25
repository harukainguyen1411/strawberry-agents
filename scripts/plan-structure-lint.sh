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
# POSIX extended regex form (for grep -E)
# ---------------------------------------------------------------------------

UI_GLOBS_RE='apps/[^[:space:]]*/src/[^[:space:]].*\.\(vue\|tsx\|jsx\|ts\|js\|css\|scss\)\b|apps/[^[:space:]]*/components/|apps/[^[:space:]]*/pages/|apps/[^[:space:]]*/routes/'

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
# Check if the plan body (non-frontmatter) references UI path-glob files.
# Scans all text lines (not just Tasks) for safety.
# Returns 0 if a UI path-glob match is found.
# ---------------------------------------------------------------------------

_is_ui_plan() {
  # Skip the frontmatter block, then grep remaining body for UI paths
  awk '
    /^---/ { count++; next }
    count >= 2 { print }
  ' "$1" | grep -qE "$UI_GLOBS_RE" 2>/dev/null
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
  # and the next "## " heading (or end of file). Check that at least one
  # non-empty, non-comment line exists in that range.
  local in_section=0
  local found_body=0

  while IFS= read -r line; do
    if printf '%s\n' "$line" | grep -q '^## UX Spec'; then
      in_section=1
      continue
    fi

    if [ "$in_section" -eq 1 ]; then
      # A new level-2 heading ends the section
      if printf '%s\n' "$line" | grep -q '^## '; then
        break
      fi

      # Ignore blank lines and HTML/markdown comments
      if printf '%s\n' "$line" | grep -qv '^[[:space:]]*$' 2>/dev/null; then
        if ! printf '%s\n' "$line" | grep -q '^<!--' 2>/dev/null; then
          found_body=1
          break
        fi
      fi
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

# Step 2: Check for UX-Waiver bypass
if _has_ux_waiver "$PLAN_FILE"; then
  # Waiver present — exempt from §UX Spec requirement
  exit 0
fi

# Step 3: Determine if this is a UI-touching plan
if ! _is_ui_plan "$PLAN_FILE"; then
  # Non-UI plan — exempt from §UX Spec requirement
  exit 0
fi

# Step 4: UI plan — require §UX Spec with non-empty body
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

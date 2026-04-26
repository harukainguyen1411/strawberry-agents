#!/bin/bash
# pre-commit-zz-idea-structure.sh — idea-structure lint for ideas/<concern>/**.
#
# Plan: plans/approved/personal/2026-04-25-plan-of-plans-and-parking-lot.md
# Task: T7 (implements T5 xfail tests); T8 wires this into the dispatcher;
#       T9 adds warning-only mode.
#
# Validates staged files under ideas/** against the light schema from §A2 / D1:
#
#   Required frontmatter fields (all five must be present):
#     title        — any non-empty string
#     concern      — must be "personal" or "work"
#     created      — ISO date YYYY-MM-DD
#     last_reviewed — ISO date YYYY-MM-DD
#     tags         — any non-empty value (the array is not parsed)
#
#   Forbidden body headers (case-sensitive):
#     ## Tasks
#     ## Test plan
#     ## Design
#     ## Decision
#     ## Risks
#     ## Rollback
#     ## Open questions
#
#   When a forbidden header is found the hook emits the canonical error message:
#     "this is a plan, not an idea — author it under plans/proposed/<concern>/ instead."
#
# Warning-only mode (T9):
#   When STRAWBERRY_IDEA_LINT_LEVEL=warn (or the current date is before the sunset
#   date constant SUNSET_DATE), the hook prints diagnostic to stderr with [warn] prefix
#   and exits 0.  After the sunset date the hook fails-closed (exit 1).
#
# Interface — two modes:
#   1. Normal pre-commit mode: reads staged files from `git diff --cached --name-only`.
#   2. Test-fixture mode: --fixture-path <file> --staged-path <path>
#
# Exit codes:
#   0 — all staged idea files are valid (or no idea files staged, or warn mode)
#   1 — one or more idea files fail validation (error mode only)
#
# POSIX-portable bash (Rule 10).

set -u

HOOK_NAME="pre-commit-zz-idea-structure"
REJECT_PREFIX="[$HOOK_NAME]"

# ---------------------------------------------------------------------------
# Warning-only sunset (T9)
# Before this date the hook exits 0 regardless of validation result (warn mode).
# After this date the hook exits 1 on validation failure (error mode).
# ---------------------------------------------------------------------------
SUNSET_DATE="2026-05-09"

# Current date as YYYY-MM-DD (POSIX-portable: date +%Y-%m-%d)
_today="$(date +%Y-%m-%d)"

# Determine effective lint level:
#   - If STRAWBERRY_IDEA_LINT_LEVEL=error → always error
#   - If STRAWBERRY_IDEA_LINT_LEVEL=warn  → always warn
#   - If unset → compare today vs SUNSET_DATE (warn before, error after)
_lint_level="${STRAWBERRY_IDEA_LINT_LEVEL:-auto}"

if [ "$_lint_level" = "auto" ]; then
  # String comparison works for ISO dates: "YYYY-MM-DD" sorts lexicographically.
  if [ "$_today" '<' "$SUNSET_DATE" ] || [ "$_today" = "$SUNSET_DATE" ]; then
    _lint_level="warn"
  else
    _lint_level="error"
  fi
fi

# ---------------------------------------------------------------------------
# Path predicate
# ---------------------------------------------------------------------------
is_ideas_path() {
  local p="${1#./}"
  case "$p" in
    ideas/*)
      return 0
      ;;
  esac
  return 1
}

# ---------------------------------------------------------------------------
# Frontmatter extraction
# extract_frontmatter_field <content> <field>
# Prints the field value; returns 1 if absent.
# ---------------------------------------------------------------------------
extract_frontmatter_field() {
  local content="$1"
  local field="$2"
  local in_front=0
  local found_open=0
  while IFS= read -r line; do
    if [ "$found_open" -eq 0 ] && [ "$line" = "---" ]; then
      found_open=1
      in_front=1
      continue
    fi
    if [ "$in_front" -eq 1 ] && [ "$line" = "---" ]; then
      break
    fi
    if [ "$in_front" -eq 1 ]; then
      case "$line" in
        "${field}:"*|"  ${field}:"*|"    ${field}:"*)
          local val
          val="${line#*${field}: }"
          val="${val#"${val%%[![:space:]]*}"}"
          printf '%s' "$val"
          return 0
          ;;
      esac
    fi
  done <<EOF
$content
EOF
  return 1
}

# field_present <content> <field>
# Returns 0 if field is present in frontmatter, 1 if absent.
field_present() {
  local content="$1"
  local field="$2"
  local val
  val="$(extract_frontmatter_field "$content" "$field")" && [ -n "$val" ]
}

# ---------------------------------------------------------------------------
# emit_diagnostic <level> <message>
# Prints to stderr.  level = "warn" or "error".
# ---------------------------------------------------------------------------
emit_diagnostic() {
  local level="$1"
  local msg="$2"
  if [ "$level" = "warn" ]; then
    printf '[warn] %s %s\n' "$REJECT_PREFIX" "$msg" >&2
  else
    printf '%s %s\n' "$REJECT_PREFIX" "$msg" >&2
  fi
}

# ---------------------------------------------------------------------------
# validate_idea_content <content> <staged-path> <lint-level>
# Returns 0 if valid, 1 if any validation fails.
# ---------------------------------------------------------------------------
validate_idea_content() {
  local content="$1"
  local staged_path="$2"
  local level="$3"
  local rc=0

  # --- Required frontmatter fields ---

  # title
  if ! field_present "$content" "title"; then
    emit_diagnostic "$level" "$staged_path: title: field required"
    rc=1
  fi

  # concern: must be personal or work
  local concern
  concern="$(extract_frontmatter_field "$content" "concern" 2>/dev/null)" || concern=""
  # Strip inline comment
  concern="${concern%%#*}"
  concern="${concern%"${concern##*[![:space:]]}"}"
  if [ -z "$concern" ]; then
    emit_diagnostic "$level" "$staged_path: concern: field required (personal|work)"
    rc=1
  else
    case "$concern" in
      personal|work)
        ;;
      *)
        emit_diagnostic "$level" "$staged_path: concern: value \"$concern\" is not allowed (must be personal or work)"
        rc=1
        ;;
    esac
  fi

  # created: ISO date
  local created
  created="$(extract_frontmatter_field "$content" "created" 2>/dev/null)" || created=""
  created="${created%%#*}"
  created="${created%"${created##*[![:space:]]}"}"
  if [ -z "$created" ]; then
    emit_diagnostic "$level" "$staged_path: created: field required (ISO date YYYY-MM-DD)"
    rc=1
  elif ! printf '%s' "$created" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    emit_diagnostic "$level" "$staged_path: created: value \"$created\" is not a valid ISO date (YYYY-MM-DD)"
    rc=1
  fi

  # last_reviewed: ISO date
  local last_reviewed
  last_reviewed="$(extract_frontmatter_field "$content" "last_reviewed" 2>/dev/null)" || last_reviewed=""
  last_reviewed="${last_reviewed%%#*}"
  last_reviewed="${last_reviewed%"${last_reviewed##*[![:space:]]}"}"
  if [ -z "$last_reviewed" ]; then
    emit_diagnostic "$level" "$staged_path: last_reviewed: field required (ISO date YYYY-MM-DD)"
    rc=1
  elif ! printf '%s' "$last_reviewed" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    emit_diagnostic "$level" "$staged_path: last_reviewed: value \"$last_reviewed\" is not a valid ISO date (YYYY-MM-DD)"
    rc=1
  fi

  # tags
  if ! field_present "$content" "tags"; then
    emit_diagnostic "$level" "$staged_path: tags: field required"
    rc=1
  fi

  # --- Forbidden body headers ---
  # Only scan lines AFTER the closing --- of the frontmatter block.
  local in_front=0
  local found_open=0
  local past_front=0
  local FORBIDDEN_HEADER_FOUND=0

  while IFS= read -r line; do
    if [ "$past_front" -eq 0 ]; then
      if [ "$found_open" -eq 0 ] && [ "$line" = "---" ]; then
        found_open=1
        in_front=1
        continue
      fi
      if [ "$in_front" -eq 1 ] && [ "$line" = "---" ]; then
        past_front=1
        continue
      fi
      continue
    fi

    # We are in the body now.
    case "$line" in
      "## Tasks"|"## Test plan"|"## Design"|"## Decision"|"## Risks"|"## Rollback"|"## Open questions")
        FORBIDDEN_HEADER_FOUND=1
        break
        ;;
    esac
  done <<EOF
$content
EOF

  if [ "$FORBIDDEN_HEADER_FOUND" -eq 1 ]; then
    emit_diagnostic "$level" "$staged_path: this is a plan, not an idea — author it under plans/proposed/<concern>/ instead."
    rc=1
  fi

  return $rc
}

# ---------------------------------------------------------------------------
# resolve_exit_code <validation-rc> <lint-level>
# In warn mode: always exit 0 (diagnostic already printed).
# In error mode: propagate validation rc.
# ---------------------------------------------------------------------------
resolve_exit_code() {
  local validation_rc="$1"
  local level="$2"
  if [ "$level" = "warn" ]; then
    exit 0
  fi
  exit "$validation_rc"
}

# ---------------------------------------------------------------------------
# Main — two modes
# ---------------------------------------------------------------------------

if [ "${1:-}" = "--fixture-path" ]; then
  # Test-fixture mode
  fixture_file="${2:-}"
  staged_path="${4:-}"  # arg 3 = --staged-path, arg 4 = value

  if [ -z "$fixture_file" ] || [ -z "$staged_path" ]; then
    printf '%s usage: --fixture-path <file> --staged-path <path>\n' "$REJECT_PREFIX" >&2
    exit 1
  fi

  if ! is_ideas_path "$staged_path"; then
    exit 0
  fi

  content="$(cat "$fixture_file")"
  validate_idea_content "$content" "$staged_path" "$_lint_level"
  _vrc=$?
  resolve_exit_code "$_vrc" "$_lint_level"
fi

# Normal pre-commit mode
_staged="$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)" || true

if [ -z "$_staged" ]; then
  exit 0
fi

_rc=0
while IFS= read -r staged_file; do
  [ -z "$staged_file" ] && continue

  if ! is_ideas_path "$staged_file"; then
    continue
  fi

  content="$(git show ":${staged_file}" 2>/dev/null)" || {
    emit_diagnostic "$_lint_level" "could not read staged content for $staged_file"
    _rc=1
    continue
  }

  validate_idea_content "$content" "$staged_file" "$_lint_level" || _rc=1
done <<EOF
$_staged
EOF

resolve_exit_code "$_rc" "$_lint_level"

#!/bin/bash
# pre-commit-zz-plan-structure.sh — plan-structure lint for plans/proposed/**.
#
# Plan: plans/approved/personal/2026-04-25-plan-of-plans-and-parking-lot.md
# Task: T6 (implements T4 xfail tests)
#
# Enforces two required frontmatter fields on every staged file under plans/proposed/**:
#   priority:      must be one of P0|P1|P2|P3
#   last_reviewed: must be an ISO date (YYYY-MM-DD)
#
# Only files staged under plans/proposed/ are gated.  Files staged under
# plans/approved/, plans/in-progress/, etc. are ignored.
#
# Interface — two modes of operation:
#   1. Normal pre-commit mode: reads staged files from `git diff --cached --name-only`.
#      Reads file content from the index (git show :path) so it validates what will
#      actually be committed, not the working-tree state.
#   2. Test-fixture mode: invoked with --fixture-path <file> --staged-path <path>
#      Reads content from <file> on disk; uses <path> to determine if it is
#      under plans/proposed/ (without requiring a git staging step in tests).
#
# Exit codes:
#   0 — all staged proposed plans are valid (or no proposed plans staged)
#   1 — one or more proposed plans fail validation
#
# POSIX-portable bash (Rule 10): no GNU-only date -d, no process substitution
# that isn't supported by bash 3.2+ (macOS default).

set -u

HOOK_NAME="pre-commit-zz-plan-structure"
REJECT_PREFIX="[$HOOK_NAME]"

# ---------------------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------------------

# is_proposed_path <staged-path>
# Returns 0 if the path falls under plans/proposed/**, else 1.
is_proposed_path() {
  local p="${1#./}"
  case "$p" in
    plans/proposed/*)
      return 0
      ;;
  esac
  return 1
}

# extract_frontmatter_field <content-lines> <field>
# Prints the value for the first occurrence of "<field>: <value>" in the YAML
# frontmatter (between the first pair of --- delimiters).
# Prints nothing if field is absent.
extract_frontmatter_field() {
  local content="$1"
  local field="$2"
  # Read only between the first pair of --- lines (frontmatter block).
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
      # Match lines of the form "field: value" (leading spaces tolerated).
      case "$line" in
        "${field}:"*|"  ${field}:"*|"    ${field}:"*)
          # Extract value after the colon+space
          local val
          val="${line#*${field}: }"
          # Strip leading whitespace in case of extra spaces
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

# validate_priority <value> <staged-path>
# Returns 0 if valid, 1 if missing, 2 if wrong value.
validate_priority() {
  local val="$1"
  local path="$2"

  if [ -z "$val" ]; then
    printf '%s %s: priority: field required (P0|P1|P2|P3)\n' \
      "$REJECT_PREFIX" "$path" >&2
    return 1
  fi

  # Strip any inline YAML comment (# ...)
  val="${val%%#*}"
  # Strip trailing whitespace
  val="${val%"${val##*[![:space:]]}"}"

  case "$val" in
    P0|P1|P2|P3)
      return 0
      ;;
    *)
      printf '%s %s: priority: value "%s" is not allowed (must be P0|P1|P2|P3)\n' \
        "$REJECT_PREFIX" "$path" "$val" >&2
      return 2
      ;;
  esac
}

# validate_last_reviewed <value> <staged-path>
# Returns 0 if valid ISO date YYYY-MM-DD, 1 otherwise.
validate_last_reviewed() {
  local val="$1"
  local path="$2"

  if [ -z "$val" ]; then
    printf '%s %s: last_reviewed: field required (ISO date YYYY-MM-DD)\n' \
      "$REJECT_PREFIX" "$path" >&2
    return 1
  fi

  # Strip any inline YAML comment (# ...)
  val="${val%%#*}"
  # Strip trailing whitespace
  val="${val%"${val##*[![:space:]]}"}"

  # POSIX-portable regex via case: match YYYY-MM-DD with rough digit-group check.
  # We use grep -E for the pattern match (POSIX).
  if printf '%s' "$val" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    return 0
  fi

  printf '%s %s: last_reviewed: value "%s" is not a valid ISO date (YYYY-MM-DD)\n' \
    "$REJECT_PREFIX" "$path" "$val" >&2
  return 1
}

# ---------------------------------------------------------------------------
# validate_plan_content <content> <staged-path>
# Returns 0 if valid, 1 if any validation fails.
# ---------------------------------------------------------------------------
validate_plan_content() {
  local content="$1"
  local staged_path="$2"
  local rc=0

  local priority
  priority="$(extract_frontmatter_field "$content" "priority")" || true

  local last_reviewed
  last_reviewed="$(extract_frontmatter_field "$content" "last_reviewed")" || true

  validate_priority "$priority" "$staged_path" || rc=1
  validate_last_reviewed "$last_reviewed" "$staged_path" || rc=1

  return $rc
}

# ---------------------------------------------------------------------------
# Main — two modes
# ---------------------------------------------------------------------------

# Test-fixture mode: --fixture-path <file> --staged-path <path>
if [ "${1:-}" = "--fixture-path" ]; then
  fixture_file="${2:-}"
  staged_path="${4:-}"  # --staged-path is arg 3, value is arg 4

  if [ -z "$fixture_file" ] || [ -z "$staged_path" ]; then
    printf '%s usage: --fixture-path <file> --staged-path <path>\n' "$REJECT_PREFIX" >&2
    exit 1
  fi

  if ! is_proposed_path "$staged_path"; then
    # Not a proposed path — skip validation.
    exit 0
  fi

  content="$(cat "$fixture_file")"
  validate_plan_content "$content" "$staged_path"
  exit $?
fi

# Normal pre-commit mode: scan staged files.
_staged="$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)" || true

if [ -z "$_staged" ]; then
  exit 0
fi

_rc=0
while IFS= read -r staged_file; do
  [ -z "$staged_file" ] && continue

  if ! is_proposed_path "$staged_file"; then
    continue
  fi

  # Read from git index (what will be committed).
  content="$(git show ":${staged_file}" 2>/dev/null)" || {
    printf '%s could not read staged content for %s\n' "$REJECT_PREFIX" "$staged_file" >&2
    _rc=1
    continue
  }

  validate_plan_content "$content" "$staged_file" || _rc=1
done <<EOF
$_staged
EOF

exit $_rc

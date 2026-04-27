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

# Derive repo root (needed for downstream_plan path validation).
# In normal pre-commit mode this is the git repo root.
# In fixture mode REPO_ROOT is overridable via env.
if [ -z "${REPO_ROOT:-}" ]; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || REPO_ROOT=""
fi

# ---------------------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------------------

# is_proposed_or_approved_path <staged-path>
# Returns 0 if the path falls under plans/proposed/** or plans/approved/**, else 1.
# Used to gate §QA Plan checks (D5 Surface 1 applies to proposed and approved).
is_proposed_or_approved_path() {
  local p="${1#./}"
  case "$p" in
    plans/proposed/*|plans/approved/*)
      return 0
      ;;
  esac
  return 1
}

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

# has_qa_plan_heading <content>
# Returns 0 if content contains a "## QA Plan" heading line outside a fenced
# code block (``` delimiters), else 1.
has_qa_plan_heading() {
  local content="$1"
  local fence=0
  while IFS= read -r line; do
    case "$line" in
      '```'*) fence=$(( 1 - fence )); continue ;;
    esac
    [ "$fence" -eq 1 ] && continue
    case "$line" in
      "## QA Plan"|"## QA Plan "*) return 0 ;;
    esac
  done <<EOF
$content
EOF
  return 1
}

# get_qa_plan_body <content>
# Prints the body text between the first "## QA Plan" heading (outside a fenced
# code block) and the next "## " heading (or EOF).
get_qa_plan_body() {
  local content="$1"
  local in_section=0
  local fence=0
  local body=""
  while IFS= read -r line; do
    case "$line" in
      '```'*) fence=$(( 1 - fence )); continue ;;
    esac
    if [ "$in_section" -eq 0 ]; then
      [ "$fence" -eq 1 ] && continue
      case "$line" in
        "## QA Plan"|"## QA Plan "*) in_section=1 ;;
      esac
      continue
    fi
    # Inside the section — stop at next ## heading (fence irrelevant here: we
    # already found our section, and we collect everything including inner fences)
    case "$line" in
      "## "*)
        break
        ;;
    esac
    body="${body}${line}
"
  done <<EOF
$content
EOF
  printf '%s' "$body"
}

# is_qa_plan_body_nonempty <body>
# Returns 0 if body contains at least one non-whitespace character, else 1.
is_qa_plan_body_nonempty() {
  local body="$1"
  # Strip all whitespace; if anything remains, it's non-empty.
  local stripped
  stripped="$(printf '%s' "$body" | tr -d '[:space:]')"
  [ -n "$stripped" ]
}

# get_ui_involvement <body>
# Prints the value after "**UI involvement:**" (yes/no or other).
# Returns 1 if the line is absent.
# The literal prefix contains ** which are shell globs — use awk for safe extraction.
get_ui_involvement() {
  local body="$1"
  local found=0
  local val=""
  while IFS= read -r line; do
    # Use grep -F for literal string detection
    if printf '%s' "$line" | grep -qF '**UI involvement:**'; then
      # awk extracts the portion after the literal prefix (character count approach)
      # prefix is 18 chars: **UI involvement:**
      val="$(printf '%s' "$line" | awk '{ idx=index($0, "**UI involvement:**"); if (idx>0) print substr($0, idx+19) }')"
      # Strip leading whitespace
      val="${val#"${val%%[![:space:]]*}"}"
      # Strip trailing whitespace
      val="${val%"${val##*[![:space:]]}"}"
      printf '%s' "$val"
      return 0
    fi
  done <<EOF
$body
EOF
  return 1
}

# validate_qa_plan <content> <staged-path>
# Returns 0 if the §QA Plan section is valid, 1 otherwise.
# Checks:
#   1. qa_plan frontmatter is present (required or none).
#   2. If qa_plan: required — ## QA Plan heading with non-empty body and valid **UI involvement:** yes|no.
#   3. If qa_plan: none — qa_plan_none_justification: present AND downstream_plan: path present
#      that resolves to proposed/, approved/, or in-progress/.
validate_qa_plan() {
  local content="$1"
  local staged_path="$2"
  local rc=0

  local qa_plan_val
  qa_plan_val="$(extract_frontmatter_field "$content" "qa_plan")" || true

  # Strip inline YAML comments and whitespace
  qa_plan_val="${qa_plan_val%%#*}"
  qa_plan_val="${qa_plan_val%"${qa_plan_val##*[![:space:]]}"}"
  qa_plan_val="${qa_plan_val#"${qa_plan_val%%[![:space:]]*}"}"

  if [ -z "$qa_plan_val" ]; then
    printf '%s %s: qa_plan: frontmatter field required (required|none). See ADR D2/D5.\n' \
      "$REJECT_PREFIX" "$staged_path" >&2
    return 1
  fi

  case "$qa_plan_val" in
    required)
      # Must have ## QA Plan heading with non-empty body and **UI involvement:** yes|no
      if ! has_qa_plan_heading "$content"; then
        printf '%s %s: ## QA Plan section missing. qa_plan: required demands a populated ## QA Plan section. See ADR D2/D5.\n' \
          "$REJECT_PREFIX" "$staged_path" >&2
        return 1
      fi

      local qa_body
      qa_body="$(get_qa_plan_body "$content")"

      if ! is_qa_plan_body_nonempty "$qa_body"; then
        printf '%s %s: ## QA Plan section is empty (whitespace-only). Populate the section per ADR D2. See ADR D2/D5.\n' \
          "$REJECT_PREFIX" "$staged_path" >&2
        return 1
      fi

      local ui_val
      ui_val="$(get_ui_involvement "$qa_body")" || true

      if [ -z "$ui_val" ]; then
        printf '%s %s: ## QA Plan missing "**UI involvement:** yes|no" line. This line is required to route to the correct QA branch. See ADR D2/D5.\n' \
          "$REJECT_PREFIX" "$staged_path" >&2
        return 1
      fi

      # Normalize to lowercase for comparison
      local ui_lower
      ui_lower="$(printf '%s' "$ui_val" | tr '[:upper:]' '[:lower:]')"
      case "$ui_lower" in
        yes|no) ;;
        *)
          printf '%s %s: ## QA Plan "**UI involvement:** %s" is invalid — only "yes" or "no" are accepted. See ADR D2/D5.\n' \
            "$REJECT_PREFIX" "$staged_path" "$ui_val" >&2
          return 1
          ;;
      esac
      ;;

    none)
      # Must have qa_plan_none_justification: field
      local justification
      justification="$(extract_frontmatter_field "$content" "qa_plan_none_justification")" || true
      justification="${justification#"${justification%%[![:space:]]*}"}"
      justification="${justification%"${justification##*[![:space:]]}"}"
      # Strip surrounding quotes if present
      case "$justification" in
        '"'*'"') justification="${justification#\"}" ; justification="${justification%\"}" ;;
        "'"*"'") justification="${justification#\'}" ; justification="${justification%\'}" ;;
      esac

      if [ -z "$justification" ]; then
        printf '%s %s: qa_plan: none requires companion field qa_plan_none_justification:. See ADR D2/D5 OQ#4.\n' \
          "$REJECT_PREFIX" "$staged_path" >&2
        return 1
      fi

      # Must also have downstream_plan: frontmatter field
      local downstream
      downstream="$(extract_frontmatter_field "$content" "downstream_plan")" || true
      downstream="${downstream#"${downstream%%[![:space:]]*}"}"
      downstream="${downstream%"${downstream##*[![:space:]]}"}"
      downstream="${downstream%%#*}"
      downstream="${downstream%"${downstream##*[![:space:]]}"}"

      if [ -z "$downstream" ]; then
        printf '%s %s: qa_plan: none requires downstream_plan: <path> frontmatter field pointing at a plan in proposed/, approved/, or in-progress/. See ADR D2/D5 OQ#4a.\n' \
          "$REJECT_PREFIX" "$staged_path" >&2
        return 1
      fi

      # Validate the downstream plan path resolves to a valid lifecycle stage
      case "$downstream" in
        plans/proposed/*|plans/approved/*|plans/in-progress/*)
          ;;
        *)
          printf '%s %s: downstream_plan: "%s" must point at a plan under plans/proposed/, plans/approved/, or plans/in-progress/. See ADR D5 OQ#4a.\n' \
            "$REJECT_PREFIX" "$staged_path" "$downstream" >&2
          return 1
          ;;
      esac

      # Verify the downstream plan actually exists on disk (if we have a repo root)
      if [ -n "$REPO_ROOT" ] && [ ! -f "$REPO_ROOT/$downstream" ]; then
        printf '%s %s: downstream_plan: "%s" does not exist on disk. Path must resolve to an existing plan file. See ADR D5 OQ#4a.\n' \
          "$REJECT_PREFIX" "$staged_path" "$downstream" >&2
        return 1
      fi
      ;;

    *)
      printf '%s %s: qa_plan: value "%s" is not valid (must be "required" or "none"). See ADR D2/D5.\n' \
        "$REJECT_PREFIX" "$staged_path" "$qa_plan_val" >&2
      return 1
      ;;
  esac

  return $rc
}

# ---------------------------------------------------------------------------
# validate_plan_content <content> <staged-path>
# Returns 0 if valid, 1 if any validation fails.
# ---------------------------------------------------------------------------
validate_plan_content() {
  local content="$1"
  local staged_path="$2"
  local rc=0

  # priority + last_reviewed only apply to proposed plans
  if is_proposed_path "$staged_path"; then
    local priority
    priority="$(extract_frontmatter_field "$content" "priority")" || true

    local last_reviewed
    last_reviewed="$(extract_frontmatter_field "$content" "last_reviewed")" || true

    validate_priority "$priority" "$staged_path" || rc=1
    validate_last_reviewed "$last_reviewed" "$staged_path" || rc=1
  fi

  # §QA Plan check applies to proposed and approved plans
  if is_proposed_or_approved_path "$staged_path"; then
    validate_qa_plan "$content" "$staged_path" || rc=1
  fi

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

  if ! is_proposed_or_approved_path "$staged_path"; then
    # Not a proposed/approved path — skip validation.
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

  if ! is_proposed_or_approved_path "$staged_file"; then
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

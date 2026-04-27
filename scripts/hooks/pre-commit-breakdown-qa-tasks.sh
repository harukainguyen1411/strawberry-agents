#!/bin/bash
# pre-commit-breakdown-qa-tasks.sh — breakdown QA Tasks subsection linter (D5 Surface 2)
#
# Plan: plans/approved/personal/2026-04-27-qa-enforcement-and-breakdown-discipline.md §D5 Surface 2
# Task: T.QA.7
#
# Identity-gated linter. Fires when the committing agent is aphelios or kayn AND
# the staged plan contains a "## Tasks" section. Requires a "### QA Tasks" subsection
# containing at least one task line (a line starting with - or *).
#
# Interface — two modes:
#   1. Normal pre-commit mode: reads staged files from `git diff --cached --name-only`.
#      Reads file content from the index (git show :path).
#   2. Test-fixture mode: --fixture-path <file> --staged-path <path>
#      Reads content from <file> on disk; STRAWBERRY_AGENT env var sets identity.
#
# Identity resolution order (mirrors pretooluse-plan-lifecycle-guard.sh):
#   1. CLAUDE_AGENT_NAME env var
#   2. STRAWBERRY_AGENT env var
#   3. Fail-open for unrecognised identities (non-breakdown agents pass through)
#
# Gated identities: aphelios, kayn (case-insensitive)
#
# Exit codes:
#   0 — valid (or identity not gated, or no ## Tasks section in staged plans)
#   1 — breakdown agent committed ## Tasks without ### QA Tasks subsection
#
# POSIX-portable bash (Rule 10).

set -u

HOOK_NAME="pre-commit-breakdown-qa-tasks"
REJECT_PREFIX="[$HOOK_NAME]"

# ---------------------------------------------------------------------------
# Identity resolution
# ---------------------------------------------------------------------------

# resolve_agent_identity
# Prints the lower-cased agent identity, or "" if unknown.
resolve_agent_identity() {
  local identity=""

  if [ -n "${CLAUDE_AGENT_NAME:-}" ]; then
    identity="$CLAUDE_AGENT_NAME"
  elif [ -n "${STRAWBERRY_AGENT:-}" ]; then
    identity="$STRAWBERRY_AGENT"
  fi

  printf '%s' "$identity" | tr '[:upper:]' '[:lower:]'
}

# is_breakdown_identity <identity>
# Returns 0 if the identity is a gated breakdown agent (aphelios or kayn), else 1.
is_breakdown_identity() {
  local id="$1"
  case "$id" in
    aphelios|kayn) return 0 ;;
  esac
  return 1
}

# ---------------------------------------------------------------------------
# Plan content checks
# ---------------------------------------------------------------------------

# has_tasks_heading <content>
# Returns 0 if content contains a "## Tasks" heading line (not ### Tasks), else 1.
has_tasks_heading() {
  local content="$1"
  while IFS= read -r line; do
    case "$line" in
      "## Tasks"|"## Tasks "*)
        return 0
        ;;
    esac
  done <<EOF
$content
EOF
  return 1
}

# has_qa_tasks_subsection <content>
# Returns 0 if content contains a "### QA Tasks" heading, else 1.
has_qa_tasks_subsection() {
  local content="$1"
  while IFS= read -r line; do
    case "$line" in
      "### QA Tasks"|"### QA Tasks "*)
        return 0
        ;;
    esac
  done <<EOF
$content
EOF
  return 1
}

# has_qa_tasks_content <content>
# Returns 0 if the ### QA Tasks subsection contains at least one task line
# (a line starting with - or * after the heading), else 1.
# Stops scanning at the next ## or ### heading after ### QA Tasks.
has_qa_tasks_content() {
  local content="$1"
  local in_qa_tasks=0
  while IFS= read -r line; do
    if [ "$in_qa_tasks" -eq 0 ]; then
      case "$line" in
        "### QA Tasks"|"### QA Tasks "*) in_qa_tasks=1 ;;
      esac
      continue
    fi
    # Stop at next heading of any level
    case "$line" in
      "## "*|"### "*|"#### "*)
        return 1
        ;;
    esac
    # Check for a task line (starts with - or *)
    case "$line" in
      "- "*|"* "*|"-"|"*")
        return 0
        ;;
    esac
  done <<EOF
$content
EOF
  return 1
}

# validate_breakdown_content <content> <staged-path> <identity>
# Returns 0 if valid, 1 if the linter must reject.
validate_breakdown_content() {
  local content="$1"
  local staged_path="$2"
  local identity="$3"

  # Only gate on breakdown identities
  if ! is_breakdown_identity "$identity"; then
    return 0
  fi

  # Only enforce if the plan has a ## Tasks section
  if ! has_tasks_heading "$content"; then
    return 0
  fi

  # Must have ### QA Tasks subsection
  if ! has_qa_tasks_subsection "$content"; then
    printf '%s %s: breakdown agent "%s" committed a ## Tasks section without a ### QA Tasks subsection.\n' \
      "$REJECT_PREFIX" "$staged_path" "$identity" >&2
    printf '%s See .claude/agents/aphelios.md Hard Rules and ADR D3:\n' \
      "$REJECT_PREFIX" >&2
    printf '%s   plans/approved/personal/2026-04-27-qa-enforcement-and-breakdown-discipline.md\n' \
      "$REJECT_PREFIX" >&2
    return 1
  fi

  # ### QA Tasks must have at least one task line
  if ! has_qa_tasks_content "$content"; then
    printf '%s %s: breakdown agent "%s" has an empty ### QA Tasks subsection (heading present but no task lines).\n' \
      "$REJECT_PREFIX" "$staged_path" "$identity" >&2
    printf '%s At least one "- " or "* " task line is required. See ADR D3.\n' \
      "$REJECT_PREFIX" >&2
    return 1
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Main — two modes
# ---------------------------------------------------------------------------

_identity="$(resolve_agent_identity)"

# Test-fixture mode: --fixture-path <file> --staged-path <path>
if [ "${1:-}" = "--fixture-path" ]; then
  fixture_file="${2:-}"
  staged_path="${4:-}"  # --staged-path is arg 3, value is arg 4

  if [ -z "$fixture_file" ] || [ -z "$staged_path" ]; then
    printf '%s usage: --fixture-path <file> --staged-path <path>\n' "$REJECT_PREFIX" >&2
    exit 1
  fi

  if [ ! -f "$fixture_file" ]; then
    printf '%s fixture file not found: %s\n' "$REJECT_PREFIX" "$fixture_file" >&2
    exit 1
  fi

  content="$(cat "$fixture_file")"
  validate_breakdown_content "$content" "$staged_path" "$_identity"
  exit $?
fi

# Normal pre-commit mode: scan staged files.
# Only run if identity is a breakdown agent (fast-path skip for non-breakdown agents).
if ! is_breakdown_identity "$_identity"; then
  exit 0
fi

_staged="$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)" || true

if [ -z "$_staged" ]; then
  exit 0
fi

_rc=0
while IFS= read -r staged_file; do
  [ -z "$staged_file" ] && continue

  # Only check plan files
  case "${staged_file#./}" in
    plans/*.md) ;;
    *) continue ;;
  esac

  content="$(git show ":${staged_file}" 2>/dev/null)" || {
    printf '%s could not read staged content for %s\n' "$REJECT_PREFIX" "$staged_file" >&2
    _rc=1
    continue
  }

  validate_breakdown_content "$content" "$staged_file" "$_identity" || _rc=1
done <<EOF
$_staged
EOF

exit $_rc

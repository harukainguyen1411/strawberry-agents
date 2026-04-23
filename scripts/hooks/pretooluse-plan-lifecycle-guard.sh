#!/bin/bash
# pretooluse-plan-lifecycle-guard.sh — PreToolUse physical guard for plan lifecycle.
# Plan: plans/approved/personal/2026-04-23-plan-lifecycle-physical-guard.md
#
# Fires before Bash / Write / Edit / NotebookEdit tool executions.
# Rejects (exit 2) any attempt to move, copy, delete, or write files under
# protected plan-lifecycle directories unless the calling agent is Orianna.
#
# Protected roots (repo-relative):
#   plans/approved/
#   plans/in-progress/
#   plans/implemented/
#   plans/archived/
#
# Unprotected (any agent may write freely):
#   plans/proposed/   and all subtrees
#
# Identity: read from $CLAUDE_AGENT_NAME, then $STRAWBERRY_AGENT (case-insensitive).
# Fail-closed: if neither is set, the guard rejects any access to protected paths.
#
# Input: JSON on stdin (Claude Code PreToolUse hook format).
# Exit 0 — allowed; exit 2 — blocked.
#
# POSIX-portable bash. Requires jq on PATH.

set -u

REJECT_MSG_PREFIX="[plan-lifecycle-guard]"

# --- resolve calling agent identity -----------------------------------------

_agent="${CLAUDE_AGENT_NAME:-}"
if [ -z "$_agent" ]; then
  _agent="${STRAWBERRY_AGENT:-}"
fi
# Lowercase for case-insensitive comparison
_agent_lc="$(printf '%s' "$_agent" | tr '[:upper:]' '[:lower:]')"

# --- protected path check helper --------------------------------------------

# is_protected_path <path>
# Returns 0 if path falls under a protected plan-lifecycle root, else 1.
is_protected_path() {
  _p="$1"
  # Normalize: strip leading ./
  _p="${_p#./}"
  case "$_p" in
    plans/approved/*|plans/approved \
    |plans/in-progress/*|plans/in-progress \
    |plans/implemented/*|plans/implemented \
    |plans/archived/*|plans/archived)
      return 0
      ;;
  esac
  return 1
}

# --- check if agent is Orianna -----------------------------------------------

is_orianna() {
  [ "$_agent_lc" = "orianna" ]
}

# --- reject helper -----------------------------------------------------------

reject() {
  _path="$1"
  printf '%s Agent '\''%s'\'' cannot move/modify files in %s.\n' \
    "$REJECT_MSG_PREFIX" "$_agent" "$_path" >&2
  printf 'Plan lifecycle moves are reserved to the Orianna agent.\n' >&2
  printf 'Dispatch Orianna via Agent(subagent_type='\''orianna'\'') instead.\n' >&2
  exit 2
}

# --- read stdin JSON ---------------------------------------------------------

_input="$(cat)"

_tool_name="$(printf '%s' "$_input" | jq -r '.tool_name // empty' 2>/dev/null)"

# --- dispatch on tool name ---------------------------------------------------

case "$_tool_name" in
  Bash)
    _cmd="$(printf '%s' "$_input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
    if [ -z "$_cmd" ]; then
      exit 0
    fi

    # Scan each whitespace-separated token in the command for protected paths.
    # We detect operations: git mv, mv, cp (incl. -R/-r), rm (incl. -rf/-r/-f).
    # Strategy: tokenize the command, for each token that looks like a path,
    # check if it matches a protected root.

    _found_protected=""
    _protected_match=""

    # Normalize whitespace
    _cmd_norm="$(printf '%s' "$_cmd" | tr '\t\n' '  ')"

    # Check for any token that looks like a plan path under protected roots
    # We use a simple word-by-word scan
    for _tok in $_cmd_norm; do
      # Strip trailing slash for matching
      _tok_clean="${_tok%/}"
      if is_protected_path "$_tok_clean"; then
        _found_protected=1
        _protected_match="$_tok_clean"
        break
      fi
    done

    if [ -n "$_found_protected" ]; then
      if ! is_orianna; then
        reject "$_protected_match"
      fi
    fi
    ;;

  Write|Edit|NotebookEdit)
    # Extract file_path (Write/Edit) or notebook_path (NotebookEdit)
    _fpath="$(printf '%s' "$_input" | jq -r '(.tool_input.file_path // .tool_input.notebook_path) // empty' 2>/dev/null)"
    if [ -z "$_fpath" ]; then
      exit 0
    fi
    # Strip leading repo root if absolute path — convert to repo-relative
    _repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$_repo_root" ]; then
      _fpath="${_fpath#"${_repo_root}"/}"
    fi

    if is_protected_path "$_fpath"; then
      if ! is_orianna; then
        reject "$_fpath"
      fi
    fi
    ;;

  *)
    # Unknown tool — pass through
    exit 0
    ;;
esac

exit 0

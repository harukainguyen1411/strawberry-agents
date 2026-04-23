#!/usr/bin/env bash
# pretooluse-inbox-write-guard.sh — PreToolUse inbox authorship guard.
# Plan: plans/approved/personal/2026-04-23-inbox-write-guard.md
#
# Fires before Write / Edit / MultiEdit tool executions.
# Rejects (exit 2) any attempt to write or broadly edit files matching
#   agents/<name>/inbox/<file>.md
# unless the calling agent is an admin identity or the edit is the sanctioned
# check-inbox status flip (pending -> read).
#
# Allowed paths (always pass through):
#   agents/*/inbox/archive/**     — archive subtree is unguarded
#
# Identity: read from $CLAUDE_AGENT_NAME, then $STRAWBERRY_AGENT (case-insensitive).
# Admin bypass: duongntd, harukainguyen1411 — may write inbox files directly.
#
# Permitted Edit/MultiEdit: old_string contains "status: pending" AND
#   new_string contains "status: read" — the check-inbox archive flip.
#
# Input: JSON on stdin (Claude Code PreToolUse hook format).
# Exit 0 — allowed; exit 2 — blocked.
#
# POSIX-portable bash. Requires jq on PATH.

set -u

REJECT_MSG_PREFIX="[inbox-write-guard]"

# --- resolve calling agent identity -----------------------------------------
# Precedence: $CLAUDE_AGENT_NAME > $STRAWBERRY_AGENT
# Admin bypass: duongntd, harukainguyen1411 (case-insensitive).

_agent="${CLAUDE_AGENT_NAME:-}"
if [ -z "$_agent" ]; then
  _agent="${STRAWBERRY_AGENT:-}"
fi
_agent_lc="$(printf '%s' "$_agent" | tr '[:upper:]' '[:lower:]')"

is_admin() {
  case "$_agent_lc" in
    duongntd|harukainguyen1411) return 0 ;;
  esac
  return 1
}

# --- reject helper -----------------------------------------------------------

reject() {
  _msg="$1"
  printf '%s %s\n' "$REJECT_MSG_PREFIX" "$_msg" >&2
  exit 2
}

# --- read stdin JSON ---------------------------------------------------------

_input="$(cat)"

if ! printf '%s' "$_input" | jq '.' >/dev/null 2>&1; then
  printf '%s malformed hook payload — denied\n' "$REJECT_MSG_PREFIX" >&2
  exit 2
fi

_tool_name="$(printf '%s' "$_input" | jq -r '.tool_name // empty' 2>/dev/null)"

if [ -z "$_tool_name" ]; then
  printf '%s missing tool_name in hook payload — denied\n' "$REJECT_MSG_PREFIX" >&2
  exit 2
fi

# --- dispatch on tool name ---------------------------------------------------

case "$_tool_name" in
  Write|Edit|MultiEdit)
    # Extract file_path
    _fpath="$(printf '%s' "$_input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
    if [ -z "$_fpath" ]; then
      exit 0
    fi

    # Strip leading repo root if absolute path — convert to repo-relative
    _repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$_repo_root" ]; then
      _fpath="${_fpath#"${_repo_root}"/}"
    fi
    # Strip leading ./
    _fpath="${_fpath#./}"

    # Target detection: matches agents/<name>/inbox/<file>.md
    # but NOT agents/<name>/inbox/archive/ (archive subtree is exempt)
    _is_inbox_target=0
    case "$_fpath" in
      agents/*/inbox/*.md)
        # Check it's not in the archive subtree
        case "$_fpath" in
          agents/*/inbox/archive/*)
            _is_inbox_target=0
            ;;
          *)
            _is_inbox_target=1
            ;;
        esac
        ;;
    esac

    if [ "$_is_inbox_target" = "0" ]; then
      exit 0
    fi

    # Admin bypass
    if is_admin; then
      exit 0
    fi

    # For Write: always blocked (new file creation must go through /agent-ops send)
    if [ "$_tool_name" = "Write" ]; then
      reject "inbox writes must go through /agent-ops send — direct Write denied"
    fi

    # For Edit / MultiEdit: allow only if this is the check-inbox status flip
    # Detection: old_string contains "status: pending" AND new_string contains "status: read"
    _old_string="$(printf '%s' "$_input" | jq -r '.tool_input.old_string // empty' 2>/dev/null)"
    _new_string="$(printf '%s' "$_input" | jq -r '.tool_input.new_string // empty' 2>/dev/null)"

    _old_has_pending=0
    _new_has_read=0

    case "$_old_string" in
      *"status: pending"*) _old_has_pending=1 ;;
    esac
    case "$_new_string" in
      *"status: read"*) _new_has_read=1 ;;
    esac

    if [ "$_old_has_pending" = "1" ] && [ "$_new_has_read" = "1" ]; then
      exit 0
    fi

    reject "inbox Edit must be the status pending -> read flip (check-inbox path) or go through /agent-ops send"
    ;;

  *)
    # Unknown tool — pass through
    exit 0
    ;;
esac

exit 0

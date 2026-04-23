#!/usr/bin/env bash
# pretooluse-inbox-write-guard.sh — PreToolUse inbox authorship guard.
# Plan: plans/approved/personal/2026-04-23-inbox-write-guard.md
#
# Fires before Write / Edit tool executions.
# Rejects (exit 2) any attempt to write or broadly edit files matching
#   agents/<name>/inbox/<file>.md
# unless the calling agent is an admin identity, the edit is the sanctioned
# check-inbox status flip (pending -> read), or the caller is executing via
# the /agent-ops skill (STRAWBERRY_SKILL=agent-ops).
#
# Allowed paths (always pass through):
#   agents/*/inbox/archive/**     — archive subtree is unguarded
#
# Identity: read from $CLAUDE_AGENT_NAME, then $STRAWBERRY_AGENT (case-insensitive).
# Admin bypass: duongntd, harukainguyen1411 — may write inbox files directly.
# Skill bypass: STRAWBERRY_SKILL=agent-ops — the /agent-ops send path.
#
# Permitted Edit: old_string and new_string differ ONLY in:
#   - "status: pending" line changed to "status: read"
#   - optional addition of a "read_at: ..." line
#   No other lines may differ between old_string and new_string.
#
# MultiEdit: not matched by this guard (removed from settings.json matcher).
#
# Input: JSON on stdin (Claude Code PreToolUse hook format).
# Exit 0 — allowed; exit 2 — blocked.
#
# POSIX-portable bash. Requires jq on PATH.

set -u

REJECT_MSG_PREFIX="[inbox-write-guard]"

# --- path normalization helper -----------------------------------------------
# Ported from pretooluse-plan-lifecycle-guard.sh.
# Strips surrounding quotes, collapses repeated slashes, resolves . and .. segments.
normalize_path() {
  _np="$1"

  # Strip surrounding single quotes
  case "$_np" in
    \'*\') _np="${_np#\'}"; _np="${_np%\'}" ;;
  esac
  # Strip surrounding double quotes
  case "$_np" in
    '"'*'"') _np="${_np#\"}"; _np="${_np%\"}" ;;
  esac

  # Collapse repeated slashes
  _prev=""
  while [ "$_np" != "$_prev" ]; do
    _prev="$_np"
    _np="$(printf '%s' "$_np" | sed 's|//|/|g')"
  done

  # Resolve . and .. segments
  _result=""
  _IFS_SAVE="$IFS"
  IFS="/"
  # shellcheck disable=SC2086
  set -- $_np
  IFS="$_IFS_SAVE"
  for _seg; do
    case "$_seg" in
      ""|".")
        ;;
      "..")
        case "$_result" in
          */*)  _result="${_result%/*}" ;;
          *)    _result="" ;;
        esac
        ;;
      *)
        if [ -z "$_result" ]; then
          _result="$_seg"
        else
          _result="$_result/$_seg"
        fi
        ;;
    esac
  done

  printf '%s' "$_result"
}

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

# Skill bypass: STRAWBERRY_SKILL=agent-ops allows Write/Edit to inbox paths.
# This is the sanctioned /agent-ops send path.
_skill="${STRAWBERRY_SKILL:-}"
_skill_lc="$(printf '%s' "$_skill" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

is_agent_ops_skill() {
  [ "$_skill_lc" = "agent-ops" ]
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
  Write|Edit)
    # Extract file_path
    _fpath="$(printf '%s' "$_input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
    if [ -z "$_fpath" ]; then
      exit 0
    fi

    # Strip leading repo root if absolute path — convert to repo-relative.
    # Try git first; fall back to path normalization only.
    _repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$_repo_root" ]; then
      _fpath="${_fpath#"${_repo_root}"/}"
    fi

    # Normalize path: collapse slashes, resolve . and .. segments.
    _fpath="$(normalize_path "$_fpath")"

    # If the normalized path still has an unrecognized prefix (e.g. absolute path
    # to a different root), extract the repo-relative portion starting at "agents/".
    # This closes the absolute-path bypass: an attacker cannot pass
    # /other/path/agents/X/inbox/Y.md to evade the guard.
    case "$_fpath" in
      agents/*) ;;  # already relative — no-op
      */agents/*)
        # Strip everything up to and including the last component before "agents/"
        _fpath="${_fpath##*/agents/}"
        _fpath="agents/$_fpath"
        ;;
    esac

    # Target detection: matches agents/<name>/inbox/<file>.md
    # but NOT agents/<name>/inbox/archive/ (archive subtree is exempt)
    _is_inbox_target=0
    case "$_fpath" in
      agents/*/inbox/*.md)
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

    # Skill bypass: /agent-ops send sets STRAWBERRY_SKILL=agent-ops
    if is_agent_ops_skill; then
      exit 0
    fi

    # For Write: always blocked unless admin or agent-ops skill (checked above)
    if [ "$_tool_name" = "Write" ]; then
      reject "inbox writes must go through /agent-ops send — direct Write denied"
    fi

    # For Edit: allow only if this is the check-inbox status flip.
    # Tightened rule: old_string and new_string must differ ONLY in:
    #   - "status: pending" -> "status: read"
    #   - optional addition of a "read_at: ..." line
    # Any other diff is rejected.
    _old_string="$(printf '%s' "$_input" | jq -r '.tool_input.old_string // empty' 2>/dev/null)"
    _new_string="$(printf '%s' "$_input" | jq -r '.tool_input.new_string // empty' 2>/dev/null)"

    # Quick pre-check: old must contain "status: pending" and new must contain "status: read"
    _old_has_pending=0
    _new_has_read=0
    case "$_old_string" in
      *"status: pending"*) _old_has_pending=1 ;;
    esac
    case "$_new_string" in
      *"status: read"*) _new_has_read=1 ;;
    esac

    if [ "$_old_has_pending" = "0" ] || [ "$_new_has_read" = "0" ]; then
      reject "inbox Edit must be the status pending -> read flip (check-inbox path) or go through /agent-ops send"
    fi

    # Tightened diff check:
    # 1. Normalize old_string: replace "status: pending" with "status: read"
    # 2. Normalize new_string: remove any "read_at: ..." line
    # 3. They must be equal after normalization.
    _old_normalized="$(printf '%s' "$_old_string" | sed 's/status: pending/status: read/')"
    _new_normalized="$(printf '%s' "$_new_string" | sed '/^read_at: /d')"

    if [ "$_old_normalized" = "$_new_normalized" ]; then
      exit 0
    fi

    reject "inbox Edit must change only the status line (and optionally add read_at) — other changes denied"
    ;;

  *)
    # Unknown tool — pass through
    exit 0
    ;;
esac

exit 0

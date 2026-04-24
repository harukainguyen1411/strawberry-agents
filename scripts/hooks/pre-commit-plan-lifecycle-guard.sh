#!/bin/bash
# pre-commit-plan-lifecycle-guard.sh — commit-phase guard for plan lifecycle.
# Plan: plans/approved/personal/2026-04-24-rule-19-guard-hole-pre-staged-moves.md
#
# Fires as a pre-commit hook (via the strawberry dispatcher).
# Inspects the staged file-change set for plan-lifecycle mutations and rejects
# non-Orianna agent commits that rename, add, or delete files under protected roots.
#
# Protected roots (repo-relative):
#   plans/approved/
#   plans/in-progress/
#   plans/implemented/
#   plans/archived/
#
# Blocked shapes for non-Orianna agents:
#   - Rename into a protected root (R: new path under protected root)
#   - Rename out of a protected root (R: old path under protected root)
#   - Add to a protected root (A: path under protected root)
#   - Delete from a protected root (D: path under protected root)
#   - Copy into a protected root (C: destination under protected root)
#
# Permitted for any agent:
#   - Pure modification (M) of an already-tracked file in a protected root
#     (matches PreToolUse Edit semantics — Aphelios/Xayah append Tasks sections)
#
# Identity resolution order (commit phase — no hook JSON available):
#   1. $CLAUDE_AGENT_NAME
#   2. $STRAWBERRY_AGENT
#   3. If both empty AND $STRAWBERRY_AGENT_MODE also empty → admin/human Duong → permit.
#   4. Otherwise (env set but not Orianna, or agent-mode flag set with empty identity) → reject.
#
# Note: git config user.name cannot disambiguate admin from agent because
# agent-identity-default.sh rewrites all agent commits to the Duongntd identity.
#
# Exit 0 — permitted; exit 1 — blocked.
# POSIX-portable bash. No external tools beyond git.

set -u

REJECT_MSG_PREFIX="[plan-lifecycle-guard]"

# --- protected path check -----------------------------------------------

# is_protected_path <path>
# Returns 0 if path falls under a protected plan-lifecycle root, else 1.
is_protected_path() {
  _p="${1#./}"  # strip leading ./
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

# --- identity resolution ------------------------------------------------

_agent="${CLAUDE_AGENT_NAME:-}"
if [ -z "$_agent" ]; then
  _agent="${STRAWBERRY_AGENT:-}"
fi

_agent_mode="${STRAWBERRY_AGENT_MODE:-}"

# Lowercase for case-insensitive comparison
_agent_lc="$(printf '%s' "$_agent" | tr '[:upper:]' '[:lower:]')"

is_orianna() {
  [ "$_agent_lc" = "orianna" ]
}

is_admin() {
  # Note: `env -i git commit` can bypass this by clearing all env; PreToolUse guard is the
  # primary defence — see architecture/plan-lifecycle.md.
  # Both identity vars empty AND no agent-mode flag → treat as human/admin Duong.
  [ -z "$_agent" ] && [ -z "$_agent_mode" ]
}

reject() {
  _path="$1"
  _shape="$2"
  # _shape encodes verb+preposition: "add files to", "delete files from",
  # "rename/copy files involving" — format: cannot <_shape> <path>
  printf '%s Agent '\''%s'\'' cannot %s %s at commit phase.\n' \
    "$REJECT_MSG_PREFIX" "$_agent" "$_shape" "$_path" >&2
  printf 'Plan lifecycle moves (rename/add/delete in protected roots) are reserved to the Orianna agent.\n' >&2
  printf 'Dispatch Orianna via Agent(subagent_type='\''orianna'\'') instead.\n' >&2
  exit 1
}

# --- scan staged changes ------------------------------------------------

# git diff --cached --name-status -M --diff-filter=ACDRM
# Note: --diff-filter excludes T (typechange, e.g. symlink↔file) intentionally —
# typechanges do not move plan files between lifecycle roots and are not lifecycle events.
# Output format per line:
#   M<TAB>path                      (modification)
#   A<TAB>path                      (addition)
#   D<TAB>path                      (deletion)
#   R<score><TAB>old<TAB>new        (rename)
#   C<score><TAB>old<TAB>new        (copy)
#
# We use --diff-filter to only enumerate relevant shapes.

_diff_output="$(git diff --cached --name-status -M --diff-filter=ACDRM 2>/dev/null)" || true

if [ -z "$_diff_output" ]; then
  exit 0
fi

while IFS='	' read -r _status _path1 _path2; do
  # Ignore empty lines
  [ -z "$_status" ] && continue

  case "$_status" in
    M*)
      # Pure modification — always permitted (Edit-in-place semantics)
      ;;
    A*)
      if is_protected_path "$_path1"; then

        if ! is_orianna && ! is_admin; then
          reject "$_path1" "add files to"
        fi
      fi
      ;;
    D*)
      if is_protected_path "$_path1"; then

        if ! is_orianna && ! is_admin; then
          reject "$_path1" "delete files from"
        fi
      fi
      ;;
    R*|C*)
      # Rename/copy: _path1=old, _path2=new
      # Block if old OR new path is protected (rename-out or rename-in)
      _blocked=""
      if is_protected_path "$_path1"; then
        _blocked="$_path1"
      fi
      if is_protected_path "$_path2"; then
        _blocked="$_path2"
      fi
      if [ -n "$_blocked" ]; then

        if ! is_orianna && ! is_admin; then
          reject "$_blocked" "rename/copy files involving"
        fi
      fi
      ;;
  esac
done <<EOF
$_diff_output
EOF

exit 0

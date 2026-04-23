#!/bin/sh
# pre-commit-plan-promote-guard.sh — v2 Orianna gate authorization.
# Plan: plans/in-progress/personal/2026-04-22-orianna-gate-simplification.md §T4
#
# Enforces two classes of commit authorization:
#
# Class A — Plan promotions (move out of plans/proposed/):
#   A staged diff that moves a file from plans/proposed/** to any other stage
#   (approved, in-progress, implemented, archived) is a PROMOTION commit.
#   Promotion commits require EITHER:
#   (a) Author email matches the Orianna agent identity (read from
#       scripts/hooks/_orianna_identity.txt) AND commit message contains
#       "Promoted-By: Orianna" trailer.
#   (b) Author email matches an admin identity (ADMIN_EMAILS).
#   Trailer forgery: non-Orianna + "Promoted-By: Orianna" → REJECT.
#
# Class B — Direct creation in non-proposed stage directories:
#   A staged diff that creates a NEW file directly under plans/approved/**,
#   plans/in-progress/**, plans/implemented/**, or plans/archived/** (without
#   a matching rename-from plans/proposed/**) is also unauthorized unless the
#   author is Orianna or admin.
#
# Class C — Admin-only paths:
#   Modifications to .claude/agents/orianna.md or
#   scripts/hooks/_orianna_identity.txt require admin authorship.
#
# Non-plan commits pass through unconditionally.

set -e

# --- identity configuration --------------------------------------------------

# Admin accounts — bypass all restrictions.
ADMIN_EMAILS="harukainguyen1411@gmail.com"

# Orianna identity file (single line: the canonical email)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IDENTITY_FILE="$SCRIPT_DIR/_orianna_identity.txt"

# Read Orianna's canonical email from the identity file.
ORIANNA_EMAIL=""
if [ -f "$IDENTITY_FILE" ]; then
  ORIANNA_EMAIL="$(head -1 "$IDENTITY_FILE" | tr -d '[:space:]')"
fi

# Resolve the author email for the pending commit.
if [ -n "$GIT_AUTHOR_EMAIL" ]; then
  current_author_email="$GIT_AUTHOR_EMAIL"
else
  current_author_email="$(git config user.email 2>/dev/null || true)"
fi

# --- helper: identity checks -------------------------------------------------

is_admin() {
  for _admin in $ADMIN_EMAILS; do
    [ "$current_author_email" = "$_admin" ] && return 0
  done
  return 1
}

is_orianna() {
  [ -n "$ORIANNA_EMAIL" ] && [ "$current_author_email" = "$ORIANNA_EMAIL" ] && return 0
  return 1
}

# --- read commit message -----------------------------------------------------

COMMIT_MSG_FILE="${GIT_DIR:-$(git rev-parse --git-dir)}/COMMIT_EDITMSG"
commit_msg=""
[ -f "$COMMIT_MSG_FILE" ] && commit_msg="$(cat "$COMMIT_MSG_FILE")"

has_promoted_by_trailer() {
  printf '%s\n' "$commit_msg" | grep -qE '^Promoted-By:[[:space:]]*Orianna[[:space:]]*$'
}

# --- inspect staged diff -----------------------------------------------------

REPO_ROOT="$(git rev-parse --show-toplevel)"

# Collect staged files by status
promoted_files=""    # files being moved out of proposed/
direct_created=""    # files created directly in non-proposed stage dirs
admin_path_changes=""  # changes to admin-only paths

while IFS= read -r line; do
  status="${line%%	*}"
  rest="${line#*	}"

  case "$status" in
    R*)
      old_path="${rest%%	*}"
      new_path="${rest#*	}"
      case "$old_path" in
        plans/proposed/*.md|plans/proposed/*/*.md)
          case "$new_path" in
            plans/approved/*|plans/in-progress/*|plans/implemented/*|plans/archived/*)
              promoted_files="$promoted_files $old_path"
              ;;
          esac
          ;;
      esac
      ;;
    D)
      case "$rest" in
        plans/proposed/*.md|plans/proposed/*/*.md)
          promoted_files="$promoted_files $rest"
          ;;
      esac
      ;;
    A|M)
      case "$rest" in
        plans/approved/*.md|plans/approved/*/*.md|\
        plans/in-progress/*.md|plans/in-progress/*/*.md|\
        plans/implemented/*.md|plans/implemented/*/*.md|\
        plans/archived/*.md|plans/archived/*/*.md)
          if [ "$status" = "A" ]; then
            direct_created="$direct_created $rest"
          fi
          ;;
      esac
      case "$rest" in
        .claude/agents/orianna.md|scripts/hooks/_orianna_identity.txt)
          admin_path_changes="$admin_path_changes $rest"
          ;;
      esac
      ;;
  esac
done <<EOF
$(git diff --cached --name-status)
EOF

# --- Class C: admin-only path protection ------------------------------------

if [ -n "$admin_path_changes" ]; then
  if ! is_admin; then
    printf '\n=== BLOCKED: admin-only path modification ===\n' >&2
    printf 'Only Duong'\''s admin identity (%s) may modify:\n' "$ADMIN_EMAILS" >&2
    for p in $admin_path_changes; do
      printf '  %s\n' "$p" >&2
    done
    printf '\n' >&2
    exit 1
  fi
fi

# --- Class A: promotion commits (move out of proposed/) ---------------------

if [ -n "$promoted_files" ]; then
  # Forged trailer: non-Orianna author with Promoted-By: Orianna trailer → reject
  if has_promoted_by_trailer && ! is_orianna && ! is_admin; then
    printf '\n=== BLOCKED: Promoted-By: Orianna trailer forgery ===\n' >&2
    printf 'Author: %s\n' "$current_author_email" >&2
    printf '\n' >&2
    printf 'The "Promoted-By: Orianna" trailer is reserved for the Orianna agent\n' >&2
    printf '(email: %s).\n' "$ORIANNA_EMAIL" >&2
    printf 'Non-Orianna, non-admin authors may not use this trailer.\n' >&2
    printf '\n' >&2
    exit 1
  fi

  # Orianna path: must have Promoted-By trailer
  if is_orianna && ! has_promoted_by_trailer; then
    printf '\n=== BLOCKED: Orianna promotion commit missing Promoted-By: Orianna trailer ===\n' >&2
    printf 'Author: %s\n' "$current_author_email" >&2
    printf 'Add "Promoted-By: Orianna" as a commit trailer.\n' >&2
    printf '\n' >&2
    exit 1
  fi

  # Admin path: always allowed (no trailer required)
  if is_admin; then
    printf '\n[plan-promote-guard] Admin promotion by %s — allowed.\n' "$current_author_email" >&2
    exit 0
  fi

  # Orianna path: allowed when trailer present
  if is_orianna; then
    exit 0
  fi

  # Fallback: no authorization
  printf '\n=== BLOCKED: unauthorized plan promotion ===\n' >&2
  printf 'Author: %s\n' "$current_author_email" >&2
  printf '\n' >&2
  printf 'Moving a plan out of plans/proposed/ requires one of:\n' >&2
  printf '  (a) Invoke the Orianna agent (.claude/agents/orianna.md) — she handles\n' >&2
  printf '      the move, commit, and Promoted-By: Orianna trailer automatically.\n' >&2
  printf '  (b) Use Duong'\''s admin identity (%s).\n' "$ADMIN_EMAILS" >&2
  printf '\n' >&2
  exit 1
fi

# --- Class B: direct creation in non-proposed stage dirs --------------------

if [ -n "$direct_created" ]; then
  if ! is_orianna && ! is_admin; then
    printf '\n=== BLOCKED: unauthorized plan creation in non-proposed stage directory ===\n' >&2
    printf 'Author: %s\n' "$current_author_email" >&2
    printf '\n' >&2
    printf 'Plans must be created in plans/proposed/ and promoted by Orianna.\n' >&2
    printf 'Blocked paths:\n' >&2
    for p in $direct_created; do
      printf '  %s\n' "$p" >&2
    done
    printf '\n' >&2
    exit 1
  fi
fi

exit 0

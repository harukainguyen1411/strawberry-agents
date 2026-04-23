#!/bin/sh
# pre-commit-plan-promote-guard.sh — v2 Orianna gate authorization (pre-commit phase).
# Plan: plans/in-progress/personal/2026-04-22-orianna-gate-simplification.md §T4
#
# This hook handles file-path and identity-shape checks that do NOT require the
# commit message body. Trailer-dependent checks live in commit-msg-plan-promote-guard.sh
# which runs at the commit-msg phase when git has written the actual commit message.
#
# Enforces two classes of commit authorization:
#
# Class A — Plan promotions (move out of plans/proposed/):
#   A staged diff that moves a file from plans/proposed/** to any other stage
#   (approved, in-progress, implemented, archived) is a PROMOTION commit.
#   Promotion commits require EITHER:
#   (a) Author email matches the Orianna agent identity (read from
#       scripts/hooks/_orianna_identity.txt). Trailer presence is verified by
#       commit-msg-plan-promote-guard.sh.
#   (b) Author email matches an admin identity (ADMIN_EMAILS).
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

# Orianna identity file (single line: the canonical email).
# SCRIPT_DIR is resolved from $0. The dispatcher calls each sub-hook with its
# absolute path, so dirname($0) reliably resolves the sibling _orianna_identity.txt
# regardless of the calling process's working directory.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IDENTITY_FILE="$SCRIPT_DIR/_orianna_identity.txt"

# Read Orianna's canonical email from the identity file.
# If absent or empty, ORIANNA_EMAIL stays "". is_orianna() then returns false
# for ALL authors — fail-closed: no agent can impersonate Orianna if her
# identity file disappears. Admin path still works.
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
# Identity check only. Trailer presence is verified by commit-msg-plan-promote-guard.sh
# at the commit-msg phase when the actual message is available via $1.

if [ -n "$promoted_files" ]; then
  # Admin path: always allowed
  if is_admin; then
    printf '\n[plan-promote-guard] Admin promotion by %s — allowed.\n' "$current_author_email" >&2
    exit 0
  fi

  # Orianna path: allowed — commit-msg hook will verify the trailer
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

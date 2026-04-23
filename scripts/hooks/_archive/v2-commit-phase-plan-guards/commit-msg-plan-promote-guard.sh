#!/bin/sh
# commit-msg-plan-promote-guard.sh — trailer checks for plan promotion commits.
# Plan: plans/in-progress/personal/2026-04-22-orianna-gate-simplification.md §T4
#
# Receives the commit message file path as $1 (standard commit-msg hook protocol).
# At this phase git has already written the final message — $1 contains the
# actual commit being applied, NOT stale content from a prior commit.
#
# Checks performed:
#   A. Orianna-identity-without-trailer — Orianna author + no Promoted-By: Orianna
#      trailer on a plan-promotion diff → BLOCKED.
#   B. Trailer forgery — non-Orianna, non-admin author + Promoted-By: Orianna
#      trailer present → BLOCKED.
#   C. Orianna-Bypass: trailer — only harukainguyen1411 admin identity may use;
#      agent-identity bypass attempts → BLOCKED.
#
# Companion: pre-commit-plan-promote-guard.sh handles file-path + identity-shape
# checks (Class B/C) that do not need the commit message body.
#
# Exit codes:
#   0 — message passes all checks
#   1 — a check failed; error printed to stderr

set -e

COMMIT_MSG_FILE="${1:-}"

if [ -z "$COMMIT_MSG_FILE" ]; then
  printf 'commit-msg-plan-promote-guard.sh: missing argument (path to commit message file)\n' >&2
  exit 1
fi

if [ ! -f "$COMMIT_MSG_FILE" ]; then
  printf 'commit-msg-plan-promote-guard.sh: commit message file not found: %s\n' "$COMMIT_MSG_FILE" >&2
  exit 1
fi

# --- identity configuration --------------------------------------------------

# Admin accounts — bypass all restrictions.
ADMIN_EMAILS="harukainguyen1411@gmail.com"

# Orianna identity file (single line: the canonical email).
# SCRIPT_DIR is resolved at hook-install time; the dispatcher calls this script
# with an absolute path ($0 is absolute), so dirname($0) reliably finds the
# sibling identity file regardless of the caller's working directory.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IDENTITY_FILE="$SCRIPT_DIR/_orianna_identity.txt"

# If identity file is absent or empty, ORIANNA_EMAIL stays empty.
# is_orianna() then returns false for ALL authors — fail-closed: no agent can
# impersonate Orianna if her identity file disappears. Admin path still works.
ORIANNA_EMAIL=""
if [ -f "$IDENTITY_FILE" ]; then
  ORIANNA_EMAIL="$(head -1 "$IDENTITY_FILE" | tr -d '[:space:]')"
fi

# Resolve the author email for the pending commit.
if [ -n "${GIT_AUTHOR_EMAIL:-}" ]; then
  current_author_email="$GIT_AUTHOR_EMAIL"
else
  current_author_email="$(git config user.email 2>/dev/null || true)"
fi

# --- helpers -----------------------------------------------------------------

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

# Read the commit message from the file passed as $1
commit_msg="$(cat "$COMMIT_MSG_FILE")"

has_promoted_by_trailer() {
  printf '%s\n' "$commit_msg" | grep -qE '^Promoted-By:[[:space:]]*Orianna[[:space:]]*$'
}

has_bypass_trailer() {
  printf '%s\n' "$commit_msg" | grep -qE '^Orianna-Bypass:'
}

# --- Check C: Orianna-Bypass trailer misuse ----------------------------------
# Only harukainguyen1411 admin identity may include an Orianna-Bypass: trailer.
# Any other author with this trailer is attempting an unauthorized bypass.

if has_bypass_trailer; then
  if ! is_admin; then
    printf '\n=== BLOCKED: unauthorized Orianna-Bypass: trailer ===\n' >&2
    printf 'Author: %s\n' "$current_author_email" >&2
    printf '\n' >&2
    printf 'The "Orianna-Bypass:" trailer is reserved for Duong'\''s admin identity (%s).\n' "$ADMIN_EMAILS" >&2
    printf 'Agent-identity bypass attempts are rejected.\n' >&2
    printf '\n' >&2
    exit 1
  fi
  # Admin bypass: skip remaining checks
  exit 0
fi

# --- inspect staged diff to determine if this is a promotion commit ----------

# Check if staged diff moves files out of plans/proposed/
is_promotion_commit() {
  git diff --cached --name-status 2>/dev/null | while IFS= read -r line; do
    status="${line%%	*}"
    rest="${line#*	}"
    case "$status" in
      R*)
        old_path="${rest%%	*}"
        case "$old_path" in
          plans/proposed/*.md|plans/proposed/*/*.md)
            printf 'yes'
            return
            ;;
        esac
        ;;
      D)
        case "$rest" in
          plans/proposed/*.md|plans/proposed/*/*.md)
            printf 'yes'
            return
            ;;
        esac
        ;;
    esac
  done
}

_is_promo="$(is_promotion_commit)"

[ "$_is_promo" = "yes" ] || exit 0  # Not a promotion commit — pass through

# --- Check A: Orianna without trailer ----------------------------------------

if is_orianna && ! has_promoted_by_trailer; then
  printf '\n=== BLOCKED: Orianna promotion commit missing Promoted-By: Orianna trailer ===\n' >&2
  printf 'Author: %s\n' "$current_author_email" >&2
  printf 'Add "Promoted-By: Orianna" as a commit trailer.\n' >&2
  printf '\n' >&2
  exit 1
fi

# --- Check B: trailer forgery ------------------------------------------------

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

exit 0

#!/bin/bash
# orianna-bypass-audit.sh — post-hoc bypass detection for plan lifecycle.
# Plan: plans/approved/personal/2026-04-23-plan-lifecycle-physical-guard.md §T7
#
# Walks protected plan-lifecycle directories and checks that each plan file
# was last introduced (Added or Renamed into) a protected path by a commit
# authored by the canonical Orianna identity.
#
# Reports orphan files — plans that arrived via a non-Orianna commit — to stdout.
# Always exits 0. This is detection only, never enforcement, never auto-fix.
#
# IMPORTANT GOTCHA: This audit is only as strong as git log author metadata.
# An agent that impersonated Orianna's git identity (the exact Ekko incident
# shape: 8717331/a802de4) will appear as Orianna in the audit and will PASS.
# The audit catches the broader class where bypass didn't bother to spoof
# identity. Identity-spoofing bypasses are the reason the PreToolUse hook is
# the sole prevention layer — this audit is a complementary detection mechanism.
#
# Usage: bash scripts/orianna-bypass-audit.sh [--repo-root <path>]
# Suggested cron: nightly CI job that runs this and posts findings to a
# reporting channel without failing the build.
#
# POSIX-portable bash. Requires git on PATH.

set -u

# --- argument parsing -------------------------------------------------------

REPO_ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi

if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT" ]; then
  printf 'ERROR: cannot determine repo root. Run from within a git repo or use --repo-root.\n' >&2
  exit 0
fi

# --- resolve Orianna canonical email ----------------------------------------

ORIANNA_IDENTITY="$REPO_ROOT/agents/orianna/memory/git-identity.sh"
ORIANNA_EMAIL="orianna@strawberry.local"
# If the identity file exists and configures a different email, detect it.
if [ -f "$ORIANNA_IDENTITY" ]; then
  _extracted="$(grep 'user.email' "$ORIANNA_IDENTITY" | sed 's/.*user\.email[[:space:]]*//' | tr -d '"'"'")" 2>/dev/null || true
  if [ -n "$_extracted" ]; then
    ORIANNA_EMAIL="$_extracted"
  fi
fi

# Admin identities that are also authorized (Duong's admin identity)
ADMIN_EMAILS="harukainguyen1411@gmail.com"

is_authorized() {
  _email="$1"
  [ "$_email" = "$ORIANNA_EMAIL" ] && return 0
  for _admin in $ADMIN_EMAILS; do
    [ "$_email" = "$_admin" ] && return 0
  done
  return 1
}

# --- walk protected plan directories ----------------------------------------

PROTECTED_ROOTS="plans/approved plans/in-progress plans/implemented plans/archived"

ORPHAN_COUNT=0

for _root in $PROTECTED_ROOTS; do
  _dir="$REPO_ROOT/$_root"
  [ -d "$_dir" ] || continue

  # Find all .md plan files recursively
  while IFS= read -r _plan_path; do
    # Get the repo-relative path
    _rel="${_plan_path#"${REPO_ROOT}/"}"

    # Find the commit that introduced this file into a protected path.
    # --diff-filter=AR: Added or Renamed (covers git mv from proposed/).
    # --follow: follow renames.
    # We want the EARLIEST commit that placed the file at its current protected path.
    _intro_commit="$(git -C "$REPO_ROOT" log --follow --diff-filter=AR \
      --format='%H|%ae|%s' -- "$_rel" 2>/dev/null | tail -1)"

    if [ -z "$_intro_commit" ]; then
      # File has no Add/Rename record — could be a freshly staged uncommitted file.
      # Skip silently.
      continue
    fi

    _sha="${_intro_commit%%|*}"
    _rest="${_intro_commit#*|}"
    _author_email="${_rest%%|*}"
    _subject="${_rest#*|}"

    if ! is_authorized "$_author_email"; then
      ORPHAN_COUNT=$((ORPHAN_COUNT+1))
      printf 'ORPHAN: %s | author=%s | sha=%s | %s\n' \
        "$_rel" "$_author_email" "$_sha" "$_subject"
    fi
  done < <(find "$_dir" -name "*.md" -type f 2>/dev/null)
done

if [ "$ORPHAN_COUNT" -eq 0 ]; then
  printf 'orianna-bypass-audit: no orphan plans found (all protected-path plans introduced by authorized identity)\n'
else
  printf 'orianna-bypass-audit: %s orphan plan(s) found\n' "$ORPHAN_COUNT"
fi

# Always exit 0 — detection only, never enforcement.
exit 0

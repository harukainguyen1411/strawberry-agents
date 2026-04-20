#!/bin/sh
# pre-commit-plan-authoring-freeze.sh — Temporary freeze on new plan authoring.
#
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §D12, T8.1
#
# Rejects newly-ADDED (status 'A') files under plans/proposed/.
# Edits (M), renames (R), and deletes (D) pass through.
#
# This freeze is TEMPORARY. It is lifted when scripts/orianna-sign.sh,
# scripts/orianna-verify-signature.sh, and the updated plan-promote.sh
# are validated end-to-end (§D12 smoke criterion — T11.1).
#
# To lift the freeze: delete this file and remove it from install-hooks.sh.
# Commit with: chore: lift §D12 plan-authoring freeze
#
# §D12 resolution: freeze applies to new files only (Q11 — added entries only).
# Authors may still edit existing proposed drafts during the freeze window.
#
# Bypass:
#   Add an "Orianna-Bypass: <reason>" trailer (min 10-char reason) to the
#   commit message. Bypass is valid ONLY when the commit author email matches
#   Duong's admin identity (harukainguyen1411@gmail.com). Agent identities
#   are never permitted to bypass (consistent with pre-commit-plan-promote-guard.sh §D9.1).

set -eu

# --- identity gates ---

# Agent account(s) — NOT permitted to use Orianna-Bypass.
# Any email NOT in this list is treated as Duong's admin identity for bypass purposes.
AGENT_EMAILS="duong.nguyen.thai.duy@gmail.com 103487096+Duongntd@users.noreply.github.com"

# Resolve author email for the pending commit.
if [ -n "${GIT_AUTHOR_EMAIL:-}" ]; then
  current_author_email="$GIT_AUTHOR_EMAIL"
else
  current_author_email="$(git config user.email 2>/dev/null || true)"
fi

# --- check bypass trailer ---

# Resolve GIT_DIR to an absolute path so COMMIT_EDITMSG lookup works
# regardless of the shell's current working directory.
_raw_git_dir="${GIT_DIR:-$(git rev-parse --git-dir 2>/dev/null)}"
case "$_raw_git_dir" in
  /*) _abs_git_dir="$_raw_git_dir" ;;
  *)  _abs_git_dir="$(cd "$_raw_git_dir" 2>/dev/null && pwd)" ;;
esac
COMMIT_MSG_FILE="${_abs_git_dir}/COMMIT_EDITMSG"
commit_msg=""
[ -f "$COMMIT_MSG_FILE" ] && commit_msg="$(cat "$COMMIT_MSG_FILE")"

bypass_reason=""
if echo "$commit_msg" | grep -qE '^Orianna-Bypass:[[:space:]].{10,}'; then
  bypass_reason="$(echo "$commit_msg" | grep -E '^Orianna-Bypass:' | head -1 | sed 's/^Orianna-Bypass:[[:space:]]*//')"
fi

# --- check for newly-ADDED files under plans/proposed/ ---

NEW_PROPOSED="$(git diff --cached --name-status 2>/dev/null | awk '$1=="A" && $2 ~ /^plans\/proposed\//')"

[ -n "$NEW_PROPOSED" ] || exit 0

# There are new proposed files — check bypass first.
if [ -n "$bypass_reason" ]; then
  # Check if author is an agent identity — bypass strictly disallowed.
  for _agent_email in $AGENT_EMAILS; do
    if [ "$current_author_email" = "$_agent_email" ]; then
      printf '[plan-authoring-freeze] BLOCKED: Orianna-Bypass forbidden for agent identity.\n' >&2
      printf '  Author  : %s\n' "$current_author_email" >&2
      printf '  The Orianna-Bypass trailer is reserved for Duong'\''s admin identity\n' >&2
      printf '  (harukainguyen1411@gmail.com) — not agent accounts. Per §D9.1.\n' >&2
      exit 1
    fi
  done

  # Admin identity — bypass allowed with warning.
  printf '\n' >&2
  printf '########################################################\n' >&2
  printf '# WARNING: plan-authoring-freeze bypassed              #\n' >&2
  printf '# Reason: %s\n' "$bypass_reason" >&2
  printf '# This bypass is logged in git history.                #\n' >&2
  printf '########################################################\n' >&2
  printf '\n' >&2
  exit 0
fi

# No bypass — block.
printf '[plan-authoring-freeze] ERROR: New plan creation is frozen (§D12 of plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md).\n' >&2
printf '\n' >&2
printf '  New files blocked:\n' >&2
printf '%s\n' "$NEW_PROPOSED" | while IFS= read -r line; do
  printf '    %s\n' "$line" >&2
done
printf '\n' >&2
printf '  The freeze prevents new plan authoring until the Orianna gate infrastructure\n' >&2
printf '  (orianna-sign.sh, orianna-verify-signature.sh, updated plan-promote.sh) is\n' >&2
printf '  validated end-to-end. See §D12 for freeze criteria and lift procedure.\n' >&2
printf '\n' >&2
printf '  To bypass (admin identity only): add to commit message:\n' >&2
printf '    Orianna-Bypass: <reason at least 10 chars>\n' >&2
exit 1

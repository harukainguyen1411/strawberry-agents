#!/bin/sh
# pre-commit-plan-promote-guard.sh
# Blocks silent Orianna-bypass plan promotions.
#
# Fires when a staged diff moves a plan out of plans/proposed/ into
# plans/{approved,in-progress,implemented,archived}/ without either:
#   (a) a matching fact-check report at assessments/plan-fact-checks/<basename>-*.md
#   (b) an "Orianna-Bypass: <reason>" trailer in the commit message (>=10 chars reason)
#
# If the trailer is present:
#   - Commit is BLOCKED if the author is an agent identity
#     (author email matches AGENT_EMAILS list below).
#   - Commit is ALLOWED with a WARNING banner if the author is Duong's
#     admin identity (harukainguyen1411 / ADMIN_EMAILS list below).
#
# Per ADR §D9.1: only Duong's admin account may use the Orianna-Bypass trailer.
# Agents must never use it.

set -e

# --- identity gates for Orianna-Bypass ---

# Agent account(s) — NOT permitted to use Orianna-Bypass under any circumstances.
# Add additional agent noreply addresses here if more agent accounts are created.
AGENT_EMAILS="duong.nguyen.thai.duy@gmail.com 103487096+Duongntd@users.noreply.github.com"

# Admin account(s) — the only identities allowed to use Orianna-Bypass.
ADMIN_EMAILS="harukainguyen1411@gmail.com"

# Resolve the author email for the pending commit.
# GIT_AUTHOR_EMAIL is set by git when running hooks; fall back to config value.
if [ -n "$GIT_AUTHOR_EMAIL" ]; then
  current_author_email="$GIT_AUTHOR_EMAIL"
else
  current_author_email="$(git config user.email 2>/dev/null || true)"
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"

# --- detect staged plan-promotion moves ---

deleted_proposed=""
added_target=""
promoted_basenames=""

while IFS= read -r line; do
  # lines look like:
  #   D<TAB>plans/proposed/foo.md
  #   A<TAB>plans/approved/foo.md
  #   R100<TAB>plans/proposed/foo.md<TAB>plans/approved/foo.md  (rename)
  status="${line%%	*}"
  rest="${line#*	}"
  case "$status" in
    R*)
      # rename: rest is "old-path<TAB>new-path"
      old_path="${rest%%	*}"
      new_path="${rest#*	}"
      case "$old_path" in
        plans/proposed/*.md)
          case "$new_path" in
            plans/approved/*|plans/in-progress/*|plans/implemented/*|plans/archived/*)
              promoted_basenames="$promoted_basenames $(basename "$old_path")"
              ;;
          esac
          ;;
      esac
      ;;
    D)
      case "$rest" in
        plans/proposed/*.md)
          deleted_proposed="$deleted_proposed $rest"
          ;;
      esac
      ;;
    A)
      case "$rest" in
        plans/approved/*|plans/in-progress/*|plans/implemented/*|plans/archived/*)
          added_target="$added_target $rest"
          ;;
      esac
      ;;
  esac
done <<EOF
$(git diff --cached --name-status)
EOF

# Collect basenames that appear in both delete-from-proposed and add-to-target (D+A case)
for del in $deleted_proposed; do
  base="$(basename "$del")"
  for add in $added_target; do
    if [ "$(basename "$add")" = "$base" ]; then
      promoted_basenames="$promoted_basenames $base"
      break
    fi
  done
done

# Nothing being promoted — exit fast, hook does not apply
[ -n "$promoted_basenames" ] || exit 0

# --- check bypass trailer in commit message ---

# COMMIT_EDITMSG is populated before pre-commit hook runs when using --message.
# When an editor is used it is also available. Fallback to empty.
COMMIT_MSG_FILE="${GIT_DIR:-$(git rev-parse --git-dir)}/COMMIT_EDITMSG"
commit_msg=""
[ -f "$COMMIT_MSG_FILE" ] && commit_msg="$(cat "$COMMIT_MSG_FILE")"

bypass_reason=""
bypass_blocked_agent=0
if echo "$commit_msg" | grep -qE '^Orianna-Bypass:[[:space:]].{10,}'; then
  bypass_reason="$(echo "$commit_msg" | grep -E '^Orianna-Bypass:' | head -1 | sed 's/^Orianna-Bypass:[[:space:]]*//')"

  # Check if the bypass is being used by an agent identity — strictly disallowed.
  for _agent_email in $AGENT_EMAILS; do
    if [ "$current_author_email" = "$_agent_email" ]; then
      bypass_blocked_agent=1
      break
    fi
  done
fi

FACT_CHECK_DIR="$REPO_ROOT/assessments/plan-fact-checks"

all_ok=1
for base in $promoted_basenames; do
  basename_noext="${base%.md}"

  # Check for fact-check report
  report_found=0
  for r in "$FACT_CHECK_DIR/${basename_noext}-"*.md; do
    [ -f "$r" ] && report_found=1 && break
  done

  if [ "$report_found" -eq 1 ]; then
    continue
  fi

  # No report — check bypass trailer
  if [ -n "$bypass_reason" ]; then
    # Agent identities are never permitted to use Orianna-Bypass (ADR §D9.1).
    if [ "$bypass_blocked_agent" -eq 1 ]; then
      all_ok=0
      printf '\n' >&2
      printf '=== BLOCKED: Orianna-Bypass forbidden for agent identity ===\n' >&2
      printf 'Plan  : %s\n' "$base" >&2
      printf 'Author: %s\n' "$current_author_email" >&2
      printf '\n' >&2
      printf 'The Orianna-Bypass trailer is reserved for Duong'\''s admin identity\n' >&2
      printf '(harukainguyen1411 / personal email) — not agent accounts.\n' >&2
      printf 'Per ADR 2026-04-20-orianna-gated-plan-lifecycle §D9.1.\n' >&2
      printf '\n' >&2
      printf 'To promote this plan:\n' >&2
      printf '  1. Run scripts/orianna-sign.sh <plan> <phase> to obtain a signature.\n' >&2
      printf '  2. Then run scripts/plan-promote.sh as usual.\n' >&2
      printf '\n' >&2
      continue
    fi

    printf '\n' >&2
    printf '########################################################\n' >&2
    printf '# WARNING: Orianna fact-check bypassed                 #\n' >&2
    printf '# Plan  : %s\n' "$base" >&2
    printf '# Reason: %s\n' "$bypass_reason" >&2
    printf '# This bypass is logged in git history.                #\n' >&2
    printf '########################################################\n' >&2
    printf '\n' >&2
    continue
  fi

  # Neither report nor bypass trailer — block
  all_ok=0
  printf '\n' >&2
  printf '=== BLOCKED: Orianna fact-check gate ===\n' >&2
  printf 'Plan "%s" is being moved out of plans/proposed/ without a fact-check report.\n' "$base" >&2
  printf '\n' >&2
  printf 'To fix, choose ONE of:\n' >&2
  printf '  1. Use scripts/plan-promote.sh — it runs orianna-fact-check.sh automatically.\n' >&2
  printf '     A report will appear at: assessments/plan-fact-checks/%s-<timestamp>.md\n' "$basename_noext" >&2
  printf '\n' >&2
  printf '  2. Add an Orianna-Bypass trailer to your commit message (min 10-char reason):\n' >&2
  printf '       Orianna-Bypass: <your reason here>\n' >&2
  printf '     The bypass will be visible in git history.\n' >&2
  printf '\n' >&2
done

[ "$all_ok" -eq 1 ] || exit 1
exit 0

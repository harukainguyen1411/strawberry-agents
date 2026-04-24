#!/usr/bin/env bash
# scripts/hooks/_lib_reviewer_anonymity.sh
#
# Shared library for work-scope reviewer anonymity enforcement.
# Source this file — do not execute directly.
#
# Exports:
#   anonymity_scan_text   — reads stdin; returns 0 = clean, 1 = hit; prints matched tokens to stderr
#   anonymity_is_work_scope <dir> — returns 0 if the repo at <dir> is work-scope (origin matches missmp/)
#
# Denylist token table — single source of truth.
# Word-boundary matching (grep -wi) prevents false positives on substrings.

# ---------------------------------------------------------------------------
# Denylist token table
# ---------------------------------------------------------------------------
# Agent first-names
_ANONYMITY_AGENT_NAMES="Senna Lucian Evelynn Sona Viktor Jayce Azir Swain Orianna Karma Talon Ekko Heimerdinger Syndra Akali Ahri Ori"

# GitHub handles (exact match — no word-boundary needed for these since they contain hyphens/digits)
_ANONYMITY_HANDLES="strawberry-reviewers strawberry-reviewers-2 harukainguyen1411 duongntd99"

# Email domain pattern
_ANONYMITY_EMAIL_PATTERN="@anthropic\.com"

# Trailer pattern
_ANONYMITY_TRAILER="Co-Authored-By: Claude"

# ---------------------------------------------------------------------------
# anonymity_scan_text — reads stdin, reports hits to stderr
# Returns: 0 = clean, 1 = at least one hit found
# ---------------------------------------------------------------------------
anonymity_scan_text() {
  local input hit=0 matched_tokens=""

  input="$(cat)"

  # Scan agent first-names (word-boundary)
  for token in $_ANONYMITY_AGENT_NAMES; do
    if printf '%s' "$input" | grep -qwi "$token"; then
      matched_tokens="${matched_tokens}  agent-name: $token\n"
      hit=1
    fi
  done

  # Scan GitHub handles (exact string match — handles contain hyphens/digits)
  for handle in $_ANONYMITY_HANDLES; do
    if printf '%s' "$input" | grep -qF "$handle"; then
      matched_tokens="${matched_tokens}  github-handle: $handle\n"
      hit=1
    fi
  done

  # Scan email domain pattern
  if printf '%s' "$input" | grep -qE "$_ANONYMITY_EMAIL_PATTERN"; then
    matched_tokens="${matched_tokens}  email-pattern: *@anthropic.com\n"
    hit=1
  fi

  # Scan trailer pattern (exact)
  if printf '%s' "$input" | grep -qF "$_ANONYMITY_TRAILER"; then
    matched_tokens="${matched_tokens}  trailer: Co-Authored-By: Claude\n"
    hit=1
  fi

  if [ "$hit" = "1" ]; then
    printf '[anonymity] Denylist tokens found:\n' >&2
    printf '%b' "$matched_tokens" >&2
  fi

  return "$hit"
}

# ---------------------------------------------------------------------------
# anonymity_scan_author
# Scans the git author identity for denylist tokens.
# Source of author ident (in priority order):
#   1. ANONYMITY_TEST_AUTHOR env var (for unit tests)
#   2. `git var GIT_AUTHOR_IDENT` in ANONYMITY_HOOK_REPO (or cwd)
# Returns: 0 = clean, 1 = denylist hit; prints matched tokens to stderr.
# ---------------------------------------------------------------------------
anonymity_scan_author() {
  local author_ident

  if [ -n "${ANONYMITY_TEST_AUTHOR:-}" ]; then
    author_ident="$ANONYMITY_TEST_AUTHOR"
  else
    local repo_dir="${ANONYMITY_HOOK_REPO:-.}"
    author_ident="$(git -C "$repo_dir" var GIT_AUTHOR_IDENT 2>/dev/null || true)"
  fi

  if [ -z "$author_ident" ]; then
    return 0
  fi

  # GIT_AUTHOR_IDENT: "Name <email> timestamp timezone" — strip trailing timestamp
  local name_email
  name_email="$(printf '%s' "$author_ident" | sed 's/ [0-9][0-9]* [+-][0-9][0-9]*$//')"

  printf '%s' "$name_email" | anonymity_scan_text
}

# ---------------------------------------------------------------------------
# anonymity_is_work_scope <dir>
# Returns 0 if the git repo rooted at <dir> has origin matching [:/]missmp/
# Returns 1 otherwise (personal scope or no remote)
# ---------------------------------------------------------------------------
anonymity_is_work_scope() {
  local dir="${1:-.}"
  local origin_url

  origin_url="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
  if [ -z "$origin_url" ]; then
    return 1
  fi

  if printf '%s' "$origin_url" | grep -qE '[:/]missmp/'; then
    return 0
  fi

  return 1
}

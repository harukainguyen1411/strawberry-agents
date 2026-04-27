#!/bin/sh
# scripts/hooks/pre-commit-resolved-identity.sh
#
# Pre-commit hook: block persona-named author/committer identities.
#
# PRIMARY GATE — reads resolved identity via `git var GIT_AUTHOR_IDENT` and
# `git var GIT_COMMITTER_IDENT`. By the time pre-commit fires, all shell
# expansion is complete and git has resolved the final identity strings
# (config + env + command-line overrides all merged). This catches every
# bypass technique that defeats pre-execve source scanning:
#   - line-continuation (NEW-BP-4)
#   - backtick expansion (NEW-BP-5)
#   - $(...) command substitution (NEW-BP-6)
#   - eval wrapper (NEW-BP-7)
#   - $VAR indirection (NEW-BP-8)
#   - cat /file indirection (NEW-BP-9)
#   - inline GIT_AUTHOR_NAME env (caught via git var resolution)
#   - sh -c / bash -c wrappers (NEW-BP-11, NEW-BP-12)
#
# NOTE: git commit-tree (NEW-BP-10) does NOT fire pre-commit hooks.
# That path is closed by pre-push-resolved-identity.sh (T3).
#
# Plan: plans/approved/personal/2026-04-25-resolved-identity-enforcement.md
# Layer: primary gate (pre-commit)
# Companion: scripts/hooks/pre-push-resolved-identity.sh (backstop)
# Advisory: scripts/hooks/pretooluse-subagent-identity.sh (defense-in-depth)
#
# Allowlist:
#   - Duongntd <103487096+Duongntd@users.noreply.github.com>
#   - STRAWBERRY_AGENT=orianna  (Orianna carve-out, pre-commit only)
#
# Persona denylist (full roster from agents/memory/agent-network.md):
#   Viktor, Lucian, Senna, Aphelios, Xayah, Caitlyn, Akali, Karma, Talon,
#   Azir, Swain, Kayn, Lux, Sona, Evelynn, Orianna
#   @strawberry.local email domain
#
# Exit codes:
#   0 — identity is clean (or allowlisted/Orianna carve-out)
#   1 — persona-named identity detected; commit blocked
#
# POSIX-portable per Rule 10.

# ---------------------------------------------------------------------------
# Orianna carve-out
# ---------------------------------------------------------------------------
if [ "${STRAWBERRY_AGENT:-}" = "orianna" ] || [ "${CLAUDE_AGENT_NAME:-}" = "orianna" ]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Read resolved identities
# ---------------------------------------------------------------------------
author_ident="$(git var GIT_AUTHOR_IDENT 2>/dev/null)" || {
  printf '[pre-commit-resolved-identity] ERROR: git var GIT_AUTHOR_IDENT failed\n' >&2
  exit 1
}
committer_ident="$(git var GIT_COMMITTER_IDENT 2>/dev/null)" || {
  printf '[pre-commit-resolved-identity] ERROR: git var GIT_COMMITTER_IDENT failed\n' >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Allowlist: Duongntd neutral identity passes unconditionally
# ---------------------------------------------------------------------------
# Format: "Duongntd <103487096+Duongntd@users.noreply.github.com> <timestamp> <tz>"
# We check the name+email portion (first two fields).
neutral_pattern="^Duongntd <103487096+Duongntd@users.noreply.github.com>"

author_name_email="$(printf '%s' "$author_ident" | sed 's/ [0-9]* [+-][0-9]*$//')"
committer_name_email="$(printf '%s' "$committer_ident" | sed 's/ [0-9]* [+-][0-9]*$//')"

# If both match neutral pattern, allow unconditionally.
author_neutral=0
committer_neutral=0

case "$author_name_email" in
  "Duongntd <103487096+Duongntd@users.noreply.github.com>") author_neutral=1 ;;
esac
case "$committer_name_email" in
  "Duongntd <103487096+Duongntd@users.noreply.github.com>") committer_neutral=1 ;;
esac

if [ "$author_neutral" -eq 1 ] && [ "$committer_neutral" -eq 1 ]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Persona denylist regex
# Full roster: Viktor, Lucian, Senna, Aphelios, Xayah, Caitlyn, Akali, Karma,
#              Talon, Azir, Swain, Kayn, Lux, Sona, Evelynn, Orianna
# Also: @strawberry.local email domain
# Case-insensitive word-boundary match (grep -iE).
# ---------------------------------------------------------------------------
PERSONA_PATTERN='(^|[[:space:]])+(Viktor|Lucian|Senna|Aphelios|Xayah|Caitlyn|Akali|Karma|Talon|Azir|Swain|Kayn|Lux|Sona|Evelynn|Orianna)([[:space:]]|$|[^[:alnum:]])'
EMAIL_PATTERN='@strawberry\.local'

violation=""

# Check author
if printf '%s' "$author_ident" | grep -iqE "$PERSONA_PATTERN"; then
  violation="author"
elif printf '%s' "$author_ident" | grep -iqE "$EMAIL_PATTERN"; then
  violation="author"
fi

# Check committer (only if author was clean)
if [ -z "$violation" ]; then
  if printf '%s' "$committer_ident" | grep -iqE "$PERSONA_PATTERN"; then
    violation="committer"
  elif printf '%s' "$committer_ident" | grep -iqE "$EMAIL_PATTERN"; then
    violation="committer"
  fi
fi

if [ -n "$violation" ]; then
  printf '\n[pre-commit-resolved-identity] BLOCKED: persona-named %s identity detected.\n' "$violation" >&2
  if [ "$violation" = "author" ]; then
    printf '  Author:    %s\n' "$author_ident" >&2
  else
    printf '  Committer: %s\n' "$committer_ident" >&2
  fi
  printf '\n  Commits must use the neutral identity:\n' >&2
  printf '    Duongntd <103487096+Duongntd@users.noreply.github.com>\n' >&2
  printf '\n  Set via: git config user.name Duongntd\n' >&2
  printf '           git config user.email 103487096+Duongntd@users.noreply.github.com\n' >&2
  printf '\n  Reference: architecture/agent-network-v1/git-identity.md\n' >&2
  exit 1
fi

exit 0

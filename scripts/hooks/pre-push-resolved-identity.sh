#!/bin/sh
# scripts/hooks/pre-push-resolved-identity.sh
#
# Pre-push hook: backstop against persona-named commits reaching a remote.
#
# Reads each pushed commit's raw object via `git cat-file commit <sha>` and
# inspects the `author` and `committer` header lines. This catches commits
# that bypassed pre-commit via `git commit-tree` (NEW-BP-10) or were created
# in a different environment without the pre-commit hook installed.
#
# Plan: plans/approved/personal/2026-04-25-resolved-identity-enforcement.md
# Layer: backstop (pre-push)
# Primary gate: scripts/hooks/pre-commit-resolved-identity.sh
# Advisory:     scripts/hooks/pretooluse-subagent-identity.sh
#
# Allowlist:
#   - Duongntd <103487096+Duongntd@users.noreply.github.com>
#   No Orianna carve-out at push time — she pushes neutral identity.
#
# Persona denylist (full roster from agents/memory/agent-network.md):
#   Viktor, Lucian, Senna, Aphelios, Xayah, Caitlyn, Akali, Karma, Talon,
#   Azir, Swain, Kayn, Lux, Sona, Evelynn, Orianna
#   @strawberry.local email domain
#
# Exit codes:
#   0 — all pushed commits have clean identity
#   1 — at least one pushed commit has persona-named author or committer
#
# Input: stdin lines per git pre-push protocol:
#   <local-ref> <local-sha> <remote-ref> <remote-sha>
#
# POSIX-portable per Rule 10.

REMOTE="$1"
# URL="$2"  # not used

ZERO_SHA="0000000000000000000000000000000000000000"
PERSONA_PATTERN='(^|[[:space:]])+(Viktor|Lucian|Senna|Aphelios|Xayah|Caitlyn|Akali|Karma|Talon|Azir|Swain|Kayn|Lux|Sona|Evelynn|Orianna)([[:space:]]|$|[^[:alnum:]])'
EMAIL_PATTERN='@strawberry\.local'

rc=0

while read -r local_ref local_sha remote_ref remote_sha; do
  # Skip deletions
  [ "$local_sha" = "$ZERO_SHA" ] && continue

  # Determine range of new commits
  if [ "$remote_sha" = "$ZERO_SHA" ] || [ -z "$remote_sha" ]; then
    # New branch — walk commits not reachable from any remote
    range="$(git rev-list "$local_sha" --not --remotes 2>/dev/null)" || range="$local_sha"
  else
    range="$(git rev-list "${remote_sha}..${local_sha}" 2>/dev/null)" || range=""
  fi

  [ -z "$range" ] && continue

  for sha in $range; do
    # Read the raw commit object
    raw="$(git cat-file commit "$sha" 2>/dev/null)" || {
      printf '[pre-push-resolved-identity] WARNING: could not read commit %s — skipping\n' "$sha" >&2
      continue
    }

    # Extract author and committer header lines (stop at blank line = end of headers)
    author_line=""
    committer_line=""
    while IFS= read -r line; do
      [ -z "$line" ] && break
      case "$line" in
        author\ *) author_line="$line" ;;
        committer\ *) committer_line="$line" ;;
      esac
    done <<EOF
$raw
EOF

    violation=""
    offending_line=""

    # Check author header
    if printf '%s' "$author_line" | grep -iqE "$PERSONA_PATTERN"; then
      violation="author"
      offending_line="$author_line"
    elif printf '%s' "$author_line" | grep -iqE "$EMAIL_PATTERN"; then
      violation="author"
      offending_line="$author_line"
    fi

    # Check committer header
    if [ -z "$violation" ]; then
      if printf '%s' "$committer_line" | grep -iqE "$PERSONA_PATTERN"; then
        violation="committer"
        offending_line="$committer_line"
      elif printf '%s' "$committer_line" | grep -iqE "$EMAIL_PATTERN"; then
        violation="committer"
        offending_line="$committer_line"
      fi
    fi

    if [ -n "$violation" ]; then
      printf '\n[pre-push-resolved-identity] BLOCKED: persona-named %s in commit %s\n' "$violation" "$sha" >&2
      printf '  %s\n' "$offending_line" >&2
      printf '\n  Commits must use the neutral identity:\n' >&2
      printf '    Duongntd <103487096+Duongntd@users.noreply.github.com>\n' >&2
      printf '\n  Reference: architecture/agent-network-v1/git-identity.md\n' >&2
      rc=1
    fi
  done
done

exit "$rc"

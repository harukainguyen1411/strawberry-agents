#!/usr/bin/env bash
# scripts/hooks/pre-commit-staged-scope-guard.sh
#
# Pre-commit hook: staged-scope guard.
# Compares staged paths against a declared STAGED_SCOPE to prevent
# cross-agent commit sweeping (incidents: Syndra co-author sweep, Ekko 10f7581).
#
# Scope resolution order (highest priority first):
#   1. STAGED_SCOPE env var — newline-separated paths. Exact literal '*' = escape hatch.
#   2. .git/COMMIT_SCOPE file — same format. Cleared on successful match.
#   3. Neither set → warning mode (non-blocking, >10 files or >3 top-level dirs).
#
# Exit codes: 0 = pass (or escape hatch), 1 = hard reject (out-of-scope paths found).
# All diagnostic output goes to stderr.
#
# Plan: 2026-04-21-staged-scope-guard-hook.md Task 2

set -uo pipefail

GIT_DIR_PATH="$(git rev-parse --git-dir)"
COMMIT_SCOPE_FILE="$GIT_DIR_PATH/COMMIT_SCOPE"

# Collect staged paths
staged_paths="$(git diff --cached --name-only --diff-filter=ACMR)"

# If nothing staged, nothing to check
if [ -z "$staged_paths" ]; then
  exit 0
fi

# -----------------------------------------------------------------------
# Resolve scope
# -----------------------------------------------------------------------
scope=""
scope_source=""

if [ "${STAGED_SCOPE+set}" = "set" ]; then
  scope="$STAGED_SCOPE"
  scope_source="STAGED_SCOPE env"
elif [ -f "$COMMIT_SCOPE_FILE" ]; then
  scope="$(cat "$COMMIT_SCOPE_FILE")"
  scope_source=".git/COMMIT_SCOPE"
fi

# -----------------------------------------------------------------------
# Escape hatch: STAGED_SCOPE='*'
# -----------------------------------------------------------------------
if [ "$scope" = "*" ]; then
  file_count="$(printf '%s\n' "$staged_paths" | wc -l | tr -d ' ')"
  printf '[staged-scope] Escape hatch active (STAGED_SCOPE=*). %s files committed without scope check.\n' "$file_count" >&2
  exit 0
fi

# -----------------------------------------------------------------------
# Scope declared: hard reject on out-of-scope paths
# -----------------------------------------------------------------------
if [ -n "$scope" ]; then
  # Build set of declared paths (strip blank lines and whitespace)
  declared="$(printf '%s\n' "$scope" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' || true)"

  # Find staged paths not in the declared set
  out_of_scope=""
  while IFS= read -r path; do
    if ! printf '%s\n' "$declared" | grep -qxF "$path"; then
      out_of_scope="${out_of_scope}  ${path}
"
    fi
  done <<EOF
$staged_paths
EOF

  if [ -z "$out_of_scope" ]; then
    # All staged paths are within scope — clear COMMIT_SCOPE and pass
    rm -f "$COMMIT_SCOPE_FILE"
    exit 0
  fi

  # Format declared scope for display
  declared_display="$(printf '%s\n' "$declared" | sed 's/^/  /')"

  cat >&2 <<REJECT
✘ Staged-scope guard: commit contains files outside the declared STAGED_SCOPE.

Out-of-scope staged paths:
${out_of_scope}
Declared scope (from ${scope_source}):
${declared_display}

This usually means \`git add -A\` / \`git add .\` / \`git add <dir>/\` swept up
another agent's parallel work. Unstage the foreign files (\`git reset HEAD <path>\`)
and retry, or widen STAGED_SCOPE if they legitimately belong to this commit.

Bulk-operation escape: STAGED_SCOPE='*' (exact asterisk) disables the check.
REJECT
  exit 1
fi

# -----------------------------------------------------------------------
# No scope declared: warning mode
# -----------------------------------------------------------------------
file_count="$(printf '%s\n' "$staged_paths" | wc -l | tr -d ' ')"
dir_count="$(printf '%s\n' "$staged_paths" | awk -F/ '{print $1}' | sort -u | wc -l | tr -d ' ')"

if [ "$file_count" -gt 10 ] || [ "$dir_count" -gt 3 ]; then
  staged_display="$(printf '%s\n' "$staged_paths" | sed 's/^/  /')"
  cat >&2 <<WARN
⚠ Staged-scope guard: commit is unscoped and touches ${file_count} files across
${dir_count} top-level directories. Set STAGED_SCOPE to narrow the commit, or
STAGED_SCOPE='*' if this is intentional bulk work.

Staged paths:
${staged_display}
WARN
fi

exit 0

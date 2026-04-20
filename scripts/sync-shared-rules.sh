#!/usr/bin/env bash
# scripts/sync-shared-rules.sh
#
# Re-inlines shared rule content from .claude/agents/_shared/<role>.md into
# each paired agent definition that carries a <!-- include: _shared/<role>.md -->
# marker.
#
# Usage:
#   bash scripts/sync-shared-rules.sh [--agents-dir <path>]
#
# Options:
#   --agents-dir <path>   Override the agent definitions directory.
#                         Defaults to <repo-root>/.claude/agents/
#
# Behavior:
#   1. Scans every *.md file in the agents directory (excluding _shared/).
#   2. For files containing a <!-- include: _shared/<role>.md --> marker:
#        a. Locates the canonical shared file.
#        b. Emits error + exits non-zero if the shared file is missing.
#        c. Preserves everything above+including the include marker line.
#        d. Replaces everything below the marker with the shared file contents.
#   3. Skips files with no include marker (emits a warning — not fatal).
#   4. Idempotent: running twice produces identical output.
#
# Exit codes:
#   0  all agents synced (or skipped with warning)
#   1  one or more shared files missing (fatal)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "")"

if [ -z "$REPO_ROOT" ]; then
  # Fallback: walk up from script dir to find repo root
  REPO_ROOT="$SCRIPT_DIR/.."
fi

AGENTS_DIR=""

# --- Argument parsing ---
while [ $# -gt 0 ]; do
  case "$1" in
    --agents-dir)
      shift
      AGENTS_DIR="$1"
      shift
      ;;
    *)
      printf 'sync-shared-rules: unknown argument: %s\n' "$1" >&2
      printf 'Usage: bash sync-shared-rules.sh [--agents-dir <path>]\n' >&2
      exit 1
      ;;
  esac
done

if [ -z "$AGENTS_DIR" ]; then
  AGENTS_DIR="$REPO_ROOT/.claude/agents"
fi

SHARED_DIR="$AGENTS_DIR/_shared"

if [ ! -d "$AGENTS_DIR" ]; then
  printf 'sync-shared-rules: agents directory not found: %s\n' "$AGENTS_DIR" >&2
  exit 1
fi

errors=0
synced=0
skipped=0

# Scan every *.md in agents dir (non-recursive; _shared/ files are skipped by the path filter)
for agent_file in "$AGENTS_DIR"/*.md; do
  [ -f "$agent_file" ] || continue

  # Determine the path of this file relative to AGENTS_DIR
  agent_basename="$(basename "$agent_file")"

  # --- Find include marker ---
  # Pattern: <!-- include: _shared/<role>.md -->
  include_line=""
  include_role=""
  while IFS= read -r line; do
    case "$line" in
      "<!-- include: _shared/"*)
        include_line="$line"
        # Extract role name: strip prefix and suffix
        include_role="${line#<!-- include: _shared/}"
        include_role="${include_role%.md -->}"
        break
        ;;
    esac
  done < "$agent_file"

  if [ -z "$include_role" ]; then
    printf 'sync-shared-rules: WARN: %s — no include marker found, skipping\n' "$agent_basename" >&2
    skipped=$((skipped + 1))
    continue
  fi

  shared_file="$SHARED_DIR/${include_role}.md"

  if [ ! -f "$shared_file" ]; then
    printf 'sync-shared-rules: ERROR: shared file not found for %s: %s\n' \
      "$agent_basename" "$shared_file" >&2
    printf '  Expected: _shared/%s.md\n' "$include_role" >&2
    printf '  Create the shared file or remove the include marker from %s\n' "$agent_basename" >&2
    errors=$((errors + 1))
    continue
  fi

  # --- Build new file content ---
  # Write everything up to and including the include marker, then append shared content.
  tmp_file="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$tmp_file'" EXIT INT TERM HUP

  marker_found=0
  while IFS= read -r line; do
    printf '%s\n' "$line" >> "$tmp_file"
    case "$line" in
      "<!-- include: _shared/${include_role}.md -->")
        marker_found=1
        break
        ;;
    esac
  done < "$agent_file"

  if [ "$marker_found" -eq 0 ]; then
    # Should not reach here since we already found the marker, but be safe
    rm -f "$tmp_file"
    printf 'sync-shared-rules: ERROR: unexpected: marker vanished in %s\n' "$agent_basename" >&2
    errors=$((errors + 1))
    continue
  fi

  # Append shared content (with a trailing newline for clean diffs)
  cat "$shared_file" >> "$tmp_file"
  # Ensure file ends with exactly one newline
  if [ -s "$tmp_file" ]; then
    last_char="$(tail -c1 "$tmp_file" | od -An -tx1 | tr -d ' \n')"
    if [ "$last_char" != "0a" ]; then
      printf '\n' >> "$tmp_file"
    fi
  fi

  # Only overwrite if content changed (idempotency: avoid spurious mtime updates)
  if ! diff -q "$tmp_file" "$agent_file" >/dev/null 2>&1; then
    cp "$tmp_file" "$agent_file"
    printf 'sync-shared-rules: synced %s <- _shared/%s.md\n' "$agent_basename" "$include_role"
    synced=$((synced + 1))
  else
    printf 'sync-shared-rules: up-to-date %s\n' "$agent_basename"
  fi

  rm -f "$tmp_file"
  trap - EXIT INT TERM HUP
done

printf 'sync-shared-rules: done. synced=%d skipped=%d errors=%d\n' "$synced" "$skipped" "$errors"

if [ "$errors" -gt 0 ]; then
  exit 1
fi
exit 0

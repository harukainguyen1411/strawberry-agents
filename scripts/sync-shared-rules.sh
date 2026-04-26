#!/usr/bin/env bash
# scripts/sync-shared-rules.sh
#
# Re-inlines shared rule content from .claude/agents/_shared/<role>.md into
# each paired agent definition that carries one or more
#   <!-- include: _shared/<role>.md -->
# markers.
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
#   2. For files containing one or more <!-- include: _shared/<role>.md --> markers:
#        a. Locates the canonical shared file for each marker.
#        b. Emits error + exits non-zero if any shared file is missing.
#        c. For each marker: preserves everything above+including the marker line,
#           then replaces the block below it (until the next marker or EOF)
#           with the corresponding shared file contents.
#        d. Multiple markers are processed in document order.
#        e. Depth-2 pass: any <!-- include: --> markers found inside the inlined
#           shared file content are themselves resolved (one level deep).
#   3. Skips files with no include marker (emits a warning — not fatal).
#   4. Idempotent: running twice produces identical output.
#   5. Depth limit: depth-3 (an include inside an include's include) is an error.
#      See §OQ2 of plans/approved/personal/2026-04-21-agent-feedback-system.md.
#
# Exit codes:
#   0  all agents synced (or skipped with warning)
#   1  one or more shared files missing (fatal) or depth limit exceeded (§OQ2)
#
# Invariant (S4):
#   Any prose written between two adjacent <!-- include: --> markers will be
#   silently discarded on the next sync run, because the script replaces
#   everything from one marker's closing newline up to (but not including) the
#   next marker. Do not write hand-authored content in those inter-marker gaps.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "")"

if [ -z "$REPO_ROOT" ]; then
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

# resolve_shared_content <shared_file> <context_name>
# Reads a shared file and resolves any depth-2 include markers within it.
# Depth-2 markers are NOT emitted into the output — only their resolved content
# is written. This keeps the agent file free of nested markers (idempotency).
# Errors if depth-3 markers are found (§OQ2).
# Writes resolved content to stdout.
resolve_shared_content() {
  local shared_file="$1"
  local context_name="$2"

  while IFS= read -r line; do
    case "$line" in
      "<!-- include: _shared/"*)
        # This is a depth-2 include marker inside a shared file.
        local nested_role="${line#<!-- include: _shared/}"
        nested_role="${nested_role%.md -->}"
        local nested_file="$SHARED_DIR/${nested_role}.md"

        if [ ! -f "$nested_file" ]; then
          printf 'sync-shared-rules: ERROR: nested shared file not found for %s: %s\n' \
            "$context_name" "$nested_file" >&2
          return 1
        fi

        # Check for depth-3: if the nested file itself has include markers, error out (§OQ2)
        if grep -q '<!-- include: _shared/' "$nested_file"; then
          printf 'sync-shared-rules: ERROR: depth-3 nested include detected in %s (via %s). Max depth is 2. See §OQ2 of plans/approved/personal/2026-04-21-agent-feedback-system.md.\n' \
            "$nested_file" "$context_name" >&2
          return 1
        fi

        # Inline the depth-2 content (do NOT emit the marker line into the agent file).
        # This keeps the agent def free of nested markers, preserving idempotency.
        cat "$nested_file"
        # Ensure newline after nested content
        local last_char
        last_char="$(tail -c1 "$nested_file" | od -An -tx1 | tr -d ' \n')"
        if [ "$last_char" != "0a" ]; then
          printf '\n'
        fi
        ;;
      *)
        printf '%s\n' "$line"
        ;;
    esac
  done < "$shared_file"
}

# sync_agent_file <path>
# Rewrites the agent file with all include markers processed.
# Returns 0 on success, 1 on error (missing shared file or depth limit).
sync_agent_file() {
  local agent_file="$1"
  local agent_basename
  agent_basename="$(basename "$agent_file")"

  # --- Collect all include markers in document order ---
  # Each entry: "<line_number>:<role_name>"
  local markers=()
  local lineno=0
  while IFS= read -r line; do
    lineno=$((lineno + 1))
    case "$line" in
      "<!-- include: _shared/"*)
        local role="${line#<!-- include: _shared/}"
        role="${role%.md -->}"
        markers+=("${lineno}:${role}")
        ;;
    esac
  done < "$agent_file"

  if [ "${#markers[@]}" -eq 0 ]; then
    printf 'sync-shared-rules: WARN: %s — no include marker found, skipping\n' "$agent_basename" >&2
    return 2
  fi

  # --- Validate all shared files exist before modifying anything ---
  local ok=1
  for entry in "${markers[@]}"; do
    local role="${entry#*:}"
    local shared_file="$SHARED_DIR/${role}.md"
    if [ ! -f "$shared_file" ]; then
      printf 'sync-shared-rules: ERROR: shared file not found for %s: %s\n' \
        "$agent_basename" "$shared_file" >&2
      printf '  Expected: _shared/%s.md\n' "$role" >&2
      ok=0
    fi
  done
  if [ "$ok" -eq 0 ]; then
    return 1
  fi

  # --- Build new file content ---
  # Strategy: stream through the file line by line.
  # State machine:
  #   mode=header  — emit lines as-is (before first marker)
  #   mode=skip    — skip lines (inlined content between/after a marker, until next marker or EOF)
  # When we hit a marker line: emit it, emit shared content (with depth-2 resolved), switch to skip mode.

  local tmp_file
  tmp_file="$(mktemp)"
  local resolved_tmp
  resolved_tmp="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$tmp_file' '$resolved_tmp'" EXIT INT TERM HUP

  # Build a lookup of marker line numbers for O(1) check
  # Format: line number as key stored in a space-separated string (portable, no assoc arrays)
  local marker_lines=""
  for entry in "${markers[@]}"; do
    local mlineno="${entry%%:*}"
    marker_lines="$marker_lines $mlineno "
  done

  local mode="header"
  local cur_lineno=0

  while IFS= read -r line; do
    cur_lineno=$((cur_lineno + 1))

    # Check if this line is a marker line
    local is_marker=0
    local marker_role=""
    case " $marker_lines " in
      *" $cur_lineno "*)
        is_marker=1
        # Extract role from the line itself
        marker_role="${line#<!-- include: _shared/}"
        marker_role="${marker_role%.md -->}"
        ;;
    esac

    if [ "$is_marker" -eq 1 ]; then
      # Always emit the marker line
      printf '%s\n' "$line" >> "$tmp_file"

      # Resolve shared content with depth-2 pass
      if ! resolve_shared_content "$SHARED_DIR/${marker_role}.md" "$agent_basename" >> "$tmp_file"; then
        rm -f "$tmp_file" "$resolved_tmp"
        trap - EXIT INT TERM HUP
        return 1
      fi

      # Ensure newline after shared content
      local last_char
      last_char="$(tail -c1 "$tmp_file" | od -An -tx1 | tr -d ' \n')"
      if [ "$last_char" != "0a" ]; then
        printf '\n' >> "$tmp_file"
      fi
      # Switch to skip mode (discard old inlined content until next marker or EOF)
      mode="skip"
    elif [ "$mode" = "header" ]; then
      printf '%s\n' "$line" >> "$tmp_file"
    elif [ "$mode" = "skip" ]; then
      # Check if we just hit another marker on the NEXT iteration —
      # we need to detect if the next line is a marker.
      # Since we're in skip mode, don't emit this line.
      # (The marker line itself is handled by the is_marker branch above.)
      :
    fi
  done < "$agent_file"

  # Ensure file ends with exactly one newline
  if [ -s "$tmp_file" ]; then
    local last_char
    last_char="$(tail -c1 "$tmp_file" | od -An -tx1 | tr -d ' \n')"
    if [ "$last_char" != "0a" ]; then
      printf '\n' >> "$tmp_file"
    fi
  fi

  # Only overwrite if content changed
  if ! diff -q "$tmp_file" "$agent_file" >/dev/null 2>&1; then
    cp "$tmp_file" "$agent_file"
    printf 'sync-shared-rules: synced %s (%d include(s))\n' "$agent_basename" "${#markers[@]}"
    rm -f "$tmp_file" "$resolved_tmp"
    trap - EXIT INT TERM HUP
    return 0
  else
    printf 'sync-shared-rules: up-to-date %s\n' "$agent_basename"
    rm -f "$tmp_file" "$resolved_tmp"
    trap - EXIT INT TERM HUP
    return 0
  fi
}

for agent_file in "$AGENTS_DIR"/*.md; do
  [ -f "$agent_file" ] || continue

  result=0
  sync_agent_file "$agent_file" || result=$?

  case "$result" in
    0) synced=$((synced + 1)) ;;
    1) errors=$((errors + 1)) ;;
    2) skipped=$((skipped + 1)) ;;
  esac
done

printf 'sync-shared-rules: done. synced=%d skipped=%d errors=%d\n' "$synced" "$skipped" "$errors"

if [ "$errors" -gt 0 ]; then
  exit 1
fi
exit 0

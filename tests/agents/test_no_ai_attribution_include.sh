#!/usr/bin/env bash
# tests/agents/test_no_ai_attribution_include.sh
#
# T1 — xfail: structural test asserting every agent def contains the
# <!-- include: _shared/no-ai-attribution.md --> marker AND the inlined
# block immediately following matches the canonical shared file content.
#
# Plan: plans/approved/personal/2026-04-25-no-ai-attribution-defense-in-depth.md T1
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

AGENTS_DIR="$REPO_ROOT/.claude/agents"
SHARED_FILE="$AGENTS_DIR/_shared/no-ai-attribution.md"

if [ ! -f "$SHARED_FILE" ]; then
  printf 'FAIL: shared file not found: %s\n' "$SHARED_FILE" >&2
  exit 1
fi

SHARED_CONTENT="$(cat "$SHARED_FILE")"
MARKER="<!-- include: _shared/no-ai-attribution.md -->"

failures=0

for agent_file in "$AGENTS_DIR"/*.md; do
  [ -f "$agent_file" ] || continue
  basename_f="$(basename "$agent_file")"

  # Check marker present
  if ! grep -qF "$MARKER" "$agent_file"; then
    printf 'FAIL: %s missing include marker\n' "$basename_f" >&2
    failures=$((failures + 1))
    continue
  fi

  # Extract block after the last occurrence of the marker line
  # Use grep -n with fixed string to get line number, then tail from there.
  marker_lineno="$(grep -nF "$MARKER" "$agent_file" | tail -1 | cut -d: -f1)"
  total_lines="$(wc -l < "$agent_file")"
  if [ "$marker_lineno" -ge "$total_lines" ]; then
    inlined=""
  else
    inlined="$(tail -n +"$((marker_lineno + 1))" "$agent_file")"
    # Strip trailing newline to match SHARED_CONTENT (cat strips trailing newline from subshell)
    inlined="${inlined%$'\n'}"
  fi

  if [ "$inlined" != "$SHARED_CONTENT" ]; then
    printf 'FAIL: %s inlined block does not match canonical shared file\n' "$basename_f" >&2
    printf '  Expected (first 5 lines):\n' >&2
    printf '%s\n' "$SHARED_CONTENT" | head -5 | sed 's/^/    /' >&2
    printf '  Got (first 5 lines):\n' >&2
    printf '%s\n' "$inlined" | head -5 | sed 's/^/    /' >&2
    failures=$((failures + 1))
  fi
done

if [ "$failures" -gt 0 ]; then
  printf 'T1: %d agent def(s) failed include check\n' "$failures" >&2
  exit 1
fi

printf 'T1: all agent defs contain correct no-ai-attribution include\n'
exit 0

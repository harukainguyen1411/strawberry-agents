#!/bin/sh
# pre-compact-gate.sh — PreCompact hook gate
# Plan: 2026-04-20-lissandra-precompact-consolidator.md §3.1.1
#
# Reads JSON payload from stdin. Decision matrix:
#   1. compaction_trigger=="auto"        → exit 0 (allow silently)
#   2. .no-precompact-save at repo root  → exit 0 (explicit opt-out)
#   3. /tmp/claude-precompact-saved-<sid> exists → exit 0 (already consolidated)
#   4. otherwise → emit block JSON telling user to run /pre-compact-save first
#
# POSIX portable (Rule 10). Requires: jq
set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"

# Read full stdin payload
payload="$(cat)"

# Extract fields via jq (hard dependency; fail loudly if absent)
if ! command -v jq >/dev/null 2>&1; then
  printf '{"decision":"block","reason":"pre-compact-gate.sh requires jq but it is not installed. Install jq or remove the PreCompact hook to unblock /compact."}\n'
  exit 0
fi

trigger="$(echo "$payload" | jq -r '.compaction_trigger // "manual"')"
session_id="$(echo "$payload" | jq -r '.session_id // ""')"

# Case 1: auto-compact — never block (user didn't ask for it)
if [ "$trigger" = "auto" ]; then
  exit 0
fi

# Case 2: explicit opt-out dotfile at repo root
if [ -f "$REPO_ROOT/.no-precompact-save" ]; then
  exit 0
fi

# Case 3: completion sentinel touched by /pre-compact-save skill
sentinel="/tmp/claude-precompact-saved-${session_id}"
if [ -n "$session_id" ] && [ -f "$sentinel" ]; then
  rm -f "$sentinel"
  exit 0
fi

# Case 4: block and instruct
printf '{"decision":"block","reason":"Lissandra has not consolidated this session yet. Run /pre-compact-save first, then re-run /compact. To skip consolidation entirely, create .no-precompact-save in the repo root."}\n'

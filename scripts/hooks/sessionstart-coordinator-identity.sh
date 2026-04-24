#!/usr/bin/env bash
# sessionstart-coordinator-identity.sh
# SessionStart hook: preserve "skipping startup reads" message on resume/clear/compact,
# and assert coordinator identity via a three-tier resolution chain.
#
# T1: extracts the existing inline SessionStart command, preserving byte-identical
#     output for source=startup (no output) and source=resume|clear|compact.
# T3: adds three-tier resolution chain per plan §Decision.2.
#
# POSIX-portable bash per Rule 10.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HINT_FILE="$REPO_ROOT/.coordinator-identity"

# Read the JSON payload from stdin
INPUT="$(cat)"
SRC="$(printf '%s' "$INPUT" | jq -r '.source' 2>/dev/null || echo "")"

# On startup: no output — let CLAUDE.md "no greeting → Evelynn" rule apply normally.
if [ "$SRC" != "resume" ] && [ "$SRC" != "clear" ] && [ "$SRC" != "compact" ]; then
  exit 0
fi

# Three-tier coordinator identity resolution (T3).
COORDINATOR=""

# Tier 1: env vars — CLAUDE_AGENT_NAME then STRAWBERRY_AGENT
for _var in "${CLAUDE_AGENT_NAME:-}" "${STRAWBERRY_AGENT:-}"; do
  _val="$(printf '%s' "$_var" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  if [ "$_val" = "evelynn" ] || [ "$_val" = "sona" ]; then
    COORDINATOR="$_val"
    break
  fi
done

# Tier 2: hint file .coordinator-identity (written by /pre-compact-save)
if [ -z "$COORDINATOR" ] && [ -f "$HINT_FILE" ]; then
  _hint="$(tr '[:upper:]' '[:lower:]' < "$HINT_FILE" | tr -d '[:space:]')"
  if [ "$_hint" = "evelynn" ] || [ "$_hint" = "sona" ]; then
    COORDINATOR="$_hint"
  fi
fi

# Emit final JSON with identity context appended.
if [ -n "$COORDINATOR" ]; then
  _cap="$(printf '%s' "$COORDINATOR" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
  _additional="RESUMED SESSION — do not re-read startup files. Reply only: Session resumed. Coordinator identity resolved: you are $_cap. Do NOT apply the no-greeting Evelynn default — identity is already pinned."
  printf '{"systemMessage":"Resumed session — skipping startup reads.","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}' "$_additional"
else
  # Tier 3: fail-loud — neither env var nor hint file resolved identity.
  _additional="RESUMED SESSION — coordinator identity unresolved. DO NOT assume Evelynn-default. Ask Duong which coordinator this session is before reading any coordinator startup files."
  printf '{"systemMessage":"Resumed session — skipping startup reads.","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}' "$_additional"
fi

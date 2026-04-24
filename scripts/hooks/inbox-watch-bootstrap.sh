#!/usr/bin/env bash
# inbox-watch-bootstrap.sh — SessionStart hook: nudge coordinator to invoke Monitor.
#
# Implements plans/in-progress/2026-04-20-strawberry-inbox-channel.md §3.3, §3.5
#
# Input (stdin): SessionStart hook JSON payload, e.g. {"source":"startup"}
# Output (stdout): JSON with hookSpecificOutput.additionalContext, or nothing.
#
# Behaviour:
#   - source != "startup" → exit 0 silently (no re-bootstrap on resume/clear/compact)
#   - .no-inbox-watch exists → exit 0 silently (total opt-out)
#   - coordinator identity unresolved → exit 0 silently
#   - source = "startup" + identity resolved + no opt-out → emit bootstrap nudge JSON
#
# Identity resolution (same chain as inbox-watch.sh):
#   1. CLAUDE_AGENT_NAME env var
#   2. STRAWBERRY_AGENT env var
#   3. No further fallback — exit 0 silently if neither is set.
#      The .claude/settings.json .agent fallback is intentionally removed (INV-4/INV-6).
#
# POSIX-portable bash (Rule 10).
set -eu

# ────────────────────────────────────────────────────────────────
# Read stdin and extract source
# ────────────────────────────────────────────────────────────────

payload="$(cat)"
source_val=""

if command -v jq >/dev/null 2>&1; then
  source_val="$(printf '%s' "$payload" | jq -r '.source // empty' 2>/dev/null || true)"
else
  # Fallback: simple grep for "source":"..."
  source_val="$(printf '%s' "$payload" | grep -o '"source":"[^"]*"' | sed 's/"source":"//;s/"//' 2>/dev/null || true)"
fi

# Only bootstrap on a fresh session start
if [ "$source_val" != "startup" ]; then
  exit 0
fi

# ────────────────────────────────────────────────────────────────
# Resolve repo root
# ────────────────────────────────────────────────────────────────

if [ -n "${REPO_ROOT:-}" ]; then
  REPO="$REPO_ROOT"
else
  REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || REPO="$(pwd)"
fi

# ────────────────────────────────────────────────────────────────
# Opt-out check
# ────────────────────────────────────────────────────────────────

if [ -f "$REPO/.no-inbox-watch" ]; then
  exit 0
fi

# ────────────────────────────────────────────────────────────────
# Coordinator identity resolution
# ────────────────────────────────────────────────────────────────

coord=""

if [ -n "${CLAUDE_AGENT_NAME:-}" ]; then
  coord="$(printf '%s' "$CLAUDE_AGENT_NAME" | tr '[:upper:]' '[:lower:]')"
elif [ -n "${STRAWBERRY_AGENT:-}" ]; then
  coord="$(printf '%s' "$STRAWBERRY_AGENT" | tr '[:upper:]' '[:lower:]')"
fi

# No identity resolved — exit cleanly (no .agent fallback per INV-4/INV-6)
if [ -z "$coord" ]; then
  exit 0
fi

# ────────────────────────────────────────────────────────────────
# Emit bootstrap nudge as JSON
# ────────────────────────────────────────────────────────────────

# Capitalise coordinator name for display (e.g. evelynn -> Evelynn)
display_name="$(printf '%s' "$coord" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"

context="FIRST ACTION REQUIRED: invoke the Monitor tool now with command: bash scripts/hooks/inbox-watch.sh — description: Watch ${display_name}'s inbox. This is your inbox watcher. Arm it before doing anything else. Events surface as INBOX: <file> lines; when one appears, run /check-inbox."

# Emit valid JSON
if command -v jq >/dev/null 2>&1; then
  jq -cn \
    --arg ctx "$context" \
    '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":$ctx}}'
else
  # jq not available — construct JSON manually (context text is safe: no quotes or backslashes)
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' \
    "$(printf '%s' "$context" | sed 's/\\/\\\\/g;s/"/\\"/g;s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')"
fi

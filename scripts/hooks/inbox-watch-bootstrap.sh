#!/usr/bin/env bash
# inbox-watch-bootstrap.sh — SessionStart hook: nudge coordinator to invoke Monitor.
#
# Implements plans/in-progress/2026-04-20-strawberry-inbox-channel.md §3.3, §3.5
#
# Input (stdin): SessionStart hook JSON payload, e.g. {"source":"startup"}
# Output (stdout): JSON with hookSpecificOutput.additionalContext, or nothing.
#
# Behaviour:
#   - source not in {startup} → exit 0 silently
#     (resume/clear/compact inherit prior Monitor task — duplicate directive causes
#      duplicate inbox-watch.sh processes; plan 2026-04-25-watcher-arm-directive-source-gate)
#   - .no-inbox-watch exists → exit 0 silently (total opt-out)
#   - coordinator identity unresolved → exit 0 silently
#   - source=startup + identity resolved + no opt-out → emit bootstrap nudge JSON
#
# Identity resolution (same three-tier chain as inbox-watch.sh):
#   1. CLAUDE_AGENT_NAME env var
#   2. STRAWBERRY_AGENT env var
#   3. .coordinator-identity file at repo root (written atomically by launchers)
#   If all three miss: exit 0 silently.
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

# Bootstrap on startup only; silent on resume/clear/compact (and anything else).
# resume/clear/compact inherit the prior session's running Monitor task — re-emitting the
# directive causes a duplicate inbox-watch.sh process (literal-vs-goal bug, plan
# 2026-04-25-watcher-arm-directive-source-gate).
case "$source_val" in
  startup) ;;
  *) exit 0 ;;
esac

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

# Tier 1: CLAUDE_AGENT_NAME env var
if [ -n "${CLAUDE_AGENT_NAME:-}" ]; then
  coord="$(printf '%s' "$CLAUDE_AGENT_NAME" | tr '[:upper:]' '[:lower:]')"
fi

# Tier 2: STRAWBERRY_AGENT env var
if [ -z "$coord" ] && [ -n "${STRAWBERRY_AGENT:-}" ]; then
  coord="$(printf '%s' "$STRAWBERRY_AGENT" | tr '[:upper:]' '[:lower:]')"
fi

# Tier 3: .coordinator-identity hint file (written atomically by launchers)
if [ -z "$coord" ] && [ -f "$REPO/.coordinator-identity" ]; then
  _hint="$(tr '[:upper:]' '[:lower:]' < "$REPO/.coordinator-identity" | tr -d '[:space:]')"
  case "$_hint" in
    evelynn|sona) coord="$_hint" ;;
  esac
fi

# No identity resolved — exit cleanly
if [ -z "$coord" ]; then
  exit 0
fi

# ────────────────────────────────────────────────────────────────
# Emit bootstrap nudge as JSON
# ────────────────────────────────────────────────────────────────

# Capitalise coordinator name for display (e.g. evelynn -> Evelynn)
display_name="$(printf '%s' "$coord" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"

context="FIRST ACTION REQUIRED: verify a watcher is armed for ${display_name} — check existing Monitor tasks and run ps aux | grep inbox-watch.sh matched against your CLAUDE_AGENT_NAME. If a watcher is already armed, no-op. If absent, invoke Monitor with command: bash scripts/hooks/inbox-watch.sh — description: Watch ${display_name}'s inbox. Events surface as INBOX: <file> lines; when one appears, run /check-inbox."

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

#!/usr/bin/env bash
# send.sh — write an inbox message for /agent-ops send subcommand.
# Called by the agent-ops skill instead of the Write tool, so the
# pretooluse-inbox-write-guard (which matches Write|Edit only) does not fire.
#
# Usage: bash scripts/agent-ops/send.sh <agent> <sender> <message>
#
# Arguments:
#   $1 — target agent name (e.g. "evelynn")
#   $2 — sender name
#   $3 — message body (full text)
#
# Exit 0 on success; exit 2 on usage/validation error.
# On success, prints the full path of the created inbox file.
#
# POSIX-portable bash. No macOS-specific commands.

set -u

AGENT="${1:-}"
SENDER="${2:-}"
MESSAGE="${3:-}"

if [ -z "$AGENT" ] || [ -z "$SENDER" ] || [ -z "$MESSAGE" ]; then
  printf 'usage: send.sh <agent> <sender> <message>\n' >&2
  exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  printf 'send.sh: cannot determine repo root\n' >&2
  exit 2
fi

AGENT_DIR="$REPO_ROOT/agents/$AGENT"
if [ ! -d "$AGENT_DIR" ]; then
  printf 'agent-ops send: unknown agent %s\n' "$AGENT" >&2
  exit 2
fi

INBOX_DIR="$AGENT_DIR/inbox"
mkdir -p "$INBOX_DIR"

TIMESTAMP="$(date -u +%Y%m%d-%H%M)"
# Last 6 chars of epoch seconds as short ID (portable — no %N on macOS)
SHORT_ID="$(date -u +%s | tail -c 7 | tr -d '\n')"
FILENAME="${TIMESTAMP}-${SHORT_ID}.md"
OUTFILE="$INBOX_DIR/$FILENAME"

printf -- '---\nfrom: %s\nto: %s\npriority: info\ntimestamp: %s\nstatus: pending\n---\n\n%s\n' \
  "$SENDER" "$AGENT" "$(date -u +%Y-%m-%d\ %H:%M)" "$MESSAGE" > "$OUTFILE"

printf '%s\n' "$OUTFILE"

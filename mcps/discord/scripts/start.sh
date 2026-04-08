#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TOKEN_FILE="$REPO_ROOT/secrets/discord-bot-token.txt"

if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "discord-mcp: missing $TOKEN_FILE" >&2
  exit 1
fi

TOKEN="$(tr -d '\n\r ' < "$TOKEN_FILE")"

if [[ -z "$TOKEN" ]]; then
  echo "discord-mcp: token file is empty" >&2
  exit 1
fi

exec npx -y mcp-discord --config "$TOKEN"

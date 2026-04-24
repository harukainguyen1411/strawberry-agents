#!/usr/bin/env bash
set -euo pipefail

TOKEN_FILE="/Users/duongntd99/Documents/Personal/strawberry-agents/secrets/slack-bot-token.txt"
[ -f "$TOKEN_FILE" ] || { echo "slack-mcp: missing $TOKEN_FILE" >&2; exit 1; }

BOT_TOKEN="$(grep '^bot_token=' "$TOKEN_FILE"  | head -1 | cut -d= -f2-)"
USER_TOKEN="$(grep '^user_token=' "$TOKEN_FILE" | head -1 | cut -d= -f2-)"
[ -n "$BOT_TOKEN"  ] || { echo "slack-mcp: bot_token missing"  >&2; exit 1; }
[ -n "$USER_TOKEN" ] || { echo "slack-mcp: user_token missing" >&2; exit 1; }

cd "$(dirname "$0")/.."
[ -x "./node_modules/.bin/tsx" ] || npm install --silent
exec env \
  SLACK_BOT_TOKEN="$BOT_TOKEN" \
  SLACK_USER_TOKEN="$USER_TOKEN" \
  SLACK_TEAM_ID="${SLACK_TEAM_ID:-T18MLBHC5}" \
  DUONG_USER_ID="${DUONG_USER_ID:-U03KDE6SS9J}" \
  ./node_modules/.bin/tsx src/server.ts

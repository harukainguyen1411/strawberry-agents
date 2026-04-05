#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Evelynn MCP server must run as Duongntd (owner), not the agent account.
# Unset agent token to ensure git/gh operations use the owner's default auth.
unset GH_TOKEN GITHUB_TOKEN

# Load environment variables
if [[ -f "$DIR/.env" ]]; then
  set -a
  source "$DIR/.env"
  set +a
fi

# Load Telegram bot token from secrets if not already set
SECRETS_DIR="$(cd "$DIR/../.." && pwd)/secrets"
if [[ -z "${TELEGRAM_BOT_TOKEN:-}" && -f "$SECRETS_DIR/telegram-bot-token" ]]; then
  export TELEGRAM_BOT_TOKEN="$(cat "$SECRETS_DIR/telegram-bot-token")"
fi

# Create venv if missing
if [[ ! -d "$DIR/.venv" ]]; then
  command -v uv >/dev/null 2>&1 || { echo "Error: uv is required but not found on PATH" >&2; exit 1; }
  echo "Creating Python venv at $DIR/.venv ..." >&2
  uv venv "$DIR/.venv"
  uv pip install --python "$DIR/.venv/bin/python" mcp firebase-admin
fi

exec "$DIR/.venv/bin/python" "$DIR/server.py"

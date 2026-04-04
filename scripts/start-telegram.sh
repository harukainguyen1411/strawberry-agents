#!/usr/bin/env bash
# Start the Telegram relay in the background
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source env vars if .env exists
if [ -f "$SCRIPT_DIR/../.env" ]; then
  set -a
  source "$SCRIPT_DIR/../.env"
  set +a
fi

# Check required vars
: "${TELEGRAM_BOT_TOKEN:?Set TELEGRAM_BOT_TOKEN in .env or environment}"
: "${TELEGRAM_CHAT_ID:?Set TELEGRAM_CHAT_ID in .env or environment}"

echo "Starting Telegram bridge..."
exec "$SCRIPT_DIR/telegram-bridge.sh"

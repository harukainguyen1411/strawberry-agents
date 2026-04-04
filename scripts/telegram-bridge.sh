#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:?Missing TELEGRAM_BOT_TOKEN}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:?Missing TELEGRAM_CHAT_ID}"
STRAWBERRY_DIR="${STRAWBERRY_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
TELEGRAM_API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"

# Offset file persists across restarts so we don't re-process old messages
OFFSET_FILE="${STRAWBERRY_DIR}/.telegram-offset"
POLL_TIMEOUT=30       # Telegram long-poll timeout in seconds
PROCESS_INTERVAL=5    # seconds between processing cycles
MAX_TURNS=15          # max claude turns per message

# --- Offset management ---

read_offset() {
  if [ -f "$OFFSET_FILE" ]; then
    cat "$OFFSET_FILE"
  else
    echo "0"
  fi
}

save_offset() {
  echo "$1" > "$OFFSET_FILE"
}

# --- Message processing ---

process_message() {
  local text="$1"

  # Write prompt to temp file to avoid shell escaping issues
  local prompt_file
  prompt_file=$(mktemp /tmp/telegram-prompt-XXXXXX.txt)

  jq -n --arg text "$text" -r \
    '"Duong sent you a message on Telegram:\n\n\($text)\n\nRespond to Duong using the telegram_send_message tool. Be yourself (Evelynn). Keep responses concise and helpful. If Duong is asking you to do something that requires agent tools beyond what you have here, let him know you will handle it in your main session and acknowledge his request."' \
    > "$prompt_file"

  local result
  result=$(cd "$STRAWBERRY_DIR" && timeout 300 claude -p "$(cat "$prompt_file")" \
    --max-turns "$MAX_TURNS" \
    --output-format text \
    --allowedTools \
      mcp__evelynn__telegram_send_message \
      Read Glob Grep \
    < /dev/null 2>&1) || {
    echo "[telegram-bridge] claude invocation failed: ${result:0:200}"
    # Send error notification to Duong
    curl -s -X POST "${TELEGRAM_API}/sendMessage" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg chat_id "$TELEGRAM_CHAT_ID" \
        --arg text "I had trouble processing your message. I'll catch up in my next session." \
        '{chat_id: $chat_id, text: $text}')" > /dev/null
  }

  rm -f "$prompt_file"
}

# --- Polling ---

poll_and_process() {
  local offset
  offset=$(read_offset)

  # Build URL params
  local params="timeout=${POLL_TIMEOUT}&allowed_updates=%5B%22message%22%5D"
  if [ "$offset" != "0" ]; then
    params="${params}&offset=${offset}"
  fi

  # Long-poll Telegram
  local response
  response=$(curl -s -m $((POLL_TIMEOUT + 10)) \
    "${TELEGRAM_API}/getUpdates?${params}") || {
    echo "[telegram-bridge] curl failed, retrying in ${PROCESS_INTERVAL}s"
    return 0
  }

  # Check API response
  local ok
  ok=$(echo "$response" | jq -r '.ok // false')
  if [ "$ok" != "true" ]; then
    echo "[telegram-bridge] API error: $response"
    return 0
  fi

  # Process each update
  local updates
  updates=$(echo "$response" | jq -c '.result[]')

  echo "$updates" | while IFS= read -r update; do
    [ -z "$update" ] && continue

    local update_id chat_id text
    update_id=$(echo "$update" | jq -r '.update_id')
    chat_id=$(echo "$update" | jq -r '.message.chat.id // empty')
    text=$(echo "$update" | jq -r '.message.text // empty')

    # Update offset regardless (skip non-matching messages)
    save_offset "$((update_id + 1))"

    # Only process messages from Duong's chat
    if [ "$chat_id" != "$TELEGRAM_CHAT_ID" ]; then
      echo "[telegram-bridge] Ignoring message from chat $chat_id"
      continue
    fi

    # Skip empty messages (photos, stickers, etc.)
    if [ -z "$text" ]; then
      echo "[telegram-bridge] Skipping non-text message"
      continue
    fi

    echo "[telegram-bridge] Processing message: ${text:0:80}..."
    process_message "$text"
  done
}

# --- Main loop ---

echo "[telegram-bridge] Starting Telegram relay for Evelynn"
echo "[telegram-bridge] Chat ID: $TELEGRAM_CHAT_ID"
echo "[telegram-bridge] Polling with ${POLL_TIMEOUT}s long-poll timeout"

# Flush old updates on first start if no offset exists
if [ ! -f "$OFFSET_FILE" ]; then
  echo "[telegram-bridge] First run — flushing old updates"
  curl -s "${TELEGRAM_API}/getUpdates?offset=-1" > /dev/null
  save_offset "0"
fi

while true; do
  poll_and_process
  sleep "$PROCESS_INTERVAL"
done

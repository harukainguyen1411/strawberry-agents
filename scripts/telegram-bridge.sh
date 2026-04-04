#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:?Missing TELEGRAM_BOT_TOKEN}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:?Missing TELEGRAM_CHAT_ID}"
STRAWBERRY_DIR="${STRAWBERRY_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
TELEGRAM_API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"
AGENTS_DIR="${STRAWBERRY_DIR}/agents"
EVELYNN_INBOX="${AGENTS_DIR}/evelynn/inbox"

OFFSET_FILE="${STRAWBERRY_DIR}/.telegram-offset"
POLL_TIMEOUT=30

# --- Signal trap ---
cleanup() {
  echo "[telegram-bridge] Shutting down"
  exit 0
}
trap cleanup SIGTERM SIGINT

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

# --- iTerm integration ---

find_evelynn_window_id() {
  osascript -e '
    tell application "iTerm"
      repeat with w in windows
        set wName to name of w
        if wName contains "evelynn" or wName contains "Evelynn" then
          return id of w
        end if
      end repeat
      return "not_found"
    end tell
  ' 2>/dev/null || echo "not_found"
}

send_to_iterm() {
  local window_id="$1"
  local text="$2"
  osascript -e "
    tell application \"iTerm\"
      repeat with w in windows
        if id of w is ${window_id} then
          tell current session of current tab of w
            write text \"${text}\"
          end tell
          return \"ok\"
        end if
      end repeat
      return \"not found\"
    end tell
  " 2>/dev/null || true
}

# --- Message delivery ---

deliver_message() {
  local text="$1"
  local timestamp
  timestamp=$(date +"%Y%m%d-%H%M")
  local ts_human
  ts_human=$(date +"%Y-%m-%d %H:%M")

  # Write inbox file
  local filename="${timestamp}-telegram-duong.md"
  local filepath="${EVELYNN_INBOX}/${filename}"

  mkdir -p "$EVELYNN_INBOX"

  printf '%s\n' "---" \
    "from: duong-telegram" \
    "to: evelynn" \
    "priority: info" \
    "timestamp: ${ts_human}" \
    "status: pending" \
    "---" \
    "" \
    "${text}" > "$filepath"

  echo "[telegram-bridge] Wrote inbox: $filename"

  # Find Evelynn's iTerm window and notify
  local window_id
  window_id=$(find_evelynn_window_id)

  if [ "$window_id" = "not_found" ]; then
    echo "[telegram-bridge] WARNING: Evelynn iTerm window not found. Inbox file written but not delivered."
    curl -s -X POST "${TELEGRAM_API}/sendMessage" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg chat_id "$TELEGRAM_CHAT_ID" \
        --arg text "Message received but Evelynn isn't running right now. It'll be waiting in her inbox." \
        '{chat_id: $chat_id, text: $text}')" > /dev/null
    return
  fi

  send_to_iterm "$window_id" "[inbox] ${filepath}"
  echo "[telegram-bridge] Notified Evelynn via iTerm (window $window_id)"
}

# --- Polling ---

poll_and_process() {
  local offset
  offset=$(read_offset)

  local params="timeout=${POLL_TIMEOUT}&allowed_updates=%5B%22message%22%5D"
  if [ "$offset" != "0" ]; then
    params="${params}&offset=${offset}"
  fi

  local response
  response=$(curl -s -m $((POLL_TIMEOUT + 10)) \
    "${TELEGRAM_API}/getUpdates?${params}") || {
    echo "[telegram-bridge] curl failed, retrying..."
    return 0
  }

  local ok
  ok=$(echo "$response" | jq -r '.ok // false')
  if [ "$ok" != "true" ]; then
    echo "[telegram-bridge] API error: $response"
    return 0
  fi

  local count
  count=$(echo "$response" | jq '.result | length')

  if [ "$count" = "0" ]; then
    return 0
  fi

  local updates
  updates=$(echo "$response" | jq -c '.result[]' 2>/dev/null) || true

  [ -z "$updates" ] && return 0

  while IFS= read -r update; do
    [ -z "$update" ] && continue

    local update_id chat_id text
    update_id=$(echo "$update" | jq -r '.update_id')
    chat_id=$(echo "$update" | jq -r '.message.chat.id // empty')
    text=$(echo "$update" | jq -r '.message.text // empty')

    save_offset "$((update_id + 1))"

    if [ "$chat_id" != "$TELEGRAM_CHAT_ID" ]; then
      echo "[telegram-bridge] Ignoring message from chat $chat_id"
      continue
    fi

    if [ -z "$text" ]; then
      echo "[telegram-bridge] Skipping non-text message"
      continue
    fi

    echo "[telegram-bridge] Message from Duong: ${text:0:80}..."
    deliver_message "$text"
  done <<< "$updates"
}

# --- Main loop ---

echo "[telegram-bridge] Starting Telegram relay (inbox mode)"
echo "[telegram-bridge] Chat ID: $TELEGRAM_CHAT_ID"
echo "[telegram-bridge] Long-poll timeout: ${POLL_TIMEOUT}s"

# Flush old updates on first start
if [ ! -f "$OFFSET_FILE" ]; then
  echo "[telegram-bridge] First run — flushing old updates"
  flush_response=$(curl -s "${TELEGRAM_API}/getUpdates?offset=-1") || true
  last_id=$(echo "$flush_response" | jq -r '.result[-1].update_id // empty' 2>/dev/null) || true
  if [ -n "$last_id" ]; then
    save_offset "$((last_id + 1))"
    echo "[telegram-bridge] Flushed up to update_id $last_id"
  else
    save_offset "0"
  fi
fi

while true; do
  poll_and_process
done

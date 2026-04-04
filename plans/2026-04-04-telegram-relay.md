---
status: revision-2
owner: rakan
implementer: bard
---

# Telegram Relay — Two-Way Messaging for Evelynn (Revised)

## Goal

Real-time two-way chat between Duong (Telegram) and Evelynn. Messages should feel instant — no manual polling, no cold-start sessions.

## What Changed from v1

v1 spawned a new `claude -p` session per message. This was slow (cold start), had no context between messages, and didn't feel like chat.

**v2 delivers messages to Evelynn's already-running iTerm session via the inbox system** — the same mechanism agent-manager uses. Evelynn is always running when the Mac is on. The bridge is just a Telegram→inbox translator.

## Architecture

```
Duong (Telegram app)
    ↓ sends message
Telegram Bot API
    ↓ getUpdates (long poll, 30s timeout — near-instant delivery)
scripts/telegram-bridge.sh (local Mac, runs in background)
    ↓ writes inbox file + sends iTerm notification
Evelynn (existing iTerm session)
    ↓ reads inbox, processes message
    ↓ calls telegram_send_message via MCP tool
Telegram Bot API → Duong sees response
```

**Key difference:** No `claude -p`. No new sessions. The bridge writes an inbox file and types `[inbox] /path/to/file.md` into Evelynn's iTerm window — exactly how `message_agent` works.

## Flow (step by step)

1. `telegram-bridge.sh` starts and long-polls Telegram (`getUpdates?timeout=30`)
2. Duong sends a message on Telegram
3. Telegram returns the update immediately (long-poll resolves)
4. Bridge writes an inbox file to `agents/evelynn/inbox/`:
   ```
   ---
   from: duong-telegram
   to: evelynn
   priority: info
   timestamp: 2026-04-04 14:30
   status: pending
   ---

   Hey Evelynn, what's on my calendar today?
   ```
5. Bridge finds Evelynn's iTerm window (via AppleScript, same as `send_to_iterm_window`)
6. Bridge types into the window: `[inbox] /path/to/agents/evelynn/inbox/<file>.md`
7. Evelynn reads the inbox file, processes the request, calls `telegram_send_message`
8. Duong sees the response in Telegram
9. Bridge loops back to step 1 (next long-poll)

## Implementation Spec

### File: `scripts/telegram-bridge.sh`

```bash
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
# Find Evelynn's iTerm window ID and send text to it.
# Uses the same AppleScript pattern as shared/helpers.py send_to_iterm_window.

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

  # Use printf to avoid shell escaping issues with message content
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
    # Fallback: send Telegram ack that message was queued
    curl -s -X POST "${TELEGRAM_API}/sendMessage" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg chat_id "$TELEGRAM_CHAT_ID" \
        --arg text "Message received but Evelynn isn't running right now. It'll be waiting in her inbox." \
        '{chat_id: $chat_id, text: $text}')" > /dev/null
    return
  fi

  # Type the inbox notification into Evelynn's window
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

  echo "$response" | jq -c '.result[]' | while IFS= read -r update; do
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
  done
}

# --- Main loop ---

echo "[telegram-bridge] Starting Telegram relay (inbox mode)"
echo "[telegram-bridge] Chat ID: $TELEGRAM_CHAT_ID"
echo "[telegram-bridge] Long-poll timeout: ${POLL_TIMEOUT}s"

# Flush old updates on first start
if [ ! -f "$OFFSET_FILE" ]; then
  echo "[telegram-bridge] First run — flushing old updates"
  curl -s "${TELEGRAM_API}/getUpdates?offset=-1" > /dev/null
  save_offset "0"
fi

while true; do
  poll_and_process
done
```

### File: `scripts/start-telegram.sh` (unchanged from v1)

Same convenience wrapper — sources `.env`, validates vars, exec's the bridge.

### Changes from v1

| Aspect | v1 | v2 |
|--------|----|----|
| Message delivery | `claude -p` per message (cold start) | Inbox file + iTerm notification (instant) |
| Evelynn session | New session per message | Existing running session |
| Context | None (each message isolated) | Full (Evelynn has her conversation history) |
| Latency | 5-30s (claude startup) | <1s (file write + AppleScript) |
| Sleep between polls | 5s | None (long-poll blocks until message arrives) |
| Allowed tools | Limited subset | All (Evelynn's full session) |
| Dependencies | `claude` CLI, `curl`, `jq` | `curl`, `jq`, `osascript` |

### Error handling

- **curl failure**: Log, retry on next poll cycle
- **Evelynn not running**: Write inbox file anyway (persisted), send Telegram ack that message is queued
- **Non-text messages**: Skip
- **Other chats**: Skip (chat_id filter)
- **Offset persistence**: File-based, survives restarts

### Requirement

Evelynn must be running in an iTerm session for real-time delivery. If she's not running, messages are still saved to inbox (they'll be there when she starts), and Duong gets a Telegram notification that Evelynn isn't online.

### .gitignore

```
.telegram-offset
```

## Testing

1. Start Evelynn in iTerm
2. Start the bridge: `./scripts/start-telegram.sh`
3. Send "test" from Telegram
4. Verify: inbox file appears in `agents/evelynn/inbox/`, Evelynn's iTerm window shows the `[inbox]` notification, Evelynn reads and responds via `telegram_send_message`
5. Kill Evelynn → send message → verify fallback Telegram ack
6. Restart bridge → verify no duplicate messages (offset file)

---
status: approved
owner: rakan
implementer: bard
---

# Telegram Relay — Two-Way Messaging for Evelynn

## Goal

Let Duong message Evelynn from Telegram and get responses back automatically. A background script polls Telegram, processes messages, and invokes Evelynn to respond — same pattern as the Discord relay but simpler.

## Architecture Overview

```
Duong (Telegram app)
    ↓ sends message
Telegram Bot API
    ↓ getUpdates (long poll)
scripts/telegram-bridge.sh (local Mac, runs in background)
    ↓ parses message, invokes claude -p as Evelynn
Evelynn (claude -p session)
    ↓ processes request, calls telegram_send_message
mcps/evelynn/server.py → Telegram Bot API → Duong sees response
```

Single script, single process. No file-based event queue. No triage pass. No separate poller.

## Existing Components (already built, do not modify)

### `mcps/evelynn/server.py` — Evelynn MCP server

Contains two Telegram tools:

- `telegram_send_message(sender, message, parse_mode?)` — sends a message to Duong
- `telegram_poll_messages(sender)` — polls for new messages (exists but won't be used by the bridge; the bridge polls directly via curl)

Env vars already configured in `.mcp.json`:
- `TELEGRAM_BOT_TOKEN` — bot token from @BotFather
- `TELEGRAM_CHAT_ID` — Duong's chat ID (`7922315245`)

### `scripts/discord-bridge.sh` — Reference implementation

The Discord bridge is the pattern to follow. Key patterns to reuse:
- `set -euo pipefail`
- Rate limiting between invocations
- `claude -p` invocation with `--allowedTools`
- Processed event archiving
- Main loop with polling fallback

## Implementation Spec

### File: `scripts/telegram-bridge.sh`

This is the **only new file** needed.

#### Configuration (top of script)

```bash
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
```

#### Offset management

```bash
# Read persisted offset (0 if file doesn't exist)
read_offset() {
  if [ -f "$OFFSET_FILE" ]; then
    cat "$OFFSET_FILE"
  else
    echo "0"
  fi
}

# Write offset to disk
save_offset() {
  echo "$1" > "$OFFSET_FILE"
}
```

**Why file-based offset instead of in-memory?** So restarts don't re-process old messages. The offset file is a single integer.

#### Polling loop

```bash
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
```

#### Message processing

```bash
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
```

#### Main loop

```bash
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
```

#### Environment variables

| Var | Required | Source | Description |
|-----|----------|--------|-------------|
| `TELEGRAM_BOT_TOKEN` | Yes | `.env` or export | Bot token from @BotFather |
| `TELEGRAM_CHAT_ID` | Yes | `.env` or export | Duong's chat ID |
| `STRAWBERRY_DIR` | No | Auto-detected | Path to strawberry repo root |

#### Error handling

- **curl failure**: Log and retry next cycle. No crash.
- **API error**: Log and retry. No crash.
- **claude -p failure**: Send fallback Telegram message to Duong, log error, continue.
- **Non-text messages** (photos, stickers): Skip silently.
- **Messages from other chats**: Skip (chat_id filter).
- **Script crash**: Offset file ensures no re-processing on restart.

#### Allowed tools for the claude -p session

```
mcp__evelynn__telegram_send_message   — reply to Duong
Read                                   — read files for context
Glob                                   — find files
Grep                                   — search code
```

**Not included:** Write, Edit, Bash, Agent, agent-manager tools. The Telegram bridge Evelynn session is read-only + reply-only. If Duong asks for something that needs agent tools, Evelynn should acknowledge and say she'll handle it in her main session.

**Rationale:** Keep the bridge lightweight and safe. No code changes, no agent launches from a background process. The bridge is a notification + quick-answer channel, not a full agent session.

### File: `scripts/start-telegram.sh` (convenience wrapper)

```bash
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
```

### File: `.env` additions

Add to the project `.env` (not committed to git):

```
TELEGRAM_BOT_TOKEN=8742144449:AAHTdIVXXOyacKMEtpv-2mJlDX2t7wtUdM8
TELEGRAM_CHAT_ID=7922315245
```

### `.gitignore` additions

```
.telegram-offset
```

## Integration with existing system

- **No changes to `mcps/evelynn/server.py`** — already has both tools
- **No changes to `.mcp.json`** — already has Telegram env vars
- **No changes to agent-manager** — bridge doesn't use agent tools
- **Offset file** (`.telegram-offset`) lives at repo root, gitignored

## How to run

```bash
# Option 1: Direct
export TELEGRAM_BOT_TOKEN="..." TELEGRAM_CHAT_ID="..."
./scripts/telegram-bridge.sh

# Option 2: Via wrapper (reads .env)
./scripts/start-telegram.sh

# Option 3: Background
nohup ./scripts/start-telegram.sh > /tmp/telegram-bridge.log 2>&1 &
```

Future: add a launchd plist for auto-start on login (not in scope for v1).

## Testing

1. Start the bridge: `./scripts/start-telegram.sh`
2. Send a message to the bot from Telegram: "Hey Evelynn, what time is it?"
3. Verify:
   - Bridge logs show the message was received
   - claude -p is invoked
   - Evelynn responds via `telegram_send_message`
   - Duong sees the response in Telegram
4. Kill and restart the bridge — verify no duplicate processing (offset file)
5. Send a non-text message (photo) — verify it's skipped

## Files to create

| File | Action |
|------|--------|
| `scripts/telegram-bridge.sh` | Create (make executable) |
| `scripts/start-telegram.sh` | Create (make executable) |
| `.gitignore` | Append `.telegram-offset` |

## Dependencies

- `curl` (pre-installed on macOS)
- `jq` (pre-installed or `brew install jq`)
- `claude` CLI (already available)
- No npm packages, no Python packages, no new MCP servers

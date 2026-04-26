# Telegram Relay

Two-way messaging between Duong (Telegram) and Evelynn. Simpler than Discord — single script, no event queue, no triage pass.

**Status:** Planned — spec approved, MCP tools already built, bridge script not yet implemented.

## Architecture

```
Duong (Telegram app)
    ↓ sends message
Telegram Bot API
    ↓ getUpdates (long poll)
scripts/telegram-bridge.sh (local Mac, runs in background)
    ↓ parses message, invokes claude -p as Evelynn
Evelynn (claude -p session)
    ↓ calls telegram_send_message
mcps/evelynn/server.py → Telegram Bot API → Duong sees response
```

## Components

| Component | Location | Status |
|---|---|---|
| `telegram_send_message` tool | `mcps/evelynn/server.py` | Built |
| `telegram_poll_messages` tool | `mcps/evelynn/server.py` | Built |
| `telegram-bridge.sh` | `scripts/telegram-bridge.sh` | Not yet created |
| `start-telegram.sh` | `scripts/start-telegram.sh` | Not yet created |

## Key Design Decisions

- **File-based offset** — persists across restarts so messages aren't reprocessed (`.telegram-offset`, gitignored)
- **Read-only Evelynn session** — bridge `claude -p` only gets: `telegram_send_message`, `Read`, `Glob`, `Grep`. No Write, Edit, Bash, or agent tools.
- **Single process** — no file queue, no separate poller, no triage pass
- **Long polling** — 30s Telegram long-poll timeout, 5s between processing cycles
- **Max 15 turns** per message, 300s timeout

## Allowed Tools (bridge session)

```
mcp__evelynn__telegram_send_message   — reply to Duong
Read                                   — read files for context
Glob                                   — find files
Grep                                   — search code
```

## Error Handling

- curl/API failures: log and retry next cycle
- claude -p failure: send fallback Telegram message, continue
- Non-text messages: skip
- Messages from other chats: skip (chat_id filter)

## Environment Variables

| Var | Required | Description |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | Yes | Bot token from @BotFather |
| `TELEGRAM_CHAT_ID` | Yes | Duong's chat ID (`7922315245`) |
| `STRAWBERRY_DIR` | No | Auto-detected from script location |

Full spec: `plans/2026-04-04-telegram-relay.md`

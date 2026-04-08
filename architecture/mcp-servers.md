# MCP Servers

One active MCP server, Python (FastMCP), configured in `.mcp.json`. The `agent-manager` MCP server is archived as of Phase 1 of the MCP restructure — see `mcps/agent-manager/README.md`.

## evelynn

**Location:** `mcps/evelynn/server.py`
**Start script:** `mcps/evelynn/scripts/start.sh`

Evelynn-restricted tools. Sender enforcement is honor-system — the server checks `sender == "evelynn"` but MCP has no built-in caller identity. Real enforcement: only register this server in Evelynn's session.

### Tools

| Tool | Access | Purpose |
|---|---|---|
| `end_all_sessions` | Evelynn only | End all agent sessions |
| `commit_agent_state_to_main` | Evelynn only | Commit agent memory/learnings/journals to main and push |
| `telegram_send_message` | Evelynn only | Send message to Duong on Telegram |
| `telegram_poll_messages` | Evelynn only | Poll for new Telegram messages |

### Environment Variables

| Var | Purpose |
|---|---|
| `AGENTS_PATH` | Path to `agents/` directory |
| `WORKSPACE_PATH` | Path to repo root |
| `ITERM_PROFILES_PATH` | Path to iTerm2 dynamic profiles |
| `TELEGRAM_BOT_TOKEN` | Bot token from @BotFather |
| `TELEGRAM_CHAT_ID` | Duong's Telegram chat ID |

## agent-manager (archived — Phase 1)

**Status:** Archived. Source preserved at `mcps/agent-manager/` per Phase 1 plan (D2). Deletion scheduled for Phase 3.

**Replacement surface (Phase 1):**

| Old tool | New surface |
|---|---|
| `list_agents` | `/agent-ops list` |
| `create_agent` | `/agent-ops new <name>` |
| `message_agent` | `/agent-ops send <agent> <message>` |
| `launch_agent` | macOS: `scripts/mac/launch-agent-iterm.sh`. Windows: Task subagent. |
| Turn-based conversation tools | Deferred to Phase 2. Use `/agent-ops send` + Evelynn escalation for now. |
| `delegate_task` / `complete_task` / `check_delegations` | Tracked via `agents/delegations/*.json` directly. Phase 2 will add `/agent-ops delegate` if needed. |
| `report_context_health` | Deferred to Phase 2. Report conversationally in turn reply to Evelynn. |

See `plans/approved/2026-04-09-mcp-restructure-phase-1-detailed.md` for the full migration spec.

## Shared Helpers

`mcps/shared/helpers.py` — common utilities used by both servers: agent scanning, iTerm window management, git operations, registry read/write, status management.

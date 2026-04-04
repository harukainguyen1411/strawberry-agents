# MCP Servers

Two MCP servers, both Python (FastMCP), configured in `.mcp.json`.

## agent-manager

**Location:** `mcps/agent-manager/server.py`
**Start script:** `mcps/agent-manager/scripts/start.sh`

General-purpose agent management. Available to all agents.

### Tools

| Tool | Purpose |
|---|---|
| `list_agents` | List available agents |
| `get_agent` | Look up agent details |
| `create_agent` | Create a new agent |
| `launch_agent` | Spin up agent in iTerm window |
| `restart_agents` | Restart agent sessions |
| `agent_status` | Check agent running status |
| `message_agent` | Send inbox message (fire-and-forget) |
| `check_inbox_status` | Check for pending inbox messages |
| `acknowledge_message` | Mark inbox message as read |
| `start_turn_conversation` | Start multi-agent conversation |
| `speak_in_turn` | Post message in conversation |
| `pass_turn` | Yield turn |
| `end_turn_conversation` | Propose ending conversation |
| `read_new_messages` | Read new messages since cursor |
| `get_turn_status` | Check conversation status |
| `invite_to_conversation` | Add agent to conversation |
| `escalate_conversation` | Escalate to Evelynn |
| `resolve_escalation` | Resolve escalation |

### Environment Variables

| Var | Purpose |
|---|---|
| `AGENTS_PATH` | Path to `agents/` directory |
| `WORKSPACE_PATH` | Path to repo root |
| `ITERM_PROFILES_PATH` | Path to iTerm2 dynamic profiles |
| `OPS_PATH` | (Optional) Path for runtime state; defaults to in-repo paths |

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

Same as agent-manager, plus:

| Var | Purpose |
|---|---|
| `TELEGRAM_BOT_TOKEN` | Bot token from @BotFather |
| `TELEGRAM_CHAT_ID` | Duong's Telegram chat ID |

## Shared Helpers

`mcps/shared/helpers.py` — common utilities used by both servers: agent scanning, iTerm window management, git operations, registry read/write, status management.

# System Overview

Strawberry is Duong's personal agent system — a network of Claude-powered agents that handle life admin, side projects, health, finance, social, and learning tasks. Work tasks go through a separate system at `~/Documents/Work/mmp/workspace/agents/`.

## Core Components

```
Duong
  ↓ (CLI, Telegram, Discord)
Evelynn (head agent, coordinator)
  ↓ delegates via agent-manager MCP
Specialist agents (13 agents, see agent-system.md)
  ↓ communicate via
Turn-based conversations, inbox messages
  ↓ backed by
MCP servers (agent-manager, evelynn)
  ↓ runtime state in
~/.strawberry/ops/ (gitignored)
```

## Entry Points

| Channel | Flow | Status |
|---|---|---|
| **CLI** | Duong types directly in iTerm → Evelynn session | Active |
| **Telegram** | Telegram → bridge script → `claude -p` as Evelynn → reply via MCP | Planned (spec ready) |
| **Discord** | Discord → relay bot → event queue → bridge → Evelynn → reply | Planned (spec ready) |

## Repository Structure

```
strawberry/
├── agents/           # Agent profiles, memory, journals, learnings
│   ├── evelynn/      # Head agent
│   ├── swain/        # Architecture
│   ├── pyke/         # Security & infra
│   ├── ...           # (see agent-system.md for full roster)
│   ├── memory/       # Shared memory (agent-network, duong profile)
│   ├── roster.md     # Agent directory
│   └── health/       # Heartbeat script
├── architecture/     # This folder — living system docs
├── mcps/             # MCP server implementations
│   ├── agent-manager/  # Agent lifecycle, messaging, conversations
│   ├── evelynn/        # Evelynn-restricted tools + Telegram
│   └── shared/         # Shared helpers
├── apps/             # Applications
│   ├── discord-relay/  # Discord bot (relay only)
│   └── myapps/         # Duong's personal apps
├── scripts/          # Bridge scripts, deploy, health checks
├── plans/            # Execution plans (transient)
├── .mcp.json         # MCP server configuration
└── GIT_WORKFLOW.md   # Git policy reference
```

## Design Principles

1. **Evelynn is the hub** — all user-facing communication goes through her
2. **Agents are autonomous** — they can start peer conversations without Evelynn's permission
3. **Two-tier escalation** — Agent → Evelynn → Duong
4. **Operational state is ephemeral** — `~/.strawberry/ops/` is gitignored; only agent memory/learnings are committed
5. **Plans are transient, architecture is permanent** — plans drive execution, architecture docs are the lasting record

# Architecture — Strawberry

Living documentation for Duong's personal agent system. These docs are the source of truth for how things work.

## Index

| Document | Covers |
|---|---|
| [system-overview.md](system-overview.md) | High-level view of the entire system |
| [agent-system.md](agent-system.md) | Agent roster, roles, boot sequence, session lifecycle |
| [agent-network.md](agent-network.md) | Communication protocols, conversations, inbox, escalation |
| [mcp-servers.md](mcp-servers.md) | MCP servers, tools, configuration |
| [discord-relay.md](discord-relay.md) | Discord integration, relay bot, bridge, VPS flow |
| [telegram-relay.md](telegram-relay.md) | Telegram integration, polling bridge, message flow |
| [git-workflow.md](git-workflow.md) | Three-tier commit policy, branching, PR process |
| [infrastructure.md](infrastructure.md) | VPS, PM2, SSH, local Mac setup |

## Rules

- **Living docs** — keep these up-to-date when the system changes.
- **Plans are transient** — `plans/` files drive execution; once implemented, update the relevant architecture doc.
- **No duplication** — reference other docs instead of copying content.

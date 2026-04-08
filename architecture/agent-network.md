# Agent Network — Communication Protocols

## Tools

Local agent operations are handled by the `/agent-ops` skill. All subcommands are POSIX-portable and run on both macOS and Windows (Git Bash).

### Quick Messaging

- `/agent-ops send <agent> <message>` — fire-and-forget via inbox file

### Agent Roster

- `/agent-ops list` — list all agents with roles
- `/agent-ops list --json` — JSON output for machine consumers

### Scaffold New Agent

- `/agent-ops new <agent-name> [--role "<role>"]` — create agent directory layout

### Launching Agents

- macOS only: `scripts/mac/launch-agent-iterm.sh <agent-name> [initial-task]` — spawn in iTerm2
- Windows: use Claude Code `Task` tool with the agent's `.claude/agents/<name>.md` subagent definition

### Turn-Based Conversations (Phase 2)

Turn-based conversations are deferred to Phase 2. During Phase 1, use `/agent-ops send` for peer-to-peer messages and escalate to Evelynn via inbox for multi-agent discussions.

## Inbox System

Messages arrive as `[inbox] /path/to/inbox/<filename>.md` notifications. Protocol:

1. Read the file
2. Update `status: pending` → `status: read`
3. Respond as appropriate

Inbox files use YAML frontmatter: `from`, `to`, `priority`, `timestamp`, `status`.

## Delegation

Delegations are tracked via `agents/delegations/*.json` files. Phase 1 has no skill wrapper; Evelynn manages delegation state directly. Phase 2 will introduce `/agent-ops delegate` if needed.

When a delegated task completes, report completion to Evelynn and update the delegation JSON file directly.

## Coordination Model

- **Evelynn is the hub, not a bottleneck** — agents can send peer messages directly via `/agent-ops send`
- **Escalation path**: Agent → Evelynn → Duong (two-tier)
- **Mandatory reporting**: when an assigned task is complete, report back to Evelynn

### When to escalate to Evelynn

- Blocker requiring cross-domain coordination
- Decision needing Duong's input
- Conflict between agents or priorities

## Runtime State

All inbox data lives under `agents/<name>/inbox/` in the repo (gitignored files for privacy):

```
agents/
└── <agent>/
    └── inbox/           # Inbox messages (timestamped .md files)
```

## Cross-references

- `architecture/platform-parity.md` — platform support matrix for all tools and scripts
- `.claude/skills/agent-ops/SKILL.md` — agent-ops skill definition
- `plans/approved/2026-04-09-mcp-restructure-phase-1-detailed.md` — Phase 1 migration spec

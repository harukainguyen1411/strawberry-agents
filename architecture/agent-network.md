# Agent Network — Communication Protocols

## Tools

All communication tools live on the `agent-manager` MCP server.

### Quick Messaging

- `message_agent(name, message)` — fire-and-forget via inbox file

### Turn-Based Conversations

Primary multi-agent communication. Two modes:

| Mode | Turn enforcement | Use case |
|---|---|---|
| **Ordered** (default) | Strict round-robin | Structured reviews, sequential decisions |
| **Flexible** | Any participant any time | Brainstorming, async collaboration |

**Tools:**

| Tool | Description |
|---|---|
| `start_turn_conversation(title, sender, participants, turn_order, message, mode?)` | Start a conversation |
| `speak_in_turn(title, sender, message)` | Post a message (must be your turn in ordered mode) |
| `pass_turn(title, sender, reason?)` | Yield without content |
| `end_turn_conversation(title, sender)` | Propose ending |
| `read_new_messages(title, agent)` | Read messages since last cursor |
| `get_turn_status(title)` | Check who's next, round status |
| `invite_to_conversation(title, sender, agent, position?)` | Add agent mid-conversation |

### Escalation

| Tool | Description |
|---|---|
| `escalate_conversation(title, sender, reason)` | Pause conversation, notify Evelynn |
| `resolve_escalation(title, sender, resolution, action)` | `resume` or `escalate_to_duong` |

## Inbox System

Messages arrive as `[inbox] /path/to/inbox/<filename>.md` notifications. Protocol:

1. Read the file
2. Update `status: pending` → `status: read`
3. Respond as appropriate

Inbox files use YAML frontmatter: `from`, `to`, `priority`, `timestamp`, `status`.

## Coordination Model

- **Evelynn is the hub, not a bottleneck** — agents can start peer conversations directly
- **Escalation path**: Agent → Evelynn → Duong (two-tier)
- **Mandatory reporting**: when an assigned task is complete, report back to Evelynn

### When to escalate to Evelynn

- Blocker requiring cross-domain coordination
- Decision needing Duong's input
- Conflict between agents or priorities

## Runtime State

All conversation and inbox data lives in `~/.strawberry/ops/` (gitignored):

```
~/.strawberry/ops/
├── inbox/<agent>/        # Inbox messages
├── conversations/        # Multi-agent conversation state
├── health/               # Heartbeats, registry
└── inbox-queue/          # Approval queue
```

The MCP server accesses these via the `OPS_PATH` environment variable.

---
status: implemented
owner: syndra
---

# Agent Context/Token Monitoring — Design Proposal

**Goal:** Give Evelynn visibility into how much context each agent is using, so she can make smart decisions about when to restart agents vs let them run.

## What signals are available?

### What Claude CLI exposes
- `/cost` — shows session cost (input/output tokens, cache reads/writes, total USD). Available interactively but not programmatically extractable mid-session.
- Session files in `~/.claude/sessions/` — contain conversation history, but reading them requires filesystem access to Claude's internal data.
- No public API or MCP tool to query "current context usage" from outside a running session.

### The hard truth
**Claude CLI does not expose context window usage programmatically.** There is no `--get-context-size` flag, no MCP resource for it, no API endpoint. The `/cost` command only works inside the session itself, and its output isn't machine-parseable from outside.

## What we CAN do: Self-reporting

Since we can't observe agents from outside, agents must **self-report** their context health. This is the only practical approach.

### Design: Agent Context Health Self-Reporting

#### 1. Extend heartbeat with context signals

Each agent already writes heartbeats via `heartbeat.sh`. Add context-related fields that the agent can self-assess:

```json
{
  "agent": "syndra",
  "last_seen": "2026-04-04T15:00:00Z",
  "platform": "cli",
  "status": "active",
  "context_health": {
    "turn_count": 42,
    "session_start": "2026-04-04T10:45:00Z",
    "estimated_weight": "medium",
    "compression_events": 1,
    "last_report": "2026-04-04T15:00:00Z"
  }
}
```

**Fields explained:**
- `turn_count` — number of user/assistant turns in this session. Agents can track this by incrementing a counter. Rough proxy for context consumption.
- `session_start` — when the session began. Long-running sessions = more context.
- `estimated_weight` — self-assessed: `"light"` (<15 turns, no large file reads), `"medium"` (15-40 turns), `"heavy"` (40+ turns or known large context loads), `"critical"` (compression has happened, or agent is noticing degraded recall).
- `compression_events` — how many times the system has compressed prior messages. Each compression = context was full. This is the single most reliable signal. Agents see a system message when compression occurs.
- `last_report` — timestamp of this report.

#### 2. New MCP tool: `report_context_health`

Add to agent-manager:

```python
@mcp.tool()
async def report_context_health(
    agent: str,
    turn_count: int,
    estimated_weight: str,  # light | medium | heavy | critical
    compression_events: int = 0,
    notes: str = "",
) -> dict:
    """Report context health for the current agent session.
    Called periodically by agents (e.g., every 10 turns or on compression)."""
```

This writes to the health registry alongside the existing heartbeat data.

#### 3. New MCP tool: `get_agent_health_summary`

For Evelynn to query:

```python
@mcp.tool()
async def get_agent_health_summary() -> dict:
    """Get context health summary for all running agents.
    Returns per-agent: turn_count, estimated_weight, compression_events,
    session_duration, and a recommendation (ok/restart-soon/restart-now)."""
```

The recommendation logic:
- `ok` — light/medium weight, no compression, <2 hours
- `restart-soon` — heavy weight, OR 1 compression event, OR >3 hours
- `restart-now` — critical weight, OR 2+ compression events, OR >5 hours

#### 4. Agent protocol update

Add to agent-network.md:

> **Context health reporting:** Every ~10 turns, call `report_context_health` with your current turn count and weight estimate. If you notice the system compressing your conversation history, report immediately with `compression_events` incremented and `estimated_weight: "critical"`.

### What Evelynn does with this

Evelynn periodically calls `get_agent_health_summary` (e.g., before delegating a new task, or every 30 minutes). When she sees:
- `restart-soon` — finish current task, then restart before assigning new work
- `restart-now` — end session immediately, restart fresh

This is a **decision aid**, not automation. Evelynn makes the call based on what the agent is doing (don't restart mid-PR-review).

## What we're NOT doing

- **No external process monitoring** — we can't read Claude CLI internals from outside
- **No token counting** — we don't have access to actual token counts programmatically; turn count and compression events are sufficient proxies
- **No auto-restart** — Evelynn decides, not the system. Auto-restart risks losing in-progress work.
- **No cost tracking here** — that's a separate concern (the end-session MCP already logs sessions)

## Implementation

1. Add `report_context_health` and `get_agent_health_summary` to agent-manager MCP
2. Update `heartbeat.sh` to support the new fields (or have the MCP tool write directly to registry)
3. Update agent-network.md with reporting protocol
4. Add reporting to each agent's startup sequence (initial report at session start)

Estimated scope: ~100 lines of Python in agent-manager, protocol doc update. Bard can build it.

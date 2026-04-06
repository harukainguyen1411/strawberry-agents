---
status: proposed
owner: syndra
date: 2026-04-06
title: Work Agent System — Isolated Architecture
---

# Work Agent System — Isolated Architecture

## Problem

The work agent system at `~/Documents/Work/mmp/workspace/agents/` currently mirrors Strawberry's open network model: agents see the full roster, can message each other directly, and share `agent-network.md`. Duong wants agent isolation — only the coordinator knows who exists. Agents cannot discover, message, or reference each other.

## Current State (Work System)

- **Coordinator:** Sona (work assistant), Azir (head agent)
- **13 agents** with full peer visibility via `agent-network.md` and `roster.md`
- **MCP server:** Shared `agent-manager` from Strawberry (same binary, different env vars)
- **Communication:** `message_agent`, `start_conversation`, `message_in_conversation` — all peer-to-peer capable
- **Agent startup** reads `memory/agent-network.md` which contains the full roster and peer messaging instructions

## Design: Isolated Hub-and-Spoke

### Core Principle

Agents are blind. They know only: (1) their own identity, (2) their task, (3) how to report back to the coordinator. They do not know other agents exist.

### What Changes

#### 1. Remove agent-network.md from agent startup

**Current:** All agents read `memory/agent-network.md` (contains roster, peer tools, communication protocol).
**New:** Only the coordinator reads network context. Worker agents read a minimal `memory/agent-protocol.md` that contains:
- How to receive tasks (inbox)
- How to report completion (single tool: `report_to_coordinator`)
- How to escalate blockers (same tool, with blocker flag)
- No roster, no peer tools, no agent names

#### 2. New MCP server: `work-agent-manager` (fork of `agent-manager`)

Strip the agent-manager down to two variants:

**Coordinator MCP** (registered only in coordinator's `.claude/settings.json`):
| Tool | Purpose |
|---|---|
| `list_agents` | See all agents |
| `launch_agent` | Spin up agent in iTerm |
| `delegate_task` | Send task to agent inbox with structured format |
| `check_delegations` | Track task status |
| `agent_status` | Check heartbeats |
| `end_agent_session` | Shut down a specific agent |

**Worker MCP** (registered in each worker's `.claude/settings.json`):
| Tool | Purpose |
|---|---|
| `report_to_coordinator` | Send completion/blocker/update to coordinator inbox |
| `get_my_task` | Re-read current task assignment |

That's it. No `list_agents`, no `message_agent`, no conversations. Workers cannot discover or address other agents.

#### 3. CLAUDE.md changes (work system)

**Current:** Single CLAUDE.md with agent-network references, peer collaboration instructions.
**New:** Two CLAUDE.md variants:
- **Coordinator CLAUDE.md** — Full system awareness, delegation protocol, roster access
- **Worker CLAUDE.md template** — Generic. Reads own profile + memory, receives tasks via inbox, reports via `report_to_coordinator`. No mention of other agents. No startup read of agent-network.md.

Workers get their CLAUDE.md via a per-agent `.claude/settings.json` that points to the worker template, or via a shared project-level CLAUDE.md that is agent-role-aware (checks agent name, shows only relevant instructions).

#### 4. Inbox system simplification

**Current:** Any agent can write to any other agent's inbox.
**New:**
- Coordinator → worker: `delegate_task` writes to `agents/<name>/inbox/`
- Worker → coordinator: `report_to_coordinator` writes to coordinator's inbox
- Worker → worker: **impossible** (tool doesn't exist, no agent names known)

#### 5. Remove conversation system from work MCP

The turn-based conversation system (`start_conversation`, `message_in_conversation`, `read_conversation`) is removed entirely from the work MCP server. All multi-agent coordination flows through the coordinator's context window — the coordinator reads worker reports and synthesizes.

#### 6. iTerm launch isolation

**Current:** `launch_agent` opens a window with the agent's profile. Any agent can call it.
**New:** Only the coordinator can call `launch_agent`. Worker agents have no launch capability. The coordinator's launch script sets up per-agent environment variables including which MCP config to use (worker variant).

### What Stays the Same

| Component | Reuse Strategy |
|---|---|
| **iTerm profiles** | Keep. Same dynamic profile mechanism, separate `work-agents.json` |
| **Heartbeat system** | Keep as-is. `agents/health/heartbeat.sh` works with any agent directory |
| **Agent directory structure** | Keep. `agents/<name>/memory/`, `journal/`, `learnings/`, `inbox/` |
| **Session closing protocol** | Keep. `log_session`, journal, handoff note, memory update |
| **Boot sequence** | Keep (minus agent-network.md for workers) |
| **Plan approval gate** | Keep if desired, or simplify since work context may need faster iteration |
| **Git workflow** | Keep. Same worktree approach, same commit conventions |

### Architecture Diagram

```
Duong
  ↓ (CLI / Cursor)
Coordinator (single agent, Opus)
  ↓ delegate_task        ↑ report_to_coordinator
  ↓                      ↑
Worker A    Worker B    Worker C    (each isolated, Sonnet)
  │           │           │
  └── inbox ──┘── inbox ──┘── inbox (coordinator writes, worker reads)
```

Workers never see horizontal arrows. They only see their vertical channel to the coordinator.

### Implementation Phases

**Phase 1: Fork MCP server**
- Copy `mcps/agent-manager/` to work system as `mcps/work-agent-manager/`
- Strip to coordinator + worker tool sets
- Add `report_to_coordinator` tool (writes to coordinator inbox)
- Remove all conversation tools, `list_agents` from worker variant

**Phase 2: CLAUDE.md split**
- Write coordinator CLAUDE.md with full delegation protocol
- Write worker CLAUDE.md template (no roster, no peer tools)
- Update boot sequence: workers skip agent-network.md

**Phase 3: MCP configuration**
- Coordinator `.mcp.json`: coordinator MCP variant
- Worker `.mcp.json` template: worker MCP variant only
- Per-agent env var injection via launch script

**Phase 4: Migration**
- Update existing work agents to use new protocol
- Remove `memory/agent-network.md` visibility from worker agents
- Test: launch coordinator → delegate to worker → worker reports back → coordinator synthesizes

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Workers can't resolve technical questions without peers | Coordinator mediates: worker reports blocker → coordinator queries another worker → relays answer back |
| Coordinator becomes bottleneck | Coordinator is Opus with large context. Parallel delegation (launch multiple workers) keeps throughput high |
| Slower than peer-to-peer for technical discussions | Accepted tradeoff for isolation. Work context values control over speed |
| Workers might hallucinate agent names from training data | Worker CLAUDE.md explicitly states "you are the only agent" — no roster to contradict this |

## Decision Points for Duong

1. **Which agent is the coordinator?** Current system has Azir (head) and Sona (work assistant) — pick one or merge roles
2. **Do workers keep profiles/personalities?** Isolation doesn't require removing personalities, but work context might prefer generic professional agents
3. **Plan approval gate in work system?** Strawberry requires it; work system may want faster iteration with coordinator auto-approving

---
status: proposed
owner: syndra
date: 2026-04-06
title: Work Agent System — Isolated Architecture & Migration Plan
---

# Work Agent System — Isolated Architecture & Migration Plan

## Decisions

- **Coordinator:** Sona (Opus). Azir is retired or repurposed as a worker.
- **Workers:** Generic — no personalities, no character names. Named by function (e.g., `worker-1`, `impl-backend`, `impl-frontend`) or kept as-is but stripped of personality in their profiles.
- **Plan approval:** Auto-approve. Sona delegates and approves without waiting for Duong. Duong intervenes only on escalation.

## Architecture

```
Duong
  ↓ (CLI / Cursor)
Sona — Coordinator (Opus, ~/.claude-work/ profile)
  ↓ delegate_task        ↑ report_to_coordinator
  ↓                      ↑
Worker 1 (Sonnet)   Worker 2 (Sonnet)   Worker N (Sonnet)
  │                   │                   │
  └── inbox ──────────┘── inbox ──────────┘── inbox
```

Workers see only their vertical channel. No horizontal communication. No roster. No peer awareness.

### Key Architectural Decisions

1. **Agent isolation** — Workers know only: their identity, their task, and `report_to_coordinator`. Nothing else.
2. **Model tiers** — Sona (coordinator) runs **Opus**. All workers run **Sonnet**.
3. **Separate Mac profile** — Work system uses `CLAUDE_CONFIG_DIR=~/.claude-work/`. Fully isolated `settings.json`, MCP configs, memory, `CLAUDE.md`. Zero cross-contamination with Strawberry.
4. **No plan approval gate** — Sona auto-approves and delegates. Faster iteration for work context.
5. **Generic workers** — No personalities or character names. Professional, task-focused.

### MCP Tool Split

**Coordinator MCP** (`work-coordinator-manager`, Sona only):

| Tool                | Purpose                                         |
| ------------------- | ----------------------------------------------- |
| `list_agents`       | See all workers                                 |
| `launch_agent`      | Spin up worker in iTerm (with Sonnet + worker MCP) |
| `delegate_task`     | Write task to worker inbox                      |
| `check_delegations` | Track task status                               |
| `agent_status`      | Check heartbeats                                |
| `end_agent_session` | Shut down a specific worker                     |

**Worker MCP** (`work-worker-manager`, all workers):

| Tool                    | Purpose                                             |
| ----------------------- | --------------------------------------------------- |
| `report_to_coordinator` | Send completion/blocker/update to Sona's inbox      |
| `get_my_task`           | Re-read current task assignment                     |

No `list_agents`, no `message_agent`, no conversations. Workers cannot discover other agents.

### Communication Flow

- **Sona → Worker:** `delegate_task` writes to `agents/<worker>/inbox/`
- **Worker → Sona:** `report_to_coordinator` writes to `agents/sona/inbox/`
- **Worker → Worker:** Impossible (no tool, no names)
- **Worker blocker:** `report_to_coordinator` with `type: blocker` — Sona mediates

---

## Detailed Migration Plan

### Phase 1: Profile Setup

**Goal:** Create isolated Claude Code config directory for the work system.

**Files to create:**

```
~/.claude-work/
├── settings.json          # Work-specific settings (model: opus for Sona)
├── CLAUDE.md              # Symlink → work repo's project CLAUDE.md (or empty, project-level takes precedence)
└── projects/
    └── <work-repo-hash>/
        └── CLAUDE.md      # Not needed if project has its own
```

**Steps:**

1. Create directory:
   ```bash
   mkdir -p ~/.claude-work/projects
   ```

2. Create `~/.claude-work/settings.json`:
   ```json
   {
     "permissions": {
       "allow": [],
       "deny": []
     },
     "env": {
       "AGENT_SYSTEM": "work",
       "AGENT_BASE_DIR": "~/Documents/Work/mmp/workspace/agents"
     }
   }
   ```

3. Create launcher script at `~/Documents/Work/mmp/workspace/agents/scripts/launch-work-agent.sh`:
   ```bash
   #!/bin/bash
   # Usage: launch-work-agent.sh <agent-name> [--coordinator]
   AGENT_NAME="$1"
   export CLAUDE_CONFIG_DIR="$HOME/.claude-work"
   export AGENT_NAME="$AGENT_NAME"
   export AGENT_BASE_DIR="$HOME/Documents/Work/mmp/workspace/agents"

   if [ "$2" = "--coordinator" ]; then
     claude --model opus "$AGENT_BASE_DIR"
   else
     claude --model sonnet "$AGENT_BASE_DIR"
   fi
   ```

4. Verify isolation:
   ```bash
   CLAUDE_CONFIG_DIR=~/.claude-work claude --version  # should not see Strawberry MCP servers
   ```

### Phase 2: Fork MCP Server

**Goal:** Create `work-agent-manager` with coordinator/worker split.

**Source:** `~/Documents/Personal/strawberry/mcps/agent-manager/`
**Target:** `~/Documents/Work/mmp/workspace/agents/mcps/work-agent-manager/`

**Steps:**

1. Copy the MCP server:
   ```bash
   cp -r ~/Documents/Personal/strawberry/mcps/agent-manager/ \
         ~/Documents/Work/mmp/workspace/agents/mcps/work-agent-manager/
   ```

2. **Modify `server.py`** (or equivalent entry point) — add a mode switch based on env var:
   ```python
   AGENT_ROLE = os.environ.get("AGENT_ROLE", "worker")  # "coordinator" or "worker"
   ```

3. **Coordinator mode** — expose these tools only:
   - `list_agents` — reads `agents/roster.md` (coordinator-only file)
   - `launch_agent` — calls `scripts/launch-work-agent.sh <name>` via iTerm
   - `delegate_task` — writes structured task to `agents/<name>/inbox/YYYYMMDD-HHMM-task.md`
   - `check_delegations` — scans delegation records
   - `agent_status` — reads heartbeat files
   - `end_agent_session` — sends SIGTERM or writes shutdown to inbox

4. **Worker mode** — expose only:
   - `report_to_coordinator` — writes to `agents/sona/inbox/YYYYMMDD-HHMM-<worker>-report.md`
     - Parameters: `type` (completion | blocker | update), `message`, `delegation_id`
   - `get_my_task` — reads most recent task from own `inbox/` with status `pending`

5. **Remove entirely** from both modes:
   - `message_agent` (replaced by role-specific tools)
   - `start_turn_conversation`, `speak_in_turn`, `pass_turn`, `end_turn_conversation`
   - `read_new_messages`, `get_turn_status`, `invite_to_conversation`
   - `escalate_conversation`, `resolve_escalation`
   - All conversation-related file I/O

6. **Update `pyproject.toml`** / package name to `work-agent-manager`.

### Phase 3: CLAUDE.md Split + Model Tiers

**Goal:** Separate instructions for coordinator vs workers.

#### 3a. Coordinator CLAUDE.md

**File:** `~/Documents/Work/mmp/workspace/agents/CLAUDE.md` (project-level, read by Sona)

Key sections:
- Identity: "You are Sona, the work system coordinator."
- Model: Opus
- Full agent roster (list of workers and their capabilities)
- Delegation protocol: how to use `delegate_task`, `check_delegations`, `launch_agent`
- Auto-approve: "You delegate tasks directly. No plan approval gate."
- Mediation protocol: when a worker reports a blocker, query another worker or resolve directly
- Session closing protocol (same as Strawberry)
- Boot sequence: read own profile, memory, roster

#### 3b. Worker CLAUDE.md Template

**File:** `~/Documents/Work/mmp/workspace/agents/worker-claude-template.md`

Key sections:
- Identity: "You are a work agent. You execute tasks given to you."
- Model: Sonnet
- **No roster, no agent names, no peer references**
- "You are the only agent. Report all results via `report_to_coordinator`."
- Boot sequence: read own `memory/` and task from `inbox/`
- Available tools: only `report_to_coordinator` and `get_my_task`
- Escalation: "If blocked, use `report_to_coordinator` with type `blocker`."
- Session closing: journal + memory update (simplified, no handoff needed)

#### 3c. Per-Worker Config

Each worker's launch sets `CLAUDE_CONFIG_DIR` to a worker-specific override, or the launch script copies `worker-claude-template.md` into the project's `.claude/` before starting. Simplest approach: a single project-level CLAUDE.md that checks `$AGENT_ROLE`:

```markdown
<!-- In project CLAUDE.md -->
If your AGENT_ROLE is "coordinator", follow coordinator-instructions.md.
If your AGENT_ROLE is "worker" (or unset), follow worker-instructions.md.
```

**Files to create:**
- `~/Documents/Work/mmp/workspace/agents/coordinator-instructions.md`
- `~/Documents/Work/mmp/workspace/agents/worker-instructions.md`
- Update project `CLAUDE.md` to route based on `$AGENT_ROLE`

### Phase 4: MCP Configuration

**Goal:** Wire up the correct MCP variant per role.

#### 4a. Coordinator MCP Config

**File:** `~/.claude-work/settings.json` (or project `.mcp.json`):

```json
{
  "mcpServers": {
    "work-agent-manager": {
      "command": "python",
      "args": ["-m", "work_agent_manager"],
      "cwd": "/Users/duongntd99/Documents/Work/mmp/workspace/agents/mcps/work-agent-manager",
      "env": {
        "AGENT_ROLE": "coordinator",
        "AGENT_NAME": "sona",
        "AGENT_BASE_DIR": "/Users/duongntd99/Documents/Work/mmp/workspace/agents"
      }
    }
  }
}
```

#### 4b. Worker MCP Config

**File:** Worker launch script injects env vars before starting Claude:

```bash
export AGENT_ROLE="worker"
export AGENT_NAME="$1"
# MCP config in project .mcp.json reads AGENT_ROLE from env
```

Project-level `.mcp.json` uses env var substitution:

```json
{
  "mcpServers": {
    "work-agent-manager": {
      "command": "python",
      "args": ["-m", "work_agent_manager"],
      "cwd": "./mcps/work-agent-manager",
      "env": {
        "AGENT_ROLE": "${AGENT_ROLE}",
        "AGENT_NAME": "${AGENT_NAME}",
        "AGENT_BASE_DIR": "${AGENT_BASE_DIR}"
      }
    }
  }
}
```

### Phase 5: Agent Migration

**Goal:** Convert existing work agents to isolated model.

**Steps:**

1. **Retire Azir as coordinator** — Sona takes over. Azir becomes a worker or is removed.

2. **Strip agent personalities:**
   - For each agent in `agents/<name>/profile.md`:
     - Remove backstory, speaking style, quirks, personality
     - Keep: role description, capabilities, domain expertise
     - Or replace with generic: "Worker agent specializing in <domain>"

3. **Remove `agent-network.md` from worker boot:**
   - Delete or move `agents/memory/agent-network.md` to `agents/sona/memory/` (coordinator-only)
   - Worker boot sequence reads only: own `profile.md`, own `memory/<name>.md`, task from `inbox/`

4. **Update worker profiles** to reference `report_to_coordinator` instead of `message_agent`

5. **Clean up roster:**
   - Create `agents/sona/roster.md` — coordinator-only file listing all workers and capabilities
   - Remove shared `agents/roster.md` (or restrict to coordinator directory)

### Phase 6: Testing & Verification

**Goal:** End-to-end validation of isolated architecture.

**Test sequence:**

1. Launch Sona (coordinator, Opus) with `CLAUDE_CONFIG_DIR=~/.claude-work`:
   ```bash
   ./scripts/launch-work-agent.sh sona --coordinator
   ```

2. Sona delegates a task to a worker:
   - `delegate_task` writes to worker inbox
   - `launch_agent` starts worker in iTerm with Sonnet + worker MCP

3. Worker receives task:
   - Reads inbox via `get_my_task`
   - Executes the task
   - Reports via `report_to_coordinator`

4. Sona reads worker report and synthesizes

5. **Isolation checks:**
   - Worker runs `list_agents` → tool not found (pass)
   - Worker runs `message_agent` → tool not found (pass)
   - Worker's CLAUDE.md mentions no agent names → pass
   - Worker's MCP config has no coordinator tools → pass
   - `~/.claude-work/` has no Strawberry MCP servers → pass
   - Worker cannot read `agents/sona/roster.md` (or it doesn't exist in their view) → pass

## Risks and Mitigations

| Risk                                                     | Mitigation                                                                                                  |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Workers can't resolve technical questions without peers  | Sona mediates: worker reports blocker → Sona queries another worker → relays answer back                   |
| Sona becomes bottleneck                                  | Sona is Opus with large context. Parallel delegation (launch multiple workers) keeps throughput high        |
| Slower than peer-to-peer for technical discussions       | Accepted tradeoff for isolation. Work context values control over speed                                     |
| Workers might hallucinate agent names from training data | Worker CLAUDE.md explicitly states "you are the only agent" — no roster to contradict this                  |
| `CLAUDE_CONFIG_DIR` not respected by all Claude features | Test thoroughly in Phase 1. Fallback: separate macOS user account                                          |

## File Inventory

**New files to create:**

| File | Purpose |
| --- | --- |
| `~/.claude-work/settings.json` | Work profile settings |
| `scripts/launch-work-agent.sh` | Launcher with profile isolation + model tier |
| `mcps/work-agent-manager/` | Forked MCP with coordinator/worker split |
| `coordinator-instructions.md` | Sona's CLAUDE.md instructions |
| `worker-instructions.md` | Generic worker CLAUDE.md instructions |
| `agents/sona/roster.md` | Coordinator-only agent roster |
| `agents/memory/agent-protocol.md` | Worker-only minimal protocol doc |

**Files to modify:**

| File | Change |
| --- | --- |
| Project `CLAUDE.md` | Route to coordinator/worker instructions based on `$AGENT_ROLE` |
| Project `.mcp.json` | Point to `work-agent-manager` with env var substitution |
| `agents/<worker>/profile.md` (each) | Strip personality, keep capabilities only |
| `agents/sona/profile.md` | Update to coordinator role |

**Files to remove/relocate:**

| File | Action |
| --- | --- |
| `agents/memory/agent-network.md` | Move to `agents/sona/memory/` (coordinator-only) |
| `agents/roster.md` (shared) | Replace with `agents/sona/roster.md` |


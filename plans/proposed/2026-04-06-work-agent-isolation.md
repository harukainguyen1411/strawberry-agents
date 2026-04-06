---
status: proposed
owner: syndra
date: 2026-04-06
title: Work Agent System — Isolated Architecture & Migration Plan
---

# Work Agent System — Isolated Architecture & Migration Plan

## Decisions

- **Coordinator:** Sona (Opus) — hands-free. Manages workstreams, does not plan or implement.
- **Planners:** Opus agents that design plans, break down work, and manage their own pool of workers.
- **Workers:** Generic Sonnet agents — no personalities, no character names. Professional, task-focused.
- **Plan approval:** Planner drafts plan → Duong approves → Planner autonomously delegates implementation to workers without further check-ins.

## Architecture: Three-Tier Hub-and-Spoke

```
Duong
  ↓ requests + plan approvals
Sona — Coordinator (Opus, ~/.claude-work/ profile)
  ↓ delegate_task              ↑ report_to_coordinator
  ↓                            ↑
Planner A (Opus)          Planner B (Opus)
  ↓ delegate_task  ↑ report     ↓ delegate_task  ↑ report
  ↓                ↑            ↓                ↑
Worker 1 (Sonnet)  Worker 2    Worker 3 (Sonnet)  Worker 4
```

**Three tiers, strict vertical channels:**

- **Tier 1 — Sona (Coordinator):** Receives requests from Duong. Delegates to planners. Coordinates multiple parallel streams. Reports back to Duong. Does NOT plan or do heavy lifting — stays free to manage concurrency.
- **Tier 2 — Planners (Opus):** Receive tasks from Sona. Design plans, break down work. Delegate implementation to Sonnet workers. Assign PR reviews and follow-up to other workers. Workers report back to their planner (not Sona). Planner synthesizes and reports to Sona.
- **Tier 3 — Workers (Sonnet):** Receive tasks from a planner. Implement, review PRs, test. Report back to their planner only.

**Flow:** Duong → Sona → Planner(s) → Worker(s) → Planner → Sona → Duong.

No horizontal communication at any tier. Each agent sees only its vertical channel.

### Key Architectural Decisions

1. **Three-tier isolation** — Workers know only their planner. Planners know only Sona. No peer visibility at any level.
2. **Model tiers** — Sona (coordinator) and planners run **Opus**. Workers run **Sonnet**.
3. **Separate Mac profile** — Work system uses `CLAUDE_CONFIG_DIR=~/.claude-work/`. Fully isolated `settings.json`, MCP configs, memory, `CLAUDE.md`. Zero cross-contamination with Strawberry.
4. **Plan approval gate** — Planner drafts plan to `plans/proposed/` → Duong approves → Planner autonomously delegates implementation. Sona does not approve plans.
5. **Generic workers** — No personalities or character names. Professional, task-focused.
6. **Sona stays hands-free** — Sona's only job is routing and coordination. She never plans, implements, or reviews. This lets her manage multiple concurrent workstreams.

### MCP Tool Split — Three Variants

**Coordinator MCP** (`work-coordinator-manager`, Sona only):

| Tool                | Purpose                                              |
| ------------------- | ---------------------------------------------------- |
| `list_agents`       | See all planners and workers                         |
| `launch_agent`      | Spin up agent in iTerm (Opus for planners, Sonnet for workers) |
| `delegate_task`     | Write task to planner inbox                          |
| `check_delegations` | Track task status across all planners                |
| `agent_status`      | Check heartbeats                                     |
| `end_agent_session` | Shut down a specific agent                           |

**Planner MCP** (`work-planner-manager`, planner agents only):

| Tool                    | Purpose                                                   |
| ----------------------- | --------------------------------------------------------- |
| `launch_worker`         | Spin up a Sonnet worker in iTerm                          |
| `delegate_task`         | Write task to worker inbox                                |
| `check_delegations`     | Track status of own workers                               |
| `agent_status`          | Check heartbeats of own workers                           |
| `end_agent_session`     | Shut down a worker                                        |
| `report_to_coordinator` | Send completion/blocker/update to Sona's inbox            |
| `get_my_task`           | Re-read task assignment from Sona                         |

**Worker MCP** (`work-worker-manager`, all workers):

| Tool                 | Purpose                                              |
| -------------------- | ---------------------------------------------------- |
| `report_to_planner`  | Send completion/blocker/update to assigning planner  |
| `get_my_task`        | Re-read current task assignment                      |

No `list_agents`, no `message_agent`, no conversations at any tier.

### Communication Flow

- **Sona → Planner:** `delegate_task` writes to `agents/<planner>/inbox/`
- **Planner → Sona:** `report_to_coordinator` writes to `agents/sona/inbox/`
- **Planner → Worker:** `delegate_task` writes to `agents/<worker>/inbox/`
- **Worker → Planner:** `report_to_planner` writes to assigning planner's inbox
- **Worker → Sona:** Impossible (no tool, no knowledge of Sona)
- **Worker → Worker:** Impossible (no tool, no names)
- **Planner → Planner:** Impossible (no tool, no names)
- **Worker blocker:** `report_to_planner` with `type: blocker` — planner mediates or escalates to Sona

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
   # Usage: launch-work-agent.sh <agent-name> [--coordinator|--planner]
   AGENT_NAME="$1"
   export CLAUDE_CONFIG_DIR="$HOME/.claude-work"
   export AGENT_NAME="$AGENT_NAME"
   export AGENT_BASE_DIR="$HOME/Documents/Work/mmp/workspace/agents"

   case "$2" in
     --coordinator)
       export AGENT_ROLE="coordinator"
       claude --model opus "$AGENT_BASE_DIR"
       ;;
     --planner)
       export AGENT_ROLE="planner"
       claude --model opus "$AGENT_BASE_DIR"
       ;;
     *)
       export AGENT_ROLE="worker"
       claude --model sonnet "$AGENT_BASE_DIR"
       ;;
   esac
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
   AGENT_ROLE = os.environ.get("AGENT_ROLE", "worker")  # "coordinator", "planner", or "worker"
   ```

3. **Coordinator mode** (`AGENT_ROLE=coordinator`) — expose:
   - `list_agents` — reads `agents/sona/roster.md` (coordinator-only file)
   - `launch_agent` — calls `scripts/launch-work-agent.sh <name> --planner|--worker` via iTerm
   - `delegate_task` — writes structured task to `agents/<name>/inbox/YYYYMMDD-HHMM-task.md`
   - `check_delegations` — scans delegation records across all planners
   - `agent_status` — reads heartbeat files
   - `end_agent_session` — sends SIGTERM or writes shutdown to inbox

4. **Planner mode** (`AGENT_ROLE=planner`) — expose:
   - `launch_worker` — calls `scripts/launch-work-agent.sh <name>` (always Sonnet)
   - `delegate_task` — writes task to `agents/<worker>/inbox/`
   - `check_delegations` — scans own workers' delegation records
   - `agent_status` — reads heartbeat files of own workers
   - `end_agent_session` — shut down a worker
   - `report_to_coordinator` — writes to `agents/sona/inbox/YYYYMMDD-HHMM-<planner>-report.md`
     - Parameters: `type` (completion | blocker | update), `message`, `delegation_id`
   - `get_my_task` — reads most recent task from own `inbox/` with status `pending`

5. **Worker mode** (`AGENT_ROLE=worker`) — expose only:
   - `report_to_planner` — writes to assigning planner's inbox (planner name injected via `$ASSIGNED_PLANNER` env var)
     - Parameters: `type` (completion | blocker | update), `message`, `delegation_id`
   - `get_my_task` — reads most recent task from own `inbox/` with status `pending`

6. **Remove entirely** from all modes:
   - `message_agent` (replaced by role-specific tools)
   - `start_turn_conversation`, `speak_in_turn`, `pass_turn`, `end_turn_conversation`
   - `read_new_messages`, `get_turn_status`, `invite_to_conversation`
   - `escalate_conversation`, `resolve_escalation`
   - All conversation-related file I/O

7. **Update `pyproject.toml`** / package name to `work-agent-manager`.

### Phase 3: CLAUDE.md Split + Model Tiers + Plan Approval

**Goal:** Three instruction sets for coordinator, planner, and worker. Establish plan approval flow.

#### 3a. Coordinator Instructions (Sona)

**File:** `coordinator-instructions.md`

Key sections:
- Identity: "You are Sona, the work system coordinator. You do NOT plan or implement."
- Model: Opus
- Full roster of planners and their domains
- Delegation protocol: receive request from Duong → delegate to appropriate planner → track progress → report back
- "You stay hands-free. Your job is routing, coordination, and managing multiple parallel workstreams."
- "You never write plans, implement code, or review PRs."
- Session closing protocol (same as Strawberry)
- Boot sequence: read own profile, memory, roster

#### 3b. Planner Instructions

**File:** `planner-instructions.md`

Key sections:
- Identity: "You are a planner agent. You design plans and manage workers."
- Model: Opus
- "You receive tasks from the coordinator. You design plans, break them down, and delegate implementation to workers."
- Plan approval: "Write plans to `plans/proposed/`. Duong approves by moving to `plans/approved/`. Once approved, autonomously delegate implementation to workers — no further check-ins."
- Worker management: how to use `launch_worker`, `delegate_task`, `check_delegations`
- "Workers report back to you. Synthesize their results and report to the coordinator."
- "You do NOT know other planners exist. You only see your workers and the coordinator."
- Escalation: report blockers to coordinator via `report_to_coordinator`
- Boot sequence: read own memory, task from inbox

#### 3c. Worker Instructions

**File:** `worker-instructions.md`

Key sections:
- Identity: "You are a work agent. You execute tasks given to you."
- Model: Sonnet
- **No roster, no agent names, no peer references**
- "You are the only agent. Report all results via `report_to_planner`."
- Boot sequence: read own `memory/` and task from `inbox/`
- Available tools: only `report_to_planner` and `get_my_task`
- Escalation: "If blocked, use `report_to_planner` with type `blocker`."
- Session closing: journal + memory update (simplified, no handoff needed)

#### 3d. Project CLAUDE.md Router

Single project-level CLAUDE.md that routes based on `$AGENT_ROLE`:

```markdown
<!-- In project CLAUDE.md -->
If your AGENT_ROLE is "coordinator", follow coordinator-instructions.md.
If your AGENT_ROLE is "planner", follow planner-instructions.md.
If your AGENT_ROLE is "worker" (or unset), follow worker-instructions.md.
```

**Files to create:**
- `coordinator-instructions.md`
- `planner-instructions.md`
- `worker-instructions.md`
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

#### 4b. Planner & Worker MCP Config

Launch script injects env vars before starting Claude. For planners:

```bash
export AGENT_ROLE="planner"
export AGENT_NAME="$1"
```

For workers (planner name injected so `report_to_planner` knows the target):

```bash
export AGENT_ROLE="worker"
export AGENT_NAME="$1"
export ASSIGNED_PLANNER="<planner-name>"  # set by planner's launch_worker tool
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

1. Launch Sona (coordinator, Opus):
   ```bash
   ./scripts/launch-work-agent.sh sona --coordinator
   ```

2. Sona delegates a task to a planner:
   - `delegate_task` writes to planner inbox
   - `launch_agent` starts planner in iTerm with Opus + planner MCP

3. Planner receives task, designs plan, writes to `plans/proposed/`

4. Duong approves plan (moves to `plans/approved/`)

5. Planner delegates implementation to workers:
   - `launch_worker` starts worker in iTerm with Sonnet + worker MCP
   - `delegate_task` writes to worker inbox

6. Worker executes and reports back to planner via `report_to_planner`

7. Planner synthesizes worker results and reports to Sona via `report_to_coordinator`

8. Sona reports to Duong

9. **Isolation checks:**
   - Worker runs `list_agents` → tool not found (pass)
   - Worker runs `report_to_coordinator` → tool not found (pass)
   - Worker knows planner name only via `$ASSIGNED_PLANNER` (pass)
   - Planner runs `list_agents` → tool not found (pass)
   - Planner knows only Sona and own workers (pass)
   - Worker's CLAUDE.md mentions no agent names → pass
   - `~/.claude-work/` has no Strawberry MCP servers → pass

## Risks and Mitigations

| Risk                                                     | Mitigation                                                                                                  |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Workers can't resolve technical questions without peers  | Planner mediates: worker reports blocker → planner queries another worker or resolves directly              |
| Sona becomes bottleneck                                  | Sona is hands-free — only routes to planners. Planners handle the heavy lifting. Multiple planners run in parallel |
| Planner becomes bottleneck for its workers               | Planner is Opus with large context. Can run multiple workers in parallel                                    |
| Extra latency from three tiers                           | Accepted tradeoff for Sona staying free to manage multiple concurrent workstreams                           |
| Slower than peer-to-peer for technical discussions       | Accepted tradeoff for isolation. Work context values control over speed                                     |
| Workers might hallucinate agent names from training data | Worker CLAUDE.md explicitly states "you are the only agent" — no roster to contradict this                  |
| `CLAUDE_CONFIG_DIR` not respected by all Claude features | Test thoroughly in Phase 1. Fallback: separate macOS user account                                          |

## File Inventory

**New files to create:**

| File | Purpose |
| --- | --- |
| `~/.claude-work/settings.json` | Work profile settings |
| `scripts/launch-work-agent.sh` | Launcher with profile isolation + model tier |
| `mcps/work-agent-manager/` | Forked MCP with coordinator/planner/worker split |
| `coordinator-instructions.md` | Sona's CLAUDE.md instructions |
| `planner-instructions.md` | Planner CLAUDE.md instructions |
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


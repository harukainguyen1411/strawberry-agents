---
status: implemented
owner: syndra
date: 2026-04-06
title: Work Agent System — Isolated Architecture & Migration Plan
---

# Work Agent System — Isolated Architecture & Migration Plan

## Decisions

- **Coordinator:** Coordinator (Opus) — hands-free. Manages workstreams, does not plan or implement.
- **Planners:** Opus agents that design plans, break down work, and manage their own pool of workers.
- **Workers:** Generic Sonnet agents — no personalities, no character names. Professional, task-focused.
- **Plan approval:** Planner drafts plan → Duong approves → Planner autonomously delegates implementation to workers without further check-ins.

## Architecture: Three-Tier Hub-and-Spoke

```
Duong
  ↓ opens Claude in ~/Documents/Work/mmp/workspace/
  ↓ "Hey Coordinator"
Coordinator (Opus, project-scoped .mcp.json)
  ↓ delegate_task              ↑ report_to_coordinator
  ↓                            ↑
Planner A (Opus)          Planner B (Opus)        ← launched programmatically
  ↓ delegate_task  ↑ report     ↓ delegate_task  ↑ report
  ↓                ↑            ↓                ↑
Worker 1 (Sonnet)  Worker 2    Worker 3 (Sonnet)  Worker 4  ← launched programmatically
```

**Three tiers, strict vertical channels:**

- **Tier 1 — Coordinator (Opus):** Duong opens Claude normally in the work directory and says "Hey Coordinator". CLAUDE.md routing activates coordinator mode. Receives requests from Duong. Delegates to planners. Coordinates multiple parallel streams. Reports back to Duong. Does NOT plan or do heavy lifting — stays free to manage concurrency.
- **Tier 2 — Planners (Opus):** Launched programmatically by Coordinator via `launch_agent`. Receive tasks from Coordinator. Design plans, break down work. Delegate implementation to Sonnet workers. Assign PR reviews and follow-up to other workers. Workers report back to their planner (not Coordinator). Planner synthesizes and reports to Coordinator.
- **Tier 3 — Workers (Sonnet):** Launched programmatically by planners via `launch_worker`. Receive tasks from a planner. Implement, review PRs, test. Report back to their planner only.

**Flow:** Duong → Coordinator → Planner(s) → Worker(s) → Planner → Coordinator → Duong.

No horizontal communication at any tier. Each agent sees only its vertical channel.

### Key Architectural Decisions

1. **Three-tier isolation** — Workers know only their planner. Planners know only Coordinator. No peer visibility at any level.
2. **Model tiers** — Coordinator and planners run **Opus**. Workers run **Sonnet**.
3. **Same UX as Strawberry** — Duong opens Claude in the work directory, greets "Hey Coordinator", and CLAUDE.md routes based on the greeting. No separate Mac profile, no special launch scripts for the coordinator. MCP isolation is project-scoped via `.mcp.json`.
4. **Plan approval gate** — Planner drafts plan to `plans/proposed/` → Duong approves → Planner autonomously delegates implementation. Coordinator does not approve plans.
5. **Generic workers** — No personalities or character names. Professional, task-focused.
6. **Coordinator stays hands-free** — Coordinator's only job is routing and coordination. It never plans, implements, or reviews. This lets it manage multiple concurrent workstreams.
7. **Programmatic launches only for planners/workers** — Coordinator launches planners, planners launch workers. The launch tool injects `AGENT_ROLE` env var for MCP tool isolation. Only Duong starts Claude manually (as Coordinator).

### MCP Tool Split — Three Variants

**Coordinator MCP** (`work-coordinator-manager`, Coordinator only):

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
| `report_to_coordinator` | Send completion/blocker/update to Coordinator's inbox            |
| `get_my_task`           | Re-read task assignment from Coordinator                         |

**Worker MCP** (`work-worker-manager`, all workers):

| Tool                 | Purpose                                              |
| -------------------- | ---------------------------------------------------- |
| `report_to_planner`  | Send completion/blocker/update to assigning planner  |
| `get_my_task`        | Re-read current task assignment                      |

No `list_agents`, no `message_agent`, no conversations at any tier.

### Communication Flow

- **Coordinator → Planner:** `delegate_task` writes to `agents/<planner>/inbox/`
- **Planner → Coordinator:** `report_to_coordinator` writes to `agents/coordinator/inbox/`
- **Planner → Worker:** `delegate_task` writes to `agents/<worker>/inbox/`
- **Worker → Planner:** `report_to_planner` writes to assigning planner's inbox
- **Worker → Coordinator:** Impossible (no tool, no knowledge of Coordinator)
- **Worker → Worker:** Impossible (no tool, no names)
- **Planner → Planner:** Impossible (no tool, no names)
- **Worker blocker:** `report_to_planner` with `type: blocker` — planner mediates or escalates to Coordinator

---

## Detailed Migration Plan

### Phase 1: Project Setup

**Goal:** Set up the work directory with CLAUDE.md routing and project-scoped MCP.

**Working directory:** `~/Documents/Work/mmp/workspace/`

No separate `~/.claude-work/` profile needed. Everything is project-scoped.

**Steps:**

1. Create/update `CLAUDE.md` in the workspace root with greeting-based routing (like Strawberry):
   ```markdown
   # Work Agent System

   ## Agent Routing
   If you receive a greeting like "Hey Coordinator", you are the Coordinator agent.
   Follow coordinator-instructions.md.

   If your AGENT_ROLE env var is "planner", follow planner-instructions.md.
   If your AGENT_ROLE env var is "worker", follow worker-instructions.md.
   ```

2. Create `.mcp.json` in the workspace root — defaults to coordinator mode (since Duong is the only one starting Claude manually):
   ```json
   {
     "mcpServers": {
       "work-agent-manager": {
         "command": "python",
         "args": ["-m", "work_agent_manager"],
         "cwd": "./agents/mcps/work-agent-manager",
         "env": {
           "AGENT_ROLE": "${AGENT_ROLE:-coordinator}",
           "AGENT_NAME": "${AGENT_NAME:-coordinator}",
           "AGENT_BASE_DIR": "./agents"
         }
       }
     }
   }
   ```
   When Duong opens Claude manually, `AGENT_ROLE` is unset → defaults to `coordinator`. When planners/workers are launched programmatically, `AGENT_ROLE` is set by the launch tool.

3. Create launcher script at `agents/scripts/launch-work-agent.sh` (used by Coordinator's `launch_agent` and Planner's `launch_worker` tools — NOT by Duong):
   ```bash
   #!/bin/bash
   # Usage: launch-work-agent.sh <agent-name> [--planner]
   # Called programmatically by coordinator/planner MCP tools, not by Duong.
   AGENT_NAME="$1"
   export AGENT_NAME="$AGENT_NAME"
   export AGENT_BASE_DIR="$HOME/Documents/Work/mmp/workspace/agents"

   if [ "$2" = "--planner" ]; then
     export AGENT_ROLE="planner"
     claude --model opus "$HOME/Documents/Work/mmp/workspace"
   else
     export AGENT_ROLE="worker"
     claude --model sonnet "$HOME/Documents/Work/mmp/workspace"
   fi
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
   - `list_agents` — reads `agents/coordinator/roster.md` (coordinator-only file)
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
   - `report_to_coordinator` — writes to `agents/coordinator/inbox/YYYYMMDD-HHMM-<planner>-report.md`
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

### Phase 3: CLAUDE.md + Instruction Files

**Goal:** Three instruction sets for coordinator, planner, and worker. Greeting-based routing for coordinator, env-var routing for planners/workers.

#### 3a. Project CLAUDE.md Router

**File:** `~/Documents/Work/mmp/workspace/CLAUDE.md`

```markdown
# Work Agent System

## Agent Routing

If you receive a greeting like **"Hey Coordinator"**, you are the Coordinator.
Follow `agents/coordinator-instructions.md`.

If your AGENT_ROLE env var is "planner", follow `agents/planner-instructions.md`.
If your AGENT_ROLE env var is "worker", follow `agents/worker-instructions.md`.
```

This mirrors Strawberry's pattern: greeting activates the role for Duong's manual sessions; env var activates the role for programmatic launches.

#### 3b. Coordinator Instructions

**File:** `agents/coordinator-instructions.md`

Key sections:
- Identity: "You are the Coordinator. You do NOT plan or implement."
- Model: Opus (Duong starts Claude with default model = Opus, or can be set in settings)
- Full roster of planners and their domains
- Delegation protocol: receive request from Duong → launch planner → delegate → track → report back
- "You stay hands-free. Your job is routing, coordination, and managing multiple parallel workstreams."
- "You never write plans, implement code, or review PRs."
- Session closing protocol
- Boot sequence: read own profile, memory, roster

#### 3c. Planner Instructions

**File:** `agents/planner-instructions.md`

Key sections:
- Identity: "You are a planner agent. You design plans and manage workers."
- Model: Opus (launched with `--model opus`)
- "You receive tasks from the coordinator. You design plans, break them down, and delegate implementation to workers."
- Plan approval: "Write plans to `plans/proposed/`. Duong approves by moving to `plans/approved/`. Once approved, autonomously delegate implementation to workers — no further check-ins."
- Worker management: how to use `launch_worker`, `delegate_task`, `check_delegations`
- "Workers report back to you. Synthesize their results and report to the coordinator."
- "You do NOT know other planners exist. You only see your workers and the coordinator."
- Escalation: report blockers to coordinator via `report_to_coordinator`
- Boot sequence: read own memory, task from inbox

#### 3d. Worker Instructions

**File:** `agents/worker-instructions.md`

Key sections:
- Identity: "You are a work agent. You execute tasks given to you."
- Model: Sonnet (launched with `--model sonnet`)
- **No roster, no agent names, no peer references**
- "You are the only agent. Report all results via `report_to_planner`."
- Boot sequence: read own `memory/` and task from `inbox/`
- Available tools: only `report_to_planner` and `get_my_task`
- Escalation: "If blocked, use `report_to_planner` with type `blocker`."
- Session closing: memory update only (simplified)

**Files to create:**
- `agents/coordinator-instructions.md`
- `agents/planner-instructions.md`
- `agents/worker-instructions.md`
- Update workspace `CLAUDE.md` with routing

### Phase 4: MCP Configuration

**Goal:** Single project-scoped `.mcp.json` that adapts based on env vars.

**File:** `~/Documents/Work/mmp/workspace/.mcp.json`

```json
{
  "mcpServers": {
    "work-agent-manager": {
      "command": "python",
      "args": ["-m", "work_agent_manager"],
      "cwd": "./agents/mcps/work-agent-manager",
      "env": {
        "AGENT_ROLE": "${AGENT_ROLE:-coordinator}",
        "AGENT_NAME": "${AGENT_NAME:-coordinator}",
        "AGENT_BASE_DIR": "./agents",
        "ASSIGNED_PLANNER": "${ASSIGNED_PLANNER:-}"
      }
    }
  }
}
```

**How it works:**
- **Duong opens Claude manually** → `AGENT_ROLE` unset → defaults to `coordinator` → coordinator tools exposed
- **Coordinator launches planner** → launch tool sets `AGENT_ROLE=planner` → planner tools exposed
- **Planner launches worker** → launch tool sets `AGENT_ROLE=worker` + `ASSIGNED_PLANNER=<name>` → worker tools exposed

Single `.mcp.json`, three behaviors. No separate profiles needed.

### Phase 5: Agent Migration

**Goal:** Convert existing work agents to isolated model.

**Steps:**

1. **Retire Azir as coordinator** — Coordinator takes over. Azir becomes a worker or is removed.

2. **Strip agent personalities:**
   - For each agent in `agents/<name>/profile.md`:
     - Remove backstory, speaking style, quirks, personality
     - Keep: role description, capabilities, domain expertise
     - Or replace with generic: "Worker agent specializing in <domain>"

3. **Remove `agent-network.md` from worker boot:**
   - Delete or move `agents/memory/agent-network.md` to `agents/coordinator/memory/` (coordinator-only)
   - Worker boot sequence reads only: own `profile.md`, own `memory/<name>.md`, task from `inbox/`

4. **Update worker profiles** to reference `report_to_planner` instead of `message_agent`

5. **Clean up roster:**
   - Create `agents/coordinator/roster.md` — coordinator-only file listing all workers and capabilities
   - Remove shared `agents/roster.md` (or restrict to coordinator directory)

### Phase 6: Testing & Verification

**Goal:** End-to-end validation of isolated architecture.

**Test sequence:**

1. Duong opens Claude in `~/Documents/Work/mmp/workspace/` and says "Hey Coordinator"
   - CLAUDE.md routing activates coordinator instructions
   - `.mcp.json` defaults to coordinator mode (AGENT_ROLE unset → coordinator)

2. Coordinator delegates a task to a planner:
   - `delegate_task` writes to planner inbox
   - `launch_agent` starts planner in iTerm with Opus + planner MCP

3. Planner receives task, designs plan, writes to `plans/proposed/`

4. Duong approves plan (moves to `plans/approved/`)

5. Planner delegates implementation to workers:
   - `launch_worker` starts worker in iTerm with Sonnet + worker MCP
   - `delegate_task` writes to worker inbox

6. Worker executes and reports back to planner via `report_to_planner`

7. Planner synthesizes worker results and reports to Coordinator via `report_to_coordinator`

8. Coordinator reports to Duong

9. **Isolation checks:**
   - Worker runs `list_agents` → tool not found (pass)
   - Worker runs `report_to_coordinator` → tool not found (pass)
   - Worker knows planner name only via `$ASSIGNED_PLANNER` (pass)
   - Planner runs `list_agents` → tool not found (pass)
   - Planner knows only Coordinator and own workers (pass)
   - Worker's CLAUDE.md mentions no agent names → pass
   - No Strawberry MCP servers visible in work project → pass

## Risks and Mitigations

| Risk                                                     | Mitigation                                                                                                  |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Workers can't resolve technical questions without peers  | Planner mediates: worker reports blocker → planner queries another worker or resolves directly              |
| Coordinator becomes bottleneck                                  | Coordinator is hands-free — only routes to planners. Planners handle the heavy lifting. Multiple planners run in parallel |
| Planner becomes bottleneck for its workers               | Planner is Opus with large context. Can run multiple workers in parallel                                    |
| Extra latency from three tiers                           | Accepted tradeoff for Coordinator staying free to manage multiple concurrent workstreams                           |
| Slower than peer-to-peer for technical discussions       | Accepted tradeoff for isolation. Work context values control over speed                                     |
| Workers might hallucinate agent names from training data | Worker CLAUDE.md explicitly states "you are the only agent" — no roster to contradict this                  |
| Coordinator MCP tools visible to planners/workers if env var not set | Launch script always sets AGENT_ROLE; `.mcp.json` defaults to coordinator only for manual sessions |

## File Inventory

**New files to create:**

| File | Purpose |
| --- | --- |
| `workspace/CLAUDE.md` | Greeting-based routing (like Strawberry) |
| `workspace/.mcp.json` | Project-scoped MCP, defaults to coordinator mode |
| `agents/scripts/launch-work-agent.sh` | Programmatic launcher for planners/workers |
| `agents/mcps/work-agent-manager/` | Forked MCP with coordinator/planner/worker split |
| `agents/coordinator-instructions.md` | Coordinator instructions |
| `agents/planner-instructions.md` | Planner instructions |
| `agents/worker-instructions.md` | Worker instructions |
| `agents/coordinator/roster.md` | Coordinator-only agent roster |

**Files to modify:**

| File | Change |
| --- | --- |
| `agents/<worker>/profile.md` (each) | Strip personality, keep capabilities only |
| `agents/coordinator/profile.md` | Update to coordinator role |

**Files to remove/relocate:**

| File | Action |
| --- | --- |
| `agents/memory/agent-network.md` | Move to `agents/coordinator/memory/` (coordinator-only) |
| `agents/roster.md` (shared) | Replace with `agents/coordinator/roster.md` |


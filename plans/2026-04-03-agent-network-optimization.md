---
status: draft
owner: syndra
created: 2026-04-03
title: Agent Network Optimization
---

# Agent Network Optimization — Implementation Plan

Executor: **Bard** (MCP Specialist)
Primary file: `mcps/agent-manager/server.py`

All changes are additive — no existing tool signatures change.

---

## Phase 0: Bug Fix — Sender Not Auto-Added to Participants

**Goal:** Fix `start_conversation` so the sender is always included in participants.

**Problem:** When an agent calls `start_conversation(sender="evelynn", participants=["syndra"], ...)`, only `syndra` is recorded in the participants list. The sender (Evelynn) is never added. This means `_ping_agents` never notifies the sender of replies — they're silently excluded from their own conversation.

**Fix in `start_conversation`** (server.py, around line 840):

```python
# Ensure sender is in participants
all_participants = list({p.lower() for p in participants} | {sender.lower()})
participant_str = ', '.join(sorted(all_participants))
```

Replace the current `participant_str` line. This is a one-line fix. Do it first.

---

## Phase 1: Agent Status Registry

**Goal:** Enable agents to report their status and Evelynn (or any agent) to check who's available before delegating.

### 1a. Health registry file

Create `agents/health/registry.json` with structure:

```json
{
  "evelynn": {
    "status": "busy",
    "last_heartbeat": "2026-04-03T09:30:00",
    "platform": "cli",
    "current_task": "coordinating network optimization"
  },
  "syndra": {
    "status": "idle",
    "last_heartbeat": "2026-04-03T09:34:00",
    "platform": "cli",
    "current_task": null
  }
}
```

Valid statuses: `offline`, `idle`, `busy`.

### 1b. Update heartbeat script

File: `agents/health/heartbeat.sh`

Modify to accept optional 3rd and 4th args: `status` and `current_task`.

```bash
# Usage: heartbeat.sh <agent_name> <platform> [status] [current_task]
```

Write to `agents/health/registry.json` using `jq`:

```bash
STATUS=${3:-idle}
TASK=${4:-null}
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")

jq --arg name "$NAME" --arg status "$STATUS" --arg ts "$TIMESTAMP" \
   --arg platform "$PLATFORM" --arg task "$TASK" \
   '.[$name] = {status: $status, last_heartbeat: $ts, platform: $platform, current_task: (if $task == "null" then null else $task end)}' \
   "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
```

### 1c. New MCP tool: `agent_status`

Add to `server.py`:

```python
@mcp.tool()
async def agent_status(name: Optional[str] = None) -> dict:
    """Check agent status. If name is given, returns that agent's status.
    If omitted, returns all agents with status.

    Args:
        name: Optional agent name. If omitted, returns all.
    """
```

Implementation:
- Read `agents/health/registry.json`
- If `name` given, return that entry (or `{"status": "offline"}` if missing)
- If no `name`, merge with `_scan_agents()` — agents not in registry are `offline`
- Mark agents as `offline` if `last_heartbeat` is older than 5 minutes

### 1d. Auto-set busy/idle in launch_agent and end_all_sessions

- In `launch_agent`: after successful launch, write status `idle` to registry
- In `end_all_sessions`: set status to `offline` for ended agents
- Agents themselves should call heartbeat with `busy` when they start a task, `idle` when done

---

## Phase 2: Delivery Confirmation

**Goal:** Senders can know whether their message was received and processed.

### 2a. Extend inbox file status values

Current: `pending` → `read`
New: `pending` → `read` → `acknowledged`

No schema change needed — agents already update the `status` field in frontmatter. Just document the new value.

### 2b. New MCP tool: `check_inbox_status`

```python
@mcp.tool()
async def check_inbox_status(
    recipient: str,
    sender: Optional[str] = None,
    since_minutes: int = 30,
) -> list[dict]:
    """Check delivery status of messages sent to an agent.

    Args:
        recipient: Agent whose inbox to check
        sender: Optional filter by sender
        since_minutes: Only check messages from the last N minutes (default 30)
    """
```

Implementation:
- Scan `agents/<recipient>/inbox/` for `.md` files
- Parse frontmatter for `from`, `status`, `timestamp`
- Filter by `sender` and `since_minutes` if provided
- Return list of `{filename, from, status, timestamp, conversation}`

### 2c. New MCP tool: `acknowledge_message`

```python
@mcp.tool()
async def acknowledge_message(
    agent: str,
    filename: str,
    response: str = "acknowledged",
) -> str:
    """Mark an inbox message as acknowledged and optionally record a short response.

    Args:
        agent: The agent acknowledging (must match the 'to' field)
        filename: Inbox filename to acknowledge
        response: Optional short response text
    """
```

Implementation:
- Read the inbox file at `agents/<agent>/inbox/<filename>`
- Update `status: read` → `status: acknowledged`
- Append `response: <response>` to frontmatter
- Return confirmation

---

## Phase 3: Conversation Polling for Large Groups

**Goal:** Reduce inbox spam when 3+ agents are in a conversation.

### 3a. Add `notify_mode` to conversation frontmatter

When a conversation is created with 3+ participants, add:

```yaml
notify_mode: poll
poll_interval_seconds: 60
```

For 2-participant conversations, keep current behavior (`notify_mode: push`).

### 3b. Modify `_ping_agents` behavior

In `_ping_agents`, check participant count:
- If 2 participants: current behavior (write inbox + iTerm pointer)
- If 3+ participants: only ping agents who haven't been pinged in the last `poll_interval_seconds`. Track last-ping time by adding a `last_notified` dict to the conversation frontmatter:

```yaml
last_notified:
  evelynn: 2026-04-03T09:34:00
  syndra: 2026-04-03T09:30:00
```

### 3c. New MCP tool: `poll_conversations`

```python
@mcp.tool()
async def poll_conversations(
    agent: str,
    since_minutes: int = 10,
) -> list[dict]:
    """Check for new messages in conversations the agent participates in.

    Args:
        agent: Agent name
        since_minutes: Only return conversations modified in the last N minutes
    """
```

Implementation:
- Scan `agents/conversations/` for files where `agent` is in participants
- Filter by `last_modified > now - since_minutes`
- Return list of `{title, file, last_modified, message_count, unread_estimate}`
- `unread_estimate`: count messages after the agent's last `message_in_conversation` timestamp

---

## Phase 4: Message Ordering / File Locking

**Goal:** Prevent interleaved writes to conversation files.

### 4a. Add file locking to `_append_message`

```python
import fcntl

def _append_message(path: Path, sender: str, message: str):
    with open(path, 'a') as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        try:
            f.write(f'\n## {sender.capitalize()} — {_timestamp()}\n{message}\n')
        finally:
            fcntl.flock(f, fcntl.LOCK_UN)
```

### 4b. Add sequence numbers to messages

Append a monotonic sequence number to each message heading:

```markdown
## Syndra — 2026-04-03 09:34 [#3]
```

To get the next number, count existing `## ` headings in the file before appending. This happens inside the lock so it's safe.

---

## Phase 5: Workflow Templates (Future)

**Goal:** Define reusable agent chains that auto-trigger without Evelynn orchestrating every step.

### 5a. Workflow definition format

Create `agents/workflows/` directory. Each workflow is a YAML file:

```yaml
# agents/workflows/build-test-review.yaml
name: build-test-review
description: Standard feature pipeline
steps:
  - agent: ornn
    action: build
    on_complete: next
  - agent: caitlyn
    action: test
    on_complete: next
  - agent: lissandra
    action: review
    on_complete: notify_evelynn
trigger: manual
```

### 5b. New MCP tool: `start_workflow`

```python
@mcp.tool()
async def start_workflow(
    workflow: str,
    context: str,
    initiated_by: str = "evelynn",
) -> dict:
    """Start a predefined workflow.

    Args:
        workflow: Workflow name (filename without .yaml)
        context: Task context to pass to the first agent
        initiated_by: Who initiated the workflow
    """
```

Implementation:
- Read workflow YAML
- Create a conversation for the workflow
- Launch or message the first agent with the context
- Write a workflow state file to `agents/workflows/active/<workflow>-<timestamp>.json` tracking current step

### 5c. New MCP tool: `advance_workflow`

Called by agents when they complete their step:

```python
@mcp.tool()
async def advance_workflow(
    workflow_id: str,
    agent: str,
    result: str,
) -> dict:
    """Mark current step complete and trigger the next agent.

    Args:
        workflow_id: Active workflow instance ID
        agent: Agent completing the step
        result: Summary of what was done
    """
```

This is the most complex addition and should only be built when multi-agent pipelines become a real use case.

---

## Phase 6: Conversation Filtering

**Goal:** Make `list_conversations` more useful.

### 6a. Add filters to `list_conversations`

Update the existing tool signature:

```python
@mcp.tool()
async def list_conversations(
    participant: Optional[str] = None,
    since: Optional[str] = None,
    title_contains: Optional[str] = None,
) -> list[dict[str, str]]:
    """List conversations with optional filters.

    Args:
        participant: Filter by participant name
        since: Filter by date (YYYY-MM-DD format)
        title_contains: Filter by title substring
    """
```

Implementation:
- Keep existing logic
- After building results list, filter:
  - `participant`: check if name is in the participants list
  - `since`: parse date string, compare against `last_modified`
  - `title_contains`: case-insensitive substring match on title

---

## Execution Order

| Phase | Priority | Complexity | Dependencies |
|-------|----------|------------|--------------|
| 1 — Status Registry | High | Medium | None |
| 2 — Delivery Confirmation | High | Low | None |
| 4 — File Locking | Medium | Low | None |
| 6 — Conversation Filtering | Medium | Low | None |
| 3 — Conversation Polling | Medium | Medium | Phase 4 |
| 5 — Workflow Templates | Low | High | Phases 1, 2 |

Phases 1, 2, 4, and 6 can be implemented in parallel. Phase 3 depends on 4 (locking). Phase 5 depends on 1 and 2.

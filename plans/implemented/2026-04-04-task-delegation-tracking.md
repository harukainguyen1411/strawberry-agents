---
status: implemented
owner: syndra
gdoc_id: 18CPKJBDHYvpa3b0XV6WfARTE4TbgLz1yWhVgwQkhp5Y
gdoc_url: https://docs.google.com/document/d/18CPKJBDHYvpa3b0XV6WfARTE4TbgLz1yWhVgwQkhp5Y/edit
---

# Task Delegation Tracking — Design Proposal

**Problem:** Evelynn delegates tasks via `message_agent` but has no way to know if agents completed them. Protocol rule #7 says "report back when done" but compliance is inconsistent. Evelynn shouldn't have to wonder.

## Root cause

The current system has no concept of a "delegated task." `message_agent` is fire-and-forget — once sent, there's no tracking. An agent might read the message, do the work, and forget to report. Or crash. Or get stuck. Evelynn has no visibility.

## Design: Delegation Ledger

A simple ledger that tracks: what was delegated, to whom, when, and whether it's been resolved.

### New tool: `delegate_task`

Replaces `message_agent` for task assignments (message_agent stays for casual FYI messages).

```python
@mcp.tool()
async def delegate_task(
    sender: str,        # who's delegating (usually evelynn)
    agent: str,         # who's receiving the task
    task: str,          # task description
    deadline: str = "", # optional: "5m", "15m", "30m", or ISO timestamp
) -> dict:
    """Delegate a task to an agent with tracking.
    Creates a tracked delegation entry and delivers via inbox.
    The receiving agent must call complete_task when done."""
```

What it does:
1. Creates a delegation record in `agents/delegations/<id>.json`
2. Sends the task via inbox (same as message_agent)
3. Returns a delegation ID for tracking

Delegation record:
```json
{
  "id": "d-20260404-1524-001",
  "sender": "evelynn",
  "agent": "reksai",
  "task": "Review PR #15 — check performance and concurrency",
  "status": "pending",
  "created": "2026-04-04T15:24:00Z",
  "deadline": "2026-04-04T15:39:00Z",
  "completed_at": null,
  "report": null
}
```

### New tool: `complete_task`

Called by the agent when they finish:

```python
@mcp.tool()
async def complete_task(
    agent: str,
    delegation_id: str,
    report: str,
) -> dict:
    """Mark a delegated task as complete with a summary report.
    Automatically notifies the delegating agent."""
```

What it does:
1. Updates delegation status to `"completed"`
2. Stores the report
3. Sends a notification to the delegator (via inbox)

### New tool: `check_delegations`

For Evelynn to see what's outstanding:

```python
@mcp.tool()
async def check_delegations(
    sender: str = "",    # filter by who delegated
    agent: str = "",     # filter by who received
    status: str = "",    # filter: pending, completed, overdue
) -> list[dict]:
    """Check status of delegated tasks. Returns all matching delegations."""
```

Auto-marks tasks as `"overdue"` if past deadline and still pending.

### Protocol changes

In agent-network.md, update the inbox delivery section:

> When you receive a delegated task (inbox message with a `delegation_id`), you MUST call `complete_task` when finished. This is not optional — it's how Evelynn tracks work.

The inbox message from `delegate_task` will include the delegation ID prominently:

```
[TASK d-20260404-1524-001] Review PR #15 — check performance and concurrency
Deadline: 2026-04-04 17:00
When done: complete_task(agent=reksai, delegation_id=d-20260404-1524-001, report=<summary>)
```

This makes it hard for agents to miss — the completion instruction is right in the message.

### Evelynn's workflow

1. Delegate: `delegate_task(sender=evelynn, agent=reksai, task="Review PR #15", deadline="15m")`
2. Check anytime: `check_delegations(status=pending)` — see all outstanding work
3. Get notified automatically when agents call `complete_task`
4. Spot overdue: `check_delegations(status=overdue)` — follow up with agents who haven't reported

### What about agents who crash or get restarted?

On startup, agents should check for open delegations assigned to them:
```
check_delegations(agent=<self>, status=pending)
```
If they find pending tasks, they pick them up. Add this to the startup sequence in CLAUDE.md.

## What we're NOT doing

- **No auto-reminders/pinging** — Evelynn checks manually. Auto-ping risks interrupting agents mid-work.
- **No complex workflow states** — just pending/completed/overdue. No "in progress", no sub-tasks. Keep it simple.
- **No replacing message_agent** — `message_agent` stays for FYI/casual messages. `delegate_task` is for tracked work only.
- **No approval flows** — agents can't reject tasks. If they're blocked, they escalate via the existing escalation system.

## Implementation

1. Create `agents/delegations/` directory (or under ops path if set)
2. Add three tools to agent-manager: `delegate_task`, `complete_task`, `check_delegations`
3. Update agent-network.md protocol
4. Update agent startup sequence to check pending delegations

Estimated scope: ~150 lines of Python, protocol doc updates. Bard can build it.

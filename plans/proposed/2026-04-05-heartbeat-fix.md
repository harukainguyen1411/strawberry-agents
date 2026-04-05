---
title: Fix heartbeat system — piggyback on MCP tool calls
status: in-progress
owner: bard
created: 2026-04-05
---

# Problem

Agents call `heartbeat.sh` once at startup. After 5 minutes with no further heartbeat, the registry shows them as "offline" even though they're actively working.

# Solution

Add a lightweight `_touch_heartbeat(agent, status="active")` helper in `mcps/shared/helpers.py` that updates only `last_heartbeat` and `status` in the registry (preserving other fields like `context_health`). Then call it from these high-frequency MCP tools in `server.py`:

- `message_agent` — sender heartbeat (every outbound message)
- `speak_in_turn` — sender heartbeat (every conversation turn)
- `complete_task` — agent heartbeat (task completion)
- `report_context_health` — already updates `last_heartbeat`, no change needed

This is a minimal, non-breaking change. No new tools, no new protocols, no agent-side changes needed.

# Implementation

1. Add `touch_heartbeat(name, status)` to `mcps/shared/helpers.py`
2. Import and call it in the 3 tools above (message_agent sender, speak_in_turn sender, complete_task agent)
3. Test by checking registry updates after tool calls

# Files changed

- `mcps/shared/helpers.py` — new `touch_heartbeat` function
- `mcps/agent-manager/server.py` — import + 3 call sites

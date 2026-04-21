---
title: Restart safeguards — auto-exclude caller & prevent end/restart confusion
status: proposed
owner: bard
created: 2026-04-05
---

# Problem

Two issues with the restart/end-session tools:

1. **Self-restart risk**: `restart_agents` accepts an `exclude` list but doesn't auto-exclude the calling agent. Evelynn must remember to pass `exclude=["evelynn"]` every time — and if she forgets, she restarts herself mid-operation.

2. **Tool confusion**: Evelynn has called `end_all_sessions` when Duong said "restart" — twice. The tool names are similar enough (`restart_agents` vs `end_all_sessions`) that an LLM confuses them under time pressure.

# Solution

## Fix 1: Auto-exclude caller in `restart_agents`

Add a `sender` parameter to `restart_agents` (like `end_all_sessions` already has). The tool auto-adds the sender to the exclude set.

```python
async def restart_agents(sender: str, exclude: Optional[list[str]] = None) -> dict[str, Any]:
    exclude_set = {n.lower() for n in (exclude or [])}
    exclude_set.add(sender.lower().strip())  # Always exclude caller
```

This is backward-compatible — existing callers just need to add `sender`.

## Fix 2: Prevent end/restart confusion

Three complementary measures:

### A. Rename `end_all_sessions` → `shutdown_all_agents`

The word "end" is too close to "restart" semantically. "Shutdown" is unambiguous and clearly destructive. Update the tool name, description, and all references.

### B. Add a confirmation gate to `shutdown_all_agents`

Require a `confirm` parameter that must be the literal string `"yes-shutdown"`:

```python
async def shutdown_all_agents(sender: str, confirm: str, exclude: Optional[list[str]] = None):
    if confirm != "yes-shutdown":
        raise ToolError("To shut down all agents, pass confirm='yes-shutdown'. Did you mean restart_agents instead?")
```

The error message explicitly suggests `restart_agents` as an alternative — nudging the LLM toward the right tool if it called the wrong one.

### C. Add clarifying descriptions

Update both tool docstrings to contrast themselves:

- `restart_agents`: "Restart all running agents (exit + resume same session). Does NOT end sessions or trigger closing protocol. Use this when Duong says 'restart'."
- `shutdown_all_agents`: "PERMANENTLY end all agent sessions with closing protocol (journal, handoff, memory). This is IRREVERSIBLE — agents lose their session context. Only use when Duong explicitly says 'end sessions' or 'shut down'."

# Files changed

- `mcps/agent-manager/server.py` — add `sender` param to `restart_agents`, update docstring
- `mcps/evelynn/server.py` — rename `end_all_sessions` → `shutdown_all_agents`, add `confirm` gate, update docstring
- `mcps/shared/helpers.py` — no changes needed

# Risk

Low. Tool rename means Evelynn's next session will see the new name. No other agents call these tools (both are Evelynn-restricted).

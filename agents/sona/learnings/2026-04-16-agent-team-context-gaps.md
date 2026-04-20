# Agent teams lack context for deep refactoring

## Problem
Spawning 8 agents for a Step 0 refactor (managed agent → direct Claude API) produced multiple bugs:
- Missing import (tools.py imported get_config from session.py before it existed)
- Stale test patches across 6+ files (create_managed_session still referenced)
- Sync Firestore writes inside async generator silently failing
- Duplicate /history route (same function name, FastAPI shadowing)

Each bug required relaying context back and forth between coordinator and agents, which was slower than doing it directly.

## Lesson
- Agent teams work well for **well-scoped, context-light tasks** (write tests for a spec, build a new module from scratch)
- For **deep refactoring** where every file is connected and changes cascade, hands-on is faster
- When delegating, send **detailed briefs** with full context, not one-line summaries
- Always write tests BEFORE fixing bugs — the bug is proof of a missing test

## Also learned
- Synchronous I/O inside Python async generators silently fails — use run_in_executor or move the I/O out of the generator
- FastAPI silently overwrites routes when two functions have the same name, even at different line numbers
- uvicorn --workers spawns separate processes that can cache stale bytecode — clear __pycache__ on restart

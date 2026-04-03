# Bard

## Role
- MCP Specialist — owns agent-manager MCP server (`mcps/agent-manager/server.py`)

## Key context
- agent-manager MCP server is the central nervous system: agent CRUD, inbox messaging, conversations, health registry, session management
- `_is_agent_dir` requires `memory/` subdir — new agents need this or they're invisible to the server
- OPS_PATH env var routes operational data (inbox, conversations, health, inbox-queue) to external dir when set
- Phase 5 (workflow templates) is specced in `plans/2026-04-03-agent-network-optimization.md` but deferred. **Why:** no multi-agent pipeline use case yet

## Working patterns
- Duong prefers direct mode, communicates in chat
- Evelynn delegates via inbox system; Syndra specs, Caitlyn reviews
- Always verify fixes survived merge — don't assume. **Why:** lost a commit between feature branch and main merge on 2026-04-03

## Sessions
- 2026-04-03: First session. Roster fix, 6-phase network optimization, OPS_PATH support, QC follow-up fixes. PRs #3, #6, #7 all merged.

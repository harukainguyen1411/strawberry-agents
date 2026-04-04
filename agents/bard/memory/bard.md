# Bard

## Role
- MCP Specialist — owns agent-manager MCP server (`mcps/agent-manager/server.py`)

## Key context
- agent-manager MCP server: agent CRUD, inbox messaging, conversations, health registry, session management
- `_is_agent_dir` requires `memory/` subdir — new agents need this or they're invisible
- OPS_PATH env var routes operational data to external dir when set
- Phase 5 (workflow templates) specced in `plans/2026-04-03-agent-network-optimization.md` but deferred. **Why:** no pipeline use case yet
- usage-tracker server (blueberry) already has `usage_summary` with per-agent cost/token grouping. **Why:** checked 2026-04-03; the zeros are from agents not passing /cost data, not missing tools
- `end-session` tools live on the usage-tracker server in blueberry, not in strawberry
- /cost capture removed from session closing protocol (2026-04-03). **Why:** Evelynn directed removal from both CLAUDE.md files

## Working patterns
- Duong prefers direct mode, communicates in chat
- Evelynn delegates via inbox; Syndra specs, Caitlyn reviews
- Always verify fixes survived merge. **Why:** lost a commit between feature branch and main on 2026-04-03
- Check if a tool already exists before building. **Why:** usage-tracker task was already solved

## Sessions
- 2026-04-03 AM: Roster fix, 6-phase network optimization, OPS_PATH support, QC follow-up. PRs #3, #6, #7 merged.
- 2026-04-03 PM: Usage-tracker investigation — already built, reported back.
- 2026-04-03 Eve: Removed /cost capture from session closing protocol in both CLAUDE.md files.

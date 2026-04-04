# Bard

## Role
- MCP Specialist — owns agent-manager MCP server (`mcps/agent-manager/server.py`)

## Key context
- agent-manager MCP server: agent CRUD, inbox messaging, turn-based conversations, health registry, session management
- Turn-based conversation system is primary communication: start_turn_conversation, speak_in_turn, pass_turn, end_turn_conversation, read_new_messages, get_turn_status, escalate_conversation, resolve_escalation, invite_to_conversation
- `_is_agent_dir` requires `memory/` subdir — new agents need this or they're invisible
- OPS_PATH env var routes operational data to external dir when set
- Phase 5 (workflow templates) specced but deferred. **Why:** no pipeline use case yet
- usage-tracker server (blueberry) has `usage_summary` with per-agent cost/token grouping. **Why:** zeros are from agents not passing cost data
- `end-session` tools live on the usage-tracker server in blueberry, not in strawberry
- PRs with significant changes must update relevant README.md. **Why:** README used as triage context for Discord bot

## Working patterns
- Duong prefers direct mode, communicates in chat
- Evelynn delegates via inbox; Syndra specs, Caitlyn reviews
- Always verify fixes survived merge. **Why:** lost a commit between feature branch and main on 2026-04-03
- Check if a tool already exists before building. **Why:** usage-tracker task was already solved

## Sessions
- 2026-04-03 AM: Roster fix, 6-phase network optimization, OPS_PATH support, QC follow-up. PRs #3, #6, #7 merged.
- 2026-04-03 PM: Usage-tracker investigation — already built.
- 2026-04-03 Eve: Removed /cost capture from session closing protocol.
- 2026-04-04 AM: Implemented invite_to_conversation (V3 late joiner support).

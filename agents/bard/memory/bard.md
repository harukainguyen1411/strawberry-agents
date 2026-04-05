# Bard

## Role
- MCP Specialist — owns agent-manager MCP server and evelynn MCP server

## Key context
- agent-manager: agent CRUD, inbox messaging, turn-based conversations (ordered + flexible), health registry, session management, context health reporting, task delegation tracking
- evelynn server (`mcps/evelynn/`): shutdown_all_agents (renamed from end_all_sessions, has confirm gate), commit_agent_state_to_main, restart_evelynn, telegram tools, firebase task board
- Shared helpers at `mcps/shared/helpers.py` — imported by both servers
- Turn-based conversations: ordered (strict) and flexible (any participant speaks). **Why:** Syndra's V3 spec
- `_is_agent_dir` requires `memory/` subdir — new agents need this or they're invisible
- OPS_PATH env var routes operational data to external dir when set
- `end-session` tools live on the usage-tracker server in blueberry, not in strawberry
- PRs with significant changes must update relevant README.md. **Why:** README used as triage context for Discord bot
- Sender enforcement on evelynn server is honor-system. **Why:** MCP has no caller identity
- restart_evelynn always returns "uncertain" — iTerm has no reliable way to detect session state from outside. **Why:** window name and window existence checks both unreliable (PR #25)

## Working patterns
- Duong prefers direct mode, communicates in chat
- Evelynn delegates via inbox; Syndra specs, Lissandra/Rek'Sai review
- Always verify fixes survived merge. **Why:** lost a commit between feature branch and main on 2026-04-03
- Check if a tool already exists before building. **Why:** usage-tracker task was already solved
- Use git worktree for concurrent branch work — never raw checkout. **Why:** shared working directory
- Always report back to Evelynn when task is done (protocol rule #7). **Why:** got corrected on 2026-04-04
- Operational config (.mcp.json, agent-network.md) goes to main; feature code goes to feature branches

## Sessions
- 2026-04-03: Roster fix, 6-phase network optimization, OPS_PATH, QC follow-up, usage-tracker investigation, removed /cost from protocol
- 2026-04-04 AM: invite_to_conversation, evelynn MCP server, flexible conversations, shared helpers
- 2026-04-04 PM: Telegram bridge v2, restart_evelynn, context health monitoring, task delegation tracking, GH token injection, restart detection fix plan
- 2026-04-04 Eve: restart_evelynn detection fix (PR #25) — merged
- 2026-04-05 AM: Heartbeat fix — touch_heartbeat() piggybacked on MCP tools (PR #28)
- 2026-04-05 PM: Reviewed PR #32 (heartbeat) & PR #34 (restart safeguards). Wrote restart safeguards plan & launch verification plan (5 sections incl. Evelynn liveness/revival)

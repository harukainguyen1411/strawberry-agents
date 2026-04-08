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
- 2026-04-04/05: evelynn MCP server, telegram bridge, heartbeat fix, restart safeguards, launch verification plan
- 2026-04-08: Wrote agent-visible-frontend-testing plan (proposed) — MVP reuses existing Playwright, new e2e/agent-verify.spec.ts + npm run verify:frontend; Phase 2 adopts/builds Playwright MCP; recommended pipeline gate placement (c) both local pre-PR and preview pre-Discord; skip Storybook for MVP. Slots into Syndra's autonomous-delivery-pipeline plan.
- 2026-04-08: Wrote /end-session skill plan (proposed) — jsonl cleaner (Python), transcripts/ dir, 11-step close orchestration, hosts Syndra Component A condenser, supersedes v1 /close-session. Recommended split into /end-session + /end-subagent-session because Sonnet subagents have no own jsonl. Phase 1 ships without condenser; Phase 2 wires it in.

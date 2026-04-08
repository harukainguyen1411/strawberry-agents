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
- 2026-04-09 (subagent): Wrote detailed Phase 1 execution spec at plans/proposed/2026-04-09-mcp-restructure-phase-1-detailed.md. Frozen decisions D1–D7 (two comms MCPs, archive not delete, no muscle-memory carve-outs, delete restart_evelynn, defer marketplace, one umbrella /agent-ops skill only, /end-session already shipped). First-class cross-platform parity section: POSIX-only skill bodies, scripts/mac/ + scripts/windows/ split, architecture/platform-parity.md. /agent-ops subcommand set pinned to send|list|new (no delegate/converse/launch). Single-commit landing for call-site sweep + MCP deregister + skill create + archive README. Exit test = round-trip via /agent-ops from fresh session. Katarina executable.
- 2026-04-08 (subagent): Wrote rough MCP restructure plan at plans/proposed/2026-04-08-mcp-restructure.md. Governing invariant: project MCPs only for external integration; local coordination → skills+rules+scripts. Phase 1 replaces agent-manager with /agent-ops skill + scripts (smallest blast radius). Phase 2 splits evelynn three ways: agent-lifecycle skill (shutdown-all, commit-state, drop restart_evelynn), mcps/telegram/, mcps/task-board/. Phase 3 governance + cleanup. Cross-refs Katarina's /end-session (shared commit-agent-state.sh helper, option b — distinct skills share helpers). Honor-system sender check disappears free because skills run in caller context. Open questions: one vs two external-comms MCPs, archive vs delete, marketplace plugins (telegram/firebase), skill-count cap umbrella-fold, restart_evelynn fate.
- 2026-04-08 (subagent): Wrote detailed Phase 1 execution spec for /end-session at plans/ready/2026-04-08-end-session-skill-phase-1.md (commit 54ff313). Introduced new plans/ready/ tier. Folded in Duong's 4 decisions (two-skill split, supersede v1 /close-session, commit transcripts, ship independent of condenser) and 3 amendments (universal scope + CLAUDE.md rule 14, .gitignore negation for agents/*/transcripts/*.md, verify Katarina's c633f4a allowlist fix). Single-commit Phase 1: scripts/clean-jsonl.py (Python stdlib, ~300 lines, session-chain-by-mtime, 3-exit-code secret denylist), .claude/skills/end-session/SKILL.md + .claude/skills/end-subagent-session/SKILL.md (folded sub-skill into Phase 1 not Phase 1.5), CLAUDE.md rule 14 mandatory skill invocation, .gitignore negate cleaned transcripts, rewrite agent-network.md Session Closing Protocol to point at skills, .gitkeep placeholders for ~15 agent transcript dirs. Smoke test is diff-against-existing S23 reference transcript (2026-04-08-cafe-to-home-session.md, 309 turns). Katarina picks up execution. Phase 2 spec'd: hard enforcement hook (marker file), condenser wire-up (reads cleaned Markdown not raw jsonl — asserted constraint on Syndra component A). Did NOT touch any approved plan files or agent profile frontmatter.

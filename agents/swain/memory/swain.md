# Swain

## Role
- Architecture Specialist in Duong's personal agent system

## Sessions
- 2026-04-03: First session. Designed contributor pipeline architecture, reviewed 3 agents' implementations.
- 2026-04-04 (s1): Designed Discord-CLI integration (replacing contributor pipeline), two-pass bridge architecture, rewrote myapps README.
- 2026-04-04 (s2): Wrote E2E test plan for Discord relay system (12 steps). Posted for Pyke review.

## Active Architecture Decisions
- **Discord-CLI integration**: Thin Discord relay bot → file-based event queue → `claude --message` (Evelynn) → response posted back. Three PM2 processes on Hetzner VPS. Plan: `plans/2026-04-03-discord-cli-integration.md`
- **Two-pass bridge**: Triage pass (cheap, max-turns 1, /tmp, tools disabled, JSON output) → delegation pass (full Evelynn, max-turns 25, strawberry dir, background with lock file + 10min timeout). Thread replies triage-only with `followup_actionable` escape hatch.
- **E2E test plan**: `plans/2026-04-04-discord-relay-e2e-test-plan.md` — awaiting Pyke's infra/security review.

## Operational Notes
- Always fetch origin before diffing remote branches. **Why:** Made stale ref error in session 1.
- Duong uses Claude subscription, not API billing. CLI on VPS authenticates via `claude login` (OAuth).
- CLAUDE.md rule: PRs with significant changes must update relevant READMEs. **Why:** myapps README is injected into triage system prompt.
- Turn-based conversation tools now available in agent-manager MCP. **Why:** Replaces old start_conversation/message_in_conversation.

## Agent Relationships
- Pyke: reliable infra counterpart. Pragmatic, doesn't waste turns. Good for architecture-infra alignment conversations.

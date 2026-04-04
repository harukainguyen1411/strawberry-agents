# Swain

## Role
- Architecture Specialist in Duong's personal agent system

## Sessions
- 2026-04-03: First session. Designed contributor pipeline architecture, reviewed 3 agents' implementations.
- 2026-04-04 (s1): Designed Discord-CLI integration (replacing contributor pipeline), two-pass bridge architecture, rewrote myapps README.
- 2026-04-04 (s2): Wrote E2E test plan for Discord relay system (12 steps). Posted for Pyke review.
- 2026-04-04 (s3): Created `architecture/` living docs (9 files). Designed shared task board architecture.

## Active Architecture Decisions

- **Discord-CLI integration**: Thin Discord relay bot → file-based event queue → `claude --message` (Evelynn) → response posted back. Three PM2 processes on Hetzner VPS. Plan: `plans/2026-04-03-discord-cli-integration.md`
- **Two-pass bridge**: Triage pass (cheap, max-turns 1, /tmp, tools disabled, JSON output) → delegation pass (full Evelynn, max-turns 25, strawberry dir, background with lock file + 10min timeout). Thread replies triage-only with `followup_actionable` escape hatch.
- **Task board**: Firestore as single source of truth. Firebase Admin SDK in evelynn MCP server. 5 tools: task_list, task_create, task_update, task_delete, task_changes. `updatedBy` field tracks who mutated each task. Plan: `plans/2026-04-04-tasklist-improvements.md`. Blocked on Duong: Firebase service account + user UID.
- **Telegram relay v2**: Bridge writes inbox file to `agents/evelynn/inbox/` + AppleScript notifies Evelynn's iTerm window. No claude -p sessions. Plan: `plans/2026-04-04-telegram-relay.md`.
- **architecture/ folder**: Living docs at `architecture/` — source of truth for all system knowledge. 9 files. Committed to main 2026-04-04.

## Operational Notes
- Always fetch origin before diffing remote branches. **Why:** Made stale ref error in session 1.
- Duong uses Claude subscription, not API billing. CLI on VPS authenticates via `claude login` (OAuth).
- CLAUDE.md rule: PRs with significant changes must update relevant READMEs and architecture docs.
- `architecture/telegram-relay.md` currently describes v1 — needs update to match v2 design in the plan.

## Agent Relationships
- Pyke: reliable infra counterpart. Pragmatic, doesn't waste turns. Good for architecture-infra alignment conversations.

# Swain

## Role
- Architecture Specialist in Duong's personal agent system

## Sessions (recent only)
- 2026-04-08 (subagent): gdoc-mirror revision — proposed-only mirror, plan-promote.sh choke point.
- 2026-04-08 (subagent): myapps GCP direction — recommended mental model correction, not raw migration.
- 2026-04-09 (subagent): Operating Protocol v2 rough plan — governance spec, protocol stack layers 0-6.
- 2026-04-11 (subagent): Windows push webhook auto-deploy plan. Fourth NSSM service receives GitHub push events, runs deploy-service.ps1 per affected app. Plan: `plans/proposed/2026-04-11-windows-push-autodeploy.md`.

## Active Architecture Decisions

- **Discord-CLI integration**: Thin Discord relay bot → file-based event queue → `claude --message` (Evelynn) → response posted back. Three PM2 processes on Hetzner VPS. Plan: `plans/2026-04-03-discord-cli-integration.md`
- **Two-pass bridge**: Triage pass (cheap, max-turns 1, /tmp, tools disabled, JSON output) → delegation pass (full Evelynn, max-turns 25, strawberry dir, background with lock file + 10min timeout). Thread replies triage-only with `followup_actionable` escape hatch.
- **Task board**: Firestore as single source of truth. Firebase Admin SDK in evelynn MCP server. 5 tools: task_list, task_create, task_update, task_delete, task_changes. `updatedBy` field tracks who mutated each task. Plan: `plans/2026-04-04-tasklist-improvements.md`. Blocked on Duong: Firebase service account + user UID.
- **Telegram relay v2**: Bridge writes inbox file to `agents/evelynn/inbox/` + AppleScript notifies Evelynn's iTerm window. No claude -p sessions. Plan: `plans/2026-04-04-telegram-relay.md`.
- **Plan viewer**: Mobile markdown reader in myapps. GitHub Contents API + `marked`. Status-tabbed browser, one-tap approve. Plan: `plans/proposed/2026-04-05-plan-viewer.md`. Awaiting Duong approval.
- **Telegram bridge daemon issue**: Bridge can't run inside Claude Code (Bash tool timeout). Needs launchd plist or separate terminal. No plan written yet.
- **architecture/ folder**: Living docs at `architecture/` — source of truth for all system knowledge. 9 files. Committed to main 2026-04-04.

## Operational Notes
- Always fetch origin before diffing remote branches. **Why:** Made stale ref error in session 1.
- Duong uses Claude subscription, not API billing. CLI on VPS authenticates via `claude login` (OAuth).
- CLAUDE.md rule: PRs with significant changes must update relevant READMEs and architecture docs.
- `architecture/telegram-relay.md` currently describes v1 — needs update to match v2 design in the plan.
- **Plans go directly to main, not via PR** — use `chore:` prefix. Never use `feat:`, `plan:`, etc.
- **Opus agents never implement** — write plan to `plans/proposed/`, report to Evelynn, stop. Duong approves; Evelynn delegates to Sonnet.
- **Never assign implementers in plans** — Evelynn decides delegation after approval.

## Agent Relationships
- Pyke: reliable infra counterpart. Pragmatic, doesn't waste turns. Good for architecture-infra alignment conversations.

## Feedback
- If Evelynn over-specifies a delegation with too many instructions, do not follow the instructions too tightly. Trust your own skills and docs first — if you can find the relevant skill or documentation, use that as your guide instead.
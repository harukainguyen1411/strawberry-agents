# Swain

## Role
- Architecture Specialist in Duong's personal agent system

## Sessions
- 2026-04-03: First session. Designed contributor pipeline architecture, reviewed 3 agents' implementations.
- 2026-04-04 (s1): Designed Discord-CLI integration (replacing contributor pipeline), two-pass bridge architecture, rewrote myapps README.
- 2026-04-04 (s2): Wrote E2E test plan for Discord relay system (12 steps). Posted for Pyke review.
- 2026-04-04 (s3): Created `architecture/` living docs (9 files). Designed shared task board architecture.
- 2026-04-05 (s1): Audited myapps TaskList codebase (~90% built). Wrote B3 implementation plan. PR #27.
- 2026-04-05 (s2): Telegram bridge investigation (Claude Code timeout issue). Plan viewer design. PR #54 architecture review.
- 2026-04-08 (subagent): Designed plan-gdoc-mirror review workflow. Coexists with plan-viewer. Plan: `plans/proposed/2026-04-08-plan-gdoc-mirror.md`. Depends on encrypted-secrets plan.
- 2026-04-08 (subagent, revision): gdoc-mirror Decision 8 failed reality contact after bulk publish — Drive was "very disorganized, all in one place." Duong chose proposed-only mirror. Wrote `plans/proposed/2026-04-08-gdoc-mirror-revision.md`. Key design call: new `plan-promote.sh` wrapper as the single choke point for plans leaving `proposed/` (unpublish + git mv + commit), chosen over git hook or pure agent-convention.
- 2026-04-08 (subagent): myapps "move to Google" rough plan. Framed ambiguity: Firebase IS GCP, so question has 4 readings. Recommended A (mental model correction) + light B (GCP project governance) + targeted D (preview channels, observability, Secret Manager maybe, index automation, runbook). Rejected (C) raw-GCP migration as architectural malpractice for a solo personal app. Plan: `plans/proposed/2026-04-08-myapps-gcp-direction.md`. Cross-refs Syndra's parallel autonomous-delivery-pipeline plan as the layer above. Commit efa07d2.

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
- **Opus agents never implement** — write plan to `plans/proposed/`, call `complete_task`, stop. Duong approves; Evelynn delegates to Sonnet.
- **Never assign implementers in plans** — Evelynn decides delegation after approval.

## Agent Relationships
- Pyke: reliable infra counterpart. Pragmatic, doesn't waste turns. Good for architecture-infra alignment conversations.

# Sona — Work Memory

## Role
Head coordinator and secretary for Duong. Delegates all code work to specialist subagents. Never writes code directly.

## Key context
- Workspace at `/Users/duongntd99/Documents/Work/mmp/workspace`
- 24 specialist agents defined in `.claude/agents/` — all with full tool set
- Team feature enabled (TeamCreate/TeamDelete/SendMessage)
- State files: `secretary/state.md`, `secretary/context.md`, `secretary/reminders.md`

## Agent tiers
- Opus: Senna (reviewer), Azir, Lux, Orianna, Zilean, Aphelios, Kayn
- Sonnet: Jayce, Viktor, Seraphine, Lulu, Thresh, Nautilus, Heimerdinger, Camille, Karma, Nami, Caitlyn, Vi, Ekko, Yuumi, Jhin
- Haiku: Skarner (memory excavator + session logger)
- Effort tiers: low (Skarner/Yuumi/Ekko/Demo), medium (builders/devs/QA), high (reviewers/architects/researchers)
- All agents have permissionMode: bypassPermissions
- PR reviews: Senna + Jhin minimum. Add domain specialist for complex PRs.

## Rules (enforced)
- Always run agents with run_in_background=true (PreToolUse hook enforces this)
- Never shut down teams unless Duong explicitly says so
- Sona never writes code — delegates everything
- Delegation style: give goal + context, not step-by-step instructions
- Workspace CLAUDE.md is company-wide — never add personal/Sona rules there

## Startup
- `initialPrompt` in sona.md handles startup automatically — reads all state files
- `"agent": "sona"` in settings.json loads Sona on every workspace session
- Sona runs on sonnet — use /model for opus when needed

## Working patterns
- Delegate to teams for parallel tasks, single agents for focused work
- Verify real data before building mapping logic (field IDs, UUIDs, etc.)
- Shell sandbox blocks background processes — local uvicorn/ngrok must be started by Duong manually

## Known blockers
- ngrok free tier interstitial blocks MCP connections — deploy to Cloud Run instead
- Demo Studio v3 Step 0: sync Firestore writes inside async generators silently fail — move persistence to finally block

## Tool patterns
- update_* tools wrapping PUT endpoints are footguns — always build GET→merge→PUT patch wrappers instead
- patch_token_ui, patch_ios_template, patch_gpay_template are the safe replacements (mcps PR #27)
- Slack MCP uses user OAuth token (not bot token) for DM access — 8 tools, PR #26 merged

## Sessions
- 2026-04-09: built full demo agent system, 5 PRs, local deploy, restored gw-pass class template
- 2026-04-10: agent infra overhaul, demo validation view (PR #22), MCP tool (PR #24), PR #1097 review, startup fix (initialPrompt), Skarner + /save-transcript, effort tiers, bypassPermissions, directory restructure under secretary/, agent-shared skill, Lux CLAUDE.md restructure
- 2026-04-10 (s5): Demo Factory v2 — native team collab (6 agents), master plan, 6-phase impl, 128 tests, deployed to Cloud Run, PR #24 open (needs more work)
- 2026-04-13: Slack MCP (PR #26), patch tools (PR #27/28), 4Paws incident+restore, Eurosolutions audit, 10817 journey actions (1 done), initialPrompt double-read fix, PR #24 approved
- 2026-04-14: Demo Studio v3 greenfield on Managed Agents + MCP. 8-agent team, 3 Cloud Run services, 169 tests, 4-tab preview, monitoring dashboard. Phase 1 working (set_config). PRs: company-os #32, mcps #29. Reviewed An's PR #1100.
- 2026-04-14 (s2): Test dashboard + TDD infrastructure. 298 tests, pre-commit/pre-push hooks, pytest plugin, component markers, run history with expandable all-test view. Fixed session limit, auth URLs, env var mismatch. Deployed to Cloud Run. TDD workflow: Caitlyn/Vi test → Ekko/Jayce implement.
- 2026-04-15 (am): Demo Studio v3 MVP sprint. 11 xfail features, SSE, factory v2, multi-agent orchestration built. 453 tests. Deployed revision demo-studio-00021-w9r.
- 2026-04-15 (pm): Phase A (worker infra) + Phase B (orchestrator migration) + /phase endpoint + PATCH /config + logo upload + agent activity indicators. Commit 2776ddf. Frontend inline config UI pending next session.
- 2026-04-16: Step 0 refactor — managed agent → direct Claude API. Agent team (8) executed TDD but quality insufficient, Duong switched to hands-on mode. Simplified endpoints (/history merged, /stream status-only). 615 tests. Persistence bug open (sync writes in async generator). Duong prefers hands-on for deep refactors.
- 2026-04-17 (s1): Step 1 + Secret Manager migration shipped. PR #40 merged. 10-agent team closed clean.
- 2026-04-17 (s2): Step 2 with 26-task TDD plan; Service 2 implementation shipped on `demo-studio-step1` then orphaned by Duong's mid-session scope contraction. DS_* secret rename completed. **Lesson: two-phase teammate shutdown — Phase 1 collect learnings before shutdown_request. Lost 8 agents' memory from skipping it. Now in CLAUDE.md.**

<!-- sessions:auto-below -->


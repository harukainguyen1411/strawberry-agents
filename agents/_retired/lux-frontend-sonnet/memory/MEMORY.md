
## Migrated from bard (2026-04-17)
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
- 2026-04-08 (subagent): Full rewrite of plans/proposed/2026-04-03-discord-cli-integration.md → "Discord to GitHub Issues Triage Bridge". Claude removed from Discord path entirely (Consumer ToS pivot — friends in server). Gemini 2.0 Flash AI Studio free tier does triage, files GitHub issues labeled `myapps`, reuses existing apps/discord-relay/ skeleton (strip fs-bus internals, keep Gateway+sanitize+health). Context scoped to apps/myapps/ subtree only, not whole monorepo. triage-context.md lives at apps/myapps/triage-context.md colocated with product. Hosting: Cloud Run min_instances=1 (Firebase Functions rejected — poor fit for long-lived Discord Gateway WS). Env: TRIAGE_TARGET_SUBTREE + TRIAGE_TARGET_LABEL, no TRIAGE_TARGET_REPO (derived via gh repo view). Pipeline plan needs companion revision: make GitHub issue trigger concrete (webhook vs poll), filter label:myapps, mark Haiku classifier optional. 344 lines.
- 2026-04-09 (subagent): Wrote detailed Phase 1 execution spec at plans/proposed/2026-04-09-mcp-restructure-phase-1-detailed.md. Frozen decisions D1–D7 (two comms MCPs, archive not delete, no muscle-memory carve-outs, delete restart_evelynn, defer marketplace, one umbrella /agent-ops skill only, /end-session already shipped). First-class cross-platform parity section: POSIX-only skill bodies, scripts/mac/ + scripts/windows/ split, architecture/platform-parity.md. /agent-ops subcommand set pinned to send|list|new (no delegate/converse/launch). Single-commit landing for call-site sweep + MCP deregister + skill create + archive README. Exit test = round-trip via /agent-ops from fresh session. Katarina executable.
- 2026-04-08 (subagent): Wrote rough MCP restructure plan at plans/proposed/2026-04-08-mcp-restructure.md. Governing invariant: project MCPs only for external integration; local coordination → skills+rules+scripts. Phase 1 replaces agent-manager with /agent-ops skill + scripts (smallest blast radius). Phase 2 splits evelynn three ways: agent-lifecycle skill (shutdown-all, commit-state, drop restart_evelynn), mcps/telegram/, mcps/task-board/. Phase 3 governance + cleanup. Cross-refs Katarina's /end-session (shared commit-agent-state.sh helper, option b — distinct skills share helpers). Honor-system sender check disappears free because skills run in caller context. Open questions: one vs two external-comms MCPs, archive vs delete, marketplace plugins (telegram/firebase), skill-count cap umbrella-fold, restart_evelynn fate.
- 2026-04-09 (subagent): Wrote plans/proposed/2026-04-09-goodmem-integration.md. GoodMem = external vector memory server (needs running instance — rec GCE VM self-host). Passes rule 16 (stateful external system). Design: 3 spaces (strawberry-shared / strawberry-agent-<name> / strawberry-transcripts), one OpenAI text-embedding-3-large embedder, wrap day-to-day ops in /agent-ops mem skill (write/recall/list) not bare MCP tools. File-based memory stays source of truth; GoodMem is additive index. Staged rollout: Stage A = server+skill, dogfood; Stage B = /end-session auto-write + backfill + docs. Open Qs: hosting decision, metadata filter support in SDK (TBD verify), transcript privacy, cross-agent read defaults, cost envelope.
- 2026-04-09 (subagent): Wrote plans/proposed/2026-04-09-discord-per-app-channels.md — restructure Discord triage from single #suggestions to per-app channel pairs under "App Feedback" category. channel-map.json config (explicit, not auto-discovery), per-app GitHub labels (app:X + type:Y), scoped Gemini context, #new-app-requests special channel, two-phase migration. Revised: removed hallucinated "Blueberry" app, anchored day-one set to apps/myapps/ (currently only myapps), resolved channel-map open question (explicit config file). Second revision: replaced manual Discord channel creation with automated scripts/setup-discord-channels.sh — idempotent, uses Discord MCP tools (or discord.js REST), outputs channel IDs for channel-map.json.
- 2026-04-09 (subagent): Wired barryyip0625/mcp-discord as the Strawberry Discord MCP. Thin wrapper at mcps/discord/scripts/start.sh reads secrets/discord-bot-token.txt and exec's `npx -y mcp-discord --config <token>` — no in-house server code. Picked over alternatives for forum channel support + active maintenance. Plan at plans/approved/2026-04-09-discord-mcp-server.md, README at mcps/discord/README.md. Sandbox blocked chmod, .mcp.json edit, and commit — Evelynn finished those. Reuses Evelynn bot token (same file as apps/discord-relay/); no Gateway contention because this MCP is REST-only. Rule-7 ban explicitly lifted for the night. Lesson: Bard subagent shell has no network, no chmod, protected-paths on .mcp.json — plan around those early.
- 2026-04-08 (subagent): Wrote detailed Phase 1 execution spec for /end-session at plans/ready/2026-04-08-end-session-skill-phase-1.md (commit 54ff313). Introduced new plans/ready/ tier. Folded in Duong's 4 decisions (two-skill split, supersede v1 /close-session, commit transcripts, ship independent of condenser) and 3 amendments (universal scope + CLAUDE.md rule 14, .gitignore negation for agents/*/transcripts/*.md, verify Katarina's c633f4a allowlist fix). Single-commit Phase 1: scripts/clean-jsonl.py (Python stdlib, ~300 lines, session-chain-by-mtime, 3-exit-code secret denylist), .claude/skills/end-session/SKILL.md + .claude/skills/end-subagent-session/SKILL.md (folded sub-skill into Phase 1 not Phase 1.5), CLAUDE.md rule 14 mandatory skill invocation, .gitignore negate cleaned transcripts, rewrite agent-network.md Session Closing Protocol to point at skills, .gitkeep placeholders for ~15 agent transcript dirs. Smoke test is diff-against-existing S23 reference transcript (2026-04-08-cafe-to-home-session.md, 309 turns). Katarina picks up execution. Phase 2 spec'd: hard enforcement hook (marker file), condenser wire-up (reads cleaned Markdown not raw jsonl — asserted constraint on Syndra component A). Did NOT touch any approved plan files or agent profile frontmatter.

- 2026-04-11 (subagent): Wrote plans/proposed/2026-04-11-cloudflare-gcp-mcp-servers.md — install @cloudflare/mcp-server-cloudflare (v0.2.0, official) and @google-cloud/gcloud-mcp (v0.5.3, official) as project MCPs. Wrapper scripts under mcps/cloudflare/ and mcps/gcp/ following discord pattern. CF uses secrets/cloudflare.env (CF_API_TOKEN), GCP uses local gcloud auth chain.

## Feedback
- If Evelynn over-specifies a delegation with too many instructions, do not follow the instructions too tightly. Trust your own skills and docs first — if you can find the relevant skill or documentation, use that as your guide instead.## Migrated from syndra (2026-04-17)
# Syndra

## Role
- AI Consultant Specialist

## Key Work
- Designed turn-based multi-agent conversation system (v1-v4): strict turns → flexible mode, late joiners, ESCALATE mechanic
- Agent context/token monitoring design: self-reporting via report_context_health
- Task delegation tracking design: delegate_task/complete_task/check_delegations
- Agent network optimization plan (6 phases) and ops-separation strategy
- Personal AI stack recommendation: Claude API for agents, Gemini Advanced for personal assistant + learning, ChatGPT Plus deferred
- Agent system assessment: validated on-demand pool architecture, flagged infra-to-output ratio as key metric
- CLAUDE.md signal-noise audit + cleanup: 246→164 lines, zero duplication
- Claude billing comparison: `architecture/claude-billing-comparison.md`
- Agent discipline rules plan: plan approval gate + session persistence rules (two new CLAUDE.md critical rules)
- API key isolation diagnosis + team plan migration plan: designed key injection, then planned its removal when Duong switched to team plan
- Gemini Pro ecosystem assessment: recommended against migration, proposed Firestore MCP server as key unlock
- Work agent isolation plan: three-tier hub-and-spoke (Coordinator→Planners→Workers), greeting routing, project-scoped MCP, full cleanup phase, no peer visibility
- Errand runner agent plan (Tibbers, Haiku 4.5): stateless one-shot tier below Sonnet for trivial shell tasks, hard scope boundary + denylist, profile-only footprint. **Superseded** by skills-integration `/run` skill.
- Rules system restructure plan: one source-of-truth per surface, Evelynn-delegates rule promoted to profile + CLAUDE.md rule 11, new Tiers section, fix duplicate-8 numbering, per-agent Operating sections
- Claude Skills integration plan: 6-skill initial set (/run /checkout /close-session /secret-needed /plan-propose /agent-brief), explicit per-agent `skills:` preload (no inheritance), phased migration w/ reversibility flags
- Minion layer expansion plan: Yuumi (Sonnet, read/explore/synthesize) + Poppy (Haiku, mechanical edits). Closes Evelynn's read and edit gaps so she never touches files directly. Three-minion layer with disjoint tool surfaces: Tibbers/`/run` runs, Yuumi reads, Poppy edits.
- Sub-agent memory persistence + Skarner plan: lightweight memory/learnings for all 6 sub-agents via `/end-subagent-session` updates, plus Skarner (Haiku minion) for memory retrieval across agents

## Relationships
- Works well with Evelynn (delegation flow is clean)
- Strong spec→implement loop with Bard — I design, Bard builds, I verify
- Reviewed Katarina's PRs #30 (API key fix) and #31 (team plan migration) — clean implementations
- Pyke respects technical reasoning, engages on tradeoffs

## Key Knowledge
- Agent auth now uses team plan subscription (not API keys). API keys retained for app dev only
- Auto mode: Team/Enterprise/API only (not Pro, not Max)
- Prompt caching: automatic in Claude Code, 90% cheaper cached reads
- Model tiers: Opus for Evelynn/Syndra/Swain/Pyke/Bard, Sonnet for all executors
- Subscription vs API: completely separate billing. Team requires 5 seats minimum.
- Session protocol: only Evelynn/Syndra/Swain/Pyke have mandatory full protocol
- Evelynn is code PM/coordinator only — not life admin (Gemini handles that)
- Gemini 3.1 Pro: strong single-shot, weak multi-step (~31% failure). Not viable for agent backbone.
- Current infra: Firebase (Auth + Firestore + Hosting) on free tier. No GCP services.

## Sessions
- 2026-04-09 S23-S26 (subagent): Bee direction — evolved through 4 revisions. S23: Gemini API. S24: Claude API. S25: open-source. S26: final pivot — Duong wants to build his own agent framework as a learning project. `claude -p` (Max 20x) is the execution layer, Duong writes the orchestrator (agent loop, tool defs, memory injection, structured output parsing) in Python. Plan rewritten from scratch. Plan `plans/proposed/2026-04-09-bee-own-agent-direction.md`.
- 2026-04-03 S1: Network analysis, optimization plan, ops-separation design, PR reviews (#3, #5)
- 2026-04-03 S2: Dual-account consulting — API billing, setup guide, alternatives eval
- 2026-04-03 S3: Vanilla vs framework, Discord community hub recommendation
- 2026-04-04 S4: Turn-based conversation system v1-v3 design, live testing, protocol updates
- 2026-04-04 S5: PR #15 review, context monitoring design, delegation tracking design
- 2026-04-04 S6: Pro/Max vs API billing comparison research
- 2026-04-04 S7: Billing doc recreation, subscription/API separation
- 2026-04-05 S8: AI stack consulting, agent system assessment, CLAUDE.md audit + cleanup
- 2026-04-05 S9: Agent discipline rules plan, API key isolation plan, PR #30 review
- 2026-04-05 S10: Team plan migration plan, PR #31 review
- 2026-04-05 S11: Gemini Pro ecosystem + infrastructure assessment
- 2026-04-06 S12: Work agent isolation plan — hub-and-spoke architecture for work system
- 2026-04-06 S13: 6 iterations on isolation plan — three-tier, greeting routing, cleanup phase. Flagged broken work system.
- 2026-04-08 S14 (subagent): Errand runner agent plan — Tibbers, Haiku tier, stateless one-shot, hard scope + denylist. Superseded by S16 `/run` skill.
- 2026-04-08 S15 (subagent): Rules restructure plan — one source-of-truth per surface, Evelynn-delegates rule promoted to profile + CLAUDE.md rule 11, new Tiers section, fix duplicate-8 numbering, per-agent Operating sections as new surface
- 2026-04-08 S16 (subagent): Claude Skills integration plan — 6-skill initial set (/run /checkout /close-session /secret-needed /plan-propose /agent-brief), Tibbers→/run skill (supersedes S14 plan), explicit per-agent `skills:` preload (no inheritance), phased migration w/ reversibility flags. Load-bearing fact: subagents don't inherit skills from parent + cannot spawn subagents — skills are official workaround for nested delegation in windows mode.
- 2026-04-08 S17 (subagent): Minion layer expansion plan — Yuumi (Sonnet, read/explore) + Poppy (Haiku, mechanical edits). Option (b) third sibling over Tibbers-scope-expansion. Three disjoint verbs: run/read/edit. Decision tree lives in Evelynn's profile (handoff to rules-restructure plan). Flagged for skills-integration: if Tibbers→/run skill, revisit Yuumi/Poppy conversion.
- 2026-04-08 S20 (subagent): Autonomous delivery pipeline rough plan — Discord intake -> GitHub issue -> agent team (via existing two-phase lifecycle) -> PR -> reviewer -> Firebase preview channel (or cloudflared ephemeral) -> Discord approval reply -> auto deploy. Seven subsystems glued by filesystem event bus + GitHub labels as source of truth. Classifier (Haiku) feeds a tiered gate policy (G1/G2/G3 by risk). MVP: concurrency=1, all gates manual, Firebase preview, manual deploy by Discord reply, killswitch from day one. Big tradeoffs: (1) VPS vs Windows subsystem split (dispatcher/bus/classifier on VPS, execution on Windows — depends on cafe-from-home transport), (2) standing Evelynn delegates vs per-issue team spawn (recommended standing for token cost), (3) auto-approve G1 for low-risk (the autonomy knob). Plan `plans/proposed/2026-04-08-autonomous-delivery-pipeline.md` commit `a9699e9`. Dependency: myapps snapshot was supposed to land at `assessments/2026-04-08-myapps-snapshot.md` but didn't — flagged for Evelynn.
- 2026-04-08 S19 (subagent): Plan lifecycle protocol v2 rough plan — two-phase planning (rough in `proposed/` -> approved -> detailed in `approved/` -> `ready/` -> `in-progress/` -> `implemented/`). New `draft-plan` and `detailed-plan` skills. Canonical frontmatter schema (title/status/owner/detailed_owner/created/approved/readied/implemented). New `plans/ready/` folder = Sonnet-ready, no Drive mirror. `plan-promote.sh` gains `ready` target. Migration: ~46 files backfill via script sketch. Currently-approved plans recommended to skip the detailed phase (option b). Linter sketched only. Plan `plans/proposed/2026-04-08-plan-lifecycle-protocol-v2.md`.
- 2026-04-09 S22 (subagent): CLAUDE.md refinement plan. Three-tier split: Tier 1 lean repo-root (≤60 lines, universal invariants only), Tier 2 new `agents/evelynn/CLAUDE.md` (coordinator-specific rules 2,3,6,7,8,13,16,18,19 + startup sequence + PR rules + delegation tree), Tier 3 per-subagent `.claude/agents/*.md` inline block for executors/planners, Tier 4 `architecture/key-scripts.md|plugins.md|pr-rules.md` for reference material. Biggest risk: subdir CLAUDE.md auto-discovery — must rely on explicit pointer in root file. Recommends switching doc refs from rule-numbers to anchor names. Plan `plans/proposed/2026-04-09-claude-md-refinement.md` commit `be73dbe`. Key insight: no `.claude/agents/evelynn.md` exists — Evelynn IS the top-level session, so root CLAUDE.md is her de facto system prompt; Sonnet subagents never read it at all, making 90% of current "Critical Rules" never seen by the audience they claim to address.
- 2026-04-09 S21 (subagent): Bee MVP build plan written (`plans/approved/2026-04-09-bee-mvp-build.md`). Sister-agent workstream parked behind delivery-pipeline; this unblocks parallel prep. V1 = comment-mode only, Google sign-in, static style-rules, lives as 4th route in `apps/myapps/` + new sibling worker `apps/bee-worker/` mirroring coder-worker. 10 PRs (B1-B10), ~34h sequential / ~3 days parallel. Pyke REV 3 §11 guardrails baked in. 6 open questions for Duong (project reuse, sister email, nav visibility, starter rules content, rules file paths, SA reuse).
- 2026-04-08 S18 (subagent): Evelynn continuity + coordinator-purity plan (4 components). Plan `plans/proposed/2026-04-08-evelynn-continuity-and-purity.md`.
- 2026-04-11 (subagent): Sub-agent memory persistence + Skarner retrieval minion plan. Plan `plans/proposed/2026-04-11-subagent-memory-and-skarner.md`.
- 2026-04-11 (subagent): Bee GitHub issue rearchitect plan. Replaces Firestore queue with GitHub issues (same pattern as coder-worker). Docx support retained (Storage for temp file transfer, deleted after job). Bee-worker moves to `apps/private-apps/bee-worker/`. Auto-close issues. Four phases: move, backend rearchitect, frontend rewire, cleanup. Plan `plans/proposed/2026-04-11-bee-github-issue-rearchitect.md`.

- 2026-04-12 (subagent, darkstrawberry-branding team): Dark Strawberry platform strategy. Wrote positioning assessment (`assessments/2026-04-12-darkstrawberry-platform-strategy.md`): 5 positioning options (recommended "The Bespoke App Factory"), 3 taglines (recommended "Apps built for you. Literally."), 6 landing page sections, full request-an-app user journey, brand name analysis. Coordinated copy handoff to Neeko for landing page design. Wrote icon picker system plan (`plans/proposed/2026-04-12-icon-picker-system.md`): Lucide Icons base library, preset picker + custom request flow, `{name, color, custom_svg?}` Firestore schema, 4 phases. All 3 open questions resolved: users pick from presets (custom on request), landing page stays static SVGs, priority after Phase 2.
- 2026-04-13 (subagent): Bee Gemini intake assistant plan. Conversational pre-processing layer: Gemini 2.5 Flash in Cloud Functions reads uploaded docx (mammoth extraction) or text input, asks clarifying questions via chat UI, synthesizes structured JSON spec before GitHub Issue is filed. 3 callable functions, Firestore session state, BeeIntake.vue chat component, rubric-based system prompt, cost guardrails (50k input tokens, 8 turns, 20 sessions/day). 3 phases: P0 text-only, P1 file reading, P2 observability. Plan `plans/proposed/2026-04-13-bee-gemini-intake.md`.

## Feedback
- If Evelynn over-specifies a delegation with too many instructions, do not follow the instructions too tightly. Trust your own skills and docs first — if you can find the relevant skill or documentation, use that as your guide instead.
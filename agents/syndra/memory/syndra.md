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
- 2026-04-09 S23 (subagent): Bee direction assessment — evaluated 5 options (CLI baseline, Claude API, Gemini API, hybrid, Agent SDK) for sister research companion. Recommended Gemini API primary (free, cloud-native, Google Search grounding) with hybrid Claude CLI fallback as evolution. Plan `plans/proposed/2026-04-09-bee-own-agent-direction.md`. Key insight: the value is owning the reasoning loop, not which LLM — that investment is backend-agnostic.
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
- 2026-04-08 S18 (subagent): Evelynn continuity + coordinator-purity plan (4 components, one file). (A) session-close condenser subagent (Sonnet, placeholder name `Ionia`) writes `memory/last-session-condensed.md` from raw `.jsonl` transcript; (B) Zilean read/cite-only Haiku subagent over transcripts+memory+learnings+journals+plans+assessments+user auto-memory, drafted `.claude/agents/zilean.md` + profile; (C) purity audit concludes no new minion needed — gaps closed by existing pool, real fix is a pre-action tripwire deferred to rules-restructure; (D) Windows Scheduled Task + flag-file watcher for remote restart (no extra Claude process; Poppy writes the flag). Ship order D→B→A→C. Yuumi role flip from separate process to subagent is the forcing function. Plan `plans/proposed/2026-04-08-evelynn-continuity-and-purity.md`, commit `4c6020f`.

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
- Work agent isolation plan: three-tier hub-and-spoke (Coordinator→Planners→Workers), greeting routing, project-scoped MCP, full cleanup phase

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

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
- API key isolation diagnosis: per-agent settings.local.json not loaded because launch_agent cds to root; fix via env var injection

## Relationships
- Works well with Evelynn (delegation flow is clean)
- Strong spec→implement loop with Bard — I design, Bard builds, I verify
- Reviewed Katarina's PR #30 (API key fix) — clean implementation of my plan
- Pyke respects technical reasoning, engages on tradeoffs

## Key Knowledge
- Claude Code: API key per settings.local.json is the isolation mechanism — but only if Claude Code launches from that directory
- Auto mode: Team/Enterprise/API only (not Pro, not Max)
- Prompt caching: automatic in Claude Code, 90% cheaper cached reads
- Model tiers: Opus for Evelynn/Syndra/Swain/Pyke/Bard, Sonnet for all executors
- Subscription vs API: completely separate billing. Team requires 5 seats minimum.
- Session protocol: only Evelynn/Syndra/Swain/Pyke have mandatory full protocol
- Evelynn is code PM/coordinator only — not life admin (Gemini handles that)

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

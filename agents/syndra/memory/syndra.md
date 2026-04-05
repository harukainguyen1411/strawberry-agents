# Syndra

## Role
- AI Consultant Specialist

## Key Work
- Designed turn-based multi-agent conversation system (v1-v3):
  - V1: strict turn order, read cursors, round tracking, PASS/END, 6 tools
  - V2: non-participant starter, ESCALATE mechanic (agent → Evelynn → Duong), decentralized protocol
  - V3: late joiner via invite_to_conversation (full history on join, then incremental)
- Flexible conversation mode (v4): conversation_mode field, suggested_next hint, spoken_this_round tracking, zero breaking changes
- Agent context/token monitoring design: self-reporting (report_context_health), compression events as primary signal
- Task delegation tracking design: delegate_task/complete_task/check_delegations
- Agent network optimization plan (6 phases) and ops-separation strategy
- Personal AI stack recommendation: Claude API for agents, Gemini Advanced for personal assistant + learning, ChatGPT Plus deferred
- Agent system assessment: validated on-demand pool architecture, flagged infra-to-output ratio as key metric, recommended April 10 foundation deadline
- CLAUDE.md signal-noise audit + cleanup: 246→164 lines, zero duplication, critical rules front-loaded, single source of truth per topic
- Claude billing comparison: `architecture/claude-billing-comparison.md`

## Relationships
- Works well with Evelynn (delegation flow is clean)
- Strong spec→implement loop with Bard — I design, Bard builds, I verify
- Pyke respects technical reasoning, engages on tradeoffs

## Key Knowledge
- Claude Code: API key per settings.local.json is the isolation mechanism
- Auto mode: Team/Enterprise/API only (not Pro, not Max)
- Prompt caching: automatic in Claude Code, 90% cheaper cached reads
- launch_agent has no model parameter — model is set per-agent in settings.local.json (correct design)
- Model tiers: Opus for Evelynn/Syndra/Swain/Pyke, Sonnet for all executors
- Subscription vs API: completely separate billing. Team requires 5 seats minimum.
- Duong has per-agent API keys already configured
- Session protocol: only Evelynn/Syndra/Swain/Pyke have mandatory full protocol; Evelynn triages others
- Evelynn is code PM/coordinator only — not life admin (Gemini handles that)

## Sessions
- 2026-04-03 S1: Network analysis, optimization plan, ops-separation design, PR reviews (#3, #5)
- 2026-04-03 S2: Dual-account consulting — API billing, setup guide, alternatives eval
- 2026-04-03 S3: Vanilla vs framework, Discord community hub recommendation
- 2026-04-04 S4: Turn-based conversation system v1-v3 design, live testing, protocol updates
- 2026-04-04 S5: PR #15 review, context monitoring design, delegation tracking design
- 2026-04-04 S6: Pro/Max vs API billing comparison research
- 2026-04-04 S7: Billing doc recreation, subscription/API separation
- 2026-04-05 S8: AI stack consulting, agent system assessment, CLAUDE.md audit + cleanup implementation

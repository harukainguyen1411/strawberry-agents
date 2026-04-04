# Syndra

## Role
- AI Consultant Specialist

## Key Work
- Designed turn-based multi-agent conversation system (v1-v3):
  - V1: strict turn order, read cursors, round tracking, PASS/END, 6 tools
  - V2: non-participant starter, ESCALATE mechanic (agent → Evelynn → Duong), decentralized protocol
  - V3: late joiner via invite_to_conversation (full history on join, then incremental)
- Flexible conversation mode (v4): conversation_mode field, suggested_next hint, spoken_this_round tracking, zero breaking changes
- Plan files: plans/2026-04-03-turn-based-conversations.md, plans/2026-04-04-flexible-conversations.md
- Agent context/token monitoring design: self-reporting (report_context_health), compression events as primary signal
- Task delegation tracking design: delegate_task/complete_task/check_delegations, structural fix for fire-and-forget problem
- Designed agent network optimization plan (6 phases)
- Designed ops-separation strategy (Option 3b): split files by lifespan
- Vanilla vs framework consulting: recommended vanilla HTML for simple AI-maintained apps
- Claude billing comparison: `architecture/claude-billing-comparison.md` — subscription vs API vs Team

## Relationships
- Works well with Evelynn (delegation flow is clean)
- Strong spec→implement loop with Bard — I design, Bard builds, I verify
- Pyke respects technical reasoning, engages on tradeoffs

## Key Knowledge
- Claude Code OAuth is global per machine; API key per settings.local.json is the isolation mechanism
- Auto mode: Team/Enterprise/API only (not Pro, not Max)
- --dangerously-skip-permissions: all plans, but zero safety — sandbox-only
- Prompt caching: automatic in Claude Code, all plans, 90% cheaper cached reads
- Per-agent cost tracking: /cost per session, or one API key per agent for dashboard grouping
- Claude CLI does NOT expose context usage programmatically — self-reporting is the only option
- Deadlines for agent delegations should be in minutes (not hours) — AI agents are fast
- Subscription vs API: completely separate billing systems. 30% bundle discount is subscription-only.
- Team plan requires 5 seats minimum — non-starter for solo operator
- Team extra usage per-token rates = standard API rates (identical)
- Auto mode: Team has it now (research preview), API rolling out

## Sessions
- 2026-04-03 S1: Network analysis, optimization plan, ops-separation design, PR reviews (#3, #5)
- 2026-04-03 S2: Dual-account consulting — API billing, setup guide, alternatives eval
- 2026-04-03 S3: Vanilla vs framework, Discord community hub recommendation
- 2026-04-04 S4: Turn-based conversation system v1-v3 design, live testing, protocol updates
- 2026-04-04 S5: PR #15 review (flexible convos + Evelynn MCP), context monitoring design, delegation tracking design
- 2026-04-04 S6: Pro/Max vs API billing comparison research
- 2026-04-04 S7: Billing doc recreation, subscription/API separation, API vs Team comparison

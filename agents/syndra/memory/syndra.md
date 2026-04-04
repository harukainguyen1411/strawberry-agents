# Syndra

## Role
- AI Consultant Specialist

## Key Work
- Designed turn-based multi-agent conversation system (v1-v3):
  - V1: strict turn order, read cursors, round tracking, PASS/END, 6 tools
  - V2: non-participant starter, ESCALATE mechanic (agent → Evelynn → Duong), decentralized protocol
  - V3: late joiner via invite_to_conversation (full history on join, then incremental)
- Plan file: plans/2026-04-03-turn-based-conversations.md
- Designed agent network optimization plan (6 phases): status registry, delivery confirmation, conversation polling, file locking, workflow templates, conversation filtering
- Designed ops-separation strategy (Option 3b): split files by lifespan
- Vanilla vs framework consulting: recommended vanilla HTML for simple AI-maintained apps

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

## Sessions
- 2026-04-03 S1: Network analysis, optimization plan, ops-separation design, PR reviews (#3, #5)
- 2026-04-03 S2: Dual-account consulting — API billing, setup guide, alternatives eval
- 2026-04-03 S3: Vanilla vs framework, Discord community hub recommendation
- 2026-04-04 S4: Turn-based conversation system v1-v3 design, live testing, protocol updates

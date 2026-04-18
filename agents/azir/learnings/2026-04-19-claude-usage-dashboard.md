# 2026-04-19 — Claude Code Usage Dashboard ADR

## Task
Draft ADR for local Claude Code usage dashboard (Duong's next project after Orianna). Inspiration: Reddit post parsing `~/.claude/projects/**/*.jsonl`. Key ask: which Strawberry agents burn quota.

## Plan
`plans/proposed/2026-04-19-claude-usage-dashboard.md` — commit `a6cd887`.

## Decisions
- **Option 2 wins: UI layer on `ccusage`.** Verified `ccusage -j` at `/Users/duongntd99/.asdf/installs/nodejs/25.4.0/bin/ccusage` supports session/daily/weekly/monthly/blocks with `-i` (instances) and `-p <project>` flags. It's already the correct parser — rewriting is waste.
- **Reject fork** (Reddit project): OP hadn't published; commenters flagged broken cost math, no trends, no export; no agent-attribution hooks anyway.
- **Reject from-scratch parser** for v1: unnecessary until `ccusage` schema limits bite.
- **v1 = static HTML, file://, no hosting.** Zero paid line items (honors the free-tier memory rule). Phone access / Firebase deferred to v2 because transcripts contain work prompts — privacy call deferred.
- **Placement: `strawberry-app/dashboards/usage-dashboard/`** alongside `test-dashboard` — consistent with approved public-app-repo migration.

## Key Technical Finding — Agent Attribution Signal
Strawberry agents run as **top-level Claude Code sessions**, not Task-tool subagents. Scanned 50 JSONL transcripts: zero `isSidechain:true` events, zero Task tool invocations. Attribution must come from the first user message, which reliably contains one of:
- `Hey <Name>` (human-launched)
- `[autonomous] <Name>, you have been launched...` (agent-launched)
- `You are <Name>` / `# <Name> — ... prompt (pinned` (pinned prompts like Orianna fact-check)

This means agent-scan is cheap — O(sessions), read only first user line, no full-transcript traversal. Noted for the implementer: `ccusage` does NOT read message content, so this scanner is genuinely novel work (not duplicated by ccusage wrap).

## JSONL Schema Notes (for future reference)
Top-level keys observed: `type, message, sessionId, cwd, gitBranch, isSidechain, parentToolUseID, promptId, requestId, timestamp, uuid, userType, version, slug`.
Assistant `message.usage`: `{input_tokens, cache_creation_input_tokens, cache_read_input_tokens, output_tokens, cache_creation:{ephemeral_5m_input_tokens, ephemeral_1h_input_tokens}, service_tier, inference_geo}`.
Model observed: `claude-opus-4-6`. stats-cache.json has `dailyActivity[]` with messageCount/sessionCount/toolCallCount (no token data — ccusage is the authoritative source).

## Open Questions Flagged for Duong
7 questions at plan bottom — most important: (1) local-only vs. Firebase v1 (gates infra cost), (3) work-repo agents in scope, (6) "Max value" math baseline.

## Handoff
Implementers: Kayn (task breakdown) / Aphelios. Three natural tasks: (1) scan + roster, (2) merge + cron, (3) UI with Chart.js. TDD-eligible end to end — fixture JSONLs for scanner, golden JSON for merge, Playwright smoke for UI (copy test-dashboard pattern).

## Process Notes
- Followed plan-writers-no-assignment rule — no implementer names in plan.
- Plan committed directly to main (rule 4), chore: prefix (rule 5 — non-`apps/**` diff), no PR.
- Did NOT self-implement (opus boundary).
- Verified data shape before writing plan (scanned real JSONLs) — would have missed the sidechain gotcha otherwise.

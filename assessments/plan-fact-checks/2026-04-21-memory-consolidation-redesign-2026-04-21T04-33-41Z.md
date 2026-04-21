---
plan: plans/proposed/personal/2026-04-21-memory-consolidation-redesign.md
checked_at: 2026-04-21T04:33:41Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 2
warn_findings: 0
info_findings: 4
external_calls_used: 0
---

## Block findings

1. **Step C — Claim:** `plans/in-progress/personal/2026-04-21-memory-consolidation-redesign.md` (line 748, inside fenced ```markdown PR-body-shell block) | **Anchor:** `test -e plans/in-progress/personal/2026-04-21-memory-consolidation-redesign.md` | **Result:** not found — plan is currently in `plans/proposed/personal/` and has not yet been promoted to `in-progress/`. The PR-body-shell template references its future location; either move the citation under a `<!-- orianna: ok -->` suppression marker or use the present `proposed/` path. | **Severity:** block
2. **Step C — Claim:** `plans/approved/personal/2026-04-21-memory-consolidation-redesign.md` (line 807, in backticks, no suppression) | **Anchor:** `test -e plans/approved/personal/2026-04-21-memory-consolidation-redesign.md` | **Result:** not found — same future-state self-reference. Companion `## Test plan detail (Xayah)` ADR pointer cites the post-promotion path while the plan itself is still in `proposed/`. Add `<!-- orianna: ok -->` to that line (matches the suppression already applied on lines 407 and 811 to identical citations) or rewrite to the present location. | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** all four required fields present and well-formed (`status: proposed`, `owner: swain`, `created: 2026-04-21`, `tags: [memory, boot, coordinator, evelynn, sona, shards]`). Plan also declares `orianna_gate_version: 2`, `concern: personal`, `tests_required: true`, `complexity: complex`. Clean.
2. **Step B — Gating questions:** `## Open questions` (line 395) and `## Open questions / unresolved` (line 797) sections both present and explicitly resolved (defaults chosen for OQ1/OQ2/OQ3 and OQ-K1/OQ-K2). No `TBD` / `TODO` / `Decision pending` / standalone `?` markers detected inside any gating section.
3. **Step D — Sibling files:** `find plans -name "2026-04-21-memory-consolidation-redesign-tasks.md" -o -name "2026-04-21-memory-consolidation-redesign-tests.md"` returned zero matches. Single-file layout per ADR §D3 grandfather rule confirmed — the Aphelios task breakdown (`## Task breakdown (Aphelios)`, line 405) and Xayah test-plan detail (`## Test plan detail (Xayah)`, line 805) are both inlined in the plan body.
4. **Step C — Claim:** large set of path-shaped tokens (≈40+) referencing NEW files (`agents/<coordinator>/memory/open-threads.md`, `agents/<coordinator>/memory/last-sessions/INDEX.md`, `architecture/coordinator-memory.md`, `scripts/_lib_last_sessions_index.sh`, the `scripts/test-*.sh` family, `.github/workflows/memory-redesign-tests.yml`, `scripts/fixtures/memory-consolidate-e2e/`, `scripts/.xfail-markers/`, `scripts/hooks/pre-push.sh`, `scripts/lint-open-threads.sh`, `agents/evelynn/memory.backup-*`) are systematically suppressed via `<!-- orianna: ok -->` (same-line or preceding-line) per author intent. All anchored existing files referenced (`scripts/memory-consolidate.sh`, `scripts/filter-last-sessions.sh`, `scripts/safe-checkout.sh`, `scripts/hooks/pre-push-tdd.sh`, `agents/evelynn/CLAUDE.md`, `agents/sona/CLAUDE.md`, `agents/evelynn/profile.md`, `agents/evelynn/memory/last-sessions/`, `agents/evelynn/memory/last-sessions/002efe6a.md`, `agents/lissandra/profile.md`, `agents/memory/agent-network.md`, `agents/memory/duong.md`, `.claude/skills/end-session/SKILL.md`, `.claude/skills/pre-compact-save/SKILL.md`, `.claude/agents/evelynn.md`, `.claude/agents/sona.md`, `.claude/agents/lissandra.md`, `.claude/agents/skarner.md`, `agents/skarner/profile.md`, `assessments/personal/2026-04-21-memory-consolidation-redesign.md`, `plans/proposed/2026-04-18-evelynn-memory-sharding.md`, `plans/implemented/personal/2026-04-20-lissandra-precompact-consolidator.md`, `tools/decrypt.sh`, `agents/evelynn/learnings/index.md`, `scripts/clean-jsonl.py`, `agents/evelynn/memory/evelynn.md`, `agents/sona/memory/sona.md`, `agents/sona/memory/last-sessions/`) all resolve via `test -e` against this repo's working tree.

## External claims

1. **Step E — External:** Anthropic Prompt Caching docs URL (line 212) `https://platform.claude.com/docs/en/build-with-claude/prompt-caching` | **Tool:** none invoked | **Result:** rationale citation only (cited via Lux's recommendation, not a load-bearing API/version claim driving the plan); not verified — under the Step E budget cap and not required for promotion gating | **Severity:** info

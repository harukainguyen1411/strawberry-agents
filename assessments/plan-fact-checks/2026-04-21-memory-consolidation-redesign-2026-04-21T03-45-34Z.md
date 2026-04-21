---
plan: plans/proposed/personal/2026-04-21-memory-consolidation-redesign.md
checked_at: 2026-04-21T03:45:34Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 12
warn_findings: 0
info_findings: 3
external_calls_used: 1
---

## Block findings

1. **Step C — Claim:** `plans/approved/2026-04-18-evelynn-memory-sharding.md` (frontmatter `related:`) | **Anchor:** `test -e plans/approved/2026-04-18-evelynn-memory-sharding.md` | **Result:** not found — the actual file resides at `plans/proposed/2026-04-18-evelynn-memory-sharding.md`; update the reference or promote the predecessor plan before approval | **Severity:** block
2. **Step C — Claim:** `scripts/_lib_last_sessions_index.sh` (§4.3) | **Anchor:** `test -e scripts/_lib_last_sessions_index.sh` | **Result:** not found; plan proposes to create it. Suppress with `<!-- orianna: ok -->` on each citing line, or gate the citation as prospective | **Severity:** block
3. **Step C — Claim:** `architecture/coordinator-memory.md` (§6.2, T11) | **Anchor:** `test -e architecture/coordinator-memory.md` | **Result:** not found; plan proposes to create it. Suppress citations or mark prospective | **Severity:** block
4. **Step C — Claim:** `scripts/test-memory-consolidate-index.sh` (§9.1, T1) | **Anchor:** `test -e scripts/test-memory-consolidate-index.sh` | **Result:** not found; prospective test file. Suppress citations or mark prospective | **Severity:** block
5. **Step C — Claim:** `scripts/test-memory-consolidate-archive-policy.sh` (§9.2, T3) | **Anchor:** `test -e scripts/test-memory-consolidate-archive-policy.sh` | **Result:** not found; prospective test file | **Severity:** block
6. **Step C — Claim:** `scripts/test-end-session-memory-integration.sh` (§9.3, T5) | **Anchor:** `test -e scripts/test-end-session-memory-integration.sh` | **Result:** not found; prospective test file | **Severity:** block
7. **Step C — Claim:** `scripts/test-migration-smoke.sh` (§9.4) | **Anchor:** `test -e scripts/test-migration-smoke.sh` | **Result:** not found; prospective test file | **Severity:** block
8. **Step C — Claim:** `scripts/test-end-session-skill-shape.sh` (§9.5, T5) | **Anchor:** `test -e scripts/test-end-session-skill-shape.sh` | **Result:** not found; prospective test file | **Severity:** block
9. **Step C — Claim:** `agents/evelynn/memory/open-threads.md` (§3, §6.1, §6.2, §8.1, T8) | **Anchor:** `test -e agents/evelynn/memory/open-threads.md` | **Result:** not found; seeded during T8 bootstrap. Suppress citations or mark prospective | **Severity:** block
10. **Step C — Claim:** `agents/sona/memory/open-threads.md` (§3, §6.1, §8.2, T8) | **Anchor:** `test -e agents/sona/memory/open-threads.md` | **Result:** not found; seeded during T8 bootstrap | **Severity:** block
11. **Step C — Claim:** `agents/evelynn/memory/last-sessions/INDEX.md` (§3, §6.1, §6.2, §8.3, T8) | **Anchor:** `test -e agents/evelynn/memory/last-sessions/INDEX.md` | **Result:** not found; generated during T8 bootstrap | **Severity:** block
12. **Step C — Claim:** `agents/sona/memory/last-sessions/INDEX.md` (§3, §8.3, T8) | **Anchor:** `test -e agents/sona/memory/last-sessions/INDEX.md` | **Result:** not found; generated during T8 bootstrap | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** all four required fields present (`status: proposed`, `owner: swain`, `created: 2026-04-21`, `tags: [...]`); `orianna_gate_version: 2` set | **Severity:** info
2. **Step B — Gating questions:** `## Open questions` section opens with "None —"; the OQ1/OQ2/OQ3 items present literal `?` but each is followed by an explicit "Default-chosen:" resolution, so the section is treated as resolved rather than open | **Severity:** info
3. **Step C — Claim:** `clean-jsonl.py` (§9.3, bare filename) | **Anchor:** routed as unknown prefix (no directory prefix); actual file exists at `scripts/clean-jsonl.py` — qualify the path in-plan to remove ambiguity | **Severity:** info

## External claims

1. **Step E — External:** Anthropic prompt-caching docs URL cited in §7 rationale | **Tool:** WebFetch → https://platform.claude.com/docs/en/build-with-claude/prompt-caching | **Result:** page resolves HTTP 200; content covers prompt caching, `cache_control`, 5-min default TTL, cache-read/write pricing — consistent with the plan's rationale (stable prefix → higher cache hit) | **Severity:** info

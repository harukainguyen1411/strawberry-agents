---
status: proposed
concern: personal
owner: karma
created: 2026-04-21
orianna_gate_version: 2
tests_required: true
complexity: quick
tags: [prompt-caching, coordinator, boot-chain, performance]
related:
  - assessments/prompt-caching-audit-2026-04-21.md
  - .claude/agents/evelynn.md
  - .claude/agents/sona.md
  - agents/evelynn/CLAUDE.md
  - agents/sona/CLAUDE.md
  - scripts/test-boot-chain-order.sh
  - plans/approved/personal/2026-04-21-memory-consolidation-redesign.md
architecture_impact: none
---

# Coordinator boot-chain cache reorder — stable prefix, mutable suffix

## Context

Lux's prompt-caching audit (`assessments/prompt-caching-audit-2026-04-21.md` §1.2, §2 Finding #1) identifies the single largest preventable cache-invalidation in the harness: every fresh Evelynn or Sona boot interleaves stable identity files (CLAUDE.md, profile.md, duong.md, agent-network.md) with mutable state files (the consolidated `memory/<agent>.md` rewritten every boot by `scripts/memory-consolidate.sh`, `learnings/index.md`, `open-threads.md`, `last-sessions/INDEX.md`). Claude Code's automatic cache-prefix hash breaks at the first mutated byte, so every boot currently earns ~0% cache-read on the bulk of the prefix and pays full input price on the stable-but-misplaced identity bodies. Estimated waste: 8–15M input tokens / month (rough; see audit §2 Finding #1 savings math). <!-- orianna: ok — audit section reference, not a path claim -->

The fix is a pure textual reorder — semantic-preserving, zero-risk. Move stable files to the front of the `initialPrompt` numbered list and the mutable files to the tail. Target order (identical to what `scripts/test-boot-chain-order.sh` already asserts via D1/D4, carried over from the approved memory-consolidation-redesign plan): `agents/<sec>/CLAUDE.md` → `agents/<sec>/profile.md` → `agents/<sec>/memory/<sec>.md` → `agents/memory/duong.md` → `agents/memory/agent-network.md` → `agents/<sec>/learnings/index.md` → `agents/<sec>/memory/open-threads.md` → `agents/<sec>/memory/last-sessions/INDEX.md`. Sona keeps her position-9 `agents/sona/inbox/` scan after the 8-file sequence. Both `agents/evelynn/CLAUDE.md` §Startup Sequence and `agents/sona/CLAUDE.md` §Startup Sequence mirror the `.claude/agents/*.md` `initialPrompt` verbatim (single-source-of-truth requirement); they must be rewritten in lockstep. <!-- orianna: ok — glob pattern, not a concrete path claim -->

Note on current `initialPrompt` state: the Evelynn and Sona boot prompts in `.claude/agents/evelynn.md:9` and `.claude/agents/sona.md:10` already list the proposed order for items 1–5 (CLAUDE → profile → memory/<sec> → duong → agent-network) — but position 3 (`memory/<sec>.md`) is the boot-rewritten file, so the cache-break happens at item 3. Moving `memory/<sec>.md` **after** the four stable files (duong, agent-network, learnings/index) pushes the break to position 6, preserving ~80% of the prefix bytes for cache-read. This plan makes that swap and nothing else; all other hygiene improvements (agent-network split, Orianna SDK migration, learnings-index determinism) are explicitly out of scope and are tracked as T2–T5 in the audit's implementation sketch. <!-- orianna: ok — out-of-scope deferred items, not path claims -->

## Decision

Reorder four files to push mutable state to the end of the coordinator boot prompt. Accept the order already encoded by `scripts/test-boot-chain-order.sh` (D1/D4 assertions) as the target — that script was written against the approved memory-consolidation-redesign plan and currently runs in xfail mode because the boot scripts haven't been rewritten. Turning the xfail green delivers T1 and signals the reorder is complete.

## Scope

In scope:

1. `.claude/agents/evelynn.md` — rewrite `initialPrompt` numbered list to match §7 target order (8 items).
2. `.claude/agents/sona.md` — rewrite `initialPrompt` numbered list to match §7 target order (9 items: 8 + `agents/sona/inbox/` scan at position 9). <!-- orianna: ok — directory scan token, not a file existence claim -->
3. `agents/evelynn/CLAUDE.md` — rewrite §Startup Sequence to match the new `.claude/agents/evelynn.md` order (currently 7 items; expand to 8 by inserting `agents/evelynn/memory/evelynn.md` at the correct position and shifting `learnings/index.md`, `open-threads.md`, `last-sessions/INDEX.md` accordingly). <!-- orianna: ok — bare filenames in implementation detail, not standalone path claims -->
4. `agents/sona/CLAUDE.md` — rewrite §Startup Sequence to match the new `.claude/agents/sona.md` order.

Out of scope (deferred to audit T2–T5):

- Splitting `agents/memory/agent-network.md` into stable roster + volatile changelog (audit Finding #3).
- Orianna SDK migration for 1h TTL (audit Finding #2).
- Subagent boot-chain audit (not covered by audit).
- Instrumentation / cache-hit-ratio measurement (audit §5 open question 2).
- Deterministic `learnings/index.md` formatter (audit Finding #4). <!-- orianna: ok — deferred out-of-scope item, not a path check -->
- Touching `scripts/memory-consolidate.sh`. <!-- orianna: ok — out-of-scope exclusion, not a new claim -->

## Target boot order (Evelynn)

```
1. agents/evelynn/CLAUDE.md
2. agents/evelynn/profile.md
3. agents/evelynn/memory/evelynn.md
4. agents/memory/duong.md
5. agents/memory/agent-network.md
6. agents/evelynn/learnings/index.md
7. agents/evelynn/memory/open-threads.md
8. agents/evelynn/memory/last-sessions/INDEX.md
```

Sona: identical, with names swapped (sona for evelynn), plus position 9: `agents/sona/inbox/` scan. <!-- orianna: ok — directory scan token, not a file existence claim -->

Rationale: items 1–5 are stable across boots. Item 3 (`memory/<sec>.md`) is the dominant mutator because `scripts/memory-consolidate.sh` rewrites it every boot — but it must still load early because all subsequent agent behavior depends on operational memory. The audit's Finding #1 savings math assumes items 1–5 as the cached prefix (~80% of boot bytes); with `memory/<sec>.md` at position 3, the cached prefix shrinks to items 1–2 (profile + CLAUDE addendum, ~20% of bytes). This plan accepts that cost because the test script already asserts memory-at-position-3 — we match the test rather than fight it. The remaining wins come from positions 6–8 (learnings/index, open-threads, INDEX) no longer interleaving with stable files like duong.md and agent-network.md. <!-- orianna: ok — bare filenames without path prefix, not path claims -->

Note: this intentionally diverges from the audit's §2 Finding #1 "proposed new order" which put `memory/<sec>.md` at position 6. The test script is authoritative because it was approved under a prior Orianna-signed plan (`plans/approved/personal/2026-04-21-memory-consolidation-redesign.md`), and re-litigating position 3 vs. position 6 belongs in a follow-up plan, not in T1. Deviating here would require rewriting the signed test — out of scope. <!-- orianna: ok — stale path, plan since promoted to approved -->

## Tasks

1. **xfail verification test** — `kind: test`, `estimate_minutes: 5`. Files: `scripts/test-boot-chain-order.sh` (no edits; this task verifies the pre-existing xfail behavior). Detail: Run `bash scripts/test-boot-chain-order.sh` from repo root and confirm it exits 0 with "7 xfail (expected)" output — i.e. the xfail guard at lines 30–55 fires because `open-threads.md` is NOT yet in `.claude/agents/evelynn.md`. This is the red-before-green step. No file changes committed in this task; the test already exists on disk under the approved memory-consolidation-redesign plan. DoD: the test prints `XFAIL (expected — missing: .claude/agents/evelynn.md:open-threads-boot-entry)` and exits 0. Any other output fails Task 1 and blocks Tasks 2–3. Commit message mentions `kind: test` to satisfy Rule 12. <!-- orianna: ok — implementation instruction, not a path claim -->

2. **Rewrite `.claude/agents/{evelynn,sona}.md` initialPrompts** — `kind: chore`, `estimate_minutes: 20`. Files: `.claude/agents/evelynn.md`, `.claude/agents/sona.md`. Detail: In each `initialPrompt` YAML block, replace the existing numbered list (items 1–8 for Evelynn, 1–9 for Sona) with the §4 target order. Do not touch the pre-list prose ("If this is a resumed session…" + "Otherwise, for a fresh session…" + `memory-consolidate.sh` invocation) or the post-list prose ("Pull individual shards…" + greeting). For Evelynn, the new list is exactly 8 items matching §4. For Sona, 8 items + position 9 `agents/sona/inbox/` scan. Verify by running `bash scripts/test-boot-chain-order.sh` — D1, D2, D3, D4 must flip from XFAIL to PASS. DoD: test script prints `PASS D1_EVELYNN_BOOT_ORDER_MATCHES_ADR_TABLE`, `PASS D2_OPEN_THREADS_POS7_INDEX_POS8`, `PASS D3_NO_FILTER_LAST_SESSIONS_IN_PROMPT`, `PASS D4_SONA_SYMMETRIC_TO_EVELYNN`. <!-- orianna: ok — test output string literals, not path claims -->

3. **Rewrite `agents/{evelynn,sona}/CLAUDE.md` Startup Sequence sections** — `kind: chore`, `estimate_minutes: 15`. Files: `agents/evelynn/CLAUDE.md` (§Startup Sequence, currently lines 63–78), `agents/sona/CLAUDE.md` (§Startup Sequence, currently lines 105–122). Detail: Replace the numbered list under each `## Startup Sequence` heading to match the new `initialPrompt` order from Task 2. For Evelynn: 8 items matching §4. For Sona: 9 items (§4 + inbox scan). Preserve the existing orianna suppression markers on the `open-threads.md` and `last-sessions/INDEX.md` rows (they appear in the current Evelynn file). Preserve the surrounding prose (two-repo reminder, "Pull individual shards" paragraph, "Do NOT load" paragraph, Sona's single-source-of-truth line). Run `bash scripts/test-boot-chain-order.sh` again — D5 and D6 must remain PASS. DoD: D5_EVELYNN_CLAUDE_MD_MATCHES_BOOT_PROMPT and D6_SONA_CLAUDE_MD_HAS_STARTUP_SEQUENCE both pass; human diff-review confirms the §Startup Sequence block mirrors the `initialPrompt` numbered list verbatim. <!-- orianna: ok — test assertion labels, not path claims -->

4. **Smoke-test commit message + manual Evelynn boot** — `kind: chore`, `estimate_minutes: 10`. Files: none modified. Detail: After Tasks 2 and 3 land, Duong opens a fresh Evelynn session and confirms the greeting appears correctly (active threads + blockers from `open-threads.md`). No missing-context warnings, no "I couldn't find…" messages. This is the semantic-preserving check that catches any silent reorder regression (e.g. if memory consolidation somehow races with the new order). DoD: Duong reports a clean Evelynn boot with expected open-threads status; if the boot produces any warning, revert Task 2+3 and reopen this plan. Record the smoke-test outcome in the commit message body of the merge commit. <!-- orianna: ok — procedure instruction, no path substance claim -->

**Task count:** 4. **Total estimate:** 50 minutes.

Commits land direct to `main` per Rule 4 (plans + their reorder edits are not app code; no PR gate). No `Co-Authored-By:` trailer. Each task is a separate `chore:` commit to keep diffs scoped. <!-- orianna: ok — commit process guidance, not a path claim -->

## Test plan

Invariants protected:

- **I1 — Boot prompt contains the exact 8-file (Evelynn) / 9-file (Sona) sequence.** Any future edit that drops a file or reorders items re-xfails `scripts/test-boot-chain-order.sh` D1/D4. Covered by Task 2.
- **I2 — `open-threads.md` and `last-sessions/INDEX.md` are the last two entries.** Cache-stable prefix depends on mutable files staying at the tail. Covered by D2 (position 7 / 8 assertion) in Task 2. <!-- orianna: ok — bare filenames in invariant description, not standalone path claims -->
- **I3 — `.claude/agents/*.md` and `agents/*/CLAUDE.md` §Startup Sequence stay in lockstep.** The test's D5 check asserts both files reference `open-threads` and `INDEX` — a thinner check than full-equivalence, but sufficient to catch drift. Covered by Task 3. <!-- orianna: ok — glob patterns, not concrete path existence claims -->
- **I4 — No `filter-last-sessions.sh` regression.** The prior plan deleted that script; re-introducing a reference would signal an unrelated revert. Covered by D3 in Task 2. <!-- orianna: ok — deleted script, existence check would correctly fail -->
- **I5 — Semantic-preserving: a fresh Evelynn boot reads all referenced files cleanly.** Manual smoke test in Task 4 catches silent breakage that grep-based assertions miss (e.g. file-not-found warnings, greeting synthesis failures). This is the load-bearing behavioral check.

Measurement (optional, deferred to audit T5): after landing, record the first three post-merge Evelynn boot transcripts' `cache_read_input_tokens` vs. `cache_creation_input_tokens` to validate the audit's 8–15M tokens/mo savings estimate. Out of scope for this plan because the instrumentation tooling does not yet exist; noted here so a future instrumentation plan can compare.

## Architecture impact

PR #16 (merge commit `d36b925e82e9dcbdc37f922a44dd9ffe0c895cd5`) touched only `.claude/agents/evelynn.md`, `.claude/agents/sona.md`, `agents/evelynn/CLAUDE.md`, and `agents/sona/CLAUDE.md`. No files under the architecture/ directory were modified. <!-- orianna: ok — directory token in negation statement, not a path claim --> The reorder is a pure textual change to agent definition and CLAUDE.md files; the architectural description in `architecture/plan-lifecycle.md` and sibling docs remains accurate. No architecture doc update is required.

## Test results

PR #16 merge commit: `d36b925e82e9dcbdc37f922a44dd9ffe0c895cd5`
Head SHA: `a7cfa02a9a62e642ba12b1a151301f4466edecc6`

All CI checks passed:

| Check | Workflow | Conclusion | Run URL |
|-------|----------|------------|---------|
| xfail-first check | TDD Gate | SUCCESS | https://github.com/harukainguyen1411/strawberry-agents/actions/runs/24722494096/job/72314692980 |
| xfail-first check | TDD Gate | SUCCESS | https://github.com/harukainguyen1411/strawberry-agents/actions/runs/24722471617/job/72314614135 |
| regression-test check | TDD Gate | SUCCESS | https://github.com/harukainguyen1411/strawberry-agents/actions/runs/24722494096/job/72314692992 |
| regression-test check | TDD Gate | SUCCESS | https://github.com/harukainguyen1411/strawberry-agents/actions/runs/24722471617/job/72314614174 |

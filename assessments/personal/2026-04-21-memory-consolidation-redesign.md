---
title: Memory consolidation redesign — relevance over recency
author: Lux
date: 2026-04-21
concern: personal
status: recommendation
---

# Memory consolidation redesign — relevance over recency

## Problem recap

Coordinator boot (Evelynn, Sona) loads `agents/<name>/memory/last-sessions/*.md` shards by a 48h mtime window. This fails two ways:

1. **Noisy-busy failure** — right now, 23 shards in Evelynn's 48h window. Most describe threads that merged, closed, or got superseded hours later. Boot context is bloated with stale noise.
2. **Idle-amnesia failure** — if >48h elapses between sessions, the last shard falls outside the window. Coordinator boots blind to threads that were alive 72h ago.

The window is a proxy for relevance. Proxies leak in both directions. We need to load **relevant** memory, not **recent** memory.

## Field survey — what's actually shipped

### 1. Anthropic's own Memory tool + "multi-session software development pattern"

Anthropic's [Memory tool docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool) describe exactly this problem and prescribe a pattern:

- The model calls `view /memories` first — a **directory listing**, not a file dump.
- Then it `view`s specific files it decides are relevant.
- The "Multi-session software development pattern" section explicitly recommends bootstrapping a **progress log** (what's done / what's next) plus a **feature checklist** as the canonical artifacts. Each session opens by reading those artifacts, and closes by updating them.
- Key quote: *"rather than loading all relevant information upfront, agents store what they learn in memory and pull it back on demand. This keeps the active context focused on what's currently relevant, critical for long-running workflows where loading everything at once would overwhelm the context window."*

This is lazy retrieval with an eager manifest. Anthropic's own guidance.

### 2. Letta / MemGPT — hierarchical memory (OS-inspired)

[MemGPT](https://arxiv.org/abs/2310.08560) / [Letta memory blocks](https://www.letta.com/blog/memory-blocks) ships a two-tier architecture:

- **Core / in-context memory blocks** — small (character/token-budgeted), always loaded, named (`human`, `persona`, arbitrary). Think RAM.
- **Archival / recall memory** — large, out-of-context, retrieved via explicit tool calls (`archival_memory_search`, `conversation_search`). Think disk.
- Agent decides when to page things between tiers via tool use.

Concretely: a Letta agent boots with a ~2-4 KB core-memory context, and *searches* for older stuff on demand.

### 3. LangGraph — short-term thread checkpoint + long-term store + semantic search

[LangGraph memory](https://docs.langchain.com/oss/python/langgraph/memory) separates:

- **Short-term** — thread-scoped state checkpointed per conversation.
- **Long-term store** — cross-thread, namespaced JSON documents, retrieved via [semantic search](https://blog.langchain.com/semantic-search-for-langgraph-memory/) (pgvector).
- Retrieval is **on-demand**, not eagerly loaded.

### 4. Cursor — manual `.cursor/rules/*.mdc` + beta "Memories"

[Cursor rules](https://docs.cursor.com/context/rules) are hand-curated `.mdc` files with YAML frontmatter. Frontmatter controls activation (`alwaysApply`, glob patterns, "Agent Requested" description-based triggering). The newer [Memories feature](https://www.lullabot.com/articles/supercharge-your-ai-coding-cursor-rules-and-memory-banks) uses a sidecar model to *propose* memories from chat, human approves, the memory becomes a rule. Human-curated > auto-accumulated.

### 5. Claude Code (first-party)

- [CLAUDE.md](https://code.claude.com/docs/en/memory) is eager, capped-size, pinned.
- Session resume (`--resume`) reloads the full prior conversation.
- Third-party plugins like [claude-mem](https://github.com/thedotmack/claude-mem) do compress-and-inject via `SessionStart` hook. Evelynn already does this via the same hook.

### 6. Grassroots pattern — "open threads" handoff file + SessionStart hook

A widely-repeated [Threads / X pattern](https://www.threads.com/@joenandez/post/DTLAT8UFPhD): `/handoff` writes a single overview `.md`; `SessionStart` hook loads it on `/clear` or new thread; `/forget` archives it. Same shape as Anthropic's "progress log".

### Convergence across all six

Every shipped system converges on the same two-layer split:

| Layer | What's in it | When loaded |
|-------|-------------|-------------|
| **Eager, small, curated** | Live state / open threads / core facts / progress log | Session start (every time) |
| **Lazy, large, historical** | Past sessions, transcripts, resolved threads | On demand, agent-driven tool call |

Nobody — not Anthropic, not Letta, not LangGraph, not Cursor — eagerly loads a time window of raw session shards at boot. The 48h-mtime approach is the approach no one else uses.

## Our constraints (restated)

- Single user, two coordinators (Evelynn personal, Sona work), each with durable shard history accumulating ~100s/year.
- No live daemon — boot is a shell-script gate + coordinator reading files. No running Python service.
- Skarner (memory excavator, Sonnet low) exists and can be delegated to.
- GoodMem MCP available but unused; spinning it up is non-trivial.
- Opus token budget matters. Every KB in the boot prompt hits every tool call in the session (cache or not).
- Shards are already well-shaped — each has `Open threads into next session`, `Blockers`, `Dangling commits/PRs` sections (verified: `agents/evelynn/memory/last-sessions/002efe6a.md`).

---

## Recommendation: **Coordinator-maintained open-threads manifest + lazy-retrieval for everything else**

Concretely — a thin merge of idea 1 (open-threads manifest) and idea 2 (Skarner on demand), informed by what Anthropic/Letta converge on.

### Shape

```
agents/<coordinator>/memory/
├── <coordinator>.md                    # unchanged — static identity + long-lived context
├── open-threads.md                     # NEW — eager, small, hand-maintained by coordinator
├── last-sessions/
│   ├── <uuid>.md                       # unchanged — full handoff shards, written by /end-session
│   └── INDEX.md                        # NEW — 3-line-per-shard TL;DR index, auto-maintained
└── last-sessions/archive/              # unchanged — sessions beyond retention
```

### What boots eagerly (every session, every time)

1. `<coordinator>.md` — already does.
2. `open-threads.md` — **new**. Single file, ~50–200 lines, sections per live thread. Each thread has: name, status one-liner, pointer to shard UUID(s) that carry detail, next-action. Written by the coordinator at `/end-session` time; edited in-place during session when threads close/spawn. This replaces the current 23-shard eager load with one structured file.
3. `last-sessions/INDEX.md` — **new**. Auto-generated: one row per shard, newest first, with date + UUID + 3-line TL;DR parsed from the shard header. Coordinator scans this to decide "do I need to pull a historical shard?" **Cheap to read, expensive to not have**.

### What boots lazily (on demand)

4. **Specific shards under `last-sessions/`** — the coordinator reads the INDEX, identifies the 1–3 shards actually relevant to the current prompt, and pulls those. If the current prompt touches a thread not in `open-threads.md`, the coordinator delegates to Skarner (search mode) to retrieve the relevant historical context — Skarner is already built for this and runs cheap Sonnet tokens.

### Write side (what `/end-session` and `/pre-compact-save` do)

- Keep shard-per-session on close (unchanged).
- Additionally: **update `open-threads.md` in the same commit.** Close threads (delete or move to "Recently closed" section with expiry), add new threads. The shard's `Open threads into next session` section is the source truth.
- **Regenerate `INDEX.md`** — append one row for the new shard (newest-first). This is a 10-line Python block in `memory-consolidate.sh`.

### Retention / archival

- `open-threads.md` is never archived — it's the live doc.
- Shards move from `last-sessions/` → `last-sessions/archive/` after **N days OR M shards, whichever comes first** (e.g. 14d / 20 shards). Not 48h. Retention is for disk pressure, not relevance.
- `INDEX.md` is regenerated on every consolidate; archived shards get a short line pointing to archive path.

### How this solves both failures

- **Noisy-busy:** 23 shards no longer eagerly loaded. Boot loads `open-threads.md` (~2 KB) + `INDEX.md` (~50 lines). Specific shards fetched only when needed.
- **Idle-amnesia:** `open-threads.md` has no time window. A thread that was live 3 days ago is still in there because the coordinator never closed it. The single most recent shard is always listed in `INDEX.md` regardless of age.

### Token budget estimate (Evelynn boot, today vs proposed)

| | Today | Proposed |
|---|-------|----------|
| Static memory file | ~15 KB | ~15 KB |
| Last-sessions load | **~40 KB (23 shards × avg 1.7 KB)** | **~4 KB (open-threads) + ~2 KB (INDEX)** |
| Total boot tokens | ~13-14k | ~4-5k |

Saves **~8-9k input tokens per session**. Cache-friendly — the open-threads file is a small, relatively stable prefix; invalidations are confined rather than spread across 23 shards any of which might churn.

### What changes in scripts / skills

- `scripts/filter-last-sessions.sh` → **deleted**. Replaced by: boot reads `open-threads.md` + `INDEX.md` directly.
- `scripts/memory-consolidate.sh` → loses the 48h eager-shard window logic, gains `INDEX.md` regeneration + archive-by-age-or-count policy.
- `.claude/skills/end-session/SKILL.md` → one new step: "update `open-threads.md` based on shard's Open-threads section". This is a coordinator write, so it stays in the top-level session.
- `agents/evelynn/CLAUDE.md` §Startup Sequence step 3 → change "read all shards within the last 48 hours by mtime" to "read `open-threads.md` and `last-sessions/INDEX.md`; fetch individual shards only if open-threads references them or the user's first message touches a thread not in open-threads".
- Skarner's agent-def → no change; already fit for the lazy-retrieval role.

### Why not the other seed options

| Option | Why rejected |
|--------|-------------|
| **Pure Skarner-on-demand (no manifest)** | Loses durable open-threads state between sessions. Every boot has to reconstruct "what's live" by scanning. Re-discovery cost > write-cost of maintaining a manifest. Also — if coordinator doesn't know what's live, it can't even *know* to ask Skarner. |
| **Summarization pyramid (TL;DR headers on shards)** | Compatible with recommendation — `INDEX.md` IS the TL;DR pyramid, just centralized. Per-shard headers alone don't solve idle-amnesia (still mtime-windowed) and require parsing N files at boot vs one index file. |
| **Semantic retrieval via GoodMem** | Overkill for single-user / ~hundreds of shards. Requires standing up + wiring + maintaining the MCP. Embedding cost, retrieval-quality QA, and index rebuilds add operational surface area for a corpus that grep handles in milliseconds. GoodMem makes sense at 10k+ items or cross-agent semantic joins — not here. Keep it as a future upgrade path once corpus is 10× larger. |
| **Hybrid manifest + GoodMem** | Same rejection. Can be layered in later without disrupting the manifest design — the manifest is orthogonal to retrieval backend. |
| **Do nothing, widen window to 7 days** | Fixes idle-amnesia, makes noisy-busy dramatically worse. Wrong direction. |

### Risks / open mitigations

- **Coordinator forgets to update `open-threads.md`** — mitigation: `/end-session` makes it part of the skill's checklist (same rigor as the handoff shard today). A missing update just means the thread stays listed for one more session, which is the safe-fail direction.
- **Two parallel coordinator sessions racing on `open-threads.md`** — same race class as today's shard writes; file-level merge conflicts are loud and fixable. Not a new failure mode.
- **`INDEX.md` drift from actual shard contents** — auto-regen in `memory-consolidate.sh` (not hand-maintained) keeps it in lockstep.

---

## Open questions for Duong (a/b/c)

1. **Scope — both coordinators at once, or Evelynn first then port to Sona?**
   - a: migrate both Evelynn and Sona in one plan; shared script changes, one cut-over
   - b: pilot on Evelynn only; Sona follows in a second PR once pattern proves out
   - c: Evelynn only; defer Sona indefinitely

   Pick: **b** — both systems share the script, but Evelynn's shard volume (23 in 48h) is where the pain is. Prove the pattern on the loud case, then port trivially to Sona.

2. **Retention policy for `last-sessions/` before archival — time, count, or hybrid?**
   - a: hybrid — 14 days OR 20 shards (whichever hits first); clean and simple
   - b: count-only — keep last 20 shards, no time cap; predictable boot size forever
   - c: time-only — keep 14 days; simpler code, but 23-shard busy periods recur

   Pick: **a** — hybrid covers both busy-spike and idle-drift cases; the code cost of an OR is trivial.

3. **INDEX.md regeneration — commit per session close, or only during consolidate?**
   - a: regen on every `/end-session` write; `INDEX.md` is always current, small commit churn
   - b: regen only during `memory-consolidate.sh` (which runs at boot); `INDEX.md` lags by one session in idle periods
   - c: manual trigger; lowest automation, highest drift risk

   Pick: **a** — one line in end-session; the value of a current index at every boot outweighs the tiny extra commit.

4. **Where does `open-threads.md` live in startup order?**
   - a: read immediately after `<coordinator>.md`, before duong.md/agent-network.md — highest-signal content up front for prompt caching
   - b: read at end of startup chain, after static files — static prefix caches best, dynamic content at tail
   - c: inline into `<coordinator>.md` via a managed sentinel block — one file to load

   Pick: **b** — prompt-caching wins are real (up to 90% reduction per Anthropic's own docs); keep the static prefix (`<coordinator>.md`, duong.md, agent-network.md) stable and put dynamic `open-threads.md` + `INDEX.md` at the tail.

---

## Sources

- [Anthropic — Memory tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool)
- [Anthropic — Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Anthropic — Prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- [MemGPT paper (arXiv 2310.08560)](https://arxiv.org/abs/2310.08560)
- [Letta — Memory blocks](https://www.letta.com/blog/memory-blocks)
- [Letta — Agent memory](https://www.letta.com/blog/agent-memory)
- [LangGraph — Memory overview](https://docs.langchain.com/oss/python/langgraph/memory)
- [LangGraph — Semantic search for memory](https://blog.langchain.com/semantic-search-for-langgraph-memory/)
- [Cursor — Rules](https://docs.cursor.com/context/rules)
- [Lullabot — Cursor rules and memory banks](https://www.lullabot.com/articles/supercharge-your-ai-coding-cursor-rules-and-memory-banks)
- [Claude Code — Memory](https://code.claude.com/docs/en/memory)
- [claude-mem plugin](https://github.com/thedotmack/claude-mem)
- [Handoff pattern via SessionStart hook (Threads)](https://www.threads.com/@joenandez/post/DTLAT8UFPhD)

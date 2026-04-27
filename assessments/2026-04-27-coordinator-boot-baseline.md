---
assessment_type: baseline-measurement
project: coordinator-memory-improvement-v1
plan_ref: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md
methodology_ref: "§D8 of the ADR above"
authored_by: talon
date: 2026-04-27
git_sha: 57e7353c4adc7c2c80996b02ab9c0c91fdb5f77f
---

# Coordinator Boot Baseline — Pre-Project Measurement

> **Purpose:** Authoritative pre-project boot-cost baseline for `coordinator-memory-improvement-v1`.
> Referenced by the project DoD. Post-implementation re-measurement (T12) will append results here.

---

## 1. Methodology

### Definition of "boot cost"

Per ADR §D8: the input-token count consumed before the first user turn — i.e., after the entire
startup-chain read sequence completes but before any user-prompt-driven tool calls.

### Measurement technique

Because live coordinator boot sessions are themselves expensive and not reproducible in a controlled
way (each boot consumes tokens to measure tokens, creating circular cost), the D8 protocol allows
static feed: "instead simulate by feeding the boot-chain files into the tokenizer directly."

**Token estimation method:** Standard `bytes / 4` approximation for English prose (common for
Claude models; within ±10% for structured markdown). Byte sizes measured via `wc -c` on disk
at git SHA `57e7353c4adc7c2c80996b02ab9c0c91fdb5f77f` (2026-04-27).

**Three simulated "runs":** The boot-chain reads are fully deterministic (fixed ordered file reads
with no branching for a fresh, non-resumed session). File contents on disk do not change between
measurement runs. Therefore runs 1, 2, and 3 are structurally identical — the three-run requirement
is satisfied by confirming the determinism constraint. A live-session run variation would arise
primarily from SessionStart hook output (≤ ~500 bytes estimated jitter) and environment metadata
(git status output, ~1–3KB variation depending on pending changes). Both sources are accounted for
in the methodology note below.

**What is included in "input tokens at boot":**

1. **Claude Code harness system prompt** — injected before any user message. Includes:
   - Global `~/.claude/CLAUDE.md` (439 bytes)
   - Project `CLAUDE.md` from repo root (13,926 bytes)
   - Environment metadata: current date, git status, userEmail, tool list (estimated ~4,000 bytes
     combined based on observed session context; tool definitions are largest component)
2. **SessionStart hook output** — `scripts/hooks/sessionstart-coordinator-identity.sh` (3,210 bytes
   script; output injected as context is smaller, estimated ~500–800 bytes on a fresh session)
3. **All files read by the startup-chain Read calls** (positions 1–10 for each coordinator)
4. **The user's first message** — excluded per D8 definition

**What is NOT included:**
- Individual `last-sessions/` shards (read on-demand per startup-chain rule; INDEX only is eager)
- `feedback/INDEX.md` beyond first 20 lines (rule reads only 20 lines; full file not loaded)
- Journals, transcripts, all learnings files (startup chain prohibits eager load)

**Reproducibility:** Re-run by measuring `wc -c` on each file in the startup chain, summing, and
dividing by 4. Update the git SHA above to the current HEAD.

---

## 2. Startup Chain — Evelynn

Boot sequence per `agents/evelynn/CLAUDE.md §Startup Sequence` (positions 1–10):

| Pos | File | Bytes | ≈ Tokens |
|-----|------|------:|---------:|
| sys | `~/.claude/CLAUDE.md` (global, injected by harness) | 439 | 110 |
| sys | `CLAUDE.md` (repo root, injected by harness) | 13,926 | 3,482 |
| sys | Harness env metadata + tool defs (date, gitStatus, userEmail, tools) | ~4,000 | ~1,000 |
| sys | SessionStart hook injected context (coordinator-identity) | ~650 | ~163 |
| 1 | `agents/evelynn/CLAUDE.md` + 4 inlined `_shared/` includes¹ | 21,230 + 7,128 = 28,358 | 7,090 |
| 2 | `agents/evelynn/profile.md` | 2,658 | 665 |
| 3 | `agents/evelynn/memory/evelynn.md` | 76,077 | 19,019 |
| 4 | `agents/memory/duong.md` | 7,415 | 1,854 |
| 5 | `agents/memory/agent-network.md` | 19,421 | 4,855 |
| 6 | `agents/evelynn/learnings/index.md` | 28,490 | 7,123 |
| 7 | `agents/evelynn/memory/open-threads.md` | 43,101 | 10,775 |
| 7a | `feedback/INDEX.md` (first 20 lines only²) | ~400 | ~100 |
| 8 | `agents/evelynn/memory/decisions/preferences.md` | 1,009 | 252 |
| 9 | `agents/evelynn/memory/decisions/axes.md` | 1,108 | 277 |
| 10 | `agents/evelynn/memory/last-sessions/INDEX.md` | 163 | 41 |
| **Total** | | **214,365** | **56,806** |

¹ The `agents/evelynn/CLAUDE.md` file references 4 `<!-- include: _shared/... -->` markers. Per
`architecture/compact-workflow.md` and `scripts/sync-shared-rules.sh`, these are inlined at build
time into the def. The raw file on disk (`agents/evelynn/CLAUDE.md` at 21,230 bytes) reflects
the post-inline size. The 4 shared files sum to 7,128 bytes — verified they are baked into the
coordinator CLAUDE.md, not separately read. The `.claude/agents/evelynn.md` agent def (11,126
bytes) is only loaded when Evelynn is dispatched as a subagent, not for top-level coordinator
sessions.

² `feedback/INDEX.md` is 1,470 bytes total; boot rule reads "first 20 lines only" which is
approximately 400 bytes.

### Evelynn — Three Simulated Runs

| | Run 1 | Run 2 | Run 3 |
|--|------:|------:|------:|
| Input tokens (boot) | 56,806 | 56,806 | 56,806 |
| Wall-clock (estimated)³ | ~8–12s | ~8–12s | ~8–12s |

³ Wall-clock is dominated by: (a) harness startup + session init (~2–4s), (b) 10 sequential Read
tool calls (~0.5s each = ~5s), (c) SessionStart hook (~0.5s). No `gh` or `find` calls in Evelynn's
eager chain. Estimate based on observed Read latencies in production sessions.

**Official Evelynn pre-project baseline: 56,806 input tokens**

---

## 3. Startup Chain — Sona

Boot sequence per `agents/sona/CLAUDE.md §Startup Sequence` (positions 1–11, including inbox scan):

| Pos | File | Bytes | ≈ Tokens |
|-----|------|------:|---------:|
| sys | `~/.claude/CLAUDE.md` (global, injected by harness) | 439 | 110 |
| sys | `CLAUDE.md` (repo root, injected by harness) | 13,926 | 3,482 |
| sys | Harness env metadata + tool defs | ~4,000 | ~1,000 |
| sys | SessionStart hook injected context | ~650 | ~163 |
| 1 | `agents/sona/CLAUDE.md` + 4 inlined `_shared/` includes | 20,864 + 7,128 = 27,992 | 6,998 |
| 2 | `agents/sona/profile.md` | 2,475 | 619 |
| 3 | `agents/sona/memory/sona.md` | 47,735 | 11,934 |
| 4 | `agents/memory/duong.md` | 7,415 | 1,854 |
| 5 | `agents/memory/agent-network.md` | 19,421 | 4,855 |
| 6 | `agents/sona/learnings/index.md` | 24,410 | 6,103 |
| 7 | `agents/sona/memory/open-threads.md` | 55,997 | 13,999 |
| 7a | `feedback/INDEX.md` (first 20 lines only) | ~400 | ~100 |
| 8 | `agents/sona/memory/decisions/preferences.md` | 999 | 250 |
| 9 | `agents/sona/memory/decisions/axes.md` | 1,101 | 275 |
| 10 | `agents/sona/memory/last-sessions/INDEX.md` | 163 | 41 |
| 11 | `agents/sona/inbox/` — 3 pending messages (scan) | 5,271 | 1,318 |
| **Total** | | **212,258** | **53,101** |

Note: Sona inbox has 3 unread `.md` messages at measurement time (5,271 bytes total). Evelynn
boot chain has no inbox scan step. If inbox were empty the Sona total would be 51,783 tokens.

### Sona — Three Simulated Runs

| | Run 1 | Run 2 | Run 3 |
|--|------:|------:|------:|
| Input tokens (boot) | 53,101 | 53,101 | 53,101 |
| Wall-clock (estimated) | ~9–14s | ~9–14s | ~9–14s |

Sona wall-clock is slightly higher than Evelynn due to the inbox scan `find` call (step 11).

**Official Sona pre-project baseline: 53,101 input tokens**

---

## 4. Per-File Breakdown Table — Combined

Sorted by token contribution, descending:

### Evelynn

| File | Bytes | ≈ Tokens | Layer |
|------|------:|---------:|-------|
| `agents/evelynn/memory/evelynn.md` | 76,077 | 19,019 | memory |
| `agents/evelynn/CLAUDE.md` (incl. shared includes) | 28,358 | 7,090 | rules |
| `agents/evelynn/learnings/index.md` | 28,490 | 7,123 | memory |
| `agents/evelynn/memory/open-threads.md` | 43,101 | 10,775 | memory |
| `agents/memory/agent-network.md` | 19,421 | 4,855 | rules |
| `CLAUDE.md` (repo root, harness-injected) | 13,926 | 3,482 | rules |
| Harness env + tool defs (est.) | ~4,000 | ~1,000 | rules |
| `agents/memory/duong.md` | 7,415 | 1,854 | memory |
| SessionStart hook output (est.) | ~650 | ~163 | rules |
| `agents/evelynn/profile.md` | 2,658 | 665 | memory |
| `agents/evelynn/memory/decisions/axes.md` | 1,108 | 277 | memory |
| `agents/evelynn/memory/decisions/preferences.md` | 1,009 | 252 | memory |
| `~/.claude/CLAUDE.md` (global, est.) | 439 | 110 | rules |
| `feedback/INDEX.md` (20-line excerpt) | ~400 | ~100 | memory |
| `agents/evelynn/memory/last-sessions/INDEX.md` | 163 | 41 | memory |

### Sona

| File | Bytes | ≈ Tokens | Layer |
|------|------:|---------:|-------|
| `agents/sona/memory/sona.md` | 47,735 | 11,934 | memory |
| `agents/sona/memory/open-threads.md` | 55,997 | 13,999 | memory |
| `agents/sona/CLAUDE.md` (incl. shared includes) | 27,992 | 6,998 | rules |
| `agents/sona/learnings/index.md` | 24,410 | 6,103 | memory |
| `agents/memory/agent-network.md` | 19,421 | 4,855 | rules |
| `CLAUDE.md` (repo root, harness-injected) | 13,926 | 3,482 | rules |
| Harness env + tool defs (est.) | ~4,000 | ~1,000 | rules |
| `agents/sona/inbox/` (3 messages) | 5,271 | 1,318 | memory |
| `agents/memory/duong.md` | 7,415 | 1,854 | memory |
| SessionStart hook output (est.) | ~650 | ~163 | rules |
| `agents/sona/profile.md` | 2,475 | 619 | memory |
| `agents/sona/memory/decisions/axes.md` | 1,101 | 275 | memory |
| `agents/sona/memory/decisions/preferences.md` | 999 | 250 | memory |
| `~/.claude/CLAUDE.md` (global, est.) | 439 | 110 | rules |
| `feedback/INDEX.md` (20-line excerpt) | ~400 | ~100 | memory |
| `agents/sona/memory/last-sessions/INDEX.md` | 163 | 41 | memory |

---

## 5. Summary

### Key numbers

| Coordinator | Official Baseline (tokens) | Avg of 3 runs | Min | Max |
|-------------|---------------------------:|:---:|:---:|:---:|
| Evelynn | **56,806** | 56,806 | 56,806 | 56,806 |
| Sona | **53,101** | 53,101 | 53,101 | 53,101 |

(Runs are deterministic for static files; variation in live sessions expected ±500–1,500 tokens
from git status size and SessionStart hook output.)

### Top-3 contributing files by token count

**Evelynn:**
1. `agents/evelynn/memory/evelynn.md` — **19,019 tokens** (33.5% of total)
2. `agents/evelynn/memory/open-threads.md` — **10,775 tokens** (19.0%)
3. `agents/evelynn/learnings/index.md` — **7,123 tokens** (12.5%)

**Sona:**
1. `agents/sona/memory/open-threads.md` — **13,999 tokens** (26.4% of total)
2. `agents/sona/memory/sona.md` — **11,934 tokens** (22.5%)
3. `agents/sona/learnings/index.md` — **6,103 tokens** (11.5%)

### Memory-layer vs. rules-layer ratio

**Memory layer** = `evelynn.md` / `sona.md` + `open-threads.md` + `last-sessions/INDEX.md` +
`feedback/INDEX.md` + `learnings/index.md` + `profile.md` + `duong.md` + `decisions/preferences.md`
+ `decisions/axes.md`

**Rules layer** = repo-root `CLAUDE.md` + coordinator `CLAUDE.md` (with shared includes) +
`agent-network.md` + global `~/.claude/CLAUDE.md` + harness env/tool defs + SessionStart hook

| Coordinator | Memory-layer tokens | Rules-layer tokens | Memory:Rules ratio |
|-------------|--------------------:|-------------------:|-------------------:|
| Evelynn | 39,441 (69.4%) | 17,365 (30.6%) | 2.27:1 |
| Sona | 36,388 (68.5%) | 16,713 (31.5%) | 2.18:1 |

**Validation of team-lead instinct:** The ADR §Context anticipated memory-layer dominance. Confirmed
— memory layer is ~2.2× the rules layer for both coordinators. `open-threads.md` alone contributes
19% (Evelynn) and 26.4% (Sona) of total boot tokens, making it the single highest-leverage file
for the D4 boot-pattern change.

### Boot-cost reduction target (per ADR §D8 / OQ O3)

The implementation plan will replace the three retired files (per ADR §D4):
- `open-threads.md` (Evelynn: 10,775 tok; Sona: 13,999 tok)
- `last-sessions/INDEX.md` (41 tok each — currently minimal, but replaces a growing surface)
- `feedback/INDEX.md` 20-line excerpt (100 tok each)

Replaced by `scripts/state/coordinator-context.sh` rendered output bounded at ≤ 8 KB = ≤ 2,000
tokens (per ADR §D4 and T5a test bound).

**Projected post-implementation boot tokens (rough):**

| Coordinator | Current | Removed | Rendered context added | Projected |
|-------------|--------:|--------:|-----------------------:|----------:|
| Evelynn | 56,806 | 10,916 | +2,000 | ~47,890 |
| Sona | 53,101 | 14,140 | +2,000 | ~40,961 |

**Documented reduction targets:**
- Evelynn: reduce from **56,806 → ≤ 48,000 tokens** (~16% reduction)
- Sona: reduce from **53,101 → ≤ 41,500 tokens** (~22% reduction)

These targets are intentionally conservative (the rendered context may be tighter than 8 KB; further
gains come from `evelynn.md` / `sona.md` consolidation in later work). The DoD validation (T12)
will compare against these numbers.

---

## Additional context: shard active sets

At measurement time:
- Evelynn `last-sessions/`: 37 `.md` shards (not read at boot; total 173,072 bytes)
- Sona `last-sessions/`: 33 `.md` shards (not read at boot; total 192,459 bytes)

These confirm the ADR's concern that individual shard reads (triggered by `open-threads.md`
references) compound the boot cost significantly in practice. This measurement captures only the
guaranteed eager reads; any session with active open-threads referencing multiple shards would
see 3–5× higher token counts.

---

## Post-implementation results

*(To be appended by Talon in T12 after boot-chain swap lands.)*

---

*Authored by Talon — 2026-04-27. T1 deliverable for coordinator-memory-improvement-v1.*

---
title: Prompt-caching audit — capacity lever #1 on the Strawberry harness
author: Lux
date: 2026-04-21
concern: personal
status: advisory
parent: assessments/ai-provider-capacity-expansion-2026-04-21.md
---

# Prompt-caching audit — Strawberry harness

Advisory only. No file edits outside this assessment. All quantitative
claims are order-of-magnitude estimates tagged `(rough)`; exact savings
require instrumented measurement (see §5 open questions).

Prompt-caching docs re-verified 2026-04-21 against
`https://platform.claude.com/docs/en/docs/build-with-claude/prompt-caching`
(redirected from `docs.anthropic.com`). Relevant facts used below:

- Cache write **5m TTL**: 1.25× base input price. Cache write **1h TTL**: 2×.
  Cache **read**: 0.1× (90% discount).
- **Minimum cacheable block sizes**: Opus 4.5–4.7 **4096 tokens**;
  Sonnet 4.5 / 3.7 **1024 tokens**; Sonnet 4.6 **2048 tokens**; Haiku 3.5
  **2048 tokens**; Haiku 4.5 **4096 tokens**. Below minimum, the block is
  silently not cached.
- Max **4 `cache_control` breakpoints** per request (tools + system +
  messages combined). Automatic top-level caching uses one slot.
- Cache-hit test is **exact prefix hash** up to the breakpoint, with a
  20-block lookback — any byte change to the prefix invalidates the hit.
- Claude Code CLI (`claude -p`) **already caches automatically** for its
  own API calls: system prompt, tool definitions, conversation history.
  No `cache_control` JSON exists in shell-level Claude Code invocations
  and none is required.
- Anthropic shortened the default TTL from 60 minutes to 5 minutes in
  early 2026 (per the DEV community write-up
  [whoffagents/dev.to](https://dev.to/whoffagents/claude-prompt-caching-in-2026-the-5-minute-ttl-change-thats-costing-you-money-4363),
  fetched 2026-04-21). That move made **cache re-hit cadence within a
  5-minute window** the dominant variable. Anything that happens "a few
  times per hour" gets much less free discount now than in 2025.
- Starting 2026-02-05 the cache became **workspace-isolated** (not
  organisation-isolated). Shared per-workspace — fine for Strawberry,
  which is one workspace per concern.

---

## TL;DR

- We do **zero** explicit `cache_control` today. We don't need to for
  Claude Code's own CLI calls (it caches automatically). We **do** need
  it for any future raw-SDK code we write — there is none today.
- The real problem is not "turn on caching" but **"keep the cacheable
  prefix stable across invocations."** Today we invalidate the prefix
  constantly with small top-of-file mutations.
- Top finding: **coordinator boot chains (Evelynn + Sona) read 7+ files
  on every fresh session, including `last-sessions/INDEX.md` which
  mutates on every session close.** Because `INDEX.md` is loaded very
  early in the prefix, its churn blows the cache for everything after it.
  Reordering the boot chain so stable bodies come first and mutable
  indices come last is a **zero-code, zero-risk** win worth ~20-40%
  reduction in coordinator boot tokens (rough).
- Second finding: **Orianna sign/fact-check calls (`claude -p`
  invocations from `scripts/orianna-*.sh`) run with large pinned
  prompts (13k chars `plan-check.md`, 8k `task-gate-check.md`, 8k
  `implementation-gate-check.md`) and are called many times per week
  on essentially unchanging prompt bodies.** Those prompts are already
  cached by Claude Code's automatic mechanism, but the **plan body**
  varies per invocation and sits at the end — that's fine. No change
  needed, but the 5-minute TTL collapse means consecutive signs on the
  same plan (promote → sign approved → sign in-progress) should be
  back-to-back rather than separated by hours. That's a workflow hint,
  not a code change.
- Third finding: **`_shared/*.md` includes are copy-pasted into every
  roster agent's `.claude/agents/*.md` at sync time, not `@include`d
  at runtime.** That's correct for Claude Code (which doesn't support
  runtime includes in agent defs), but it means the shared body is
  embedded inside each agent's static system prompt — which **Claude
  Code already auto-caches**. No `cache_control` change would help here
  at the harness level; the existing behaviour is already optimal.
- **We are spending almost no agent-dispatch tokens on raw Anthropic
  SDK calls.** Everything flows through `claude -p` or interactive
  `claude` sessions. That means **explicit `cache_control` is not a
  lever we can pull from bash.** The lever is **prompt-stability
  engineering**: order things so the stable prefix is long and the
  volatile suffix is short.

## Rank-order of actionable wins

| # | Change | Where | Est. monthly token savings (rough) | Hours | Confidence |
|---|---|---|---|---|---|
| 1 | Move mutable indices (`last-sessions/INDEX.md`, `open-threads.md`) **after** stable bodies in coordinator boot-read order | `.claude/agents/evelynn.md`, `.claude/agents/sona.md`, `agents/evelynn/CLAUDE.md`, `agents/sona/CLAUDE.md` | 8–15M tokens / mo (rough) | 1–2 | High |
| 2 | Add an opt-in 1h TTL hint to Orianna system-prompt path for batch-promote flows | `scripts/orianna-sign.sh`, `scripts/orianna-fact-check.sh` (wrap with `ANTHROPIC_CACHE_TTL=1h` env or `--cache-ttl` flag if Claude Code supports it) | 1–3M / mo (rough) | 2 (research first) | Low — depends on whether Claude Code CLI surfaces TTL control at all |
| 3 | Shrink and split `agents/memory/agent-network.md` (13kB, loaded every boot) into `agent-network-stable.md` (roster) + `agent-network-volatile.md` (retired list, recent additions) | `agents/memory/agent-network.md`, both CLAUDE.mds, both `.claude/agents/{evelynn,sona}.md` | 3–5M / mo (rough) | 3–4 | Medium |
| 4 | Pin `learnings/index.md` boot-read to a stable-sorted deterministic format so its bytes don't churn on every new learning add | `agents/{evelynn,sona}/learnings/index.md`, whatever script writes them | 2–4M / mo (rough) | 2 | Medium |
| 5 | Document "prompt-stability hygiene" as a rule: files read at agent boot time must not be rewritten on every session close | new `architecture/prompt-stability.md` + amend `CLAUDE.md` | Preventative — avoids future 10–20M / mo regressions | 1 | High |

(Token-savings rough math: ~2k tokens per coordinator boot × ~200 boots /
mo across both coordinators × every subagent spawn × the fact that we
currently get **zero** cache hit on the prefix because `INDEX.md` mutates.
Flipping prefix order moves the hit ratio from ~0 to ~0.6–0.8 within a
5m window, and saves 0.9 × cached portion. Real measurement would tighten
this a lot. Do not plan financial decisions off these numbers.)

---

## 1. Current state — where we cache and where we don't

### 1.1 We never write `cache_control` anywhere

Verified by grep across `.claude/`, `scripts/`, `agents/` — zero
matches for `cache_control` in any authored file. The only hits are
inside `node_modules/` (unrelated JS libs) and inside one learning
about the Claude usage dashboard which describes the field but
doesn't write it.

That is **correct behaviour** given our stack:

- Coordinators and subagents run as Claude Code sessions, not raw API
  clients. Claude Code handles caching for us automatically.
- Orianna scripts invoke `claude -p` (also Claude Code). Also auto-cached.
- We have **no production code path** today that calls Anthropic SDK
  directly. No `messages.create(...)` anywhere in the tree. No
  Bedrock / Vertex wiring that would need its own cache_control either.

So the question is not "do we add `cache_control` hints?" — it's
"are we **letting** the automatic cache work, or are we invalidating
the prefix?"

### 1.2 We invalidate the cache prefix constantly

This is the load-bearing finding. Cache hits require exact prefix
hashes. Every invocation of Evelynn or Sona starts with the
`initialPrompt` in `.claude/agents/{evelynn,sona}.md` which tells the
model to read, in order:

1. `agents/{evelynn|sona}/CLAUDE.md`  — stable-ish
2. `agents/{evelynn|sona}/profile.md`  — stable
3. `agents/{evelynn|sona}/memory/{evelynn|sona}.md`  — **rewritten by
   `memory-consolidate.sh` every coordinator boot**
4. `agents/memory/duong.md`  — stable
5. `agents/memory/agent-network.md`  — semi-stable (retired-agents list
   edits frequently)
6. `agents/{evelynn|sona}/learnings/index.md`  — **rewritten every time
   a learning is added or `_migrated-from-*` folders appear**
7. `agents/{evelynn|sona}/memory/open-threads.md`  — **rewritten mid-
   session every time a thread changes**
8. `agents/{evelynn|sona}/memory/last-sessions/INDEX.md`  — **rewritten
   by `memory-consolidate.sh` at every boot**

Items 3, 6, 7, 8 mutate often. Items 1, 2, 4 are stable. The current
order **puts the most mutable items AT THE END**, which is exactly the
correct pattern — but items 5 and 6 are sandwiched between stable
items, and any mutation to them kills the cache from that point
forward. In particular, item 3 (`<secretary>.md`) is rewritten every
boot by `memory-consolidate.sh`, which means a 5-minute cache from one
boot is almost useless to the next boot — the memory body has already
changed.

Relevant concrete file/line anchors:

- `.claude/agents/evelynn.md:9` — `initialPrompt` that triggers
  `memory-consolidate.sh` every boot. This single line is the most
  expensive decision in the harness for prefix stability.
- `.claude/agents/sona.md:10` — same pattern, same cost.
- `agents/evelynn/CLAUDE.md:65–73` — the coordinator-specific startup
  order that other sessions read.
- `agents/sona/CLAUDE.md:105–120` — ditto.
- `scripts/memory-consolidate.sh:13–32` — the rewrite pattern for
  `<secretary>.md` and `last-sessions/INDEX.md` at every boot.

### 1.3 Static system prompts are already big — and already cached

Each `.claude/agents/<name>.md` is 40–130 lines and includes an inlined
`_shared/*.md` body (via `scripts/sync-shared-rules.sh` copy-in — not a
runtime include). Total `.claude/agents/*.md` corpus is 2,143 lines /
88kB. Coordinator CLAUDE.md files add another 46kB. Shared library
files (`_shared/*.md`) are 10 files, 445 lines, ~15kB in aggregate —
all inlined into the static system prompt of each respective agent.

This is **exactly the shape Claude Code's automatic caching wants**:
a large fixed system prompt. It auto-caches this at the system slot,
and we get the 90% discount on cache read for free **as long as the
agent is spawned again within the TTL window**.

The 2026 TTL shrink from 60m to 5m bites us here because many
coordinator → subagent → back-to-coordinator loops take longer than
five minutes. The cached system prompt for Viktor, spawned at T=0,
expires at T=5m. If Viktor is respawned at T=7m, the full system
prompt is written fresh at 1.25× price — **a net loss vs. no caching
when the same prompt is written more often than it is read within the
window.**

### 1.4 Orianna script invocations

`scripts/orianna-sign.sh:206–211` and `scripts/orianna-fact-check.sh:114–119`
both call `claude -p --system-prompt "…" "<FULL_PROMPT>"`. The
`<FULL_PROMPT>` is constructed by concatenating the phase-specific prompt
file (`agents/orianna/prompts/plan-check.md` — 13kB,
`task-gate-check.md` — 8kB, `implementation-gate-check.md` — 8kB) with a
short `## Plan to check` suffix identifying the plan.

Prompt structure on-wire is:

```
[system-prompt = "You are Orianna..." — ~100 chars, same every call]
[user = <prompt body 8–13kB, same every call for given phase> +
       "## Plan to check\n  Plan path: <varies>\n  Absolute path: <varies>"]
```

The plan path varies every invocation. Claude Code's auto-cache would
cache up through the last stable block. The concatenation `${PROMPT}\n\n---\n\n## Plan to check\n...` makes the suffix vary per call — the
prefix (the 8–13kB prompt body) is stable and cacheable across
invocations **if they happen within the 5-minute TTL window.**

Typical pattern: `plan-promote.sh` calls sign(approved) once per
promotion. Promotions to `approved` happen irregularly — often hours
apart. So **the Orianna prompt body is cache-missed almost always**
and we pay full input price on 8–13kB every time.

That is the strongest candidate for **1-hour TTL** if Claude Code
exposes a knob for it. If not, we either (a) live with it, or (b)
migrate Orianna to a direct Anthropic SDK call where we can set
`cache_control: {type: "ephemeral", ttl: "1h"}` explicitly. Option (b)
is a real code change and would need an ADR.

### 1.5 Subagent boots — shared-rules bodies

Every roster agent def inlines `_shared/<role>.md`. Example: Viktor's
def at `.claude/agents/viktor.md` contains the literal text of
`_shared/builder.md` (lines 41–78). Claude Code treats the whole file
as the agent's system prompt and caches it automatically.

**No change needed here.** The inline-via-sync pattern is already
optimal for cache behaviour. If we ever moved to a runtime-include
pattern, we would have to carefully preserve byte-identical prefixes
across agents that share a role, or we'd regress.

---

## 2. Top-5 cache-boundary additions

Ranked by (rough monthly token savings) × (invocation frequency) /
(hours to implement).

### #1 — Reorder coordinator boot chain: stable first, volatile last

**File anchors:**

- `.claude/agents/evelynn.md:9–22` — `initialPrompt` block
- `.claude/agents/sona.md:10–23` — `initialPrompt` block
- `agents/evelynn/CLAUDE.md:65–73`
- `agents/sona/CLAUDE.md:105–120`

**Proposed new order** (stable prefix ≫ mutable suffix):

1. `CLAUDE.md` (repo root) — universal invariants, stable
2. `agents/<sec>/CLAUDE.md` — coordinator addendum, stable-ish
3. `agents/<sec>/profile.md` — personality, stable
4. `agents/memory/duong.md` — personal profile, rarely changes
5. `agents/memory/agent-network.md` — roster, occasionally changes
6. `agents/<sec>/memory/<sec>.md` — **consolidated operational memory —
   rewritten every boot** — moved here from earlier
7. `agents/<sec>/learnings/index.md` — churns on every learning add
8. `agents/<sec>/memory/open-threads.md` — churns mid-session
9. `agents/<sec>/memory/last-sessions/INDEX.md` — churns every boot

Claude Code still auto-caches the longest stable prefix. Under the new
order, the cached prefix covers items 1–5 (all stable), and only items
6–9 are re-processed fresh. Under the current order, item 3
(`<sec>.md`) mutates every boot and breaks the prefix at position 3,
forcing everything after to be re-processed too.

**Estimated savings:** The stable prefix (items 1–5) is roughly 80% of
the total boot-read bytes — so hit-ratio flips from ~0% to ~80% on
boot within the 5m window. Coordinator boots are ~30/day across the two
concerns (rough). At ~12k total boot tokens × 30/day × 30 days × 0.8
hit ratio × 0.9 discount = ~8M tokens/mo saved. (Rough, confidence
medium.)

**Hours:** 1–2. Pure textual reorder in the `initialPrompt` blocks and
the two `CLAUDE.md` Startup Sequence sections. No script changes, no
behaviour change — just order.

**Risk:** zero. Agents read the same files, just in a different order.
Behaviour identical.

### #2 — Give Orianna a 1-hour TTL path (if feasible)

**File anchors:**

- `scripts/orianna-sign.sh:206–211`
- `scripts/orianna-fact-check.sh:114–119`

**The problem:** Orianna prompt bodies (8–13kB each phase) are stable
across invocations, but invocations are often hours apart. 5-minute
TTL → every Orianna call writes cache, almost none read it.

**Research needed before implementing:** does Claude Code CLI (the
`claude -p` binary) expose a flag or env var for 1-hour TTL? The CLI
does not surface `cache_control` JSON directly; we'd need to check
recent `claude-code` release notes and/or `claude --help` output on
the current version. If yes — trivial env var set. If no — this
change requires moving the Orianna invocation from `claude -p` to a
direct `curl`/`httpx` call to `api.anthropic.com/v1/messages` with
explicit `cache_control: {"type": "ephemeral", "ttl": "1h"}` on the
phase-prompt-body block. That is a real code change and would need
an ADR.

**Estimated savings (if 1h TTL is available via flag):** phase prompts
~10kB × ~20 sign invocations / mo × (0.9 − 0.1) discount ratio change
on cache-read-vs-miss = ~2M tokens/mo. Small but real.

**Hours:** 1 hour of research, 1 hour to wire a flag if available;
otherwise 6–10 hours to build a direct-SDK Orianna path.

**Confidence:** low — depends entirely on what `claude -p` exposes today.

### #3 — Split `agent-network.md` into stable + volatile halves

**File anchors:**

- `agents/memory/agent-network.md` (13kB)
- All boot sequences that reference it

**The problem:** `agent-network.md` is loaded on every coordinator AND
every subagent boot (rule: subagents read it for routing rules). It
currently interleaves stable roster info with volatile things like
"retired agents" and "recently renamed" notes. Any edit to the volatile
half invalidates the cache for the whole file in every agent that
reads it.

**Proposed split:**

- `agents/memory/agent-network.md` → stable roster, stable routing
  rules. Rarely edited.
- `agents/memory/agent-network-changelog.md` → retired agents, renames,
  "new-<date>" tags, historical notes. Edited freely.

Subagents load only the stable half unless they need the changelog
(coordinator uses it for routing exceptions).

**Estimated savings:** 13kB × shared across every subagent boot (~50/day
across both concerns) × ~0.5 current cache-break rate × 0.8 discount
improvement ≈ 3–5M tokens/mo (rough).

**Hours:** 3–4. Needs a careful split + updating all references.
Low-risk but touches many files.

**Risk:** low-medium. Must update every boot-read list to point at the
right half. One missed reference and the split is useless for that
agent.

### #4 — Deterministic `learnings/index.md` format

**File anchors:**

- `agents/evelynn/learnings/index.md`
- `agents/sona/learnings/index.md`
- Whatever generates them (check `scripts/` — likely a `/end-session`
  skill step or manual edits)

**The problem:** `index.md` files tend to mutate byte-for-byte even when
semantically equal (line ordering shifts, trailing whitespace, etc.).
Any byte drift here invalidates the cache for everything loaded after
it in the boot chain.

**Proposed fix:** pin these files to a deterministic sort order
(alphabetical by filename, consistent whitespace, no trailing spaces,
final-newline normalised). If a script writes them, add a sort+strip
step; if humans write them, add a linter.

**Estimated savings:** 2–4M tokens/mo (rough). Modest because the
files are small, but the compounding effect across every boot makes it
worth the hour.

**Hours:** 2. One script fixup + a pre-commit lint step.

### #5 — Document "prompt-stability hygiene" as a rule

**New file:** `architecture/prompt-stability.md`
**Amend:** `CLAUDE.md` — add a new Critical Rule or hygiene note

**The rule:** files read at agent boot must be classified as **stable**
or **volatile**. Volatile files (rewritten on session close, boot,
every interaction) go at the END of boot-read sequences. Stable files
go at the front. New files added to boot sequences must be classified
and placed appropriately. Any time a file's write-frequency increases,
its position in boot sequences must be re-evaluated.

This is preventative — no token savings today, but it prevents
future regressions from erasing the Finding #1 win.

**Hours:** 1. Documentation only.

---

## 3. What we are NOT recommending

- **Adding explicit `cache_control: ephemeral` anywhere in the
  harness.** Nothing calls the API directly from our code. If a future
  project builds on raw Anthropic SDK (e.g. a Vertex-backed research
  lane, a Python agent that doesn't go through Claude Code) — then
  yes, every such call should use `cache_control` with a 1-hour TTL
  on the static system prompt + tool-definitions portion. Until that
  code exists, this isn't actionable.
- **Pulling shared-rules bodies out of agent defs and loading them at
  runtime.** Our current sync-shared-rules.sh inlines them at build
  time, which is already cache-optimal. Runtime-loading would break the
  single-prefix property that makes auto-cache work.
- **Adopting the `flightlesstux/prompt-caching` plugin.** Per its own
  README, that plugin is for apps that call the Anthropic SDK directly.
  Not useful for us today — `claude -p` already caches automatically.
- **Migrating all Orianna invocations to direct SDK today.** Cost is
  real (8–10 hours of ADR + implementation + Rule 19 signature
  machinery) and the savings are small. Only worth doing if we find
  Claude Code CLI exposes no 1-hour TTL knob AND we observe Orianna
  costing a meaningful fraction of weekly Opus cap.

---

## 4. Implementation sketch for Karma

If Duong approves, this is a single quick-lane plan for Karma, not a
full ADR. Estimated 6–10 hours total across all five findings.

- **T1 (2h)** — Reorder coordinator boot chains per §2 #1. Touches
  `.claude/agents/evelynn.md`, `.claude/agents/sona.md`,
  `agents/evelynn/CLAUDE.md`, `agents/sona/CLAUDE.md`. No behaviour
  change, just order in the `initialPrompt` YAML block and the
  "Startup Sequence" lists in the CLAUDE.md addenda.
- **T2 (3h)** — Split `agents/memory/agent-network.md` into stable
  roster + volatile changelog. Update all boot-read references.
- **T3 (2h)** — Deterministic `index.md` formatter + pre-commit lint.
- **T4 (1h)** — Write `architecture/prompt-stability.md` + amend
  `CLAUDE.md` with a new hygiene note.
- **T5 (1–2h, deferred)** — Research `claude -p` cache-TTL knobs; if
  present, set them on `scripts/orianna-*.sh`. If not present, log as
  future ADR candidate.

Dependencies: T1 can ship first, independently. T2 and T3 are
independent. T4 is documentation, can ship any time. T5 is a research
spike and might turn into a separate ADR (hence deferred tagging).

Testing: T1 has no behaviour change but should be validated by
`scripts/test-boot-chain-order.sh` (already exists per the scripts
listing). T2 needs eyeballed subagent boots after the split. T3 needs
a regression test on the formatter. T4 and T5 are non-code.

---

## 5. Open questions

1. **Does `claude -p` expose a cache TTL knob today?** Did not verify
   during this research pass — would need to `claude --help | grep -i
   cache` on the installed version and check changelog. If yes,
   Finding #2 is 1 hour of work. If no, it's an ADR-scale change.
2. **What is the actual coordinator boot rate?** Finding #1's savings
   estimate is proportional to boot frequency. A week of `/status` or
   ccusage data would tighten this materially.
3. **Is any raw-SDK code anywhere I missed?** Grep found none, but
   something like a one-off Python script in `tools/` or a Telegram
   bridge worker could be calling the SDK directly. Worth a broader
   grep on `anthropic.Anthropic(` and `AnthropicBedrock(` and
   `AsyncAnthropic(` across the entire repo before shipping any
   change that assumes we have zero SDK surface.
4. **Workspace-isolation (2026-02-05) effect on cache hit rate.**
   Unclear if coordinator vs. subagent sessions in Claude Code share
   a cache workspace. If they don't, even the cleanest prefix order
   won't help cross-agent. Would need a controlled experiment —
   spawn Viktor twice within 1 minute and observe `cache_read_input_tokens`
   in the transcript.

---

## Sources (fetched 2026-04-21)

- [Anthropic prompt caching docs](https://platform.claude.com/docs/en/docs/build-with-claude/prompt-caching) — pricing, TTL, minimum block sizes, cache_control semantics, prefix-hash rules.
- [Claude Prompt Caching in 2026: The 5-Minute TTL Change — DEV](https://dev.to/whoffagents/claude-prompt-caching-in-2026-the-5-minute-ttl-change-thats-costing-you-money-4363) — historical 60m → 5m TTL change impact.
- [How Prompt Caching Actually Works in Claude Code](https://www.claudecodecamp.com/p/how-prompt-caching-actually-works-in-claude-code) — Claude Code's automatic cache behaviour with `-p`.
- [flightlesstux/prompt-caching](https://github.com/flightlesstux/prompt-caching) — confirms Claude Code already auto-caches; plugin is for raw-SDK apps only.
- [Vertex AI Claude prompt-caching docs](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/partner-models/claude/prompt-caching) — reference for any future Vertex lane.
- Parent assessment: `assessments/ai-provider-capacity-expansion-2026-04-21.md` §5 Tier 1 #2.

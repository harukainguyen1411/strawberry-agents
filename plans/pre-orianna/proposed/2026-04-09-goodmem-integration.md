---
status: proposed
owner: bard
---

# GoodMem Integration — Semantic Memory Layer for Strawberry Agents

## 1. Problem Statement

Strawberry's current memory model is **file-based, per-agent, and lexical**:

- Each agent has `agents/<name>/memory/<name>.md` (operational memory, capped at ~50 lines) and `memory/last-session.md` (handoff note).
- Journals, learnings, and transcripts live as plain Markdown under `agents/<name>/journal/`, `agents/<name>/learnings/`, `agents/<name>/transcripts/`.
- Shared memory is `agents/memory/duong.md` and `agents/memory/agent-network.md`.
- Retrieval is either (a) deterministic startup reads of a fixed shortlist, or (b) ad-hoc `Grep`/`Read` when an agent remembers a keyword.

This has served the system well for ~1 month but is showing three structural limits:

1. **No semantic recall across agents.** Bard cannot find "that thing Syndra decided about condenser placement" without knowing Syndra's filename and grepping for the right literal. Cross-agent knowledge reuse relies on Evelynn having read the relevant thing recently.
2. **Aggressive pruning loses context.** The 50-line memory cap forces agents to drop nuance. Everything pruned is gone unless it happened to land in a journal or learning file — and those aren't indexed.
3. **Startup reads don't scale.** Every agent reads 5–6 fixed files at boot. As the learnings archive grows (and with `/end-session` now writing cleaned transcripts into `transcripts/`), the "read everything relevant" strategy can't cover growing corpora without blowing context budget.

What we actually want: agents should be able to ask *"what do I/we know about X?"* in natural language and get the top-k most relevant snippets from across the entire historical record — learnings, journals, transcripts, decisions, plans — regardless of which agent wrote them.

## 2. What GoodMem Is

GoodMem is a self-hostable memory server for AI agents. Core concepts:

- **Embedder** — a registered embedding model (OpenAI, Voyage, Google, etc.) that converts text to vectors.
- **Space** — a named container of memories bound to one embedder, with chunking config. Think "collection" or "index".
- **Memory** — a piece of text stored in a space; automatically chunked + embedded on write.
- **Retrieve** — semantic search across one or more spaces, returns ranked chunks (NDJSON stream).
- **Optional: LLM / Reranker** — registered models GoodMem can use for RAG-style answer generation or result reranking.

It exposes:

- A **REST API** (that's the ground truth).
- A **Python SDK** (`goodmem` package) with context-managed client.
- An **MCP server** (`goodmem:*` tools) wrapping the REST API 1:1 — already installed as a Claude Code plugin in this environment.

Two env vars drive everything: `GOODMEM_BASE_URL` and `GOODMEM_API_KEY` (starts with `gm_`).

**Critical caveat:** GoodMem requires a **running server somewhere**. It is not a local library. Duong must either self-host (Docker on the GCE VM, Fly.io, etc.) or use a hosted instance. No server → no integration. This is the single biggest prerequisite.

## 3. Fit Against Rule 16

CLAUDE.md rule 16: *"Project MCPs are only for external system integration."* GoodMem cleanly passes this test:

- It is a **stateful external system** (vector DB + embeddings API + server process).
- It has a **protocol-heavy** surface (41 MCP tools, REST, streaming retrieval).
- Local coordination and procedural discipline stay in skills/scripts/CLAUDE.md. GoodMem only handles the "shared semantic memory" concern — nothing about delegation, session lifecycle, or agent-to-agent messaging moves into it.

The `goodmem` MCP is therefore a legitimate addition per the MCP restructure governing invariant. It sits alongside `evelynn` (and the new `discord` MCP from 2026-04-09) as a thin wrapper over an external stateful system.

## 4. Design — How Agents Would Use It

### 4.1 Space layout

Three spaces (keep it simple; we can split later if recall suffers):

| Space | Purpose | Writers | Readers |
|---|---|---|---|
| `strawberry-shared` | Cross-agent canonical knowledge: Duong profile facts, agent-network rules, architecture decisions, approved plans summaries, learnings marked "shared". | Any agent (via `/agent-ops mem write --shared`) | All agents |
| `strawberry-agent-<name>` | Per-agent long memory: journals, session handoffs, personal learnings, pruned memory overflow. One space per agent. | Only that agent | That agent (default); other agents on explicit cross-read |
| `strawberry-transcripts` | Cleaned session transcripts produced by `/end-session`. High volume, high noise — separated so retrieval against `strawberry-shared` isn't polluted. | `/end-session` skill | Any agent on explicit opt-in (e.g. `/agent-ops mem recall --include-transcripts`) |

Rationale for separation:

- **Shared vs. per-agent** preserves the mental model of "my memory" while still enabling cross-agent search when asked.
- **Transcripts in their own space** avoids drowning out deliberate, curated memories. Transcripts are "everything I said"; shared/agent are "things I chose to remember".

### 4.2 Embedder choice

Start with **one** OpenAI `text-embedding-3-large` embedder bound to Duong's OpenAI key. Reasons:

- Well-understood, cheap, high-quality, 3072-dim.
- Single embedder → all three spaces are mutually searchable (embedder-per-space is a GoodMem constraint; if we change embedder we'd have to re-embed).
- Can switch to Voyage or Google later if needed — plan a re-embed path but don't over-engineer now.

Credentials live in `secrets/openai-api-key.txt` (age-encrypted, decrypted via `tools/decrypt.sh` into the MCP server env at launch time). Same pattern as the existing Telegram/Discord tokens.

### 4.3 Agent-facing surface

Agents should **not** need to learn 41 MCP tool names. Wrap the common operations in a new `/agent-ops mem` subcommand (skill, not MCP — local coordination discipline):

```
/agent-ops mem write <text>                     # write to current agent's space
/agent-ops mem write --shared <text>             # write to strawberry-shared
/agent-ops mem recall <query>                    # semantic search: own space + shared
/agent-ops mem recall --all-agents <query>       # search every agent's space + shared
/agent-ops mem recall --include-transcripts <q>  # also search transcripts
/agent-ops mem list [--space <name>]             # list recent memories in a space
```

Under the hood the skill shells out to a small Python script (`scripts/goodmem-client.py`) that uses the `goodmem` Python SDK. The MCP server is still registered in `.mcp.json` for cases where an agent wants to do something the skill doesn't expose — but day-to-day agents use the skill.

Why skill + script rather than bare MCP tool calls:

- Consistent with Phase 1 MCP restructure pattern (`/agent-ops` umbrella, POSIX bash, rule 17).
- Agents don't have to remember space IDs — the skill resolves `$CLAUDE_AGENT_NAME` to `strawberry-agent-<name>`.
- We can add guardrails (e.g. dedupe, length caps, redaction of secret-denylist strings before write) in one place.
- Cross-platform: same skill works on Mac and Git Bash on Windows.

### 4.4 Write flow — what gets embedded, when

Not everything should go to GoodMem. Proposed policy:

| Source | Written to GoodMem? | Space | When |
|---|---|---|---|
| `agents/<name>/memory/<name>.md` prune overflow | Yes | `strawberry-agent-<name>` | When `/end-session` prunes memory below 50 lines, pruned lines flow to GoodMem with a `pruned-from-memory` tag. |
| `agents/<name>/learnings/*.md` | Yes | `strawberry-agent-<name>`, and `strawberry-shared` if marked `shared: true` in frontmatter | At write time by the learning-writing flow (part of `/end-session`). |
| `agents/<name>/journal/cli-*.md` | Yes | `strawberry-agent-<name>` | At write time by `/end-session`. |
| Cleaned transcripts (`agents/<name>/transcripts/*.md`) | Yes | `strawberry-transcripts` | At write time by `/end-session`. |
| `agents/memory/duong.md`, `agent-network.md` | Yes | `strawberry-shared` | On change, via a git post-commit hook or manual `/agent-ops mem sync`. |
| Architecture docs (`architecture/*.md`) | Yes | `strawberry-shared` | Same as above. |
| Approved plans (`plans/approved/*.md`, `plans/implemented/*.md`) | Yes (summary only, not full body) | `strawberry-shared` | On promotion via `plan-promote.sh`. |
| `plans/proposed/*.md` | No | — | Too churny; retrieval quality would drop. |
| Duong's raw chat / CLI input | No | — | Privacy + signal/noise. |

Writes are best-effort. If GoodMem is down, `/end-session` logs a warning and continues — file-based memory remains the source of truth. Rule 1 (never leave work uncommitted) is unchanged.

### 4.5 Read flow — when agents query

Startup sequence (CLAUDE.md §Startup Sequence) **stays file-based**. We do not add a GoodMem call to every boot. Reasons:

- File reads are deterministic, fast, and work offline.
- GoodMem is additive: agents query it *on demand* when they need recall beyond the boot shortlist.

New optional step 7 in startup: *"If you're about to take on a task referencing historical context, run `/agent-ops mem recall <topic>` before planning."* This is a behavioral nudge, not a hard requirement.

Concrete use cases where agents should hit GoodMem:

- Bard is asked to integrate a new MCP — `/agent-ops mem recall "mcp integration patterns"` surfaces Discord MCP and agent-manager lessons.
- Syndra plans a new pipeline — recalls past autonomous-delivery-pipeline decisions.
- Evelynn receives a task and isn't sure who handled similar work — `/agent-ops mem recall --all-agents "frontend testing"`.

## 5. Setup Work (what has to happen, in order)

**Phase 0 — Server decision (blocker, needs Duong).**
1. Decide hosted vs. self-hosted. Recommendation: **self-host on the always-on GCE VM** (`project_agent_runtime_dual_mode` in user memory — the VM is already the autonomous overnight target). Docker compose file, Postgres + pgvector backend, persistent disk.
2. If Duong prefers zero-ops, evaluate a hosted GoodMem instance (if one exists) or fall back to Fly.io.
3. Provision an OpenAI API key (likely already exists) and commit the encrypted secret to `secrets/openai-api-key.txt.age`.

**Phase 1 — Bootstrap GoodMem (Sonnet-executable once Phase 0 lands).**
1. Add `goodmem` to `.mcp.json` with `GOODMEM_BASE_URL` / `GOODMEM_API_KEY` piped through `tools/decrypt.sh`.
2. Write `scripts/goodmem-bootstrap.py` — idempotent script that: creates the OpenAI embedder if missing, creates the three spaces if missing, prints their IDs to `secrets/goodmem-space-ids.env` (gitignored).
3. Run bootstrap once on the VM; verify via `goodmem_system_info` and `goodmem_spaces_list`.

**Phase 2 — `/agent-ops mem` skill + client script.**
1. Write `scripts/goodmem-client.py` (Python, SDK-based, POSIX-portable invocation). Subcommands: `write`, `recall`, `list`. Reads space IDs from env.
2. Write `.claude/skills/agent-ops/SKILL.md` additions for the `mem` subcommand, following the same pattern as `send` / `list` / `new`.
3. Update `scripts/list-agents.sh` — no change needed, but document the new subcommand in agent-network.md.

**Phase 3 — Wire `/end-session` writes.**
1. Extend `.claude/skills/end-session/SKILL.md` and `.claude/skills/end-subagent-session/SKILL.md` step list: after the journal/handoff/memory/learnings writes, call `scripts/goodmem-client.py write` for each new artifact. Best-effort; log-and-continue on failure.
2. Add a secret-denylist pre-filter: reuse `scripts/pre-commit-secrets-guard.sh` logic (or factor it to a shared helper) so nothing matching known secrets ever gets embedded.

**Phase 4 — Backfill (one-time).**
1. One-shot script: walk `agents/*/learnings/`, `agents/*/journal/`, `agents/*/transcripts/`, `agents/memory/`, `architecture/`, `plans/approved/`, `plans/implemented/`, write everything to GoodMem.
2. Idempotent via content hashing (check if `hash(text)` already exists as a tag; skip if so).

**Phase 5 — Documentation.**
1. New `architecture/memory-layer.md` — explains file-based (source of truth) vs. GoodMem (semantic index), write policy, read policy.
2. Update `architecture/mcp-servers.md` with a `goodmem` section.
3. Update `agents/memory/agent-network.md` with the `/agent-ops mem` subcommand reference and a one-paragraph recall nudge.
4. Update CLAUDE.md §Startup Sequence with the optional step 7 recall nudge.
5. Update every agent's profile.md startup sequence where relevant (probably handled by a sweep script, not hand-edited per agent).

## 6. Migration Path

**File-based memory remains the source of truth.** GoodMem is an index, not a replacement. This keeps the migration low-risk:

- Nothing that currently works breaks. Agents still read `memory/<name>.md` at boot. Learnings/journals still live on disk and get committed.
- GoodMem adds a parallel, queryable layer. If the server goes down, the only loss is semantic recall — agents keep functioning.
- If we decide GoodMem isn't worth it, we stop writing to it and delete the spaces. No agent code changes required beyond removing the recall nudge.

Specific file edits (not a full list, but the shape):

- `CLAUDE.md` — add rule or note in §Startup Sequence about `mem recall` nudge; cross-ref `architecture/memory-layer.md`.
- `agents/memory/agent-network.md` — document `/agent-ops mem` under Communication Tools.
- `.mcp.json` — add `goodmem` entry.
- `.claude/skills/agent-ops/SKILL.md` — add `mem` subcommand.
- `.claude/skills/end-session/SKILL.md` + `.claude/skills/end-subagent-session/SKILL.md` — add write step.
- `architecture/mcp-servers.md` — document `goodmem`.
- `architecture/memory-layer.md` — new file.
- `architecture/README.md` — link the new doc.
- `secrets/openai-api-key.txt.age` — new encrypted secret.
- `secrets/goodmem-space-ids.env` — gitignored, written by bootstrap.

No changes required to individual agent profiles or to the 50-line memory cap (though we may relax it in a follow-up once GoodMem is proven — the cap exists because reads are expensive, and semantic recall changes that calculus).

## 7. Open Questions (need Duong input or follow-up research)

1. **Hosting decision.** GCE VM self-host vs. hosted. Recommendation: GCE VM. Needs a green light and a slot in the VM bring-up plan.
2. **Backend DB.** GoodMem docs should confirm supported backends (Postgres+pgvector most likely). If it needs a separate DB, that's another piece of infra to manage on the VM.
3. **Cost envelope for embeddings.** Embedding `text-embedding-3-large` is ~$0.13/M tokens. One-time backfill is probably <$1. Ongoing writes during `/end-session` are negligible. Worth confirming but not a blocker.
4. **Privacy of transcripts.** Cleaned transcripts can contain sensitive context. Is Duong comfortable with those being embedded even locally? If not, drop the `strawberry-transcripts` space from Phase 1 and revisit.
5. **Cross-agent reads — default on or opt-in?** Current proposal: agent's own space + shared by default, all-agents/transcripts behind explicit flags. Confirm that matches Duong's mental model of "private vs. shared memory".
6. **Does GoodMem support metadata filters?** The MCP reference doesn't show a `tags`/`metadata` parameter on `memories_create` or `memories_retrieve`. If it does (via request body), we can tag writes with `agent:<name>`, `source:learning`, `date:...` and filter at query time. If not, we rely purely on space separation, which may be coarse. **Bard to verify against Python SDK reference in Phase 1.**
7. **Reranker?** Start without one. Add Voyage `rerank-2` in a follow-up if retrieval quality feels noisy.
8. **Interaction with the Google Drive plan mirror.** Plans in `plans/proposed/` are also mirrored to Drive. GoodMem writes only on promotion, so no conflict. Noted for awareness.
9. **MCP server runtime.** The `goodmem` MCP plugin appears to run client-side (inside Claude Code). That's fine for agents running locally, but autonomous GCE-VM sessions also need it registered in their `.mcp.json`. Confirm both runtime targets from `project_agent_runtime_dual_mode` get the MCP wired.

## 8. Recommendation

**Proceed in two stages.**

- **Stage A (small, reversible):** Phases 0–2. Bring up a GoodMem server, wire the MCP, ship `/agent-ops mem` skill. Agents *can* use semantic recall but nothing writes to it automatically yet. Evelynn + Bard dogfood it for a week.
- **Stage B (broader):** Phases 3–5. Wire `/end-session` writes, backfill history, document in architecture, nudge agents to use `mem recall` in their boot sequences.

This minimizes blast radius: Stage A is two skills and a Docker compose file, revertible in minutes. Stage B only happens after Stage A proves the retrieval quality is worth the plumbing.

If retrieval quality is disappointing at Stage A, the fallback is to treat GoodMem as an opt-in lookup Bard/Syndra use for research sessions, and not bother with the automatic write path.

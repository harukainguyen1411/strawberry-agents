---
status: proposed
concern: personal
owner: swain
created: 2026-04-21
orianna_gate_version: 2
tests_required: true
complexity: complex
tags: [memory, boot, coordinator, evelynn, sona, shards]
related:
  - assessments/personal/2026-04-21-memory-consolidation-redesign.md
  - plans/proposed/2026-04-18-evelynn-memory-sharding.md
  - plans/implemented/personal/2026-04-20-lissandra-precompact-consolidator.md
architecture_impact: refactor
orianna_signature_approved: "sha256:e096a46fc6f915d9a1e1e6e3f2a72bbe121459dc3c2b8e417ef6ee2fb469646e:2026-04-21T03:56:51Z"
---

# Memory consolidation redesign — two-layer boot (eager manifest + lazy archive)

## 1. Problem & motivation

Evelynn and Sona both boot by eagerly loading every shard in `agents/<coordinator>/memory/last-sessions/` whose mtime falls within the last 48 hours. That window is a proxy for relevance, and proxies leak in both directions:

1. **Noisy-busy failure** — right now Evelynn has 23 shards in her 48h window (verified `ls agents/evelynn/memory/last-sessions/` on 2026-04-21). Most describe threads that merged, closed, or were superseded hours later. Boot context is dominated by stale noise.
2. **Idle-amnesia failure** — if more than 48h elapses between sessions, every shard falls outside the window and the coordinator boots blind to threads that were alive three days ago. The most recent shard disappears from the eager load purely because wall-clock moved.

Current boot token cost (Evelynn, per recommendation §Token budget estimate): ~13–14k input tokens, of which ~40k raw bytes / ~10k tokens come from the 23-shard eager load alone. Proposed two-layer shape drops this to ~4–5k, saving ~8–9k tokens per boot and giving a far more cache-friendly static prefix.

Lux's 2026-04-21 recommendation (`assessments/personal/2026-04-21-memory-consolidation-redesign.md`) surveys six shipped memory systems (Anthropic Memory tool, Letta/MemGPT, LangGraph, Cursor, Claude Code, grassroots handoff-pattern) and observes they all converge on the same split: eager curated manifest + lazy on-demand historical retrieval. Nobody eagerly loads a time window of raw session shards. This plan adopts that convergent pattern for Evelynn and Sona simultaneously.

## 2. Decision

Replace the 48h-mtime eager boot with a **two-layer memory shape**:

- **Eager, small, curated** — `open-threads.md` (hand-maintained live state) plus `last-sessions/INDEX.md` (auto-generated 3-line-per-shard TL;DR). Always loaded at boot.
- **Lazy, large, historical** — `last-sessions/<uuid>.md` shards (unchanged) and `last-sessions/archive/<uuid>.md` (new archival tier). Pulled on demand by the coordinator or delegated to Skarner.

### Settled design (Duong's gating answers, 2026-04-21)

These four decisions are final and drive the plan below:

1. **Scope — option a: migrate BOTH Evelynn and Sona in one plan.** Shared scripts (`memory-consolidate.sh`, deletion of `filter-last-sessions.sh`), shared skill (`end-session`), shared boot shape. One cutover, no dual-mode overlap.
2. **Retention — option a: hybrid (14 days OR 20 shards, whichever hits first).** Archive policy for shards moving `last-sessions/` → `last-sessions/archive/`.
3. **INDEX.md regen cadence — option a: regenerate on every `/end-session` write.** INDEX is always current at the next boot; commit churn is one extra staged file per session close.
4. **Startup order — option b: dynamic tail (after static files).** Read order: `<coordinator>.md` → `duong.md` → `agent-network.md` (static prefix — prompt-cacheable) → `open-threads.md` → `INDEX.md` (dynamic tail — invalidates independently of the stable prefix).

## 3. File structure

Concrete paths under `agents/<coordinator>/memory/` for each of Evelynn and Sona. "unchanged" means shape and semantics are already in place today.

```
agents/<coordinator>/memory/
├── <coordinator>.md                        # unchanged — static identity + durable context (consolidated sessions block)
├── open-threads.md                         # NEW — eager, small (~50–200 lines), hand-maintained by coordinator
├── last-sessions/
│   ├── <uuid>.md                           # unchanged — full handoff shards, written by /end-session Step 6
│   ├── INDEX.md                            # NEW — auto-regenerated 3-line-per-shard TL;DR, newest first
│   └── archive/
│       └── <uuid>.md                       # NEW archival tier — shards past 14d OR beyond #20 (whichever first)
└── sessions/                               # unchanged — separate tier folded into <coordinator>.md by memory-consolidate.sh
    ├── <uuid>.md
    └── archive/
```

Relevant details:

- `open-threads.md`: a single markdown file with one `## <thread-name>` section per live thread. Each section carries a status one-liner, the shard UUID(s) that hold detail, and the next action. Written by the coordinator at `/end-session` time, edited in-place during the session as threads open or close. Never archived — it is the live doc.
- `last-sessions/INDEX.md`: auto-generated by `scripts/memory-consolidate.sh`. One row per shard under `last-sessions/` (plus a short pointer line per archived shard), newest first, columns: date · UUID · 3-line TL;DR parsed from the shard header. Fail-safe for "did I need to pull a historical shard?" lookups.
- `last-sessions/archive/<uuid>.md`: shard files moved via `git mv` once the retention policy triggers. The 30d-window prune logic in the current `memory-consolidate.sh` for `last-sessions/` is replaced by the 14d-OR-20-shards archive logic; the pre-existing 30d prune of `archive/` contents is kept unchanged.
- Coexistence with `sessions/`: the `sessions/` → `<coordinator>.md ## Sessions` consolidation path stays intact. This plan touches `last-sessions/` only.

### Layer responsibilities (single source of truth for each invariant)

| Concern | Owner | Mechanism |
|---|---|---|
| What threads are live | `open-threads.md` | Coordinator-hand-written at `/end-session`, in-place during session |
| Which historical shards exist | `last-sessions/INDEX.md` | Auto-regenerated on every `/end-session` write |
| Full shard detail | `last-sessions/<uuid>.md` | Unchanged; on-demand read via the coordinator or Skarner |
| Archival retention | `scripts/memory-consolidate.sh` | 14d OR 20 shards whichever first → `archive/` |
| Archive deletion | `scripts/memory-consolidate.sh` | 30d prune (kept as-is from current script) |

## 4. Script changes

### 4.1 DELETE `scripts/filter-last-sessions.sh`

The 48h-mtime window goes away entirely. No dual-mode overlap — boot reads `open-threads.md` + `INDEX.md` directly. The script's pre-boot validator (sentinel count + shard count) moves into `scripts/memory-consolidate.sh` so boot still gets a validation gate.

### 4.2 REWRITE `scripts/memory-consolidate.sh`

Additive responsibilities (preserve all existing `sessions/` → `<coordinator>.md ## Sessions` block folding + UUID collision loop + locking + commit/push):

1. **INDEX regeneration pass (new).** Walk `last-sessions/*.md` sorted newest-first by mtime. For each shard: parse the TL;DR from the shard header (first non-heading paragraph under the top `# ...` heading, or a dedicated `TL;DR:` line — see §4.4). Emit a row into `last-sessions/INDEX.md`: `YYYY-MM-DD · <uuid> · <3-line TL;DR>`. Append a "## Archived" section listing archive/<uuid>.md files with one-line pointers. Idempotent: overwrite the file every call.
2. **Archive policy (new, replaces the existing `last-sessions/` 30d prune).** After INDEX regen and before commit, compute the set of shards to archive:
   - Input set = `last-sessions/*.md` (exclude `.gitkeep`, exclude `INDEX.md` itself, exclude `archive/`).
   - Order newest-first by mtime (ties broken by filename ascending).
   - For each shard: archive it if EITHER mtime-age > 14d OR its index position (1-based) > 20. Whichever hits first; both checks ORed means the first 20 shards newer than 14d stay put, everything else moves.
   - Pre-archive guard: before moving a shard X, read `open-threads.md` and check for any reference to X's UUID. If `open-threads.md` still points at X, skip the archive move and log a warning (§10 failure mode #4).
   - Move via `git mv` into `last-sessions/archive/<uuid>.md`. Reuse existing UUID-collision-suffix loop (max 100 attempts, same as today).
3. **Archive deletion (retain as-is).** The existing 30d-from-commit-date prune on `archive/` contents stays unchanged. It is the backstop for disk pressure.
4. **Pre-boot validator (new, moved from `filter-last-sessions.sh`).** Verify sentinel `<!-- sessions:auto-below` appears exactly once in `<coordinator>.md`. Verify `last-sessions/` exists. Log shard counts to stderr for the coordinator's audit trail. Fail loud on sentinel drift.

Keep unchanged: the `sessions/*.md` → `<coordinator>.md ## Sessions` folding path, UUID collision handling, flock/noclobber locking, commit message (`chore: <secretary> memory consolidation YYYY-MM-DD`), push-with-retry behavior, POSIX-portable bash, python3 dependency.

### 4.3 NEW helper `scripts/_lib_last_sessions_index.sh` (sourced-only) <!-- orianna: ok -->

Single source of truth for INDEX row generation from a shard path. Public functions:

- `extract_shard_tldr <shard_path>` — stdout: 3 lines of TL;DR. Parse rules (in order): (a) if the shard has a line matching `^TL;DR:` (case-sensitive), use the first 3 non-blank lines beginning at that anchor; (b) else use the first 3 non-blank prose lines under the first `# ...` heading (skip frontmatter, skip subsequent `##` headings); (c) else fall back to filename + "(no summary extractable)".
- `render_index_row <shard_path> <mtime_epoch>` — stdout: one markdown table row or indented list entry (format to be finalised in T2; must be greppable by UUID).
- `regenerate_index <last_sessions_dir> <output_file>` — walk the directory, sort newest-first, emit header + rows + archive-pointer section.

Sourced by `memory-consolidate.sh`; no shebang. POSIX bash.

### 4.4 Shard header convention (documented, not enforced)

Shards today begin with a plain `# <one-line title>` and free-form content. To keep INDEX generation deterministic, document an optional convention in `.claude/skills/end-session/SKILL.md` Step 6 and in `architecture/coordinator-memory.md` (new, see §6.2): coordinators MAY include a `TL;DR: <line>` trio immediately after the H1. <!-- orianna: ok --> If absent, §4.3 rule (b) falls back to prose parsing. Pre-existing shards continue to work without rewriting.

## 5. Skill changes

### 5.1 `.claude/skills/end-session/SKILL.md` — inject open-threads update + INDEX regen

Current Step 6 ("Remember handoff") for `agent == evelynn` writes `agents/evelynn/memory/last-sessions/<short-uuid>.md` and stages it. Add a **Step 6b** (between 6 and 7) for coordinators (`evelynn` OR `sona`):

1. Parse the shard's `## Open threads into next session` section (today's shard convention — verified present in `agents/evelynn/memory/last-sessions/002efe6a.md`).
2. Apply the parsed deltas to `agents/<coordinator>/memory/open-threads.md`:
   - For each thread listed as resolved/closed in the shard: remove or move the matching `## <thread>` section from `open-threads.md`.
   - For each thread listed as new or still-open: add or update its `## <thread>` section in `open-threads.md` with the shard UUID as a pointer.
   - Coordinator-authored — the skill asks the coordinator to confirm the diff before writing. Hand-curation is the value (see §11 out-of-scope: no LLM auto-summarization).
3. Stage: `git add agents/<coordinator>/memory/open-threads.md`.
4. Regenerate `last-sessions/INDEX.md`:
   ```
   bash scripts/memory-consolidate.sh --index-only <coordinator>
   ```
   (New `--index-only` flag: runs only the INDEX regen pass from §4.2, no archive move, no sessions-block fold, no commit/push. Lightweight — target sub-second.)
5. Stage: `git add agents/<coordinator>/memory/last-sessions/INDEX.md`.

Ordering within `/end-session`:

- Step 6 (write shard) MUST complete before Step 6b (update open-threads + regen INDEX) because the shard is the source truth for both writes.
- Step 6b MUST complete before Step 9 (commit + push) so all three artifacts land atomically in one commit.
- If Step 6b fails partway, the shard write already landed and is recoverable at next `/end-session` or by running `scripts/memory-consolidate.sh --index-only` manually. Open-threads staleness is the soft-fail direction (§10 failure mode #1).

For non-coordinator agents (Sonnet subagents invoked via `/end-subagent-session`), Step 6b is a no-op — they don't have `open-threads.md` or `last-sessions/INDEX.md`.

### 5.2 `.claude/skills/pre-compact-save/SKILL.md` — mirror the open-threads + INDEX step

`pre-compact-save` dispatches Lissandra (`agents/lissandra/profile.md`) to run the coordinator close protocol at compact boundaries. Lissandra's current protocol mirrors `/end-session` Steps 2–9. Two changes required, in Lissandra's agent definition rather than in the skill file (the skill is a thin dispatcher):

1. Audit Lissandra's protocol file (`.claude/agents/lissandra.md` + `agents/lissandra/profile.md`) for an equivalent of the Step-6b open-threads update. As of 2026-04-21 it does not exist.
2. Add the Step 6b sequence (parse shard's Open threads section → update `open-threads.md` → regenerate INDEX → stage) to Lissandra's agent-def ordering, identical to `end-session`'s new Step 6b but written in Lissandra's voice.

The `pre-compact-save` SKILL.md itself needs only a one-line note confirming Lissandra updates `open-threads.md` and regenerates INDEX as part of the shard write. No functional skill changes; the shape is already "dispatcher + sentinel check."

## 6. Agent definition changes

### 6.1 `.claude/agents/evelynn.md` and `.claude/agents/sona.md` — boot script rewrite

Both files currently run `bash scripts/filter-last-sessions.sh <name>` and read each listed shard. Replace that step. New `initialPrompt` shape (Evelynn example; Sona identical with names swapped):

> Otherwise, for a fresh session with no prior history: First run `bash scripts/memory-consolidate.sh evelynn` (fold old `sessions/*` shards into `evelynn.md`, regenerate `last-sessions/INDEX.md`, archive `last-sessions/` shards past 14 days OR beyond #20; commit+push). Then read in order:
> 1. `agents/evelynn/CLAUDE.md`
> 2. `agents/evelynn/profile.md`
> 3. `agents/evelynn/memory/evelynn.md`
> 4. `agents/memory/duong.md`
> 5. `agents/memory/agent-network.md`
> 6. `agents/evelynn/learnings/index.md` (if exists)
> 7. `agents/evelynn/memory/open-threads.md` <!-- orianna: ok -->
> 8. `agents/evelynn/memory/last-sessions/INDEX.md` <!-- orianna: ok -->
>
> Pull individual shards (`agents/evelynn/memory/last-sessions/<uuid>.md`) only if `open-threads.md` references them or Duong's first message touches a thread not in `open-threads.md`. For topic searches across historical shards, delegate to Skarner.
>
> After reading, greet Duong with a brief status (active threads from `open-threads.md`, blockers).

### 6.2 `agents/evelynn/CLAUDE.md` §Startup Sequence — rewrite step 3

Current step 3: "read all shards within the last 48 hours by mtime". Replace with a two-line description mirroring the boot script:

> 3. `agents/evelynn/memory/open-threads.md` — live thread state (eager). <!-- orianna: ok -->
> 4. `agents/evelynn/memory/last-sessions/INDEX.md` — historical shard manifest (eager, auto-generated). <!-- orianna: ok -->
> 5. Pull individual shards under `last-sessions/` on demand; delegate topic searches to Skarner.

Renumber subsequent entries. Also amend the "Do NOT load journals, transcripts, or all learnings at startup" line to "Do NOT load individual last-sessions shards at startup unless referenced by open-threads.md or the current prompt."

### 6.3 `agents/sona/CLAUDE.md` — add Startup Sequence section (new)

Sona's CLAUDE.md has no explicit Startup Sequence section today; the boot steps live only in `.claude/agents/sona.md`. Add a new `## Startup Sequence` section mirroring §6.2's structure, for parity with Evelynn. Single source of truth stays the `.claude/agents/sona.md` `initialPrompt` — the CLAUDE.md section is documentation for subagents and humans reading the rules.

### 6.4 `agents/memory/agent-network.md` — new "Memory Consumption" section

Short section (≤ 20 lines) describing the two-layer pattern so every agent can consume on-demand:

- Coordinators (Evelynn, Sona) keep a hand-maintained `open-threads.md` + auto-generated `last-sessions/INDEX.md` under `agents/<coordinator>/memory/`.
- To read full shard detail: `cat agents/<coordinator>/memory/last-sessions/<uuid>.md`.
- To search across historical shards: delegate to Skarner (read-only memory excavator).
- Archive tier (`last-sessions/archive/`) holds shards past 14d or #20; same read path, different directory.
- Subagents MUST NOT eagerly load another agent's last-sessions/ at startup.

## 7. Boot-sequence placement

Final startup order for both coordinators (Duong answered option **b** — dynamic tail after static files for prompt-cache stability):

| # | File | Type | Cacheable? |
|---|---|---|---|
| 1 | `agents/<coordinator>/CLAUDE.md` | static | yes |
| 2 | `agents/<coordinator>/profile.md` | static | yes |
| 3 | `agents/<coordinator>/memory/<coordinator>.md` | slow-churn | yes (changes only at consolidation) |
| 4 | `agents/memory/duong.md` | static | yes |
| 5 | `agents/memory/agent-network.md` | slow-churn | yes |
| 6 | `agents/<coordinator>/learnings/index.md` | slow-churn | yes |
| 7 | `agents/<coordinator>/memory/open-threads.md` | high-churn | **tail — invalidates per session** |
| 8 | `agents/<coordinator>/memory/last-sessions/INDEX.md` | high-churn | **tail — invalidates per session** |

Rationale (from Anthropic's [Prompt caching docs](https://platform.claude.com/docs/en/build-with-claude/prompt-caching) cited in Lux's recommendation §Token budget estimate): cache hits give up to 90% cost reduction on the cached prefix. Keeping the stable identity+rules+roster+profile blocks at the top of the prompt and the two dynamic files at the tail means a churning `open-threads.md` invalidates only positions 7–8, not the whole prompt. Reversing the order (option a) would put the dynamic files first, forcing every boot to re-pay the full static prefix.

Hard invariant: positions 7 and 8 must remain the **last two** entries in the coordinator boot chain. Any future additions (new static doc, new rule file) go above them, not between.

## 8. Migration / cutover plan

Single PR, single cutover. No phased rollout, no dual-mode overlap (per §D12 decision and Duong's scope-option-a).

### 8.1 Evelynn bootstrap — hand-seed `open-threads.md`

Before merge, produce a one-shot seed of `agents/evelynn/memory/open-threads.md` by consolidating the "Open threads into next session" sections across the current 23 shards in `agents/evelynn/memory/last-sessions/`. Method: <!-- orianna: ok -->

1. Read each shard's `## Open threads into next session` (or equivalent) section.
2. De-dup threads across shards, keeping the most recent status per thread.
3. For each surviving thread, write a `## <thread>` section with status one-liner + shard UUIDs as pointers + next action.
4. Hand-review the result before commit — this is curation work, not script work. Duong (or Evelynn in a live session) owns the review.

Output file committed as part of the implementation PR, not as a separate pre-merge commit.

### 8.2 Sona bootstrap — hand-seed `open-threads.md`

Sona has only 2 shards in `last-sessions/` today. Same method as §8.1, lower volume. Seed from those 2 shards + Sona's `## Sessions` block's "Paused work (to resume)" entries already in `sona.md`.

### 8.3 Initial INDEX population

Part of the same PR: run the new `scripts/memory-consolidate.sh <coordinator> --index-only` once per coordinator to produce the initial `INDEX.md` files. Commit both.

### 8.4 Cutover — old 48h behaviour removed in the same commit as the new behaviour

Single PR shape:

- T1–T4 build the scripts and `_lib` (see §12 Tasks).
- T5–T7 update the skill + agent defs + CLAUDE.md.
- T8 runs the bootstrap for both coordinators and commits the seed `open-threads.md` + initial `INDEX.md`.
- T9 deletes `scripts/filter-last-sessions.sh`.
- T10 updates `architecture/coordinator-memory.md` (new) documenting the final shape. <!-- orianna: ok -->
- All land in one PR. First session boot post-merge dogfoods the new path.

No feature flag, no environment variable, no conditional "if --legacy use old path". The old script is gone and the boot prompt no longer references it.

## 9. Test plan

`tests_required: true` — see invariants this plan must protect.

### 9.1 Unit tests for `scripts/memory-consolidate.sh` INDEX regeneration

Test file: `scripts/test-memory-consolidate-index.sh`. Fixture: a temp `last-sessions/` dir populated with a known set of shards with known TL;DR sections. Assertions: <!-- orianna: ok -->

- INDEX row count == fixture shard count.
- Row ordering == mtime-descending (newest first).
- Each row contains the shard UUID, date, and first 3 TL;DR lines verbatim.
- Shards with no explicit `TL;DR:` anchor fall back to the first 3 prose lines under H1.
- Shards with neither produce a "(no summary extractable)" row rather than failing.
- Archived shards appear in a "## Archived" section with a single-line pointer.
- Re-running produces a byte-identical file (idempotency).

xfail-first per Rule 12 — test committed in a prior commit on the same branch, before the script implementation commit.

### 9.2 Unit tests for the archive policy

Test file: `scripts/test-memory-consolidate-archive-policy.sh`. Fixture: temp `last-sessions/` with 25 shards at varied mtimes and one shard referenced by a fake `open-threads.md`. Assertions: <!-- orianna: ok -->

- Shards with mtime > 14d ago move to `archive/`.
- Shards at positions 21+ by newest-first ordering move to `archive/` regardless of age.
- The 20 newest, all within 14d, stay in `last-sessions/`.
- A shard whose UUID appears in `open-threads.md` is NOT moved, even if it triggers the policy. A warning is logged.
- `git mv` is used (shard's git history preserved).
- UUID collisions in `archive/` are suffixed `-2`, `-3`, … up to `-100` before failing.
- INDEX regen after archive move correctly surfaces the moved shards under "## Archived".

xfail-first, same branch.

### 9.3 Integration test — full `/end-session` close lands atomically

Test file: `scripts/test-end-session-memory-integration.sh`. Sets up a temp agent dir, stubs `clean-jsonl.py` and git, then drives the `/end-session` flow for a synthetic coordinator. Assertions: <!-- orianna: ok -->

- On success: `open-threads.md` update + `INDEX.md` regen + shard write all present in the final commit.
- On failure of any step in 6 → 6b → 6b-continued: the commit does NOT land (prior steps staged but not committed; recoverable by running `memory-consolidate.sh --index-only` + re-staging + re-committing manually).
- The commit message matches the end-session template.
- Pre-push hook passes (no orphan staged secrets, correct commit prefix).

xfail-first, same branch.

### 9.4 Migration smoke test — Evelynn real-memory backup

Smoke test script: `scripts/test-migration-smoke.sh`. Steps: <!-- orianna: ok -->

1. `cp -r agents/evelynn/memory agents/evelynn/memory.backup-$(date +%s)` — preserve pre-migration state.
2. Run the bootstrap: hand-seed `open-threads.md` + initial `INDEX.md`.
3. Diff the seeded `open-threads.md` against the union of shards' "Open threads into next session" sections — verify no thread lost.
4. Simulate boot: read `open-threads.md` + `INDEX.md`, count total tokens (via `wc -c`). Assert < 8 KB combined (recommendation §Token budget estimate target).
5. Delete the backup at the end (not committed).

Runs once at T8 time, output captured in commit message. Not part of CI.

### 9.5 Skill-file shape assertion

Test file: `scripts/test-end-session-skill-shape.sh`. Grep-based assertion that `.claude/skills/end-session/SKILL.md` contains: <!-- orianna: ok -->

- A "Step 6b" heading.
- Reference to `open-threads.md`.
- Reference to `INDEX.md` regeneration.
- Ordering documented: Step 6 before 6b, 6b before Step 9.

Cheap to run, pre-push gate.

### 9.6 Rule 12 compliance

All test files in §9.1–§9.3 land as xfail-first commits on the feature branch before the implementation commits. Pre-push TDD hook (`scripts/hooks/pre-push-tdd.sh`) enforces this.

## 10. Failure modes & mitigations

| # | Failure | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | Coordinator forgets to update `open-threads.md` at `/end-session` | Medium | Soft — stale thread stays listed one session longer | `/end-session` Step 6b is part of the skill checklist (same rigor as shard write today). Missing update is the safe-fail direction: extra thread is noise, not data loss. |
| 2 | `INDEX.md` drifts from actual shard contents | Low | Medium — coordinator can't find a shard it should know about | Auto-regen on every `/end-session` write + on every boot's `memory-consolidate.sh` call. Two independent re-syncs per day. |
| 3 | Two parallel coordinator sessions race on `open-threads.md` | Low | Medium — file-level merge conflict | Same race class as today's `last-sessions/<uuid>.md` shard writes. Git merge conflicts are loud and fixable. Advisory lock in `memory-consolidate.sh` (flock/noclobber — already implemented) serializes the INDEX regen side. `open-threads.md` itself is edited atomically by the coordinator; parallel sessions producing conflicting edits fail at push-time, not at read-time. |
| 4 | Archive move deletes a shard still referenced by `open-threads.md` | Low | High — silent context loss | `scripts/memory-consolidate.sh` pre-archive guard reads `open-threads.md` and skips any shard whose UUID appears there. Test 9.2 covers this invariant. Warning logged on skip. |
| 5 | `TL;DR` parsing falls through all three rules and produces "(no summary extractable)" | Medium | Low — index row is less useful but shard is still findable by UUID | Document shard header convention (§4.4); skills teach it. Over time, convention adherence improves quality. Shards without TL;DR still index and stay reachable. |
| 6 | Archive directory fills up past 30d prune (backstop) | Low | Low — disk usage | Existing 30d prune in `memory-consolidate.sh` continues to run (kept unchanged from current implementation). |
| 7 | Bootstrap misses an open thread during seed (§8.1 hand-review) | Medium | Low–Medium — thread not in `open-threads.md` after cutover | First post-merge session will show the gap; coordinator adds the missing thread and commits. Recoverable in one `/end-session`. |
| 8 | `--index-only` flag runs during a concurrent full consolidation | Low | Medium — INDEX could be regenerated on a partially-moved shard set | `--index-only` respects the same flock/noclobber advisory lock. If lock is held, exit as no-op. |

## 11. Out of scope

Explicitly excluded from this plan; revisit criteria noted per item:

- **GoodMem semantic retrieval** — revisit at 10× current shard volume (~400+ shards per coordinator) or when cross-agent semantic joins become a real requirement. Today's grep + Skarner handles search latency in milliseconds; embedding infra is operational debt not yet earned.
- **Cross-session real-time memory sharing between coordinators** — Evelynn and Sona stay single-writer per their own memory dirs. No real-time mirror.
- **Automatic `open-threads.md` generation from LLM summarization** — rejected. The hand-curation IS the value: coordinators decide what's "live" and what's "resolved," and that judgment is why `open-threads.md` beats mtime-window load. An LLM auto-summarizer would reintroduce the same noise problem at higher token cost.
- **Rewriting existing shards to add `TL;DR:` anchors** — parser falls back to prose, no retro-fix needed.
- **A separate `scripts/lint-open-threads.sh`** — `open-threads.md` is markdown; drift detection is human-visible at next `/end-session`.
- **Exposing `open-threads.md` to subagents at their own boot** — subagents do not boot-load coordinator memory. This remains a coordinator-local surface.
- **MCP-based memory reads** — no new MCP. Local files + Skarner delegation only.

## 12. Tasks

- [ ] **T1** — Write xfail tests for `scripts/memory-consolidate.sh` INDEX regeneration. estimate_minutes: 40. Files: `scripts/test-memory-consolidate-index.sh` (new). DoD: fixture-driven assertions from §9.1 all failing with "not implemented"; committed as its own commit on the branch before any implementation (Rule 12). <!-- orianna: ok -->
- [ ] **T2** — Build `scripts/_lib_last_sessions_index.sh` helper (shard TL;DR parser + row renderer + directory walk). estimate_minutes: 45. Files: `scripts/_lib_last_sessions_index.sh` (new). DoD: `extract_shard_tldr`, `render_index_row`, `regenerate_index` functions implemented per §4.3; sourced-only; POSIX bash; all T1 tests pass. <!-- orianna: ok -->
- [ ] **T3** — Write xfail tests for archive policy (14d OR 20 shards, pre-archive open-threads guard). estimate_minutes: 35. Files: `scripts/test-memory-consolidate-archive-policy.sh` (new). DoD: §9.2 assertions in place as xfail; committed before T4 on the branch. <!-- orianna: ok -->
- [ ] **T4** — Rewrite `scripts/memory-consolidate.sh` — add INDEX regen, archive policy, `--index-only` flag, pre-boot validator (moved from `filter-last-sessions.sh`); preserve existing sessions-fold + lock + commit/push. estimate_minutes: 60. Files: `scripts/memory-consolidate.sh`. DoD: T1 + T3 tests pass; existing sessions-fold behaviour unchanged (verified by smoke: run on evelynn's current memory, confirm `## Sessions` block identical to pre-change modulo new index); `--index-only` returns in < 1s on a 25-shard fixture.
- [ ] **T5** — Write xfail integration test for `/end-session` Step 6 → 6b ordering + atomic commit. estimate_minutes: 40. Files: `scripts/test-end-session-memory-integration.sh` (new), `scripts/test-end-session-skill-shape.sh` (new). DoD: §9.3 + §9.5 assertions as xfail; committed before T6. <!-- orianna: ok -->
- [ ] **T6** — Update `.claude/skills/end-session/SKILL.md` with Step 6b (open-threads update + INDEX regen). estimate_minutes: 30. Files: `.claude/skills/end-session/SKILL.md`. DoD: §5.1 shape in place; T5 tests pass; ordering rules documented; non-coordinator no-op path explicit.
- [ ] **T7** — Update Lissandra protocol for Step 6b parity. estimate_minutes: 25. Files: `.claude/agents/lissandra.md`, `agents/lissandra/profile.md`, `.claude/skills/pre-compact-save/SKILL.md` (one-line note only). DoD: §5.2 changes landed; dry-run pre-compact-save on a test session updates open-threads + INDEX identically to `/end-session`.
- [ ] **T8** — Bootstrap `open-threads.md` + initial `INDEX.md` for Evelynn and Sona. estimate_minutes: 55. Files: `agents/evelynn/memory/open-threads.md` (new), `agents/sona/memory/open-threads.md` (new), `agents/evelynn/memory/last-sessions/INDEX.md` (new, generated), `agents/sona/memory/last-sessions/INDEX.md` (new, generated). DoD: §8.1 hand-seed for Evelynn (23 shards → curated thread list); §8.2 for Sona (2 shards); initial INDEX generated via `scripts/memory-consolidate.sh <name> --index-only`; smoke test §9.4 runs and passes; backup dir cleaned up. <!-- orianna: ok -->
- [ ] **T9** — Rewrite `.claude/agents/evelynn.md` and `.claude/agents/sona.md` boot scripts + delete `scripts/filter-last-sessions.sh`. estimate_minutes: 25. Files: `.claude/agents/evelynn.md`, `.claude/agents/sona.md`, `scripts/filter-last-sessions.sh` (deleted). DoD: §6.1 boot shape in both agent defs; boot order §7 table matches; `filter-last-sessions.sh` deleted via `git rm`; no remaining references anywhere (grep clean).
- [ ] **T10** — Update `agents/evelynn/CLAUDE.md` §Startup Sequence + add section to `agents/sona/CLAUDE.md` + add Memory Consumption section to `agents/memory/agent-network.md`. estimate_minutes: 30. Files: `agents/evelynn/CLAUDE.md`, `agents/sona/CLAUDE.md`, `agents/memory/agent-network.md`. DoD: §6.2–§6.4 edits landed; startup sequence matches the boot-prompt ordering; subagent-facing consumption doc reads clean on a fresh pass.
- [ ] **T11** — Add `architecture/coordinator-memory.md` documenting the final two-layer shape. estimate_minutes: 35. Files: `architecture/coordinator-memory.md` (new). DoD: sections covering file layout, write-side flow (`/end-session` + `pre-compact-save`), read-side flow (boot + on-demand shard pull), retention policy, and the plan invariants referenced here (§3 table, §7 boot order, §10 failure mode table). Cross-referenced from `agents/evelynn/CLAUDE.md` and `agents/sona/CLAUDE.md`. <!-- orianna: ok -->
- [ ] **T12** — Dogfood + commit evidence. estimate_minutes: 20. Files: none new. DoD: first post-merge coordinator boot runs the new path cleanly (no filter-last-sessions.sh reference); `open-threads.md` loads; INDEX loads; a sample shard pulled on-demand; boot-token count measured (target < 8 KB for tail 7+8); evidence captured in PR body or commit message.

Total estimate: 440 minutes.

## Test plan

Xfail-first commits (T1, T3, T5) land on the feature branch before their implementation commits (T2+T4, T4, T6–T7). The invariants the test harness protects:

- **Boot token invariant** — Coordinator boot reads `open-threads.md` + `last-sessions/INDEX.md` instead of 23 raw shards. Combined static-tail file size stays under 8 KB for Evelynn post-bootstrap (§9.4).
- **INDEX freshness invariant** — `last-sessions/INDEX.md` is byte-identical to a fresh regeneration at every boot. Any drift is auto-corrected by `memory-consolidate.sh` at next call.
- **Archive policy invariant** — A shard is moved to `archive/` if and only if either (mtime > 14d) OR (newest-first index position > 20), with the open-threads-reference skip guard (§9.2).
- **Atomicity invariant** — `/end-session` produces a single commit containing shard + `open-threads.md` + `INDEX.md`; partial states are recoverable by re-running `memory-consolidate.sh --index-only` (§9.3).
- **Ordering invariant** — Skill documents Step 6 → 6b → Step 9 ordering; shape test (§9.5) greps the skill file.
- **No-orphan invariant** — Deletion of `scripts/filter-last-sessions.sh` leaves no dangling references (T9 DoD: grep-clean).
- **Bootstrap-completeness invariant** — Initial seed of `open-threads.md` for Evelynn and Sona contains every open thread referenced in their respective shard backlogs; no thread silently dropped (§9.4 diff step).

Test harnesses live alongside existing scripts (`scripts/test-*.sh`) and are invoked by the pre-push hook chain. Pre-push TDD gate (`scripts/hooks/pre-push-tdd.sh`) enforces xfail-before-impl on the branch.

## Rollback

Low-risk, local-only rollback path. No external integration, no data migration in the destructive-write sense (bootstrap is additive).

1. Revert the implementation PR commits in reverse order (merge, not rebase — Rule 11). Specifically:
   - Revert T12 evidence commit (no-op).
   - Revert T9 + T10 + T11 (agent-def/CLAUDE.md/architecture edits).
   - Revert T8 bootstrap (deletes the seeded `open-threads.md` + `INDEX.md` files — safe because pre-change state had no such files).
   - Revert T5–T7 (skill + Lissandra changes).
   - Revert T1–T4 (scripts + tests).
2. Re-add `scripts/filter-last-sessions.sh` from git history (`git show HEAD^:scripts/filter-last-sessions.sh > scripts/filter-last-sessions.sh && chmod +x scripts/filter-last-sessions.sh`).
3. Next coordinator boot falls back to the old 48h-mtime path with no further intervention.

The only non-trivial recovery step is restoring `scripts/filter-last-sessions.sh` from git history. All other changes are file additions/edits reversible by `git revert`.

No prod deploy, no data loss risk, no external system to reset.

## Open questions

None — the four gating questions (scope, retention, INDEX cadence, startup order) are all settled by Duong's answers inline in §2. The following round-2 items are flagged in the plan body but have defaults-chosen resolutions; surface to Duong only if they surprise him at review time:

- **OQ1** (§4.4) — Shard TL;DR header convention: mandate `TL;DR:` anchor going forward, or leave as optional with prose-parsing fallback? Default-chosen: **optional with fallback**. Mandate would require retro-fixing existing shards; not worth the churn.
- **OQ2** (§5.2) — Lissandra-maintained open-threads update vs coordinator-maintained: today Lissandra impersonates the coordinator at pre-compact time. Default-chosen: **Lissandra writes open-threads.md in the coordinator's voice**, same as she does for the shard today. Full parity with `/end-session`.
- **OQ3** (§8.1) — Evelynn's hand-seed of `open-threads.md`: driven by Duong (manual curation during a dedicated bootstrap session) or by Evelynn herself (live coordinator session that reads all 23 shards once and writes the seed). Default-chosen: **Evelynn-driven in a single bootstrap session**, with Duong reviewing the output before the implementation PR commits. Lower friction, same curation quality.

Flag any of these if the default runs counter to Duong's preference; otherwise they travel with the plan as-is.

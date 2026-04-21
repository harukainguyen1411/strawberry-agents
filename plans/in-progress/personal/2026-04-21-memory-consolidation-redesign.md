---
status: in-progress
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
orianna_signature_approved: "sha256:e883a36e8113366665a25f30231162f29338784479d9850f05787d744ac1b973:2026-04-21T05:01:21Z"
orianna_signature_in_progress: "sha256:e883a36e8113366665a25f30231162f29338784479d9850f05787d744ac1b973:2026-04-21T05:03:18Z"
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
- **A separate `scripts/lint-open-threads.sh`** — `open-threads.md` is markdown; drift detection is human-visible at next `/end-session`. <!-- orianna: ok -->
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

## Task breakdown (Aphelios)

Companion breakdown for `plans/approved/personal/2026-04-21-memory-consolidation-redesign.md`. Twelve tasks (T1–T12) executed by a complex-track pair on a single feature branch, single PR. <!-- orianna: ok -->

---

## 1. Team composition

| Role | Agent | Track | Model | Responsibilities |
|---|---|---|---|---|
| Complex-track builder | **Viktor** | complex | opus | Script implementation (T2, T4), skill + agent-def rewrites (T6, T7, T9, T10, T11), bootstrap curation (T8), dogfood evidence (T12). |
| Complex-track test implementer | **Rakan** | complex | opus | xfail test authorship (T1, T3, T5). Lands each test commit on the branch **before** the matching implementation commit. |

**No concurrent-repo rule.** Viktor and Rakan share the one feature branch; serialize via phase gates (G1–G5 below). No parallel work on the same files across sessions. If both need to push simultaneously, the later session rebases-via-merge (never `git rebase`).

---

## 2. Branching strategy

**Single feature branch, single PR.**

- Branch name: `feat/coordinator-memory-two-layer-boot`
- Base: `main`
- Creation: `bash scripts/safe-checkout.sh feat/coordinator-memory-two-layer-boot` (Rule 3 — worktree, never raw `git checkout`).
- Commit discipline: one commit per task (12 commits total), subjects prefixed per Rule 5 (all `chore:` — no `apps/**` touched).
- Merge strategy: merge commit into `main` after PR green (Rule 11 — never rebase).

### Rule 12 — xfail-before-impl ordering on the branch

These three test commits MUST land before their paired implementation commits on the **same branch**. The pre-push TDD hook (`scripts/hooks/pre-push-tdd.sh`) and CI (`tdd-gate.yml`) enforce this.

| xfail commit (Rakan) | Covers | Must land before impl commit(s) (Viktor) |
|---|---|---|
| **T1** `scripts/test-memory-consolidate-index.sh` | §9.1 INDEX regen | T2 (`_lib_last_sessions_index.sh`) and T4 (`memory-consolidate.sh` rewrite). | <!-- orianna: ok -->
| **T3** `scripts/test-memory-consolidate-archive-policy.sh` | §9.2 archive policy | T4 (`memory-consolidate.sh` rewrite). | <!-- orianna: ok -->
| **T5** `scripts/test-end-session-memory-integration.sh` + `scripts/test-end-session-skill-shape.sh` | §9.3 + §9.5 | T6 (`end-session` SKILL.md) and T7 (Lissandra). | <!-- orianna: ok -->

Each xfail commit must reference the parent plan's ADR file path and the task ID in the commit body so the TDD gate can map test → plan.

---

## 3. Duong-in-loop blockers

| ID | Blocker | Task | Expected turnaround |
|---|---|---|---|
| D-memory-1 | Review hand-seeded `agents/evelynn/memory/open-threads.md` for completeness (curation, not mechanical — §8.1 DoD). | T8 | 10–15 min — before T8 commit push. | <!-- orianna: ok -->
| D-memory-2 | Review `agents/sona/memory/open-threads.md` seed (lower volume, §8.2). | T8 | 5 min — same session as D-memory-1. | <!-- orianna: ok -->
| D-memory-3 | Approve PR — this is a coordinator-boot change affecting both Evelynn and Sona; Duong is the only valid non-author reviewer + Senna/Lucian (see §7). | PR review | same-day. |

**Default resolution** for OQ1/OQ2/OQ3 from the ADR (§Open questions) is already baked in — Viktor executes against the defaults unless Duong surfaces a preference at D-memory-1 review time.

---

## 4. Per-task detail

All paths absolute-from-repo-root. DoD = Definition of Done.

### T1 — xfail: INDEX regeneration tests

- **Owner**: Rakan
- **Inputs**: ADR §4.3 (helper contract), §9.1 (assertions list).
- **Outputs**: `scripts/test-memory-consolidate-index.sh` (new, executable). <!-- orianna: ok -->
- **Commands**: `chmod +x scripts/test-memory-consolidate-index.sh`; script must exit non-zero under the xfail convention (`set -e` + explicit "not implemented" sentinel, or marker file under `scripts/.xfail-markers/` — match whatever `scripts/hooks/pre-push-tdd.sh` already recognises; check the hook once). <!-- orianna: ok -->
- **Test anchors**: every assertion in ADR §9.1 — row count, mtime-descending order, UUID+date+TL;DR verbatim, fallback-to-prose when no `TL;DR:` anchor, "(no summary extractable)" fallback, archived-section presence, idempotency.
- **Commit subject**: `chore: xfail T1 — memory-consolidate index regen tests (ADR 2026-04-21-memory-consolidation-redesign)`
- **Rule 12**: must land before T2 and T4 on the branch.
- **Dependencies**: none (first commit on the branch after creation).
- **Estimate**: 40 min.
- **Acceptance gate**: G1.

### T2 — impl: `scripts/_lib_last_sessions_index.sh` helper <!-- orianna: ok -->

- **Owner**: Viktor
- **Inputs**: ADR §4.3 (public function contract), T1 test fixtures.
- **Outputs**: `scripts/_lib_last_sessions_index.sh` (new, **no shebang** — sourced-only). <!-- orianna: ok -->
- **Functions to implement**:
  - `extract_shard_tldr <shard_path>` — ADR §4.3 rules a/b/c in order.
  - `render_index_row <shard_path> <mtime_epoch>` — one markdown row, greppable by UUID.
  - `regenerate_index <last_sessions_dir> <output_file>` — newest-first walk + `## Archived` pointer section.
- **Constraints**: POSIX-portable bash (Rule 10); python3 usage OK (already a dep of `memory-consolidate.sh`); no external binaries beyond `git`, `date`, `stat`, `python3`, `awk`, `sed`, `grep`.
- **Commands**: run `bash scripts/test-memory-consolidate-index.sh` locally — must pass (converts T1's xfail to pass). <!-- orianna: ok -->
- **Commit subject**: `chore: T2 — add _lib_last_sessions_index.sh helper (shard TL;DR + index row + regen)`
- **Dependencies**: T1 committed.
- **Estimate**: 45 min.
- **Acceptance gate**: G1.

### T3 — xfail: archive policy tests

- **Owner**: Rakan
- **Inputs**: ADR §4.2 (archive rules), §9.2 (assertions list).
- **Outputs**: `scripts/test-memory-consolidate-archive-policy.sh` (new, executable). <!-- orianna: ok -->
- **Test anchors**: mtime > 14d → archive; position > 20 (newest-first) → archive; 20 newest within 14d stay; `open-threads.md` UUID-reference skip-guard (with warn-log); `git mv` used (shard git history preserved — assert via `git log --follow`); UUID collision suffix loop up to `-100`; INDEX regen post-archive surfaces moved shards in `## Archived`.
- **Commit subject**: `chore: xfail T3 — memory-consolidate archive policy tests (ADR 2026-04-21-memory-consolidation-redesign)`
- **Rule 12**: must land before T4 on the branch.
- **Dependencies**: T2 landed (test fixture generator reuses `_lib` helpers if convenient, but hard dep is only T1 → fixtures; T2 → fixtures is a soft convenience).
- **Estimate**: 35 min.
- **Acceptance gate**: G2.

### T4 — impl: rewrite `scripts/memory-consolidate.sh`

- **Owner**: Viktor
- **Inputs**: ADR §4.2, existing `scripts/memory-consolidate.sh` (preserve sessions-fold, UUID collision loop, flock/noclobber lock, commit message template, push-with-retry), ADR §5.1 (`--index-only` flag contract).
- **Outputs**: `scripts/memory-consolidate.sh` (rewritten in place).
- **Additive responsibilities** (ADR §4.2):
  1. INDEX regeneration pass — sources `_lib_last_sessions_index.sh`.
  2. Archive policy — 14d OR position > 20, newest-first; pre-archive open-threads UUID-reference guard; `git mv`; UUID-collision suffix loop (reuse existing).
  3. Pre-boot validator — moved from `filter-last-sessions.sh`: sentinel `<!-- sessions:auto-below` appears exactly once in `<coordinator>.md`; `last-sessions/` exists; shard counts to stderr.
  4. `--index-only` flag — runs **only** the INDEX regen pass, no archive move, no sessions-fold, no commit/push; respects flock (no-op if lock held, per ADR §10 failure mode #8); target < 1s on a 25-shard fixture.
- **Preserve**: sessions-fold path, UUID collision loop, lock handling, commit prefix `chore: <secretary> memory consolidation YYYY-MM-DD`, push-with-retry, POSIX bash.
- **Commands**:
  - `bash scripts/test-memory-consolidate-index.sh` → passes. <!-- orianna: ok -->
  - `bash scripts/test-memory-consolidate-archive-policy.sh` → passes. <!-- orianna: ok -->
  - Smoke: dry-run on Evelynn's current memory — confirm `## Sessions` block in `agents/evelynn/memory/evelynn.md` is **byte-identical** pre/post modulo the INDEX additions (grep-diff to verify).
  - Timing: `time bash scripts/memory-consolidate.sh evelynn --index-only` < 1s.
- **Commit subject**: `chore: T4 — rewrite memory-consolidate.sh with INDEX regen + archive policy + --index-only`
- **Dependencies**: T1, T2, T3 all landed.
- **Estimate**: 60 min.
- **Acceptance gate**: G2.

### T5 — xfail: `/end-session` integration + skill-shape tests

- **Owner**: Rakan
- **Inputs**: ADR §9.3 (integration assertions), §9.5 (shape assertions), §5.1 (Step 6b contract).
- **Outputs**:
  - `scripts/test-end-session-memory-integration.sh` (new, executable). Stubs `clean-jsonl.py` + git; drives `/end-session` flow for a synthetic coordinator; asserts atomic commit of shard + `open-threads.md` + `INDEX.md`. <!-- orianna: ok -->
  - `scripts/test-end-session-skill-shape.sh` (new, executable). Grep-based: `"Step 6b"`, `"open-threads.md"`, `"INDEX.md"`, ordering "Step 6 before 6b, 6b before Step 9". <!-- orianna: ok -->
- **Commit subject**: `chore: xfail T5 — /end-session memory-integration + skill-shape tests (ADR 2026-04-21-memory-consolidation-redesign)`
- **Rule 12**: must land before T6 and T7 on the branch.
- **Dependencies**: T4 landed (integration test invokes the rewritten script).
- **Estimate**: 40 min.
- **Acceptance gate**: G3.

### T6 — impl: `.claude/skills/end-session/SKILL.md` — inject Step 6b

- **Owner**: Viktor
- **Inputs**: ADR §5.1 (full Step 6b shape).
- **Outputs**: `.claude/skills/end-session/SKILL.md` (edited in place).
- **Edits**:
  - Insert **Step 6b** between existing Step 6 and Step 7 of the coordinator branch (agent == evelynn OR sona). Step 6b content per ADR §5.1 items 1–5 verbatim (parse shard Open-threads section → apply deltas to `open-threads.md` → stage → run `bash scripts/memory-consolidate.sh <coordinator> --index-only` → stage `INDEX.md`).
  - Document the ordering invariant explicitly: "Step 6 MUST complete before 6b; Step 6b MUST complete before Step 9 (commit+push)."
  - Add explicit no-op clause for non-coordinator agents (Sonnet subagents via `/end-subagent-session`).
  - Include the recovery note: "If Step 6b fails partway, the shard write already landed. Recover by running `bash scripts/memory-consolidate.sh <coordinator> --index-only` and re-staging `open-threads.md` + `INDEX.md` before next commit."
- **Commands**: `bash scripts/test-end-session-skill-shape.sh` → passes (T5 shape xfail flips to pass). <!-- orianna: ok -->
- **Commit subject**: `chore: T6 — add /end-session Step 6b (open-threads update + INDEX regen)`
- **Dependencies**: T5 landed.
- **Estimate**: 30 min.
- **Acceptance gate**: G3.

### T7 — impl: Lissandra Step 6b parity

- **Owner**: Viktor
- **Inputs**: ADR §5.2.
- **Outputs**:
  - `.claude/agents/lissandra.md` (edited) — Step 6b inserted into Lissandra's coordinator-close protocol, identical sequence to T6 but in Lissandra's voice.
  - `agents/lissandra/profile.md` (edited) — mirror the protocol update (same ordering invariant, same recovery note).
  - `.claude/skills/pre-compact-save/SKILL.md` (edited) — one-line note: "Lissandra updates `open-threads.md` and regenerates `INDEX.md` as part of the coordinator shard write, same as `/end-session` Step 6b."
- **Commands**: dry-run `pre-compact-save` on a test session (synthetic coordinator memory dir) — confirm `open-threads.md` and `INDEX.md` update identically to `/end-session` output.
- **Commit subject**: `chore: T7 — Lissandra pre-compact Step 6b parity with /end-session`
- **Dependencies**: T5, T6 landed.
- **Estimate**: 25 min.
- **Acceptance gate**: G3.

### T8 — bootstrap: seed `open-threads.md` + initial `INDEX.md` for both coordinators

- **Owner**: Viktor (curation) + Duong (review gate D-memory-1, D-memory-2)
- **Inputs**: ADR §8.1 (Evelynn seed method), §8.2 (Sona seed method), §9.4 (migration smoke steps).
- **Outputs**:
  - `agents/evelynn/memory/open-threads.md` (new, hand-curated). <!-- orianna: ok -->
  - `agents/sona/memory/open-threads.md` (new, hand-curated). <!-- orianna: ok -->
  - `agents/evelynn/memory/last-sessions/INDEX.md` (new, generated). <!-- orianna: ok -->
  - `agents/sona/memory/last-sessions/INDEX.md` (new, generated). <!-- orianna: ok -->
- **Method (Evelynn)**:
  1. `cp -r agents/evelynn/memory agents/evelynn/memory.backup-$(date +%s)` (local only, not committed).
  2. Read each of the 26 shards currently in `agents/evelynn/memory/last-sessions/` (ADR says 23 — count may have drifted by commit time; use actual count).
  3. Parse each shard's `## Open threads into next session` section.
  4. De-dup threads across shards; keep most recent status per thread.
  5. For each surviving thread, write `## <thread>` section into `open-threads.md` with status one-liner + shard-UUID pointers + next action.
  6. Duong review (D-memory-1) — no thread silently dropped; curation quality OK.
  7. `bash scripts/memory-consolidate.sh evelynn --index-only` → writes `last-sessions/INDEX.md`.
- **Method (Sona)**: same shape, lower volume (2 shards + `sona.md` Paused-work entries).
- **Smoke test (ADR §9.4)**:
  - Diff seeded `open-threads.md` against union of shards' Open-threads sections — no thread lost.
  - `wc -c agents/evelynn/memory/open-threads.md agents/evelynn/memory/last-sessions/INDEX.md` → combined < 8 KB. <!-- orianna: ok -->
  - Delete `agents/evelynn/memory.backup-*` after smoke passes.
- **Commit subject**: `chore: T8 — bootstrap open-threads.md + INDEX.md for Evelynn and Sona`
- **Dependencies**: T4 landed (needs `--index-only`); T7 landed (so skill+Lissandra are ready; bootstrap + skill land together).
- **Estimate**: 55 min (+ 10–15 min Duong review latency).
- **Acceptance gate**: G4.

### T9 — impl: rewrite Evelynn + Sona boot scripts; delete `filter-last-sessions.sh`

- **Owner**: Viktor
- **Inputs**: ADR §6.1, §7 (boot order table).
- **Outputs**:
  - `.claude/agents/evelynn.md` (edited) — `initialPrompt` rewritten per ADR §6.1; boot order positions 1–8 match §7 table; no reference to `filter-last-sessions.sh`.
  - `.claude/agents/sona.md` (edited) — same shape, names swapped.
  - `scripts/filter-last-sessions.sh` — **deleted** via `git rm`.
- **Commands**:
  - `git rm scripts/filter-last-sessions.sh`
  - Grep guard: `grep -rn "filter-last-sessions" .` → returns zero hits (enforce in commit message or fail the commit).
- **Commit subject**: `chore: T9 — rewrite coordinator boot scripts; delete filter-last-sessions.sh`
- **Dependencies**: T8 landed (seed files must exist before boot scripts reference them).
- **Estimate**: 25 min.
- **Acceptance gate**: G5.

### T10 — impl: CLAUDE.md + agent-network.md edits

- **Owner**: Viktor
- **Inputs**: ADR §6.2 (Evelynn CLAUDE.md), §6.3 (new Sona section), §6.4 (agent-network.md Memory Consumption).
- **Outputs**:
  - `agents/evelynn/CLAUDE.md` (edited) — Startup Sequence step 3 rewritten; "Do NOT load" clause amended; subsequent entries renumbered.
  - `agents/sona/CLAUDE.md` (edited) — new `## Startup Sequence` section mirroring Evelynn's.
  - `agents/memory/agent-network.md` (edited) — new `## Memory Consumption` section (≤ 20 lines) per §6.4 bullet list.
- **Commands**: post-edit grep check — `grep -n "last-sessions" agents/evelynn/CLAUDE.md agents/sona/CLAUDE.md agents/memory/agent-network.md` returns only the intended references.
- **Commit subject**: `chore: T10 — update CLAUDE.md startup sequences + agent-network memory consumption doc`
- **Dependencies**: T9 landed.
- **Estimate**: 30 min.
- **Acceptance gate**: G5.

### T11 — impl: `architecture/coordinator-memory.md` <!-- orianna: ok -->

- **Owner**: Viktor
- **Inputs**: ADR §3 (file layout), §5 (write-side flow), §6 (read-side flow), §7 (boot order), §10 (failure modes).
- **Outputs**: `architecture/coordinator-memory.md` (new). <!-- orianna: ok -->
- **Required sections**:
  - File layout (copy ADR §3 tree + table).
  - Write-side flow — `/end-session` Step 6 → 6b → 9 + `pre-compact-save` via Lissandra.
  - Read-side flow — boot order (§7 table) + on-demand shard pull path.
  - Retention policy — 14d OR 20-shards + 30d archive prune.
  - Failure modes — copy ADR §10 table.
  - Cross-references: link from `agents/evelynn/CLAUDE.md` and `agents/sona/CLAUDE.md` (add the link in the Startup Sequence sections from T10 — coordinate with that commit if T10 not yet in).
- **Commit subject**: `chore: T11 — add architecture/coordinator-memory.md (two-layer boot doc)` <!-- orianna: ok -->
- **Dependencies**: T10 landed (CLAUDE.md cross-refs).
- **Estimate**: 35 min.
- **Acceptance gate**: G5.

### T12 — dogfood + evidence

- **Owner**: Viktor
- **Inputs**: merged branch (or a local dogfood session on the branch tip).
- **Outputs**: no new files; evidence captured in PR body or the T12 commit message.
- **Procedure**:
  1. In a fresh coordinator session (Evelynn or Sona), run the new boot path end-to-end.
  2. Confirm no reference to `filter-last-sessions.sh` in the boot transcript.
  3. Confirm `open-threads.md` loads; `INDEX.md` loads.
  4. Pull one sample shard on-demand (simulate a Duong prompt touching a known thread).
  5. Measure boot-token count for positions 7+8 (tail) — capture output of `wc -c <open-threads.md> <INDEX.md>`; target combined < 8 KB.
  6. Record evidence in the PR body under a "Dogfood" heading.
- **Commit subject**: `chore: T12 — dogfood two-layer boot, evidence in PR body`
- **Dependencies**: T11 landed.
- **Estimate**: 20 min.
- **Acceptance gate**: G5 (closes phase).

---

## 5. Execution order + phase gates

Five sequential phase gates. Viktor and Rakan can work in parallel across gates only where noted.

```
G1 — scripts lib ready
  T1 (Rakan, xfail) -> T2 (Viktor, impl)

G2 — consolidator rewritten
  T3 (Rakan, xfail) -> T4 (Viktor, impl)

G3 — skill + Lissandra ready
  T5 (Rakan, xfail) -> T6 (Viktor) -> T7 (Viktor)

G4 — bootstrap landed
  T8 (Viktor + Duong review D-memory-1, D-memory-2)

G5 — cutover + docs
  T9 (Viktor) -> T10 (Viktor) -> T11 (Viktor) -> T12 (Viktor, dogfood)
```

### Parallel windows (safe)

- **Window P1** (G1 → G2 transition): Rakan authoring T3 can start as soon as T1 is committed, even while Viktor is mid-T2. The two xfail-tests have disjoint assertion surfaces and no file collisions.
- **Window P2** (during G3): Rakan can draft T5's two test files in parallel with Viktor finishing T4. Merge must be coordinated — Rakan pushes T5 only after T4 is in so the integration test can invoke the rewritten script.
- **Window P3** (during G4 → G5): Viktor can draft T10 and T11 edits locally while waiting on Duong's T8 review, but cannot commit them until T9 is in.

### Hard-serial points

- T2 depends on T1 (Rule 12).
- T4 depends on T3 (Rule 12) and T2 (sources `_lib`).
- T6 depends on T5 (Rule 12).
- T7 depends on T6 (skill must exist before Lissandra mirrors it).
- T8 depends on T4 + T7 (needs `--index-only` flag + mirrored close protocol).
- T9 depends on T8 (boot scripts reference seeded files).
- T10 depends on T9 (CLAUDE.md cross-references renumbered entries).
- T11 depends on T10 (adds cross-refs back to CLAUDE.md).
- T12 depends on T11 (dogfood against final state).

### Owner-concurrent schedule

| Clock | Viktor | Rakan |
|---|---|---|
| 0–40 min | idle | T1 xfail |
| 40–85 min | T2 impl | T3 xfail (parallel, window P1) |
| 85–145 min | T4 impl | idle / begin T5 draft (window P2) |
| 145–185 min | idle | T5 xfail |
| 185–215 min | T6 impl | idle |
| 215–240 min | T7 impl | idle |
| 240–295 min | T8 bootstrap + Duong D-memory-1/2 | idle |
| 295–320 min | T9 impl | idle |
| 320–350 min | T10 impl | idle |
| 350–385 min | T11 impl | idle |
| 385–405 min | T12 dogfood | idle |

Total wall-clock (serialized on Viktor's path after G3): ~405 min (ADR estimate 440 min — the 35 min saving comes from P1/P2 parallel windows for Rakan's xfail work).

---

## 6. Acceptance-gate cross-reference

| Gate | Task(s) | Invariant satisfied (ADR §Test plan) |
|---|---|---|
| **G1** | T1, T2 | INDEX freshness (regen correctness); Rule 12 xfail-before-impl for T1→T2. |
| **G2** | T3, T4 | Archive policy invariant; no-orphan guard (open-threads UUID skip); Rule 12 T3→T4; preserves existing sessions-fold behaviour (smoke-diff). |
| **G3** | T5, T6, T7 | Atomicity invariant (shard + open-threads + INDEX in one commit); Ordering invariant (Step 6 → 6b → 9); Rule 12 T5→T6/T7; Lissandra parity. |
| **G4** | T8 | Bootstrap-completeness invariant (no thread silently dropped); Boot token invariant (< 8 KB combined). |
| **G5** | T9, T10, T11, T12 | No-orphan invariant (`filter-last-sessions.sh` deletion, grep-clean); Boot-order invariant (§7 table); Dogfood evidence. |

---

## 7. PR metadata

- **Branch**: `feat/coordinator-memory-two-layer-boot`
- **Base**: `main`
- **Title**: `Coordinator memory: two-layer boot (open-threads + last-sessions INDEX)`
- **Reviewers**: Senna (code review, single-repo PR review) + Lucian (architecture guard). Duong is the non-author approver required by Rule 18.
- **Body shell**:

```markdown
## Summary
Replaces 48h-mtime eager shard load with a two-layer coordinator memory shape:
- `open-threads.md` (eager, hand-maintained live state)
- `last-sessions/INDEX.md` (eager, auto-regenerated 3-line TL;DR manifest)
- `last-sessions/<uuid>.md` (lazy, on-demand) + `last-sessions/archive/` (14d OR >20 shards)

Migrates Evelynn and Sona simultaneously. Deletes `scripts/filter-last-sessions.sh`.

Plan: plans/in-progress/personal/2026-04-21-memory-consolidation-redesign.md <!-- orianna: ok -->

## Changes (12 commits)
- T1 (xfail) → T2 — `_lib_last_sessions_index.sh`
- T3 (xfail) → T4 — `memory-consolidate.sh` rewrite
- T5 (xfail) → T6 — `/end-session` Step 6b
- T7 — Lissandra Step 6b parity
- T8 — bootstrap `open-threads.md` + INDEX for both coordinators
- T9 — boot scripts rewrite + delete `filter-last-sessions.sh`
- T10 — CLAUDE.md startup + agent-network memory-consumption doc
- T11 — `architecture/coordinator-memory.md` <!-- orianna: ok -->
- T12 — dogfood evidence

## Test plan
- [ ] `bash scripts/test-memory-consolidate-index.sh` passes
- [ ] `bash scripts/test-memory-consolidate-archive-policy.sh` passes
- [ ] `bash scripts/test-end-session-memory-integration.sh` passes
- [ ] `bash scripts/test-end-session-skill-shape.sh` passes
- [ ] Evelynn dogfood boot — no `filter-last-sessions.sh` reference
- [ ] Sona dogfood boot — same
- [ ] Combined `open-threads.md` + `INDEX.md` size < 8 KB per coordinator
- [ ] `grep -rn "filter-last-sessions" .` returns zero hits

## Dogfood
<evidence from T12 pasted here — boot transcript excerpt, token count, sample shard pull>
```

- **Required checks (must go green)**:
  - `tdd-gate` (CI `tdd-gate.yml`) — enforces Rule 12 xfail-before-impl on branch.
  - Pre-push hooks (local): secrets scan, commit-prefix check, TDD gate, pre-commit unit tests.
  - Non-UI PR — QA/E2E/Playwright gates (Rules 15, 16) do not apply (no `apps/**` touched). PR body linter should see the Test plan checklist as sufficient.
  - Branch protection: one approving review from an account other than author (Rule 18).

- **Merge**: merge commit (not rebase — Rule 11). Non-author merger (not Viktor — Rakan or Duong). No `--admin` (Rule 18).

---

## 8. Rollback summary

ADR §Rollback applies verbatim. Short form:

1. `git revert` the 12 commits in reverse order (T12 → T1). Merge, never rebase.
2. Restore `scripts/filter-last-sessions.sh` from git history: `git show <pre-T9-SHA>:scripts/filter-last-sessions.sh > scripts/filter-last-sessions.sh && chmod +x scripts/filter-last-sessions.sh`.
3. Next coordinator boot falls back to 48h-mtime path.

No data loss risk — bootstrap outputs (`open-threads.md`, `INDEX.md`) are additive; reverting removes the files and leaves prior shards intact.

---

## 9. Open questions / unresolved

None block execution. Viktor executes against ADR §Open-questions defaults (OQ1 optional `TL;DR:` anchor; OQ2 Lissandra-writes-in-coordinator-voice; OQ3 Evelynn-driven bootstrap with Duong review) unless Duong flags at D-memory-1.

**OQ-K1** (breakdown-level, new): The ADR says "23 shards" for Evelynn (§1), but `ls agents/evelynn/memory/last-sessions/` at breakdown time shows 26 shards. Drift is expected (new sessions since ADR authorship). T8 bootstrap uses the live count at T8 execution time, not the ADR figure. Flagging only for traceability — no action needed.

**OQ-K2** (breakdown-level, new): The xfail-marker convention used by `scripts/hooks/pre-push-tdd.sh` is not specified in the ADR. Rakan must read the hook once at the start of T1 and match whatever sentinel format the hook already recognises (explicit "not implemented" string, `.xfail-markers/` file, or annotation in the test body). If the hook's convention is unclear, surface to Duong before T1 lands.

## Test plan detail (Xayah)

This document IS the test plan for the memory-consolidation-redesign ADR (`plans/approved/personal/2026-04-21-memory-consolidation-redesign.md`). Sections §1–§10 below enumerate xfail skeletons, integration tests, fault-injection harnesses, migration assertions, and surface-coverage audit. Xfail-first commits X1–X6 land before their implementation commits per CLAUDE.md Rule 12. <!-- orianna: ok -->

# Test plan — memory consolidation redesign (two-layer boot)

**ADR:** `plans/approved/personal/2026-04-21-memory-consolidation-redesign.md` <!-- orianna: ok -->
**Implementer:** Rakan (complex-track test implementer)
**Runners:** Vi / Caitlyn
**Authoring agent:** Xayah

This document turns the ADR's `## Test plan` invariants and §9 test-plan details into concrete, implementable test harnesses. Every test is named, located, and specifies assertions plus Rakan implementation notes. Xfail-first discipline (CLAUDE.md Rule 12) is tracked explicitly per surface.

All prospective script paths below carry `<!-- orianna: ok -->` suppression markers so future Orianna fact-check passes treat them as authored, not broken references.

---

## 0. Cheat sheet — surfaces × tests

| Surface (task prompt) | xfail skeletons | Fault-injection harness | Integration |
|---|---|---|---|
| 1. `memory-consolidate.sh` rewrite (INDEX + archive policy + ref guard) | §2.1, §2.2, §2.3 | §4.1, §4.2, §4.3 | §3.1 |
| 2. `open-threads.md` eager load, tail position, prompt-cache friendliness | §2.4 | — | §3.2 |
| 3. `last-sessions/INDEX.md` eager load, TL;DR shape, newest-first | §2.1, §2.5 | — | §3.2 |
| 4. `/end-session` Step 6b atomicity | §2.6 | §4.4 | §3.3 |
| 5. Lissandra pre-compact parity | §2.7 | §4.4 | §3.4 |
| 6. Skarner on-demand shard retrieval | §2.8 | — | §3.5 |
| 7. Migration (Evelynn + Sona cutover in one PR) | §2.9 | §4.5 | §3.6 |
| 8. Failure injection (interrupt, concurrency, ref-to-missing) | — | §4.1–§4.5 | §3.3 |

---

## 1. Xfail-first commit plan (Rule 12 traceability)

Six xfail-test commits land on the feature branch before implementation. Each references the ADR task it gates.

| Xfail commit | Files | Gates ADR task | Surface covered |
|---|---|---|---|
| X1 | `scripts/test-memory-consolidate-index.sh` | T1 → T2 + T4 | 1, 3 |
| X2 | `scripts/test-memory-consolidate-archive-policy.sh` | T3 → T4 | 1 |
| X3 | `scripts/test-end-session-memory-integration.sh`, `scripts/test-end-session-skill-shape.sh` | T5 → T6 | 4 |
| X4 | `scripts/test-lissandra-precompact-memory.sh` | (new — gates T7) | 5 | <!-- orianna: ok -->
| X5 | `scripts/test-boot-chain-order.sh` | (new — gates T9) | 2, 3 | <!-- orianna: ok -->
| X6 | `scripts/test-migration-smoke.sh` | (new — gates T8) | 7 | <!-- orianna: ok -->

Pre-push TDD hook (`scripts/hooks/pre-push-tdd.sh`) enforces each xfail commit precedes its impl commit on the branch. Rakan MUST NOT combine xfail and impl in a single commit.

**XFAIL stub convention** (matches existing harnesses like `test-orianna-lifecycle-smoke.sh`):

```sh
# --- XFAIL guard: implementation not yet present ---
MISSING=""
[ ! -f "$SCRIPT" ] && MISSING="$MISSING memory-consolidate.sh:--index-only"
if [ -n "$MISSING" ]; then
  printf 'XFAIL (expected — missing:%s)\n' "$MISSING"
  exit 0
fi
# From here on, real assertions; any FAIL exits 1.
```

---

## 2. Unit-level xfail skeletons

### 2.1 INDEX regeneration — `scripts/test-memory-consolidate-index.sh` <!-- orianna: ok -->

**Gates:** ADR T1 → T2 + T4.
**What it asserts (from ADR §9.1):**

| # | Assertion | Rakan note |
|---|---|---|
| A1 | INDEX row count equals fixture shard count (`.gitkeep` and `INDEX.md` itself excluded). | Use `grep -c` on a UUID pattern; do not count lines. |
| A2 | Row ordering is mtime-descending. | Fixture: create 5 shards with `touch -t <stamp>`; read back UUID column and assert lexicographic match vs the known-sorted list. |
| A3 | Each row contains shard UUID, date (YYYY-MM-DD), and first 3 TL;DR lines verbatim. | For each fixture shard, write a known TL;DR block; grep the row for each of the 3 lines. |
| A4 | Shards with no `TL;DR:` anchor fall back to first 3 prose lines under H1. | Fixture shard B: omit `TL;DR:`, include `# Title\n\npara 1\npara 2\npara 3`. Expect rows. |
| A5 | Shards with neither anchor nor prose produce "(no summary extractable)". | Fixture shard C: only `# Title`, no body. |
| A6 | Archived shards appear in a distinct `## Archived` section, one-line pointer each. | Place a file in `archive/`, assert INDEX has an `## Archived` heading and a line containing its UUID. |
| A7 | Idempotency — running `--index-only` twice produces byte-identical output. | `diff` two successive runs. Assert exit 0. |
| A8 | INDEX is UTF-8 safe (unicode TL;DR content round-trips). | Fixture shard D: TL;DR contains `é` and `→`. |
| A9 | `--index-only` exit code 0 on clean run, non-zero if `last-sessions/` missing. | Negative case: point at nonexistent dir. |

**Rakan implementation notes:**
- Fixture dir lives under `$(mktemp -d)`; populate with handcrafted shards; never touch `agents/evelynn/memory/` during unit tests.
- Stub `git` if the script tries to stage; use `GIT_DIR=/dev/null` + fake `PATH` shim.
- Assert assertions even when fixture contains zero shards: INDEX should still be valid with an empty body (A1 → 0 rows, file exists).

### 2.2 Archive policy — `scripts/test-memory-consolidate-archive-policy.sh` <!-- orianna: ok -->

**Gates:** ADR T3 → T4.
**What it asserts (from ADR §9.2):**

| # | Assertion | Rakan note |
|---|---|---|
| B1 | Shards with mtime > 14d ago move to `archive/`. | Fixture: 3 shards aged 15d via `touch -t`; assert post-run they are under `archive/`. |
| B2 | Shards at newest-first positions 21+ move to `archive/` regardless of age. | Fixture: 25 shards all aged < 14d; assert shards 21–25 move. |
| B3 | The 20 newest within 14d stay in `last-sessions/`. | Same fixture as B2; assert positions 1–20 are untouched. |
| B4 | A shard whose UUID appears in `open-threads.md` is NOT moved even if policy triggers. | Fixture: 1 shard aged 30d; fake `open-threads.md` contains its UUID. Assert shard stays. |
| B5 | Skipping a referenced shard emits a stderr warning containing the UUID. | Capture stderr, grep for UUID + `warning`. |
| B6 | `git mv` is used (not `mv`), so shard history is preserved. | Init a scratch repo in the fixture, commit shards, run the archive step, assert `git log --follow archive/<uuid>.md` shows pre-move commits. |
| B7 | UUID collision in `archive/` is suffixed `-2`, `-3`, … up to `-100` before failing. | Pre-populate `archive/<uuid>.md` and `archive/<uuid>-2.md`; expect new shard renamed `<uuid>-3.md`. |
| B8 | INDEX regenerated after archive move correctly surfaces moved shards under `## Archived`. | Chained assertion: after archive step, run `--index-only` and grep the `## Archived` section for the moved UUIDs. |
| B9 | OR semantics — shards aged > 14d that are ALSO at positions 1–20 still move (age clause wins). | Fixture: position 3 shard is 20d old. Assert it moves. |
| B10 | Tie-breaking — shards with identical mtime order by filename ascending. | Fixture: 3 shards, same `touch -t`; assert order is deterministic filename-ascending. |

**Rakan implementation notes:**
- Use a scratch git repo inside `$(mktemp -d)` for B6 / B7.
- For B4 / B5: the `open-threads.md` parse must be UUID-substring based (short-uuid is the first 8 hex chars of the shard filename stem). Assert BOTH long-form UUID and short-form references are detected.
- Run each assertion in an independent fixture to avoid cross-test pollution.

### 2.3 INDEX↔archive consistency — `scripts/test-memory-consolidate-consistency.sh` <!-- orianna: ok -->

**Gates:** T4 (post-impl regression guard; not on the xfail gate path).
**What it asserts:**

| # | Assertion |
|---|---|
| C1 | After a full `memory-consolidate.sh <name>` run, every file in `last-sessions/` has a matching INDEX row, and every file in `archive/` has a `## Archived` pointer. |
| C2 | No INDEX row points at a shard that doesn't exist on disk. |
| C3 | Total active (non-archived) rows ≤ 20. |
| C4 | No shard appears both in `last-sessions/` and `archive/`. |
| C5 | Pre-boot validator fails loud if `<!-- sessions:auto-below` sentinel is missing from `<coordinator>.md`. |

**Rakan implementation notes:**
- This is a "property" suite — it can run against the real Evelynn memory (read-only copy into temp) after migration to catch drift.
- Guard all filesystem checks with `set -euo pipefail`.

### 2.4 Boot-chain ordering — `scripts/test-boot-chain-order.sh` <!-- orianna: ok -->

**Gates:** ADR T9 (agent-def rewrite).
**What it asserts:**

| # | Assertion | Rakan note |
|---|---|---|
| D1 | `.claude/agents/evelynn.md` `initialPrompt` reads files in the exact order of ADR §7 table. | Extract the numbered list via regex; assert each line matches. |
| D2 | `open-threads.md` is position 7, `INDEX.md` is position 8 (last two). | Parse numbered list; assert len == 8 AND tail-2 == the expected entries. |
| D3 | No mention of `filter-last-sessions.sh` anywhere in the boot prompt. | `! grep filter-last-sessions`. |
| D4 | `.claude/agents/sona.md` symmetric to Evelynn (names swapped). | Same assertions, parameterised on coordinator name. |
| D5 | `agents/evelynn/CLAUDE.md` §Startup Sequence matches the boot prompt's file order (single-source-of-truth symmetry). | Parse the `## Startup Sequence` section; compare against `.claude/agents/evelynn.md`. |
| D6 | `agents/sona/CLAUDE.md` has a `## Startup Sequence` section (new per ADR §6.3). | Assert heading exists. |
| D7 | `agents/memory/agent-network.md` contains a `## Memory Consumption` section describing the two-layer pattern. | Grep for the heading and for `open-threads.md` + `INDEX.md` + `Skarner`. |

**Rakan implementation notes:**
- This is a pure grep-based shape assertion; no fixtures needed.
- Parse `initialPrompt` as YAML-in-markdown; tolerate blockquote `>` prefixes on numbered lines.

### 2.5 INDEX shape — `scripts/test-index-format.sh` <!-- orianna: ok -->

**Gates:** T4 regression guard (runs after T4 impl). Enforces TL;DR extraction contract so downstream consumers (Skarner, coordinator boot read) can rely on stable format.
**What it asserts:**

| # | Assertion |
|---|---|
| E1 | INDEX starts with a generated-by header comment (`<!-- generated by memory-consolidate.sh -->`). |
| E2 | Each active row matches regex `^YYYY-MM-DD · [0-9a-f]{8} · .*$` or the markdown-table equivalent (whichever §4.3 finalises). |
| E3 | Archived-section pointer lines contain the shard UUID and the archived-date. |
| E4 | No row exceeds 240 chars (keeps INDEX scannable; guards against TL;DR runaway). |
| E5 | TL;DR text is sanitized: no raw backticks that would break markdown rendering at boot. |

**Rakan implementation notes:**
- The exact row format finalises in T2. This test LOCKS it once finalised — if T2 picks markdown-table over dot-separated, update E2's regex during the xfail commit to match the finalised shape.

### 2.6 `/end-session` skill shape + Step 6b ordering — `scripts/test-end-session-skill-shape.sh` <!-- orianna: ok -->

**Gates:** ADR T5 → T6 (paired with §3.3 integration test).
**What it asserts (from ADR §9.5, extended):**

| # | Assertion |
|---|---|
| F1 | `.claude/skills/end-session/SKILL.md` contains a `Step 6b` heading. |
| F2 | Step 6b body references `open-threads.md`. |
| F3 | Step 6b body references `INDEX.md` regeneration. |
| F4 | Ordering is documented: text asserts Step 6 before 6b, 6b before Step 9. |
| F5 | Step 6b marked as no-op for non-coordinator agents (explicit `evelynn` OR `sona` guard). |
| F6 | Exact command `scripts/memory-consolidate.sh --index-only <coordinator>` appears literally in Step 6b. |
| F7 | `git add agents/<coordinator>/memory/open-threads.md` and the INDEX add line both appear. |

### 2.7 Lissandra pre-compact skill shape — `scripts/test-lissandra-precompact-memory.sh` <!-- orianna: ok -->

**Gates:** ADR T7.
**What it asserts:**

| # | Assertion |
|---|---|
| G1 | `.claude/agents/lissandra.md` includes a Step-6b-equivalent protocol section. |
| G2 | Section parses the shard's `## Open threads into next session` block. |
| G3 | Writes into `agents/<coordinator>/memory/open-threads.md` (both `evelynn` AND `sona` mentioned). |
| G4 | Regenerates INDEX via `memory-consolidate.sh --index-only <coordinator>`. |
| G5 | Stages all three artifacts (shard + open-threads + INDEX) before commit. |
| G6 | `.claude/skills/pre-compact-save/SKILL.md` carries a one-line note confirming Lissandra updates `open-threads.md` + INDEX. |
| G7 | `agents/lissandra/profile.md` matches G1–G5 (secondary source of truth). |

**Rakan implementation notes:**
- Two source files to check (`.claude/agents/lissandra.md` + `agents/lissandra/profile.md`) — assert BOTH.
- Parallel to §2.6 — reuse grep helpers.

### 2.8 Skarner on-demand retrieval contract — `scripts/test-skarner-on-demand.sh` <!-- orianna: ok -->

**Gates:** new (ADR §6.4 + §11 — Skarner is referenced as the search-delegation target; must continue to work against the new layout).
**What it asserts:**

| # | Assertion | Rakan note |
|---|---|---|
| H1 | Skarner's profile (`agents/skarner/profile.md` or `.claude/agents/skarner.md`) documents reading `last-sessions/<uuid>.md` and `last-sessions/archive/<uuid>.md` as valid lookup paths. | Grep. |
| H2 | Skarner does NOT eagerly load all shards at its own boot (lazy contract honored). | Grep the boot prompt; assert absence of a wildcard read under `last-sessions/`. |
| H3 | Skarner's search path tolerates INDEX absence (falls through to direct-file grep). | Grep prose; document as behavioral contract. |
| H4 | Skarner profile updated to drop the retired `filter-last-sessions.sh` reference, if any. | `! grep filter-last-sessions agents/skarner/** .claude/agents/skarner.md`. |

**Rakan implementation notes:**
- This is a documentation-shape check, not a behavior test. Skarner is an agent definition, not a script — so assertions are grep-based.
- If `agents/skarner/` does not exist yet (unlikely — check), stub the test with an XFAIL that skips cleanly.

### 2.9 Migration-only assertions — see §3.6 smoke test for runnable migration checks.

---

## 3. Integration tests (cross-boundary)

### 3.1 Full `memory-consolidate.sh` end-to-end — `scripts/test-memory-consolidate-e2e.sh` <!-- orianna: ok -->

**Gates:** T4 post-impl.
**Scope:** runs `scripts/memory-consolidate.sh evelynn` (or a test-double coordinator) against a controlled fixture that exercises ALL branches in one call: sessions-fold + INDEX regen + archive policy + commit/push simulation.

**Assertions:**

| # | Assertion |
|---|---|
| I1 | Existing `sessions/*.md` → `<coordinator>.md ## Sessions` behavior is byte-identical to the pre-ADR `memory-consolidate.sh` (captured snapshot for regression). |
| I2 | INDEX regenerates even when `last-sessions/` is empty (produces a header-only file). |
| I3 | Commit message exactly matches `chore: <coordinator> memory consolidation YYYY-MM-DD`. |
| I4 | Both `last-sessions/INDEX.md` and any moved `archive/<uuid>.md` files are staged in the same commit as the `sessions/` fold. |
| I5 | `flock`/noclobber lock is held during the run (concurrent second invocation exits as no-op — see §4.3). |
| I6 | Script honors `--index-only` as a short-circuit: sessions-fold is skipped, archive is skipped, commit+push are skipped. |
| I7 | Script is POSIX-portable bash (Rakan: run under `bash --posix` + `dash` quick smoke; warn-only, not hard assert). |

**Rakan implementation notes:**
- Use a scratch repo under `$(mktemp -d)`; copy the real `scripts/memory-consolidate.sh` into it and point the script at the scratch `agents/` tree via a `STRAWBERRY_MEMORY_ROOT` env shim (Rakan may need to add this shim to the script itself during T4 impl — call out in the PR).
- Snapshot golden files under `scripts/fixtures/memory-consolidate-e2e/` (create via git, not gitignored). <!-- orianna: ok -->

### 3.2 Boot simulation — `scripts/test-coordinator-boot-simulation.sh` <!-- orianna: ok -->

**Gates:** T8 (after bootstrap) + T9 (after agent-def rewrite).
**Scope:** simulates a coordinator's boot by reading the files in order from `initialPrompt` and measuring the outcome.

**Assertions:**

| # | Assertion | Rakan note |
|---|---|---|
| J1 | Boot reads exactly 8 files (ADR §7 table), in the documented order. | Parse via regex; assert list length + entries. |
| J2 | Positions 7–8 are `open-threads.md` + `INDEX.md`. | (Dup of D2, but enforced at runtime rather than from agent-def text; catches drift between doc and reality.) |
| J3 | Combined bytes of positions 7–8 < 8 KB for Evelynn post-bootstrap. | `wc -c`; hard assert. |
| J4 | Combined bytes of positions 1–8 for Evelynn < 20 KB (generous ceiling — recommendation target is ~4–5k tokens ≈ 16 KB). | Soft assert with a clear message. |
| J5 | No `last-sessions/<uuid>.md` shard (non-INDEX) is read during simulated boot. | Read-tracing via `strace -f` is overkill; simpler: verify `initialPrompt` itself doesn't reference any `<uuid>.md` filename. |
| J6 | Boot simulation for Sona produces symmetric results. | Parameterise on coordinator name. |
| J7 | Prompt-cache stability — static prefix (positions 1–6) byte-identical across two consecutive simulated boots. Dynamic tail (7–8) may differ. | Hash positions 1–6; assert hash equal between runs. Hash positions 7–8 to record, not assert. |

**Rakan implementation notes:**
- This test is the single most load-bearing check that the ADR's stated savings actually materialise. Do not skip it.
- J7 is the prompt-cache invariant. If it fails, either the static block churned (bug) or the dynamic block bled into static (bug).

### 3.3 `/end-session` Step 6b atomic commit — `scripts/test-end-session-memory-integration.sh` <!-- orianna: ok -->

**Gates:** T5 → T6.
**Scope:** drives a synthetic coordinator session through the full end-session flow; asserts atomic commit and failure-partial recoverability.

**Assertions (from ADR §9.3, extended):**

| # | Assertion | Rakan note |
|---|---|---|
| K1 | On successful run: shard + `open-threads.md` + `INDEX.md` all present in the final commit. | `git show --stat HEAD` grep. |
| K2 | Step 6 completes before Step 6b (enforced by ordering). | Inject a tracing hook around each step; assert timestamp order. |
| K3 | Step 6b completes before Step 9 (commit/push). | Same technique. |
| K4 | If Step 6b fails partway (inject `false` into INDEX regen): shard write still exists on disk, staged but not committed. | Force failure; assert `git status` shows the shard staged but no HEAD commit. |
| K5 | Manual recovery works: run `memory-consolidate.sh --index-only` + re-stage + commit; no data loss. | Scripted recovery sequence; assert final `git log --stat` is correct. |
| K6 | Pre-push hook passes (correct commit prefix, no secrets, TDD gate green). | Run the hook against the scratch commit. |
| K7 | Commit message matches the end-session template (first line contains coordinator name + "session close"). | Regex match. |
| K8 | On interrupt (SIGINT during Step 6b): working tree is consistent — either pre-6 state or post-6b state, never mid-6b. | See §4.4 for fault-injection technique. |

**Rakan implementation notes:**
- This is the richest integration test. Budget ~45–60 min.
- Stub `clean-jsonl.py` so the test doesn't need a real transcript.
- K4 is the key recoverability check — without it the soft-fail mitigation in ADR §10 #1 is unproven.

### 3.4 Lissandra pre-compact atomic write — `scripts/test-lissandra-precompact-integration.sh` <!-- orianna: ok -->

**Gates:** T7.
**Scope:** mirrors §3.3 but runs the Lissandra pre-compact path instead of `/end-session`. Symmetry is the point: whatever `/end-session` produces, Lissandra must produce identical artifacts.

**Assertions:**

| # | Assertion |
|---|---|
| L1 | Lissandra shard + updated `open-threads.md` + regen INDEX appear in one commit. |
| L2 | Diff between a `/end-session` artifact set and a Lissandra artifact set (same synthetic input) is empty modulo timestamp and UUID. |
| L3 | Interrupting Lissandra mid-run leaves recoverable state (see §4.4). |
| L4 | Works for `concern: personal` (Evelynn dispatch) AND `concern: work` (Sona dispatch). |

**Rakan implementation notes:**
- L2 is the symmetry check. Without it, drift between the two write paths is invisible.
- Drive Lissandra via its profile rather than a live SDK call — synthesize the input transcript, run the Step-6b shell sequence by hand, compare.

### 3.5 Skarner search path works post-cutover — `scripts/test-skarner-integration.sh` <!-- orianna: ok -->

**Gates:** post-T9.
**Scope:** given a prompt of the form "find the thread about X in historical shards", assert Skarner (invoked via Agent tool or simulated shell equivalent) reads from `last-sessions/<uuid>.md` and `last-sessions/archive/<uuid>.md` — and NOT from the removed `filter-last-sessions.sh` path.

**Assertions:**

| # | Assertion |
|---|---|
| M1 | Skarner profile contains no reference to `filter-last-sessions.sh`. |
| M2 | Skarner can resolve a `<uuid>` mentioned in INDEX to the on-disk shard in either `last-sessions/` or `archive/`. |
| M3 | Skarner does NOT attempt to mass-load all shards at start-of-task (verifies lazy contract). |

**Rakan implementation notes:**
- Simulate Skarner's file reads by recording the list of files the agent profile instructs it to open (grep of profile prose, not live Agent tool call — keep it cheap).

### 3.6 Migration smoke — `scripts/test-migration-smoke.sh` <!-- orianna: ok -->

**Gates:** T8.
**Scope:** exercises the one-shot bootstrap for Evelynn + Sona and validates the before/after boot shape.

**Assertions (from ADR §9.4, extended):**

| # | Assertion | Rakan note |
|---|---|---|
| N1 | `cp -r agents/evelynn/memory agents/evelynn/memory.backup-$(date +%s)` runs cleanly; backup dir is NOT committed (gitignored or `rm -rf`'d at end). | Ensure `.gitignore` entry exists OR the test cleans up in a trap. |
| N2 | Hand-seeded `open-threads.md` for Evelynn: every thread present in the union of the 23 shards' `## Open threads into next session` sections appears in `open-threads.md` (no silent drops). | Diff script: parse each shard's section, dedup, compare against `open-threads.md`. |
| N3 | Same N2 check for Sona (2 shards + `## Sessions` "Paused work (to resume)" entries). | Parameterise. |
| N4 | Initial INDEX generated: row count equals shard count in `last-sessions/`. | Call `--index-only`, count rows. |
| N5 | Combined `open-threads.md` + `INDEX.md` < 8 KB for Evelynn. | `wc -c`; hard assert. |
| N6 | Combined < 4 KB for Sona (lower volume). | `wc -c`; soft assert. |
| N7 | `scripts/filter-last-sessions.sh` is removed; no remaining references in tree. | `! test -f` + `! grep -r filter-last-sessions .claude/ scripts/ agents/`. |
| N8 | First simulated post-cutover boot (reuse §3.2) completes cleanly with the new files. | Chained. |
| N9 | No shard file lost during migration (pre-migration shard UUIDs still exist on disk — either in `last-sessions/` or `archive/`). | Snapshot pre-migration UUID list; verify post-migration membership. |
| N10 | `git log --follow <shard>` still works for each migrated shard (history preserved via `git mv`). | Spot-check 3 shards. |

**Rakan implementation notes:**
- Runs once at T8 time; the CI mode can run a read-only variant that skips the actual copy-out.
- N9 is the "no data loss" invariant. Most important assertion in the whole plan. Do not weaken.

---

## 4. Fault-injection harnesses

### 4.1 Interrupted write during consolidation — `scripts/test-faultinject-consolidate-interrupt.sh` <!-- orianna: ok -->

**Scope:** mid-consolidation interrupts must not corrupt state.

**Scenarios:**

| # | Injection point | Expected |
|---|---|---|
| P1 | SIGINT during `sessions/` → `<coordinator>.md` fold (pre-INDEX). | Sessions-fold rolled back OR committed; never mid-state. INDEX unchanged. |
| P2 | SIGINT during INDEX regen (between read-shards and write-INDEX). | INDEX either unchanged-from-previous OR new-complete. No partial/truncated INDEX. |
| P3 | SIGINT during archive move (between `git mv` calls for shards N and N+1). | All already-moved shards recorded in INDEX on next run; no orphan — shard either fully in `last-sessions/` or fully in `archive/`. |
| P4 | SIGKILL during the commit step. | Next `memory-consolidate.sh` run detects the uncommitted state and either completes or errors loud. |
| P5 | Disk-full simulation (`ulimit -f 0` or a tiny tmpfs). | Script fails loud; INDEX not truncated. |
| P6 | Permission denied on `archive/` dir. | Script fails loud; original `last-sessions/<uuid>.md` preserved. |

**Rakan implementation notes:**
- Use a background `( memory-consolidate.sh; ) & PID=$!; sleep 0.05; kill -INT $PID` pattern.
- Because the script is fast, injection is timing-sensitive — add a debug env var (`STRAWBERRY_SLEEP_BEFORE_STEP=<N>`) to the T4 impl so tests can synchronize deterministically. Call this out in Rakan's impl PR.
- Assertions after each injection: run `git status` + walk `last-sessions/` + read INDEX; confirm no truncation (file-size > 0 OR absent, never ½-written).

### 4.2 Concurrent `/end-session` invocations — `scripts/test-faultinject-concurrent-endsession.sh` <!-- orianna: ok -->

**Scope:** two parallel coordinator sessions race on `open-threads.md` and `INDEX.md`.

**Scenarios:**

| # | Injection | Expected |
|---|---|---|
| Q1 | Two `/end-session` flows spawn simultaneously; both hit Step 6b at the same time. | `flock`/noclobber serializes them OR second exits as no-op with a clear message. Either outcome acceptable; silent corruption is not. |
| Q2 | Two flows produce conflicting `open-threads.md` edits. | Git merge conflict surfaces at push-time. Asserts: pre-push detects conflict, blocks push. |
| Q3 | One flow runs `--index-only` while the other runs the full consolidation. | Lock held by full run; `--index-only` exits no-op per ADR §10 #8. |
| Q4 | Both flows write distinct shards (different UUIDs) — INDEX must end up containing both. | After both settle (conflict resolved), INDEX row count == 2 shard rows. |

**Rakan implementation notes:**
- Use `( flow1 & ) ; ( flow2 & ) ; wait`.
- Q2's conflict resolution is out-of-test scope; the test only verifies that the conflict IS detected (i.e. git surfaces it), not that it auto-resolves.
- Budget ~30 min.

### 4.3 Advisory lock — `scripts/test-faultinject-lock.sh` <!-- orianna: ok -->

**Scope:** verifies flock/noclobber behavior of `memory-consolidate.sh`.

**Scenarios:**

| # | Injection | Expected |
|---|---|---|
| R1 | Pre-acquire the lock file via `flock -x <lockfile> sleep 30 &`, then invoke the script. | Script exits quickly with lock-held message, non-zero exit code. |
| R2 | Stale lock file (lockfile present but holder process dead). | Script acquires lock and runs (flock handles PID-liveness automatically). |
| R3 | Lock held across `--index-only` invocation. | Exits no-op per ADR §10 #8. |

### 4.4 Interrupted `/end-session` Step 6b — `scripts/test-faultinject-endsession-interrupt.sh` <!-- orianna: ok -->

**Scope:** Step 6b atomicity under interrupt.

**Scenarios:**

| # | Injection point | Expected |
|---|---|---|
| S1 | SIGINT between Step 6 (shard write) and Step 6b-start. | Shard file exists on disk, staged. Recovery via rerunning Step 6b manually is documented and works. |
| S2 | SIGINT mid-Step-6b (after `open-threads.md` write, before INDEX regen). | `open-threads.md` update staged; INDEX stale. Running `memory-consolidate.sh --index-only` on recovery produces correct INDEX. |
| S3 | SIGINT during commit step. | Either nothing committed (re-runnable) OR commit completed atomically (Rakan: git commits are atomic at the OS level). |
| S4 | Identical scenarios S1–S3 via Lissandra's pre-compact path (symmetry with §3.4). | Same outcomes. |

### 4.5 Shard-missing reference in `open-threads.md` — `scripts/test-faultinject-missing-shard-ref.sh` <!-- orianna: ok -->

**Scope:** the pre-archive ref-guard relies on reading `open-threads.md` and matching UUIDs. What if `open-threads.md` references a UUID that doesn't exist on disk (stale pointer)?

**Scenarios:**

| # | Injection | Expected |
|---|---|---|
| T1 | `open-threads.md` cites UUID `abc12345`; no `last-sessions/abc12345.md` exists (maybe archived long ago or hand-deleted). | `memory-consolidate.sh` logs a warning ("open-threads references missing shard") but does NOT crash. Consolidation completes. |
| T2 | `open-threads.md` cites an archived UUID. | Reference guard recognises archive path; still blocks re-archiving if somehow re-added. |
| T3 | `open-threads.md` is missing entirely (first bootstrap case). | Script treats it as empty — no references, no shards skipped. |
| T4 | `open-threads.md` is present but empty. | Same as T3 — no references. |
| T5 | `open-threads.md` contains a UUID that's a substring of another valid UUID. | Reference guard does WORD-boundary match, not substring match. Assert only exact-UUID matches are blocked. |

**Rakan implementation notes:**
- T5 is the nastiest bug class — a naive `grep -F <uuid>` will trigger false positives. Build the parser with regex word-boundary anchors.
- Fixture UUIDs must be crafted to exercise the substring case: e.g. `abc12345` and `abc123456789`.

---

## 5. Migration assertions (before/after boot comparison) — `scripts/test-migration-before-after.sh` <!-- orianna: ok -->

**Gates:** T8 + T12 (dogfood).
**Scope:** most-load-bearing test in the plan — proves the ADR's claimed token savings.

**Procedure:**

1. **Before:** with pre-migration tree (use a git ref `main^N` of the feature branch before T8), simulate Evelynn boot. Measure:
   - Number of files read at boot.
   - Total bytes of files read at boot.
   - Tokens (approx bytes/4) for the boot prefix.
2. **After:** with post-migration tree (tip of feature branch after T9), simulate Evelynn boot. Measure same.

**Assertions:**

| # | Assertion |
|---|---|
| U1 | After-boot file count == 8 (ADR §7 table). |
| U2 | Before-boot file count was ≥ 10 (5 static + ≥5 shards typical). |
| U3 | After-boot total bytes < Before-boot total bytes by at least 20 KB (recommendation §Token budget estimate: 40 KB saved from 23-shard load alone). |
| U4 | After-boot tail (positions 7–8) < 8 KB. |
| U5 | Static prefix (positions 1–6) identical-or-smaller between before and after (no new static docs added at boot). |
| U6 | Every shard UUID readable pre-migration is readable post-migration (via `last-sessions/` OR `archive/`). |
| U7 | Symmetric test for Sona. |

**Rakan implementation notes:**
- Checkout the "before" tree via `git worktree add` (never raw `git checkout` — CLAUDE.md Rule 3).
- Report results in the T12 commit evidence.

---

## 6. Test-runner integration

**Pre-push hook chain** (`scripts/hooks/pre-push.sh`) must invoke, in order: <!-- orianna: ok -->
1. Existing hooks (secret-scan, commit-prefix, TDD gate).
2. `scripts/test-memory-consolidate-index.sh` — cheap, always run. <!-- orianna: ok -->
3. `scripts/test-memory-consolidate-archive-policy.sh` — cheap, always run. <!-- orianna: ok -->
4. `scripts/test-end-session-skill-shape.sh` — cheap, grep-only. <!-- orianna: ok -->
5. `scripts/test-boot-chain-order.sh` — cheap, grep-only. <!-- orianna: ok -->

Heavier tests (§3, §4, §5) run on demand (Rakan's impl PR CI job) but NOT on every pre-push. Rakan to wire a GitHub Actions job `.github/workflows/memory-redesign-tests.yml` that runs the full suite on PRs touching `scripts/memory-consolidate.sh`, `scripts/_lib_last_sessions_index.sh`, `.claude/skills/end-session/SKILL.md`, `.claude/agents/evelynn.md`, `.claude/agents/sona.md`, `.claude/agents/lissandra.md`, or `agents/lissandra/**`. <!-- orianna: ok -->

**CI entrypoint** — `scripts/test-memory-redesign-all.sh` <!-- orianna: ok -->: a single script that invokes every test in §2–§5 in order. Exit 0 only if every sub-test returns 0 or XFAIL-expected. Print a summary line at the end (`PASS: N  FAIL: M  XFAIL: K`).

---

## 7. Surface-coverage audit (task-prompt surfaces → tests)

| Surface (from Sona's task prompt) | Tests |
|---|---|
| 1. `memory-consolidate.sh` rewrite: INDEX regen correctness, archive policy 14d OR 20, reference-check guard | §2.1 A1–A9, §2.2 B1–B10, §2.3 C1–C5, §3.1 I1–I7, §4.1 P1–P6, §4.3 R1–R3, §4.5 T1–T5 |
| 2. `open-threads.md` eager load at boot, tail position, prompt-cache stability | §2.4 D1–D7, §3.2 J1–J7 |
| 3. `last-sessions/INDEX.md` eager load, TL;DR shape, newest-first | §2.1 A2/A3/A4/A5/A8, §2.5 E1–E5, §3.2 J1–J3 |
| 4. `/end-session` Step 6b atomicity | §2.6 F1–F7, §3.3 K1–K8, §4.4 S1–S3 |
| 5. Lissandra pre-compact parity | §2.7 G1–G7, §3.4 L1–L4, §4.4 S4 |
| 6. Skarner on-demand retrieval | §2.8 H1–H4, §3.5 M1–M3 |
| 7. Migration — both coordinators in one PR, shards get INDEX entries retroactively, filter-last-sessions.sh removed | §3.6 N1–N10, §5 U1–U7 |
| 8. Failure injection: interrupted writes, concurrency, missing-shard refs | §4.1 P1–P6, §4.2 Q1–Q4, §4.3 R1–R3, §4.4 S1–S4, §4.5 T1–T5 |

Every surface has at least one unit-level + one integration-or-fault-injection check.

---

## 8. Rakan implementation order (recommended)

1. X1 (§2.1) — xfail commit for INDEX regen.
2. X2 (§2.2) — xfail commit for archive policy.
3. T2 + T4 (scripts) — impl; X1 + X2 go green.
4. Add §2.3 + §2.5 regression guards (post-impl).
5. X3 (§2.6 + §3.3) — xfail commits for end-session.
6. T5 + T6 — impl; X3 goes green.
7. X4 (§2.7) — xfail commit for Lissandra.
8. T7 — impl; X4 goes green.
9. X5 (§2.4) — xfail commit for boot-chain order.
10. T9 + T10 — impl; X5 goes green.
11. X6 (§3.6 + §5) — xfail commit for migration.
12. T8 — bootstrap; X6 goes green.
13. Fault-injection suites (§4.1–§4.5) — commit post-impl as regression guards.
14. CI wiring (`scripts/test-memory-redesign-all.sh` + GitHub Actions workflow). <!-- orianna: ok -->
15. T12 — dogfood + commit evidence.

---

## 9. Blocking questions for Duong / Swain

**None blocking implementation.** Three low-stakes clarifications Rakan may hit — pre-answered with defaults so he can proceed:

1. **Exact INDEX row format** (table vs dot-separated) — Rakan picks during T2 impl; §2.5 E2 regex updates during the X1 xfail commit to match.
2. **`STRAWBERRY_MEMORY_ROOT` env shim** for testability (§3.1 I1) — Rakan adds this to the T4 impl; if Xayah-the-reviewer disagrees, raise at impl-PR review.
3. **`STRAWBERRY_SLEEP_BEFORE_STEP` debug hook** for deterministic fault injection (§4.1) — Rakan adds behind an env-gate so production runs are unaffected.

If any of these three surprise Swain or Duong at review time, raise in the impl PR thread, not here.

---

## 10. Handoff summary

- **Xfail-first commits:** X1–X6 (six commits, each on the feature branch before its impl).
- **Test scripts to create:** 15 new `scripts/test-*.sh` files (§2.1–§2.8, §3.1–§3.6, §4.1–§4.5, §5, §6 CI entrypoint).
- **Test scripts to modify:** `scripts/hooks/pre-push.sh` (wire the cheap tests). <!-- orianna: ok -->
- **New workflow file:** `.github/workflows/memory-redesign-tests.yml`. <!-- orianna: ok -->
- **Invariants protected:** boot-token, INDEX-freshness, archive-policy, atomicity, ordering, no-orphan, bootstrap-completeness, prompt-cache stability, migration-lossless.
- **Rakan authors; Vi/Caitlyn run.** Xayah reviews the impl PR for coverage gaps before merge.

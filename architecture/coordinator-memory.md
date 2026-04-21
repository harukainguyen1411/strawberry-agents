# Coordinator Memory — Two-Layer Boot Design

Applies to: Evelynn (personal concern) and Sona (work concern).

Source plan: `plans/in-progress/personal/2026-04-21-memory-consolidation-redesign.md`

---

## 1. Problem

The previous boot loaded every shard from `agents/<coordinator>/memory/last-sessions/` whose mtime fell within the last 48 hours. This produced two failure modes:

- **Noisy-busy failure** — right before this design shipped, Evelynn had 24 shards in her 48h window; most described threads that had merged, closed, or been superseded. Boot context was dominated by stale noise (~13–14k input tokens, ~40k raw bytes in shards alone).
- **Idle-amnesia failure** — if more than 48h elapsed between sessions, every shard fell outside the window and the coordinator booted blind to threads that were alive days ago.

---

## 2. Decision

Two-layer memory shape:

- **Eager, small, curated** — `open-threads.md` (hand-maintained live state) + `last-sessions/INDEX.md` (auto-generated 3-line-per-shard TL;DR). Always loaded at boot. Target: combined < 8 KB.
- **Lazy, large, historical** — `last-sessions/<uuid>.md` shards (unchanged). Pulled on demand when a thread reference or Duong's prompt requires it. Topic searches delegated to Skarner.

---

## 3. File Layout

```
agents/<coordinator>/memory/
├── <coordinator>.md                      # unchanged — static identity + durable context
├── open-threads.md                       # EAGER — hand-maintained live thread state
├── last-sessions/
│   ├── <uuid>.md                         # unchanged — full handoff shards (written per /end-session)
│   ├── INDEX.md                          # EAGER — auto-generated 3-line-per-shard TL;DR, newest first
│   └── archive/
│       └── <uuid>.md                     # archival tier — shards past 14d OR beyond #20
└── sessions/                             # unchanged — folded into <coordinator>.md by memory-consolidate.sh
    ├── <uuid>.md
    └── archive/
```

### File responsibilities

| Concern | Owner | Mechanism |
|---|---|---|
| What threads are live | `open-threads.md` | Coordinator-hand-written at `/end-session`, in-place during session |
| Which historical shards exist | `last-sessions/INDEX.md` | Auto-regenerated on every `/end-session` write |
| Full shard detail | `last-sessions/<uuid>.md` | Unchanged; on-demand read via coordinator or Skarner |
| Archival retention | `scripts/memory-consolidate.sh` | 14d OR 20 shards whichever first → `archive/` |
| Archive deletion | `scripts/memory-consolidate.sh` | 30d prune (backstop for disk pressure) |

---

## 4. Write-Side Flow

### Via `/end-session`

The skill (`./claude/skills/end-session/SKILL.md`) runs this sequence for coordinator agents (evelynn or sona):

1. **Step 6** — Write handoff shard to `last-sessions/<uuid>.md`. Stage.
2. **Step 6b** — Parse shard's `## Open threads into next session` section. Apply deltas to `open-threads.md` (add/update live threads, close resolved ones). Stage. Then regenerate `INDEX.md`:
   ```
   bash scripts/memory-consolidate.sh <coordinator> --index-only
   ```
   Stage `INDEX.md`.
3. **Step 9** — Commit all staged artifacts (shard + open-threads.md + INDEX.md) in one atomic commit + push.

**Ordering invariant:** Step 6 MUST complete before Step 6b (shard is the source for both writes). Step 6b MUST complete before Step 9 (all three artifacts land atomically). If Step 6b fails partway, the shard is already staged and recoverable — log the failure and proceed to Step 9 with only the shard staged. Recovery: run `bash scripts/memory-consolidate.sh <coordinator> --index-only`, stage `INDEX.md`, amend the next commit.

Non-coordinator agents (Sonnet subagents via `/end-subagent-session`): Step 6b is a no-op.

### Via `/pre-compact-save` (Lissandra)

When a coordinator session runs `/pre-compact-save`, Lissandra mirrors the `/end-session` close protocol at compact boundaries. Lissandra's Step 2b (in `.claude/agents/lissandra.md`) runs the identical Step 6b sequence — parse shard's Open threads section → apply deltas to `open-threads.md` → stage → regenerate INDEX → stage — in the coordinator's voice, then commits.

---

## 5. Read-Side Flow

### Boot order

Both coordinators read files in this order (ADR §7, option b: dynamic tail after static files for prompt-cache stability):

| # | File | Type | Cache-stable? |
|---|---|---|---|
| 1 | `agents/<coordinator>/CLAUDE.md` | static | yes |
| 2 | `agents/<coordinator>/profile.md` | static | yes |
| 3 | `agents/<coordinator>/memory/<coordinator>.md` | slow-churn | yes (changes only at consolidation) |
| 4 | `agents/memory/duong.md` | static | yes |
| 5 | `agents/memory/agent-network.md` | slow-churn | yes |
| 6 | `agents/<coordinator>/learnings/index.md` | slow-churn | yes |
| 7 | `agents/<coordinator>/memory/open-threads.md` | high-churn | **tail — invalidates per session** |
| 8 | `agents/<coordinator>/memory/last-sessions/INDEX.md` | high-churn | **tail — invalidates per session** |

Positions 7 and 8 are always the last two entries. Any future additions (new static doc, new rule file) go above them, never between.

### On-demand shard access

Pull a specific shard (`last-sessions/<uuid>.md`) only when:
- `open-threads.md` references that UUID, or
- Duong's first message touches a thread not described in `open-threads.md`.

Do NOT bulk-load shards at boot.

### Historical search

For broad topic searches across historical shards (or archived shards), delegate to Skarner. Skarner is a read-only memory excavator — do not load shards in the coordinator session yourself.

---

## 6. Retention Policy

Managed by `scripts/memory-consolidate.sh` (called at coordinator boot via the `initialPrompt`):

1. **Archive trigger (14d OR 20 shards)** — after INDEX regeneration, compute the set of active shards in `last-sessions/*.md` (excluding `INDEX.md` itself and `.gitkeep`). Order newest-first by mtime. Archive a shard if EITHER its mtime-age > 14d OR its 1-based position in the ordered set > 20. Move via `git mv` to `last-sessions/archive/<uuid>.md`.
2. **Pre-archive guard** — before moving a shard, check `open-threads.md` for a reference to that UUID. If found, skip the archive move and log a warning (failure mode #4).
3. **Archive deletion (30d backstop)** — shards in `last-sessions/archive/` are pruned if their commit-date age > 30d. Keeps disk pressure in check.

---

## 7. Failure Modes

| # | Failure | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | Coordinator forgets to update `open-threads.md` at `/end-session` | Medium | Soft — stale thread stays listed one session longer | Step 6b is part of the skill checklist. Extra thread is noise, not data loss. |
| 2 | `INDEX.md` drifts from actual shard contents | Low | Medium — can't find a shard it should know about | Auto-regen on every `/end-session` write + every boot's `memory-consolidate.sh` call. |
| 3 | Two parallel coordinator sessions race on `open-threads.md` | Low | Medium — merge conflict | Same race class as shard writes. Advisory lock in `memory-consolidate.sh` serializes INDEX regen. `open-threads.md` edits fail loud at push-time. |
| 4 | Archive move deletes a shard still referenced by `open-threads.md` | Low | High — silent context loss | `memory-consolidate.sh` pre-archive guard skips any shard whose UUID appears in `open-threads.md`. Warning logged on skip. |
| 5 | TL;DR parsing produces "(no summary extractable)" | Medium | Low — index row less useful but shard still findable by UUID | Shard header convention documented in `architecture/coordinator-memory.md` §4.4 of the plan; fallback to prose parsing. |
| 6 | Archive fills up past 30d prune | Low | Low — disk usage | 30d prune in `memory-consolidate.sh` continues unchanged. |
| 7 | Bootstrap misses an open thread during seed | Medium | Low–Medium — thread absent from `open-threads.md` after cutover | First post-merge session will show the gap; coordinator adds missing thread and commits. Recoverable in one `/end-session`. |
| 8 | `--index-only` flag runs during a concurrent full consolidation | Low | Medium — INDEX regenerated on partially-moved shard set | `--index-only` respects the same advisory lock. If lock held, exits as no-op. |

---

## 8. Cross-References

- Agent boot prompts: `.claude/agents/evelynn.md`, `.claude/agents/sona.md` (positions 7–8 in `initialPrompt`)
- Coordinator rules: `agents/evelynn/CLAUDE.md` §Startup Sequence, `agents/sona/CLAUDE.md` §Startup Sequence
- Agent roster note: `agents/memory/agent-network.md` §Memory Consumption
- Write-side skill: `.claude/skills/end-session/SKILL.md` Step 6b
- Pre-compact write: `.claude/agents/lissandra.md` Step 2b, `agents/lissandra/profile.md` §Behavior
- Script: `scripts/memory-consolidate.sh` (`--index-only` flag, archive policy, pre-boot validator)
- Helper lib: `scripts/_lib_last_sessions_index.sh` (INDEX row generation, `extract_shard_tldr`, `render_index_row`, `regenerate_index`)

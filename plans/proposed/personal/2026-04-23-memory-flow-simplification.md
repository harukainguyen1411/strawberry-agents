---
status: proposed
concern: personal
owner: swain
created: 2026-04-23
orianna_gate_version: 2
tests_required: true
complexity: complex
tags: [memory, coordinator, evelynn, sona, open-threads, remember, last-sessions, architecture]
architecture_impact: refactor
related:
  - plans/implemented/personal/2026-04-21-memory-consolidation-redesign.md
  - plans/implemented/personal/2026-04-21-coordinator-boot-chain-cache-reorder.md
  - plans/proposed/personal/2026-04-21-coordinator-decision-feedback.md
  - architecture/coordinator-memory.md
  - agents/evelynn/CLAUDE.md
  - agents/sona/CLAUDE.md
  - .claude/skills/end-session/SKILL.md
  - .claude/skills/end-subagent-session/SKILL.md
  - .claude/skills/pre-compact-save/SKILL.md
  - scripts/memory-consolidate.sh
orianna_signature_approved: "sha256:b9a6fe938bc5e266b64fec73f7cf104c40c1f6af6adb3e2590a0131ddabc530c:2026-04-23T02:43:38Z"
---

# Memory flow simplification — ADR

## 1. Problem

Coordinator memory has grown to ~15 distinct surfaces and 4 closing skills (`/end-session`, `/end-subagent-session`, `/pre-compact-save`, `remember:remember`). Semantics overlap. The system has **two eager live-state surfaces** at every coordinator boot:

- `.remember/now.md` — auto-captured event buffer (cross-agent, time-ordered, accurate)
- `agents/<coordinator>/memory/open-threads.md` — hand-authored thread ledger (per-coordinator, thread-shaped, stale-prone) <!-- orianna: ok -- per-coordinator placeholder, resolves to evelynn/sona at read time -->

On 2026-04-23 Sona booted with `.remember/now.md` showing three thread-state updates ("T7 Firestore wipe executed", "dashboard scope contracted", "PR #32 awaiting full chain") that her `agents/sona/memory/open-threads.md` ledger did not reflect. Sona briefed Duong from the stale ledger. Sona's own root-cause post at `agents/evelynn/inbox/archive/2026-04/20260423-0219-910771.md` identified two bugs: (A) authoring — the ledger is only updated at `/end-session`, so intra-session state changes silently diverge from the auto-buffer; (B) reading — at boot both surfaces load eagerly and current behaviour silently privileges the curated (stale) file.

This ADR treats Sona's bug as a **symptom** of the deeper problem: the memory architecture has two independent writers for overlapping "live state" — one automatic, one manual. Any reconciliation layer is a patch, not a fix. The fix is to collapse the surfaces so **live state has exactly one writer and exactly one reader path**, by construction.

Adjacent overlaps that compound the complexity, enumerated before deciding:

Surface paths below that use `<coordinator>` or `<uuid>` resolve to a concrete per-coordinator file at read time; they are not unresolved placeholders. The authoritative live examples are `agents/evelynn/memory/open-threads.md` and `agents/sona/memory/open-threads.md`.

- **O1.** `.remember/now.md` vs `agents/evelynn/memory/open-threads.md` (and Sona's equivalent at `agents/sona/memory/open-threads.md`) — both claim to be "what's live right now."
- **O2.** `.remember/today-2026-04-22.done.md` (daily "done" buffer files under `.remember`) vs per-session shards under the directory `agents/evelynn/memory/last-sessions` — both capture "what happened during a day's work." <!-- orianna: ok -- directory path cited without trailing slash -->
- **O3.** The `## Sessions` list inside `agents/evelynn/memory/evelynn.md` vs the per-session shards under `agents/evelynn/memory/last-sessions/` — same content, different shape (consolidated prose vs per-session shard). <!-- orianna: ok -- directory reference with trailing slash -->
- **O4.** `agents/evelynn/learnings/index.md` entries vs session-shard "delta notes" — both capture takeaways.
- **O5.** `agents/evelynn/memory/last-sessions/archive/` vs `agents/evelynn/memory/sessions/archive/` — two archive roots for what are effectively one artifact class. <!-- orianna: ok -- directory reference with trailing slash -->
- **O6.** `.remember/recent.md` + `.remember/archive.md` vs `agents/evelynn/memory/last-sessions/INDEX.md` — two index/manifest surfaces over the same shard stream.
- **O7.** First-person reflection files under `agents/evelynn/journal/` (pattern `cli-YYYY-MM-DD.md`) vs shards under `agents/evelynn/memory/last-sessions/` — first-person reflection vs structured handoff; both per-session. <!-- orianna: ok -- directory reference with trailing slash -->
- **O8.** `agents/evelynn/inbox/` vs `agents/evelynn/memory/open-threads.md` — both carry "things awaiting coordinator attention." <!-- orianna: ok -- directory reference with trailing slash -->
- **O9.** `/end-session` Step 6 vs `/pre-compact-save` — both write a shard + mutate the open-threads ledger; one commits, the other "mirrors."
- **O10.** `remember:remember` plugin vs `/end-session` Step 6 — the plugin writes `.remember/remember.md`; the skill writes a separate handoff shard under `agents/evelynn/memory/last-sessions/`; Evelynn bypasses the plugin, Sona uses it. <!-- orianna: ok -- directory reference with trailing slash -->

Closing-surface count is 4. Memory-surface count is 11. Collapsed targets (§3): 1 closing-surface template parameterised per role, 6 memory surfaces. Elimination removes 4 overlap pairs outright (O1, O2, O5, O6); the remaining pairs (O3, O4, O7, O8, O9, O10) gain clean non-overlapping roles (§3.5).

## 2. Constraints

From the task brief and the existing system:

1. Single source of truth for "what's live right now" — no manual reconciliation between two files.
2. Subagent close path stays cheap (one-shot, often a no-op).
3. Coordinator close path preserves the audit trail (commit + push, handoff readable by future-self).
4. Compact-boundary preservation survives — losing session state at `/compact` is unacceptable.
5. Learnings survive as their own artifact (citation-grade, cross-session knowledge).
6. Concern (personal vs work) is identifiable cleanly — memory is shared across concerns but some surfaces are coordinator-scoped.
7. Don't break already-written shards mid-flight. Migration plan mandatory.
8. Learnings remain immutable and append-only.
9. Any new skill/hook works on both Evelynn and Sona with identical shape.
10. `remember:remember` is a third-party plugin; if dropped, migration must be explicit.
11. Concurrent-coordinator writes must not race. The coordinator lock (`plans/implemented/personal/2026-04-22-concurrent-coordinator-race-closeout.md`) already exists — preserve it.
12. Prompt-cache stability — static files ahead of high-churn tail (already enforced by `plans/implemented/personal/2026-04-21-coordinator-boot-chain-cache-reorder.md`). Do not break.

## 3. Decision — the new topology

Collapse to **six memory surfaces + one parameterised close skill.**

### 3.1 Memory surfaces (per coordinator)

```
agents/<coordinator>/memory/
├── <coordinator>.md              # identity + durable context (unchanged role)
├── live-threads.md               # LIVE LEDGER — single source of truth for "what's open now"
├── sessions/
│   ├── <uuid>.md                 # immutable per-session snapshot (written at close)
│   ├── INDEX.md                  # auto-generated TL;DR manifest, newest first
│   └── archive/<uuid>.md         # aged-out snapshots (single archive root)
└── (no journal/ — folded into session snapshots, see §3.4)
```

Cross-agent:
```
agents/<name>/learnings/          # unchanged — immutable, append-only
agents/<name>/inbox/              # unchanged — fire-and-forget messages
.remember/                        # RETIRED for coordinators (see §3.2); kept for Sonnet subagents via remember:remember plugin until §5 migration
```

Rename highlights:
- Ledger rename: the file today called `open-threads.md` becomes `live-threads.md` (new semantic: ledger that is updated in-session on every state change, not only at close). <!-- orianna: ok -- prospective rename, created by T3 -->
- Snapshot dir consolidation: today's `last-sessions/` directory under each coordinator collapses into the coordinator's `sessions/` directory (single archive root — kills the two-archive-root confusion of O5; today's `sessions/` content moves to `sessions/legacy/` first per T2). <!-- orianna: ok -- prospective consolidation, done by T2 -->
- Journal fold: today's first-person reflection files under `agents/<coordinator>/journal/cli-<date>.md` are folded into the session snapshot as a `## Journal` section (§3.4). <!-- orianna: ok -- coordinator placeholder, resolves to evelynn/sona -->
- `.remember/` — retired for coordinators; still used by Sonnet subagents that opt into the plugin-based lightweight handoff. Evelynn and Sona stop reading or writing it. <!-- orianna: ok -- directory reference with trailing slash -->

### 3.2 The single source of truth rule

**Rule S1.** There is exactly one surface that answers "what is live right now?" and it is `live-threads.md`. All other surfaces are derived from it, snapshots of it, or orthogonal to it. <!-- orianna: ok -- prospective path cited by ADR -->

**Rule S2.** `live-threads.md` is **coordinator-writable in-session.** The coordinator updates it whenever a thread changes state. No separate "end-session writes the ledger" step. The writer is always in-session; end-session only snapshots. <!-- orianna: ok -- prospective path cited by ADR -->

**Rule S3.** `.remember/now.md` is not read by coordinators. It is not written by coordinators. It is not reconciled against anything. The `remember:remember` plugin `SessionStart` hook is disabled for coordinator sessions (via `.claude/agents/evelynn.md` and `.claude/agents/sona.md` — initialPrompt already bypasses Evelynn; extend to Sona in T1).

**Rule S4.** Anything in `.remember/` that is currently load-bearing for coordinators is migrated into `live-threads.md` during T2 (§5.1). After cutover, coordinators treat `.remember/` as if it does not exist. <!-- orianna: ok -- directory reference with trailing slash -->

This eliminates the two-source-of-truth drift **by construction** — there is no second source. Sona's bug cannot recur because there is no `.remember/now.md` to diverge from. No reconciliation script is required or permitted (adding one re-creates the drift surface).

### 3.3 live-threads.md shape

One `## <thread-name>` section per live thread. Ledger fields:

```markdown
## <thread-name>

- Status: <one-line current state>
- Last-updated: <YYYY-MM-DD HH:MM session-id-short or "in-session">
- Snapshot-pointers: <uuid-1>, <uuid-2>   # sessions/<uuid>.md references
- Next: <what should happen next>
- Owner: <agent-name or "coordinator">
```

When a thread resolves, it is **removed** from `live-threads.md` (not marked closed). Resolved threads live only in the session snapshot that resolved them. The ledger answers "what's live", not "what was". <!-- orianna: ok -- prospective path cited by ADR -->

Edge: if Duong asks "whatever happened to thread X", coordinator delegates to Skarner to scan snapshots — same retrieval path as today's last-sessions search.

Target size: < 6 KB typical, < 10 KB hard ceiling. If the ledger grows past 10 KB, the coordinator **must** resolve or archive threads before taking new work — enforced as a close-time check in T3.b (§5.1).

### 3.4 sessions/<uuid>.md shape — single snapshot artifact

Replaces four current artifacts (`last-sessions/<uuid>.md` + `sessions/<uuid>.md` + `journal/cli-<date>.md` + `.remember/today-<date>.md`) with one structured file written at close: <!-- orianna: ok -- prospective path cited by ADR -->

```markdown
# Session <uuid> — <coordinator> — <YYYY-MM-DD>

## TL;DR
<3-line summary. Consumed verbatim by INDEX.md regen.>

## Timeline
<Chronological log of what happened this session. Pulled from the session's own cleaned transcript — not hand-typed. Replaces .remember/today-<date>.md's role.>

## Threads touched
- <thread-name>: <what-changed>, <new-status>
- ...

## Journal
<First-person reflection. Replaces journal/cli-<date>.md's role.>

## Delta-to-durable-memory
<Anything that should fold into <coordinator>.md at next consolidation. May be empty.>
```

Written once, at close. Immutable after commit. INDEX.md auto-generates from the `## TL;DR` sections.

Session snapshots are the archival audit trail. Skarner retrieves across them on demand.

### 3.5 Role clarity for remaining pairs (resolves O3, O4, O7, O8, O9, O10)

| Pair | Resolution |
|---|---|
| O3 `<coordinator>.md` Sessions vs snapshots | `<coordinator>.md` has NO Sessions list. `memory-consolidate.sh` folds `## Delta-to-durable-memory` sections into `## Key context` / `## Working patterns` only. Sessions list disappears — it was redundant with INDEX.md. | <!-- orianna: ok -- prospective path cited by ADR -->
| O4 Learnings vs session delta-notes | `learnings/` = cross-session, reusable, immutable lesson. Session snapshot's `## Journal` = this-session-only reflection. Different retention (learnings forever, snapshots 14d active + archive). Rule: if a delta note would benefit a future session, it's a learning — promote it. | <!-- orianna: ok -- directory reference with trailing slash -->
| O7 Journal vs last-sessions | Merged — `## Journal` is a section of the snapshot. One file per session, not two. |
| O8 Inbox vs live-threads | `inbox/` = inbound unread messages from other agents (auto-archived on read). `live-threads.md` = threads the coordinator has already acknowledged and is tracking. Inbox items are promoted to threads on read, not duplicated. | <!-- orianna: ok -- directory reference with trailing slash -->
| O9 `/end-session` vs `/pre-compact-save` | Both use the same skill core (§3.6). `/pre-compact-save` is a compact-boundary snapshot — writes the session shard but keeps the session open. `/end-session` also archives the transcript and closes. Same Step sequence, one parameter. |
| O10 `remember:remember` plugin | **Retired for coordinators** (already bypassed for Evelynn; extended to Sona in T1). Kept available for Sonnet subagents that choose the lightweight plugin-based handoff — but subagents rarely write handoffs anyway (see `/end-subagent-session`), so in practice the plugin becomes optional. Plugin not uninstalled; just unused by coordinators. |

### 3.6 Closing-skill collapse

Current state: 4 overlapping skills.

Target: **1 parameterised close-session skill + 1 subagent close-session skill.**

```
/close-coordinator-session <mode>
  mode = end       → write snapshot + INDEX regen + transcript archive + commit + push + terminate
  mode = compact   → write snapshot + INDEX regen + commit + push (session stays open, sentinel for PreCompact hook)
  mode = handoff   → write snapshot + INDEX regen + commit + push (alias for end without transcript archive; reserved for rare "save state and continue")

/close-subagent-session                   (unchanged — `/end-subagent-session`, already lean)
```

Skill-file layout:

- `.claude/skills/close-coordinator-session/SKILL.md` — the new unified skill. Replaces `/end-session`, `/pre-compact-save`. `remember:remember` invocation removed. <!-- orianna: ok -- prospective path cited by ADR -->
- `.claude/skills/end-subagent-session/SKILL.md` — retained as-is; `/close-subagent-session` is an alias.
- Old skills `.claude/skills/end-session/` and `.claude/skills/pre-compact-save/` are kept as thin aliases for one release cycle (prints deprecation banner, calls new skill with the appropriate `mode`), then removed in T9 cleanup. <!-- orianna: ok -- directory reference with trailing slash -->

Mode dispatch inside the skill is a single branch — no duplicated step list. All three modes share the snapshot + INDEX + commit core; `end` additionally archives transcript + sets a close-flag that the harness can observe; `compact` additionally writes the PreCompact sentinel.

This collapses four skills to two, kills the "which skill do I run" decision, and gives Lissandra a single target when impersonating the coordinator at compact boundaries.

### 3.7 Boot order after collapse

No change to positions 1–6. Positions 7–8 simplify:

| # | File | Type |
|---|---|---|
| 1–6 | unchanged (CLAUDE.md, profile, memory, Duong, network, learnings index) | static / slow-churn |
| 7 | `agents/<coordinator>/memory/live-threads.md` | high-churn — **the only live-state surface** | <!-- orianna: ok -- prospective path cited by ADR -->
| 8 | `agents/<coordinator>/memory/sessions/INDEX.md` | high-churn — snapshot manifest | <!-- orianna: ok -- prospective path cited by ADR -->
| 9 | `agents/<coordinator>/inbox/` — scan pending | high-churn | <!-- orianna: ok -- directory reference with trailing slash -->

Coordinator does NOT read `.remember/now.md`, `.remember/today-*.md`, or `.remember/recent.md`. They are removed from the initialPrompt chain in T1. <!-- orianna: ok -- prospective path cited by ADR -->

## 4. Alternatives considered

### 4.1 Alt A — `.remember/` wins, drop `open-threads.md` <!-- orianna: ok -- directory reference with trailing slash -->

Make `.remember/now.md` the live state surface. Generate a thread view on demand (by script, from the time-ordered buffer).

**Rejected because:**
- `.remember/now.md` is cross-agent time-ordered — it does not cleanly express per-coordinator thread state without a derivation layer. Derivation is the kind of "reconciliation on top" we're trying to avoid.
- Threads are the coordinator's actual unit of work. A time-ordered log is the wrong primary shape for "which PR am I waiting on?".
- The `remember:remember` plugin is third-party; making it load-bearing for coordinator memory couples Strawberry to an external cadence.
- Auto-capture semantics are a feature, not a bug, but the feature belongs in the session snapshot's `## Timeline`, not the live-state ledger.

### 4.2 Alt B — reconcile at boot (Sona's original proposal)

Keep both surfaces; add `scripts/reconcile-live-state.sh` that diffs `.remember/today-*.md` since last close against `open-threads.md` and prompts the coordinator to resolve discrepancies at `/end-session` and at boot. <!-- orianna: ok -- prospective path cited by ADR -->

**Rejected because:**
- It's a 15th surface (the reconciliation script + its diff reports) on top of an already-too-many-surfaces system. Duong's framing: "too complicated and too many tools conflict."
- Reconciliation is mechanically complex (thread-key matching, fuzzy disambiguation, coordinator-in-the-loop prompts) and is itself a source of bugs.
- It doesn't solve drift — it only flags it. A drift flag at boot is strictly worse than no drift possibility.
- The coordinator-in-the-loop prompt adds cognitive load at boot, which is exactly the moment Sona's brief went wrong.

### 4.3 Alt C — drop live state entirely, derive on demand

Remove `open-threads.md` and `.remember/*.md`. At boot, run a script that scans the last N session snapshots + git log + open PRs and produces a synthesized thread list. <!-- orianna: ok -- prospective path cited by ADR -->

**Rejected because:**
- Derivation fidelity is poor — a script cannot know "this PR is god-mode, stays open until full chain ships" (one of Sona's three stale items). That's curated judgement, not metadata.
- It makes boot slow and non-deterministic. The current eager two-file read is fast (< 10 KB, one cache hit).
- The curated ledger shape has genuine value — coordinator's judgement about thread priority, next actions, and blockers is load-bearing context that doesn't survive a pure derivation.
- Moves complexity from memory format to derivation logic; net reduction unclear.

### Pick rationale

Chosen design (§3) makes `live-threads.md` the **only** live-state surface, written in-session by the coordinator on every state change, and snapshotted at close. Drift is impossible because there is no second surface. `.remember/` is retired for coordinators, collapsing an entire parallel system. The other overlap pairs gain non-overlapping roles (§3.5), reducing memory surfaces from 11 to 6 and close skills from 4 to 2. <!-- orianna: ok -- directory reference with trailing slash -->

## 5. Migration plan

Phased, non-breaking. Each task commits independently. Any task can be reverted without affecting others until T3 cutover lands.

### Phase 1 — prepare the new surfaces alongside the old (no reader change yet)

**T1. Draft `.claude/skills/close-coordinator-session/SKILL.md`** — the new unified skill (modes `end` / `compact` / `handoff`). <!-- orianna: ok -- prospective path, created by this plan -->
Parameterise Steps from current `/end-session` + `/pre-compact-save`. Write snapshot into the **new** directory `agents/<coordinator>/memory/sessions/` (the same directory currently holding the secondary session shard — no name collision because T2 moves the old contents first). Does not yet replace old skills. <!-- orianna: ok -- directory reference with trailing slash -->
estimate_minutes: 60, kind: design

**T2. Migrate existing `sessions/` → `sessions/legacy/`** — preserve the current `sessions/<uuid>.md` artifact class under `sessions/legacy/` so the namespace is free for the new unified snapshot artifact. `memory-consolidate.sh` Session-fold logic updated to read from `sessions/legacy/` one last time during the migration consolidation, then stop reading it. <!-- orianna: ok -- directory reference with trailing slash -->
estimate_minutes: 35, kind: refactor

**T3. Seed `live-threads.md` from current `open-threads.md`** — one-shot copy with `git mv`. Shape-normalise entries to the §3.3 schema. Commit per coordinator. <!-- orianna: ok -- prospective path cited by ADR -->
estimate_minutes: 25, kind: refactor

**T4. Update `agents/evelynn/CLAUDE.md` + `agents/sona/CLAUDE.md` + `.claude/agents/evelynn.md` + `.claude/agents/sona.md`** — change initialPrompt position 7 from `open-threads.md` to `live-threads.md`. Remove any read of `.remember/`. Update boot-position docs in `architecture/coordinator-memory.md`. <!-- orianna: ok -- directory reference with trailing slash -->
estimate_minutes: 30, kind: refactor

### Phase 2 — cutover

**T5. Flip coordinators to the new skill** — update `agents/evelynn/CLAUDE.md` + `agents/sona/CLAUDE.md` to invoke `/close-coordinator-session end` instead of `/end-session`. Old `/end-session` becomes a deprecation-banner alias.
estimate_minutes: 25, kind: refactor

**T6. Retire `open-threads.md`** — `git mv` any remaining open-threads files to a one-shot archive location `agents/<coordinator>/memory/archive/open-threads-<date>.md` so git history is preserved. Remove from `architecture/coordinator-memory.md` §3 file-layout. One-liner in learnings describing the rename. <!-- orianna: ok -- prospective path cited by ADR -->
estimate_minutes: 20, kind: refactor

**T7. Suppress `remember:remember` for coordinators** — extend Evelynn's current bypass (already documented in `agents/evelynn/CLAUDE.md`) to Sona. Add SessionStart hook guard that skips the plugin when the session's initial greeting matches `/^Hey Sona/i` or the agent-def `concern:` field is `personal` or `work`. Plugin remains installed for Sonnet subagents that opt in.
estimate_minutes: 30, kind: hook

**T8. Rewrite `scripts/memory-consolidate.sh`** — remove last-sessions/ references, point at new `sessions/`. Delete the session-fold block that wrote to `<coordinator>.md` Sessions list (§3.5 O3 resolution). Preserve `--index-only` flag and advisory lock. Preserve archive policy (14d OR 20 shards). <!-- orianna: ok -- directory reference with trailing slash -->
estimate_minutes: 50, kind: refactor

### Phase 3 — cleanup (one week after T5 lands stable)

**T9. Remove old close-session skill files** — delete `.claude/skills/end-session/SKILL.md` and `.claude/skills/pre-compact-save/SKILL.md` one week after T5 confirms stable. Update every agent-def that referenced them. Leave `/end-subagent-session` alone.
estimate_minutes: 25, kind: cleanup

**T10. Clean `.remember/` for coordinator use** — delete coordinator-referencing files under `.remember/` (`now.md`, `today-*.md`, `recent.md`, `archive.md`). Keep `.remember/remember.md` schema intact so the plugin keeps working for subagents. Document under `architecture/` that `.remember/` is subagent-only post-migration. <!-- orianna: ok -- directory reference with trailing slash -->
estimate_minutes: 20, kind: cleanup

**T11. Fold `journal/cli-*.md` into new snapshot shape (documentation-only)** — update agent-def boot prompts and `agents/<agent>/CLAUDE.md` files to describe the `## Journal` section of the snapshot as the canonical first-person-reflection location. Existing `journal/cli-*.md` files stay on disk as historical artifacts; no further writes by the close-session skill. <!-- orianna: ok -- prospective path cited by ADR -->
estimate_minutes: 20, kind: doc

**T12. Update architecture doc** — rewrite `architecture/coordinator-memory.md` to reflect §3 (six surfaces, `live-threads.md`, single sessions root, no `.remember`, unified close skill, parameterised modes). <!-- orianna: ok -- prospective path cited by ADR -->
estimate_minutes: 45, kind: doc

**T13. Write migration learning** — `agents/swain/learnings/2026-04-23-memory-surface-collapse.md` capturing the O1–O10 collapse table and the "single-source-of-truth by construction" principle. Index entry appended. <!-- orianna: ok -- prospective path cited by ADR -->
estimate_minutes: 15, kind: doc

### Migration invariants

- Each task commits independently with `chore:` prefix. No PR required (plan-level work is direct-to-main per Rule 4).
- No task may touch both old and new skill files in the same commit (blast-radius isolation).
- Post-T5 rollback: revert the T5 commit; coordinators resume `/end-session`. `live-threads.md` vs `open-threads.md` state divergence is a non-issue during rollback because both point at the same thread list (T3 seeded them identically). <!-- orianna: ok -- prospective path cited by ADR -->
- No single task modifies both `evelynn/` and `sona/` in the same commit — keeps the coordinator lock semantics intact. <!-- orianna: ok -- directory reference with trailing slash -->

## 6. Answer to Sona's drift bug — by construction

Sona's bug recurrence path was: `.remember/now.md` captured event, `open-threads.md` lagged, both loaded at boot, curated-but-stale won. <!-- orianna: ok -- prospective path cited by ADR -->

Under §3:

- `.remember/now.md` is not read by the coordinator at boot (§3.7).
- `.remember/now.md` is not written by the coordinator at all (Rule S3).
- `.remember/now.md` is not compared to anything (Rule S4).
- The only live-state surface (`live-threads.md`) is updated **in-session** by the coordinator whenever a thread changes state (Rule S2). There is no lag between auto-capture and curated ledger because there is no auto-capture surface competing with the ledger. <!-- orianna: ok -- prospective path cited by ADR -->
- Intra-session state changes are reflected by the coordinator writing the single ledger directly (edit tool on `live-threads.md`). No skill invocation required. <!-- orianna: ok -- prospective path cited by ADR -->

If in a future session a coordinator forgets to update `live-threads.md` mid-session, the result is **staleness in a single surface**, not drift between two. The coordinator can still be wrong; but the "my two memory sources disagree and I silently picked the wrong one" class of bug — the one Sona hit — is structurally eliminated. <!-- orianna: ok -- prospective path cited by ADR -->

Failure mode that remains: a coordinator updates `live-threads.md` but then Duong does work on a thread outside any session (e.g., Duong merges a PR manually). The ledger is stale until the next session read-out. This is an acceptable residual — it's the same failure mode a Kanban board has when people work around the board, and there is no auto-reconciliation that can fix it without recreating the two-source problem. <!-- orianna: ok -- prospective path cited by ADR -->

## 7. Out of scope

Consciously not addressed in this ADR:

- **`.remember/` plugin architecture for subagents** — subagents are one-shot; their handoff surface (plugin-based or `last-session.md`) is a separate question. This ADR only retires `.remember/` for coordinators. <!-- orianna: ok -- directory reference with trailing slash -->
- **Cross-coordinator thread handoff** — if Sona wants to hand a thread to Evelynn, we currently use the inbox. This ADR does not change that, and does not add a cross-coordinator live-thread namespace.
- **Learnings retrieval improvements** — `agents/<name>/learnings/index.md` remains a flat list. Retrieval via Skarner is unchanged. <!-- orianna: ok -- prospective path cited by ADR -->
- **Decision-feedback** — `plans/proposed/personal/2026-04-21-coordinator-decision-feedback.md` is a separate ADR. It fits cleanly on top of `live-threads.md` (its `log/*.md` files are orthogonal to thread state). Serialization after T5 lands. <!-- orianna: ok -- prospective path cited by ADR -->
- **Orianna gate changes** — out of scope.
- **Journal entries for already-closed sessions** — kept as historical artifacts under `agents/<agent>/journal/`; no migration into the new snapshot shape. <!-- orianna: ok -- directory reference with trailing slash -->
- **Agent transcripts** — `agents/<agent>/transcripts/` retention and shape unchanged. Transcripts are the raw audit artifact; snapshots are the synthesised handoff. <!-- orianna: ok -- directory reference with trailing slash -->
- **Compact-boundary concurrency** — the existing coordinator lock (`plans/implemented/personal/2026-04-22-concurrent-coordinator-race-closeout.md`) continues to protect `live-threads.md` and `INDEX.md` under concurrent writes. No new lock required. <!-- orianna: ok -- prospective path cited by ADR -->
- **Sona's inbox post resolution path** — the inbox message that triggered this ADR stays archived; no reply thread needed.

## 8. Open questions for Duong

Numbered a/b/c per Duong's convention. If skipped, Duong concurs with the Pick.

1. **Scope of the ledger rename** — should we literally rename `open-threads.md` to `live-threads.md`? <!-- orianna: ok -- prospective path cited by ADR -->
   a: Yes, rename — the new semantic (in-session-writable ledger) deserves a new name; preserves git history via `git mv`.
   b: Keep the name `open-threads.md` — less churn across docs/prompts; semantic shift documented in `architecture/coordinator-memory.md`. <!-- orianna: ok -- prospective path cited by ADR -->
   c: Alias — keep both names as a symlink during migration, resolve after one stable week.
   **Pick: a** — renaming is cheap with `git mv`, and the behavioral change (in-session writable vs end-of-session authored) is load-bearing enough to deserve a distinct name. Sticking with `open-threads.md` invites "which behavior is this?" confusion. <!-- orianna: ok -- prospective path cited by ADR -->

2. **`.remember/` plugin fate for Sonnet subagents** — once coordinators stop using it, do we keep it available for subagents? <!-- orianna: ok -- directory reference with trailing slash -->
   a: Uninstall the plugin entirely; subagents use `agents/<agent>/memory/last-session.md` via `/end-subagent-session` Step 2 fallback (already present). <!-- orianna: ok -- prospective path cited by ADR -->
   b: Keep the plugin installed; subagents may opt in via `Skill: remember:remember`, but nothing requires them to.
   c: Retire the plugin aggressively — uninstall after T9 cleanup; subagents forced to the `last-session.md` fallback. <!-- orianna: ok -- prospective path cited by ADR -->
   **Pick: b** — the plugin is harmless when unused; forced uninstall risks breaking any subagent that silently relied on it; the "optional" path keeps migration surface small.

3. **Sessions snapshot shape — single file vs multi-section**
   a: Single file with `## TL;DR` / `## Timeline` / `## Threads touched` / `## Journal` / `## Delta-to-durable-memory` (§3.4).
   b: Two files — `sessions/<uuid>.md` (structured) + `sessions/<uuid>.journal.md` (first-person). <!-- orianna: ok -- prospective path cited by ADR -->
   c: Keep current three-file pattern (last-sessions shard + sessions shard + journal file).
   **Pick: a** — one file per session is the simplest shape; sections are cheap to parse and easy to diff; consolidates three artifacts into one without losing the first-person channel.

4. **Transcript archive path under the new skill** — the cleaned jsonl lives at `agents/<agent>/transcripts/<YYYY-MM-DD>-<uuid>.md` today. <!-- orianna: ok -- prospective path cited by ADR -->
   a: Unchanged — keep `transcripts/` as a top-level memory sibling. <!-- orianna: ok -- directory reference with trailing slash -->
   b: Move into `agents/<agent>/memory/sessions/<uuid>.transcript.md` alongside the snapshot — "same session, same directory." <!-- orianna: ok -- prospective path cited by ADR -->
   c: Archive transcripts under `memory/archive/transcripts/` after 30 days to reduce active listing noise. <!-- orianna: ok -- directory reference with trailing slash -->
   **Pick: a** — transcripts and snapshots serve different audiences (raw audit vs synthesised handoff); separate directories make that clearer. No structural reason to move them.

5. **Deprecation window for old close-session skills (T9)** — how long between T5 cutover and removal?
   a: One week — aggressive, low cost because the new skill is a superset.
   b: Two weeks — more conservative, accommodates any edge case that only surfaces at specific close patterns (compact-then-end, multi-day-idle boot).
   c: No window — delete in the same task as T5.
   **Pick: a** — one week is enough to surface ergonomic issues; the aliasing shim is cheap to maintain during that window. Two weeks invites accumulating other changes on top.

6. **Boot-time live-threads size enforcement** — §3.3 proposes a 10 KB hard ceiling with a close-time check.
   a: Soft warning only — coordinator sees a warning at close, no block.
   b: Hard block at close — cannot `/close-coordinator-session end` while `live-threads.md` > 10 KB; must resolve or archive threads first. <!-- orianna: ok -- prospective path cited by ADR -->
   c: No enforcement — document the target; trust the coordinator.
   **Pick: a** — warning at close surfaces drift without blocking a close. Hard block risks stranding a session at a bad moment (e.g., 2am Duong wants to go to bed). The cost of overshoot is small (boot reads a slightly larger file); the cost of a blocked close is high.

7. **Should `/pre-compact-save` continue to dispatch Lissandra, or run inline in the coordinator?**
   a: Keep Lissandra dispatch — she already owns the compact-boundary close protocol; parameterising `/close-coordinator-session compact` inside her prompt is a one-line change.
   b: Run inline in the coordinator session — `/close-coordinator-session compact` executes locally, no Lissandra. Faster, no subagent spawn.
   c: Both allowed — inline is default, Lissandra dispatch available as `/close-coordinator-session compact --via=lissandra` for cases where the coordinator is context-poor.
   **Pick: a** — Lissandra's existence was justified by the token cost of doing the close in the coordinator's own context; that rationale still holds. Changing the dispatch pattern is out of scope of this ADR; the new skill is just Lissandra's target payload.

## 9. Fact-check markers

All prospective paths introduced by this ADR are marked in §5 with the linter's expected suppressor form. Paths cited as already-existing (e.g., `agents/evelynn/CLAUDE.md`, `.claude/skills/end-session/SKILL.md`) are real on disk at author time (2026-04-23) and do not need markers.

## Test plan

Tests land with the implementing tasks. Each item below is an xfail-first contract the implementer commits before the implementation commit.

- [ ] **T1 xfail** — skill file `.claude/skills/close-coordinator-session/SKILL.md` exists and declares modes `end`, `compact`, `handoff` in its frontmatter. Grep-based. estimate_minutes: 5, kind: test <!-- orianna: ok -- prospective path cited by ADR -->
- [ ] **T3 xfail** — `agents/evelynn/memory/live-threads.md` and `agents/sona/memory/live-threads.md` exist and their first line matches the schema `^# <Coordinator> — Live Threads$`. Grep-based. estimate_minutes: 5, kind: test <!-- orianna: ok -- prospective path cited by ADR -->
- [ ] **T4 xfail** — `.claude/agents/evelynn.md` initialPrompt does NOT reference `.remember/` and DOES reference `live-threads.md`. Grep-based. Symmetric test for `.claude/agents/sona.md`. estimate_minutes: 10, kind: test <!-- orianna: ok -- directory reference with trailing slash -->
- [ ] **T5 xfail** — `agents/evelynn/CLAUDE.md` references `/close-coordinator-session` and does NOT reference `/end-session` outside a deprecation banner. Symmetric for sona. estimate_minutes: 5, kind: test
- [ ] **T7 xfail** — SessionStart hook for Sona skips `remember:remember`. Integration test using `.claude/settings.json` inspection. estimate_minutes: 10, kind: test
- [ ] **T8 xfail** — `scripts/memory-consolidate.sh` exits 0 for both `evelynn` and `sona` against a fixture with the new `sessions/` layout. Shim-based integration test using `STRAWBERRY_MEMORY_ROOT`. estimate_minutes: 15, kind: test <!-- orianna: ok -- directory reference with trailing slash -->
- [ ] **T9 xfail** — `.claude/skills/end-session/SKILL.md` and `.claude/skills/pre-compact-save/SKILL.md` no longer exist on disk after T9 lands. Filesystem-existence check. estimate_minutes: 5, kind: test
- [ ] **regression S1** — Sona's 2026-04-23 bug: simulate a state change (edit `sessions/<uuid>.md` to claim a thread resolved), verify `live-threads.md` reflects the change at the next boot only if the coordinator updated it in-session. Absence of `.remember/now.md` read is verified by absence of `.remember/` access in boot-chain trace. estimate_minutes: 20, kind: regression <!-- orianna: ok -- directory reference with trailing slash -->
- [ ] **regression S2** — boot with `live-threads.md` mtime older than last session snapshot: confirm coordinator boots cleanly, no reconciliation prompt, no extra surface read. estimate_minutes: 10, kind: regression <!-- orianna: ok -- prospective path cited by ADR -->

## Tasks

Tasks are grouped by phase. Each task lands as one commit. Implementer to be decided by Evelynn post-approval (owner: swain here is authorship only).

- [ ] T1 — draft `.claude/skills/close-coordinator-session/SKILL.md`  estimate_minutes: 60  kind: design <!-- orianna: ok -- prospective path, created by this plan -->
- [ ] T2 — migrate `agents/<coordinator>/memory/sessions/` → `sessions/legacy/`  estimate_minutes: 35  kind: refactor <!-- orianna: ok -- directory reference with trailing slash -->
- [ ] T3 — seed `agents/<coordinator>/memory/live-threads.md` from `open-threads.md`  estimate_minutes: 25  kind: refactor <!-- orianna: ok -- prospective path, created by this plan -->
- [ ] T4 — update CLAUDE.md + agent-defs boot prompts  estimate_minutes: 30  kind: refactor
- [ ] T5 — flip coordinators to `/close-coordinator-session end`  estimate_minutes: 25  kind: refactor
- [ ] T6 — retire `open-threads.md` (git mv to archive)  estimate_minutes: 20  kind: refactor <!-- orianna: ok -- prospective path cited by ADR -->
- [ ] T7 — SessionStart hook guard for `remember:remember` on coordinator sessions  estimate_minutes: 30  kind: hook
- [ ] T8 — rewrite `scripts/memory-consolidate.sh` for new `sessions/` layout  estimate_minutes: 50  kind: refactor <!-- orianna: ok -- directory reference with trailing slash -->
- [ ] T9 — remove old close-session skill files  estimate_minutes: 25  kind: cleanup
- [ ] T10 — clean coordinator-referencing `.remember/` files  estimate_minutes: 20  kind: cleanup <!-- orianna: ok -- directory reference with trailing slash -->
- [ ] T11 — fold journal into snapshot shape (doc-only)  estimate_minutes: 20  kind: doc
- [ ] T12 — rewrite `architecture/coordinator-memory.md`  estimate_minutes: 45  kind: doc
- [ ] T13 — write migration learning `agents/swain/learnings/2026-04-23-memory-surface-collapse.md`  estimate_minutes: 15  kind: doc <!-- orianna: ok -- prospective path, created by this plan -->

Total estimate: 400 min (6h 40m) across 13 tasks, distributed over 3 phases.

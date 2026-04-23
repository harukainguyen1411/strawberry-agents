---
status: in-progress
concern: personal
owner: swain
created: 2026-04-23
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

Authored by Xayah (complex-track). Test author: **Rakan**. Tests land with the implementing tasks using xfail-first (Rule 12): every test task below commits **before** the implementation task it pairs with, on the same branch. All tests are behavioral / integration checks against the filesystem, agent-def frontmatter, or the skill's dispatch contract — no mocked coordinator LLM required.

Categories, ID conventions:

- **INV-N** — invariant tests (one per structural rule)
- **MIG-N** — migration / cutover tests (Phase 2, T5 and surrounding)
- **DEP-N** — deprecation-window tests (Phase 3, T9 gap behavior)
- **INT-N** — cross-agent integration tests
- **REG-N** — drift-bug regression tests (Sona's 2026-04-23 bug)

Test-fixture discipline: all tests must drive the new skill via `STRAWBERRY_MEMORY_ROOT` pointed at a tempdir fixture — no test may mutate the live `agents/evelynn/` or `agents/sona/` trees. Pre-commit hook will reject any test that writes outside the fixture.

### 1. Invariants (INV-1 … INV-8)

- [ ] **T-INV-1 xfail — live-threads.md is the sole live-state surface post-T5.** Anchor: `agents/<coordinator>/memory/`. Shape: behavioral (fs-walk). After T5 lands on a fresh fixture, assert: exactly one `live-threads.md` exists per coordinator; zero `open-threads.md` files exist anywhere under `agents/evelynn/memory/` or `agents/sona/memory/` (including archive root — archive lives at `agents/<coordinator>/memory/archive/open-threads-<date>.md`, which the test explicitly tolerates). xfail-first: yes. Pairs with: **T6**. Committed before T6 per Rule 12. estimate_minutes: 20, kind: test
- [ ] **T-INV-2 xfail — unified session snapshot is singular per session.** Anchor: `agents/<coordinator>/memory/sessions/<uuid>.md`. Shape: behavioral. Drive `/close-coordinator-session end` against fixture; assert exactly one `sessions/<uuid>.md` produced with the five required sections (`## TL;DR`, `## Timeline`, `## Threads touched`, `## Journal`, `## Delta-to-durable-memory`) present as level-2 headings. Assert zero writes to `agents/<coordinator>/journal/cli-*.md` and zero writes to `agents/<coordinator>/memory/last-sessions/` during the close. xfail-first: yes. Pairs with: **T1**. Committed before T1. estimate_minutes: 25, kind: test
- [ ] **T-INV-3 xfail — mode=end artifact-set matches legacy `/end-session`.** Anchor: `.claude/skills/close-coordinator-session/SKILL.md`. Shape: integration (golden-artifact diff). Capture the artifact set produced by the current `/end-session` skill against a synthetic closed session (transcript archive path, handoff-shard presence, commit trailer shape, push-target). Drive `/close-coordinator-session end` against the same fixture; assert the artifact set is a **superset** of the legacy set in path + structural shape (permitting the new snapshot file; forbidding any dropped artifact). xfail-first: yes. Pairs with: **T1, T5**. Committed before T1. estimate_minutes: 30, kind: test
- [ ] **T-INV-4 xfail — mode=compact dispatches via Lissandra.** Anchor: `.claude/skills/close-coordinator-session/SKILL.md` + `.claude/agents/lissandra.md`. Shape: integration. Invoke `/close-coordinator-session compact` in dry-run-with-trace mode; assert the skill's dispatch trace contains a spawn of the Lissandra subagent (by agent-def name match) and that the PreCompact sentinel file is written. Assert the coordinator session remains "open" — no transcript archive, no close-flag set. xfail-first: yes. Pairs with: **T1**. Committed before T1. estimate_minutes: 20, kind: test
- [ ] **T-INV-5 xfail — mode=handoff writes snapshot without closing.** Anchor: `.claude/skills/close-coordinator-session/SKILL.md`. Shape: integration. Invoke `/close-coordinator-session handoff`; assert: snapshot written + INDEX regenerated + commit + push, but no transcript archive and no close-flag. xfail-first: yes. Pairs with: **T1**. Committed before T1. estimate_minutes: 15, kind: test
- [ ] **T-INV-6 xfail — coordinator path does NOT write `.remember/`.** Anchor: close-coordinator-session skill + `.remember/`. Shape: behavioral. Drive all three modes; assert zero writes under `.remember/` for the coordinator session (inspect via fs-watch inotify-equivalent or a post-run tree-hash comparison of `.remember/` pre- and post-invocation). This is the structural guarantee that kills Sona's drift class. xfail-first: yes. Pairs with: **T1, T7**. Committed before T7. estimate_minutes: 20, kind: test
- [ ] **T-INV-7 xfail — subagent `.remember/` path still works.** Anchor: `.claude/skills/end-subagent-session/SKILL.md` + `remember:remember` plugin. Shape: integration. Spawn a Sonnet subagent fixture (Vi) through `/end-subagent-session`; assert the plugin's `.remember/remember.md` write path executes unchanged; assert `remember:remember` SessionStart hook fires (no coordinator-guard false-positive). xfail-first: yes. Pairs with: **T7**. Committed before T7. estimate_minutes: 20, kind: test
- [ ] **T-INV-8 xfail — transcripts path unchanged.** Anchor: `agents/<agent>/transcripts/`. Shape: grep + fs. Assert cleaned transcripts from `/close-coordinator-session end` land at `agents/<agent>/transcripts/<YYYY-MM-DD>-<uuid>.md` — same format and directory as legacy `/end-session`. Assert no new path `agents/<agent>/memory/sessions/<uuid>.transcript.md` appears (question 4 pick-a guard). xfail-first: yes. Pairs with: **T1**. Committed before T1. estimate_minutes: 10, kind: test

### 2. Migration / cutover (MIG-1 … MIG-4)

- [ ] **T-MIG-1 xfail — T2 idempotence on `sessions/` → `sessions/legacy/`.** Anchor: T2 migration script (to be authored by Aphelios/Rakan). Shape: integration. Run migration twice against the same fixture; assert tree-hash of `agents/<coordinator>/memory/` is bit-identical after run 2 vs run 1; assert no duplicate `sessions/legacy/legacy/` nesting appears on re-run. xfail-first: yes. Pairs with: **T2**. Committed before T2. estimate_minutes: 20, kind: test
- [ ] **T-MIG-2 xfail — dry-run mode prints diff without writes.** Anchor: T2 + T3 + T5 cutover scripts. Shape: behavioral. Invoke each migration script with `--dry-run`; assert exit 0, stdout contains the proposed diff, and tree-hash of the fixture is byte-identical pre- and post-invocation. xfail-first: yes. Pairs with: **T2, T3, T5**. Committed before T2. estimate_minutes: 25, kind: test
- [ ] **T-MIG-3 xfail — T5 cutover is rollbackable.** Anchor: T5 cutover script + `agents/<coordinator>/CLAUDE.md`. Shape: integration. Pre-T5 the script tags the tree (e.g., `git tag strawberry/pre-T5-cutover-<ts>` or writes a snapshot archive path to stdout). Execute T5; then execute the documented rollback path; assert `diff -r` of the fixture vs the pre-T5 tag shows zero differences. Assert the rollback command is documented in the ADR §5 migration-invariants section. xfail-first: yes. Pairs with: **T5**. Committed before T5. estimate_minutes: 30, kind: test
- [ ] **T-MIG-4 xfail — T3 seed preserves git history via `git mv`.** Anchor: T3 rename script. Shape: integration. Run T3 against a fixture with a real `open-threads.md` containing N commits of history; assert `git log --follow agents/<coordinator>/memory/live-threads.md` returns ≥ N commits (history preserved through the rename). Assert no `cp`-then-delete pattern was used (would break `--follow`). xfail-first: yes. Pairs with: **T3**. Committed before T3. estimate_minutes: 15, kind: test

### 3. Deprecation window (DEP-1 … DEP-3)

- [ ] **T-DEP-1 xfail — soft warning during window on retired-path write.** Anchor: `.claude/skills/end-session/SKILL.md` alias + `.claude/skills/pre-compact-save/SKILL.md` alias + any stray write to `.remember/now.md` by coordinator-path code. Shape: behavioral. Within the T5→T9 window (simulate via env `STRAWBERRY_DEPRECATION_PHASE=soft`), invoke the old skill; assert exit 0, assert stderr contains the literal string `DEPRECATED` and a pointer to `/close-coordinator-session`. Assert the deprecated skill still successfully delegated to the new skill (artifact parity with INV-3). xfail-first: yes. Pairs with: **T5**. Committed before T5. estimate_minutes: 20, kind: test
- [ ] **T-DEP-2 xfail — hard fail post-T9 on retired-path invocation.** Anchor: `.claude/skills/end-session/` + `.claude/skills/pre-compact-save/` (absent). Shape: fs + behavioral. After T9, assert the skill files do not exist (filesystem check); simulate a caller attempting to invoke `/end-session` via `.claude/settings.json` lookup; assert the lookup fails with a non-zero exit and stderr contains `Unknown skill` or equivalent. xfail-first: yes. Pairs with: **T9**. Committed before T9. estimate_minutes: 15, kind: test
- [ ] **T-DEP-3 xfail — T10 cleanup removes coordinator-referencing `.remember/` files.** Anchor: `.remember/`. Shape: fs. After T10, assert `.remember/now.md`, `.remember/today-*.md`, `.remember/recent.md`, `.remember/archive.md` do not exist. Assert `.remember/remember.md` schema file DOES exist (plugin still works for subagents per Pick 2b). xfail-first: yes. Pairs with: **T10**. Committed before T10. estimate_minutes: 10, kind: test

### 4. Cross-agent integration (INT-1 … INT-3)

- [ ] **T-INT-1 xfail — Evelynn↔Sona live-threads isolation.** Anchor: `agents/evelynn/memory/live-threads.md` + `agents/sona/memory/live-threads.md`. Shape: integration. Simulate Evelynn session writing thread-state update to her `live-threads.md`; assert Sona's `live-threads.md` is byte-unchanged. Reverse direction. Assert no cross-coordinator read path is instantiated (grep agent-def initialPrompts — Evelynn's prompt must not reference Sona's live-threads, and vice versa). xfail-first: yes. Pairs with: **T4**. Committed before T4. estimate_minutes: 15, kind: test
- [ ] **T-INT-2 xfail — concurrent close produces independent snapshots.** Anchor: `agents/<coordinator>/memory/sessions/<uuid>.md` + coordinator lock. Shape: integration (parallel invocation). Launch two `/close-coordinator-session end` invocations in parallel — one under evelynn concern, one under sona concern, different `<uuid>`s. Assert both produce their own `sessions/<uuid>.md` file under the correct coordinator root; assert no contention-induced corruption (JSON-parseable frontmatter, markdown section structure intact); assert the concurrent-coordinator lock from `plans/implemented/personal/2026-04-22-concurrent-coordinator-race-closeout.md` serialized any shared-file mutations (INDEX.md byte-level sanity check). xfail-first: yes. Pairs with: **T1, T5**. Committed before T5. estimate_minutes: 30, kind: test
- [ ] **T-INT-3 xfail — boot chain reads live-threads.md at position 7, not `.remember/now.md`.** Anchor: `.claude/agents/evelynn.md` + `.claude/agents/sona.md` + `agents/evelynn/CLAUDE.md` + `agents/sona/CLAUDE.md`. Shape: static analysis. Parse the initialPrompt chain for both agent-defs; assert position 7 matches `live-threads.md`; assert no line in the chain reads any `.remember/` file; assert position 8 is `sessions/INDEX.md` and position 9 is `inbox/`. xfail-first: yes. Pairs with: **T4**. Committed before T4. estimate_minutes: 15, kind: test

### 5. Drift regression (REG-1 … REG-2)

- [ ] **T-REG-1 xfail — Sona 2026-04-23 drift-bug cannot recur.** Anchor: coordinator boot chain + `.remember/now.md` + `live-threads.md`. Shape: behavioral regression. Fixture: pre-populate `.remember/now.md` with three thread-state events (mirror of Sona's 2026-04-23 symptom — "T7 Firestore wipe executed", "dashboard scope contracted", "PR #32 awaiting full chain"). Pre-populate `live-threads.md` with a stale ledger that omits those events. Boot Sona under the new regime; assert: (i) `.remember/now.md` is never read during boot (tracing-confirmed), (ii) coordinator briefs from `live-threads.md` only, (iii) no reconciliation prompt appears. The test's assertion is **not** that the ledger becomes fresh — it is that drift between two sources is structurally impossible because only one source exists on the coordinator path. xfail-first: yes. Pairs with: **T4, T7**. Committed before T4. estimate_minutes: 30, kind: regression
- [ ] **T-REG-2 xfail — `/close-coordinator-session end` cannot produce divergent `.remember/now.md` vs `live-threads.md`.** Anchor: close-coordinator-session skill. Shape: behavioral regression. Run a simulated session where the coordinator edits `live-threads.md` three times in-session (state transitions on a thread); invoke `/close-coordinator-session end`; assert post-close: `.remember/now.md` either does not exist or is bit-identical to its pre-session state (no coordinator-path write reached it). Assert `live-threads.md` reflects the final in-session state and is snapshotted into `sessions/<uuid>.md` `## Threads touched`. xfail-first: yes. Pairs with: **T1, T5, T7**. Committed before T5. estimate_minutes: 25, kind: regression

### Coverage matrix (test → implementation task)

| Test ID | Pair task(s) | Category | xfail-first |
|---|---|---|---|
| T-INV-1 | T6 | Invariant | yes |
| T-INV-2 | T1 | Invariant | yes |
| T-INV-3 | T1, T5 | Invariant | yes |
| T-INV-4 | T1 | Invariant | yes |
| T-INV-5 | T1 | Invariant | yes |
| T-INV-6 | T1, T7 | Invariant | yes |
| T-INV-7 | T7 | Invariant | yes |
| T-INV-8 | T1 | Invariant | yes |
| T-MIG-1 | T2 | Migration | yes |
| T-MIG-2 | T2, T3, T5 | Migration | yes |
| T-MIG-3 | T5 | Migration | yes |
| T-MIG-4 | T3 | Migration | yes |
| T-DEP-1 | T5 | Deprecation | yes |
| T-DEP-2 | T9 | Deprecation | yes |
| T-DEP-3 | T10 | Deprecation | yes |
| T-INT-1 | T4 | Integration | yes |
| T-INT-2 | T1, T5 | Integration | yes |
| T-INT-3 | T4 | Integration | yes |
| T-REG-1 | T4, T7 | Regression | yes |
| T-REG-2 | T1, T5, T7 | Regression | yes |

Total: 20 tests (8 INV, 4 MIG, 3 DEP, 3 INT, 2 REG). Aggregate estimate: 390 min (~6h 30m) — Rakan authors over ~1 day distributed across the implementation window, front-loaded so each xfail lands before its paired implementation commit.

### Gaps observed in the ADR (Xayah notes)

The ADR is comfortably testable but three seams need Aphelios/Swain input to make the above contracts bite cleanly:

1. **No explicit dry-run / rollback contract on migration scripts (T2, T3, T5).** §5.1 mentions rollback for T5 informally ("revert the T5 commit"), but T2's `sessions/` → `sessions/legacy/` move and T3's `git mv` rename have no `--dry-run` flag or explicit rollback documented. T-MIG-2 and T-MIG-3 assume these exist; if Aphelios breaks the tasks out without a `--dry-run` flag and a `strawberry/pre-T*-cutover-<ts>` tag contract, those tests become weaker (can still exit-status-check, but cannot asssert diff-without-write semantics). **Recommend: Swain adds a one-line migration-script contract to §5.1 — "all T2/T3/T5 scripts MUST accept `--dry-run` and MUST `git tag` their pre-mutation state."**

2. **No boot-chain trace mechanism documented.** T-INV-6, T-INT-3, and T-REG-1 all need to assert "no `.remember/` read during coordinator boot." Today there is no `STRAWBERRY_BOOTCHAIN_TRACE=1`-style instrument that the test harness can enable. As written, the tests fall back to `strace`/`fs_usage` or to inspecting the agent-def initialPrompt file statically — the latter is reliable but only verifies the prompt, not runtime behavior. **Recommend: Aphelios adds a small T4.5 task (or folds into T4) to emit a boot-chain trace when an env var is set. Absent that, INV-6 / INT-3 / REG-1 degrade to static-analysis checks only — acceptable but weaker.**

3. **Deprecation phase env var is un-specified.** T-DEP-1 references `STRAWBERRY_DEPRECATION_PHASE=soft` but the ADR does not define how the deprecation alias distinguishes window-mode from post-T9 hard-fail. The aliases in §3.6 print a banner unconditionally. **Recommend: Swain clarifies in §5.3 / T9 whether the hard-fail mode is simply "file deleted → unknown-skill error" (cleanest) or whether there is an interim "still-exists-but-errors" phase. The current tests assume the former; if the latter is chosen, add a T-DEP-2b test for the error shape.**

None of the gaps are blockers. They reduce test strength from behavioral to static-analysis for three specific contracts, which Evelynn should note when evaluating the implementation PRs.

### Author handoff

Rakan: author these 20 tests in xfail-first order against the fixture root `tests/fixtures/memory-flow/` (create if absent). Pair each test commit with its implementation task per the matrix above. Pre-push hook will verify xfail-first ordering via commit-log inspection on branch before merge to main.

## Tasks

Tasks are grouped by phase. Each parent task (T1–T13) lands as one logical bundle; substeps (`T<N>.<k>`) each land as a single commit ≤ 15 min of builder time. Kayn's xfail suite (T-INV-*, T-MIG-*, T-DEP-*, T-INT-*, T-REG-*, authored above) pairs in per the coverage matrix: Rakan lands each xfail commit on the same branch **before** its paired implementation substep per Rule 12.

Conventions (Aphelios breakdown, 2026-04-23):
- Every substep declares `estimate_minutes` (≤ 15), `tier` (sonnet / opus), `STAGED_SCOPE` (single path or narrow glob), and `DoD`.
- Commit prefix is `chore:` for every substep (no `apps/**` diff).
- Dependency notation: `blockedBy: T<N>.<k>`. Phase gates block cross-phase substeps.
- **Migration invariant (§5.1):** no substep modifies both `agents/evelynn/**` and `agents/sona/**` in the same commit. When a parent task needs to touch both, substeps split evelynn-side / sona-side.
- **Xfail-first invariant:** Kayn's T-* tests are committed by Rakan on the same branch before the paired implementation substep. Substep lines below cite the paired test IDs; Rakan owns the test commits, builders own the implementation commits.

### Phase 1 — prepare the new surfaces alongside the old

#### T1 — Draft `.claude/skills/close-coordinator-session/SKILL.md` (60 min)

Paired xfail tests (authored by Rakan before this task starts): **T-INV-2, T-INV-3, T-INV-4, T-INV-5, T-INV-6, T-INV-8, T-INT-2, T-REG-2**.

- [ ] **T1.1** — Create skill directory + SKILL.md with frontmatter (`name: close-coordinator-session`, `description`, `allowed-tools`, `disable-model-invocation: false`). estimate_minutes: 8. tier: sonnet. STAGED_SCOPE: `.claude/skills/close-coordinator-session/SKILL.md`. DoD: file exists; `yq` parses frontmatter. blocks: T1.2.
- [ ] **T1.2** — Write `## Modes` section enumerating `end` / `compact` / `handoff` dispatch semantics (§3.6) — pairs with T-INV-3/4/5 `mode=*` assertions. estimate_minutes: 12. tier: opus. STAGED_SCOPE: same. DoD: all three mode names present verbatim in a single bulleted table. blockedBy: T1.1. blocks: T1.3.
- [ ] **T1.3** — Write `## Steps` shared core (snapshot assembly into `agents/<coordinator>/memory/sessions/<uuid>.md` with five required sections, INDEX regen, commit, push) — parameterised once, not per-mode. Pairs with T-INV-2 snapshot-shape assertion. estimate_minutes: 14. tier: opus. STAGED_SCOPE: same. DoD: Steps reference new snapshot path (never `last-sessions/`); five section headings enumerated. blockedBy: T1.2. blocks: T1.4.
- [ ] **T1.4** — Write mode-tail branches: `end` archives transcript to `agents/<agent>/transcripts/` (T-INV-8 guard — no new transcript path); `compact` writes PreCompact sentinel + dispatches Lissandra per OQ7-a (T-INV-4); `handoff` plain return (T-INV-5). estimate_minutes: 14. tier: opus. STAGED_SCOPE: same. DoD: each mode has ≤ 5 lines of mode-specific behavior; no duplicated step list. blockedBy: T1.3. blocks: T1.5.
- [ ] **T1.5** — Add safety notes: coordinator lock held by caller; `remember:remember` NOT invoked; reference §3.2 Rule S3 for `.remember/` non-read (pairs T-INV-6, T-REG-2). estimate_minutes: 7. tier: sonnet. STAGED_SCOPE: same. DoD: grep "coordinator lock" and "remember:remember disabled" in skill body returns ≥ 1 each. blockedBy: T1.4. blocks: T1.6.
- [ ] **T1.6** — Add `--dry-run` flag support per Xayah gap 1 — dispatch through each mode without writes when env `CLOSE_SESSION_DRY_RUN=1`. Pairs T-MIG-2. estimate_minutes: 5. tier: sonnet. STAGED_SCOPE: same. DoD: dry-run flag documented in SKILL.md; behavioural contract stated. blockedBy: T1.5. blocks: T2.

#### T2 — Migrate existing `sessions/` → `sessions/legacy/` (35 min)

Paired xfail tests: **T-MIG-1** (idempotence), **T-MIG-2** (dry-run).

Risk/rollback: reversible via inverse `git mv` until T5 cutover; no new readers of `sessions/legacy/` except T8's one-shot fold.

- [ ] **T2.1** — Author `scripts/migrate-sessions-to-legacy.sh` accepting `--dry-run` and emitting `git tag strawberry/pre-T2-sessions-migrate-<ts>` before any writes. Pairs T-MIG-2. estimate_minutes: 15. tier: sonnet. STAGED_SCOPE: `scripts/migrate-sessions-to-legacy.sh`. DoD: `shellcheck` clean; `--dry-run` mode confirmed byte-identical tree-hash pre/post. blocks: T2.2.
- [ ] **T2.2** — Run the migration for Evelynn: `git mv agents/evelynn/memory/sessions/*.md agents/evelynn/memory/sessions/legacy/`. Preserve `archive/` and `INDEX.md` at the parent `sessions/` level untouched. estimate_minutes: 6. tier: sonnet. STAGED_SCOPE: `agents/evelynn/memory/sessions/`. DoD: all `sessions/<uuid>.md` relocated under `legacy/`; `archive/` & `INDEX.md` unmoved. blockedBy: T2.1. blocks: T2.3.
- [ ] **T2.3** — Same for Sona (separate commit per migration invariant). estimate_minutes: 5. tier: sonnet. STAGED_SCOPE: `agents/sona/memory/sessions/`. DoD: sona side relocated; T-MIG-1 idempotence test passes. blockedBy: T2.2. blocks: T2.4.
- [ ] **T2.4** — Add `agents/evelynn/memory/sessions/legacy/README.md` — "Legacy session shards. Read once by memory-consolidate.sh T8 migration fold (MIGRATION_FOLD=1). Do not write." estimate_minutes: 4. tier: sonnet. STAGED_SCOPE: `agents/evelynn/memory/sessions/legacy/README.md`. DoD: file present with stated one-liner. blockedBy: T2.3. blocks: T2.5.
- [ ] **T2.5** — Same stub for Sona. estimate_minutes: 5. tier: sonnet. STAGED_SCOPE: `agents/sona/memory/sessions/legacy/README.md`. DoD: file present. blockedBy: T2.4. blocks: T3.

#### T3 — Seed `live-threads.md` from current `open-threads.md` (25 min)

Paired xfail tests: **T-MIG-4** (git-history preservation via `git mv`), **T-MIG-2** (dry-run).

Risk/rollback: reversible via inverse `git mv` until T6. During Phase 1 the old filename `open-threads.md` is already migrated to `live-threads.md` (one-shot rename) but boot still reads `open-threads.md` path — so T4 is the gate that actually switches readers.

- [ ] **T3.1** — Author `scripts/seed-live-threads.sh` — accepts `--dry-run`, emits pre-mutation `git tag`, performs `git mv` (never cp-then-delete — T-MIG-4 guard), rewrites header, normalises entries to §3.3 schema. estimate_minutes: 15. tier: sonnet. STAGED_SCOPE: `scripts/seed-live-threads.sh`. DoD: script passes T-MIG-4 fixture (`git log --follow` returns ≥ N commits). blocks: T3.2.
- [ ] **T3.2** — Run for Evelynn: `git mv agents/evelynn/memory/open-threads.md agents/evelynn/memory/live-threads.md`; rewrite H1 to `# Evelynn — Live Threads`; normalise each `## <thread>` block to Status / Last-updated / Snapshot-pointers / Next / Owner schema. estimate_minutes: 8. tier: opus. STAGED_SCOPE: `agents/evelynn/memory/live-threads.md`. DoD: first line matches `^# Evelynn — Live Threads$`; every thread block has all five fields; `wc -c` < 10240. blockedBy: T3.1. blocks: T3.3.
- [ ] **T3.3** — Same for Sona (separate commit). estimate_minutes: 2. tier: sonnet. STAGED_SCOPE: `agents/sona/memory/live-threads.md`. DoD: first line matches `^# Sona — Live Threads$`; all fields present; `wc -c` < 10240. If over, add `## Archived during migration` footer with threads > 14 days. blockedBy: T3.2. blocks: T4.

#### T4 — Update CLAUDE.md + agent-defs boot prompts (30 min)

Paired xfail tests: **T-INT-1** (evelynn↔sona live-threads isolation), **T-INT-3** (boot-chain position 7/8/9 static-analysis), **T-REG-1** (Sona drift-bug regression).

- [ ] **T4.1** — Update `.claude/agents/evelynn.md` initialPrompt — replace `open-threads.md` with `live-threads.md` at position 7; remove any `.remember/*.md` read line. estimate_minutes: 8. tier: sonnet. STAGED_SCOPE: `.claude/agents/evelynn.md`. DoD: T-INT-3 evelynn half passes; grep `.remember/` in file returns zero. blocks: T4.2.
- [ ] **T4.2** — Same for `.claude/agents/sona.md` (separate commit). estimate_minutes: 6. tier: sonnet. STAGED_SCOPE: `.claude/agents/sona.md`. DoD: T-INT-3 fully passes. blockedBy: T4.1. blocks: T4.3.
- [ ] **T4.3** — Update `agents/evelynn/CLAUDE.md` memory-surface description and boot-reading-order section (reference `live-threads.md` at position 7; drop `.remember/`). estimate_minutes: 5. tier: sonnet. STAGED_SCOPE: `agents/evelynn/CLAUDE.md`. DoD: grep `live-threads.md` ≥ 1; grep `.remember/now.md` = 0. blockedBy: T4.2. blocks: T4.4.
- [ ] **T4.4** — Same for `agents/sona/CLAUDE.md`. estimate_minutes: 5. tier: sonnet. STAGED_SCOPE: `agents/sona/CLAUDE.md`. DoD: same assertions, sona side. blockedBy: T4.3. blocks: T4.5.
- [ ] **T4.5** — Add boot-chain trace hook per Xayah gap 2 — when env `STRAWBERRY_BOOTCHAIN_TRACE=1`, emit the list of files read in order to stderr. Touch only the minimal place where the chain is assembled (likely in `agents/<coordinator>/CLAUDE.md` or a helper script). Enables T-INV-6, T-INT-3, T-REG-1 to verify runtime behavior rather than static-only. estimate_minutes: 6. tier: opus. STAGED_SCOPE: the single helper file chosen during implementation (one commit). DoD: trace env var documented; test harness can assert `.remember/` absent from stderr trace. blockedBy: T4.4. blocks: phase-gate-1.

**Phase-1 gate** — T1–T4 landed; both coordinators still invoke `/end-session` at close (unchanged behavior); boot now reads new `live-threads.md` but closing writes have not flipped yet.

### Phase 2 — cutover

Phase 2 is the load-bearing flip. After T5 every new session closes via the new skill. Rollback path documented per substep.

#### T5 — Flip coordinators to `/close-coordinator-session end` (25 min)

Paired xfail tests: **T-INV-3** (artifact-superset), **T-MIG-3** (rollback), **T-DEP-1** (soft-warn alias), **T-INT-2** (concurrent close), **T-REG-2** (no divergent `.remember/`).

Risk/rollback: revert the specific substep commit; CLAUDE.md line reverts to invoking `/end-session`; old skills (still present until T9 as thin aliases) resume ownership. `live-threads.md` schema is identical pre/post so revert lands cleanly. Before running T5.2/T5.3, emit `git tag strawberry/pre-T5-cutover-<ts>` per T-MIG-3 contract.

- [ ] **T5.1** — Emit pre-T5 rollback tag + document rollback command in `agents/evelynn/memory/sessions/INDEX.md` header note. Pairs T-MIG-3. estimate_minutes: 5. tier: sonnet. STAGED_SCOPE: `agents/evelynn/memory/sessions/INDEX.md`. DoD: `git tag --list strawberry/pre-T5-cutover-*` returns ≥ 1; rollback command documented. blocks: T5.2.
- [ ] **T5.2** — Update `agents/evelynn/CLAUDE.md` — replace `/end-session` invocation with `/close-coordinator-session end`; add deprecation-banner line `<!-- deprecated-alias -->` pointing at `/end-session` for one release cycle. estimate_minutes: 6. tier: sonnet. STAGED_SCOPE: `agents/evelynn/CLAUDE.md`. DoD: grep `/close-coordinator-session` ≥ 1; bare `/end-session` only on a `<!-- deprecated-alias -->` line. blockedBy: T5.1. blocks: T5.3.
- [ ] **T5.3** — Same for `agents/sona/CLAUDE.md` (separate commit). estimate_minutes: 4. tier: sonnet. STAGED_SCOPE: `agents/sona/CLAUDE.md`. DoD: same as T5.2 for sona. blockedBy: T5.2. blocks: T5.4.
- [ ] **T5.4** — Convert `.claude/skills/end-session/SKILL.md` into thin alias — prints "DEPRECATED — use /close-coordinator-session end" to stderr (T-DEP-1 assertion) then invokes new skill with `mode=end`. Preserve original file as the alias wrapper so T-INV-3 artifact-parity still passes via delegation. estimate_minutes: 5. tier: sonnet. STAGED_SCOPE: `.claude/skills/end-session/SKILL.md`. DoD: file ≤ 30 lines; stderr contains literal `DEPRECATED`. blockedBy: T5.3. blocks: T5.5.
- [ ] **T5.5** — Convert `.claude/skills/pre-compact-save/SKILL.md` into thin alias dispatching `mode=compact`. estimate_minutes: 5. tier: sonnet. STAGED_SCOPE: `.claude/skills/pre-compact-save/SKILL.md`. DoD: stderr `DEPRECATED` banner; invocation path preserved; T-DEP-1 passes. blockedBy: T5.4. blocks: T6.

#### T6 — Retire `open-threads.md` via archival `git mv` (20 min)

Paired xfail test: **T-INV-1** (no `open-threads.md` anywhere except archive).

Risk/rollback: if Phase 2 exposes a boot-chain gap, revert T6.1/T6.2 to restore the old filename next to the new one. Note: after T3 the file `open-threads.md` no longer exists at the canonical path — T6 handles residual references (doc updates) and any rewrite of the archive path.

- [ ] **T6.1** — Evelynn residual check: `git ls-files agents/evelynn/memory/open-threads.md`; if present, `git mv` to `agents/evelynn/memory/archive/open-threads-2026-04-23.md`. If absent, skip to T6.2 (no commit). estimate_minutes: 5. tier: sonnet. STAGED_SCOPE: `agents/evelynn/memory/`. DoD: `open-threads.md` absent under `memory/` root; archive copy exists (either from T3.2 `git mv` or this one). blocks: T6.2.
- [ ] **T6.2** — Same for Sona. estimate_minutes: 4. tier: sonnet. STAGED_SCOPE: `agents/sona/memory/`. DoD: same, sona side. T-INV-1 passes for both coordinators. blockedBy: T6.1. blocks: T6.3.
- [ ] **T6.3** — Remove `open-threads.md` references from `architecture/coordinator-memory.md` §3 file-layout. Keep a §3 historical-note paragraph describing the rename. estimate_minutes: 8. tier: sonnet. STAGED_SCOPE: `architecture/coordinator-memory.md`. DoD: grep `open-threads.md` outside a historical-note section returns zero. blockedBy: T6.2. blocks: T6.4.
- [ ] **T6.4** — Add one-line learnings entry `agents/evelynn/learnings/2026-04-23-open-threads-rename.md` capturing the rename + semantic shift (in-session-writable). Update learnings index. estimate_minutes: 3. tier: sonnet. STAGED_SCOPE: `agents/evelynn/learnings/2026-04-23-open-threads-rename.md` + `agents/evelynn/learnings/index.md` (two-file commit ok — same agent). DoD: file exists; index appended. blockedBy: T6.3. blocks: T7.

#### T7 — SessionStart hook guard for `remember:remember` (30 min)

Paired xfail tests: **T-INV-6** (coordinator path does NOT write `.remember/`), **T-INV-7** (subagent path still works), **T-REG-1** (Sona drift-bug cannot recur).

Risk/rollback: the hook guard is a `.claude/settings.json` edit; revert reinstates the plugin fire. Because `live-threads.md` is already the live source post-T4, even a spurious plugin fire writes to `.remember/now.md` which is no longer read (Rule S3).

- [ ] **T7.1** — Inspect `.claude/settings.json` current SessionStart hooks; identify the block governing `remember:remember`. estimate_minutes: 5. tier: sonnet. STAGED_SCOPE: none (read-only inspection; capture findings in T7.2 commit body). DoD: current matcher logic documented for the T7.2 implementer. blocks: T7.2.
- [ ] **T7.2** — Add guard to `.claude/settings.json` — SessionStart matcher that skips the plugin when the session greeting matches `/^Hey (Sona|Evelynn)/i` or the session's `concern:` resolves to `personal` or `work`. Preserve the subagent path (T-INV-7). estimate_minutes: 12. tier: sonnet. STAGED_SCOPE: `.claude/settings.json`. DoD: `jq . .claude/settings.json` validates; T-INV-6 passes; T-INV-7 passes. blockedBy: T7.1. blocks: T7.3.
- [ ] **T7.3** — Document the guard in `agents/sona/CLAUDE.md` (matches existing Evelynn doc pattern) — one sentence under the memory-surfaces section. estimate_minutes: 5. tier: sonnet. STAGED_SCOPE: `agents/sona/CLAUDE.md`. DoD: grep `remember:remember` in sona CLAUDE.md ≥ 1. blockedBy: T7.2. blocks: T7.4.
- [ ] **T7.4** — Document symmetric note in `agents/evelynn/CLAUDE.md` (evelynn's existing bypass may be in a different phrase — confirm and normalise). estimate_minutes: 4. tier: sonnet. STAGED_SCOPE: `agents/evelynn/CLAUDE.md`. DoD: both CLAUDE.md files describe the guard in identical shape. blockedBy: T7.3. blocks: T7.5.
- [ ] **T7.5** — Smoke-test fixture: simulate `Hey Sona` boot against the guard; assert `.remember/now.md` is not written. Capture fixture under `scripts/fixtures/remember-plugin-guard/` if one is added. estimate_minutes: 4. tier: sonnet. STAGED_SCOPE: `scripts/fixtures/remember-plugin-guard/` (optional — may be verification-only with no commit). DoD: T-REG-1 regression passes end-to-end. blockedBy: T7.4. blocks: T8.

#### T8 — Rewrite `scripts/memory-consolidate.sh` for new layout (50 min)

No direct test pair in Kayn's matrix (all Kayn tests are skill/settings/layout-focused); builder should assert unit tests under `scripts/__tests__/` continue passing.

Risk/rollback: script supports `--dry-run`; every substep tests dry-run before committing the write path change. Advisory lock preserved throughout.

- [ ] **T8.1** — Audit current `scripts/memory-consolidate.sh` — enumerate every reference to `last-sessions/`, `sessions/`, `<coordinator>.md ## Sessions` list. Capture the enumerated list in the T8.2 commit body. estimate_minutes: 8. tier: sonnet. STAGED_SCOPE: none (audit only). DoD: reference list captured; refactor plan agreed. blocks: T8.2.
- [ ] **T8.2** — Update directory walker — primary path `agents/<coordinator>/memory/sessions/` (new); secondary one-shot path `agents/<coordinator>/memory/sessions/legacy/` guarded by env `MIGRATION_FOLD=1`. Drop all `last-sessions/` references. estimate_minutes: 15. tier: sonnet. STAGED_SCOPE: `scripts/memory-consolidate.sh`. DoD: `shellcheck` clean; existing unit tests still green (or updated). blockedBy: T8.1. blocks: T8.3.
- [ ] **T8.3** — Remove the session-fold block that wrote the `## Sessions` list into `<coordinator>.md` (§3.5 O3 resolution). Preserve `## Key context` / `## Working patterns` fold paths. estimate_minutes: 10. tier: sonnet. STAGED_SCOPE: `scripts/memory-consolidate.sh`. DoD: grep `## Sessions` write-path in the script returns zero. blockedBy: T8.2. blocks: T8.4.
- [ ] **T8.4** — Preserve & verify: advisory-lock (`_lib_coordinator_lock.sh`), 14d-OR-20-shard archive policy, `--index-only` flag. Add a one-shot migration-fold helper invoked via `MIGRATION_FOLD=1`. estimate_minutes: 10. tier: sonnet. STAGED_SCOPE: `scripts/memory-consolidate.sh`. DoD: `MIGRATION_FOLD=1` fixture-run processes `sessions/legacy/` exactly once; lock acquired/released. blockedBy: T8.3. blocks: T8.5.
- [ ] **T8.5** — Run migration fold against live coordinator memory once (with `--dry-run` first, then live) to consolidate legacy shards into `<coordinator>.md` before Phase 3 cleans up. estimate_minutes: 7. tier: sonnet. STAGED_SCOPE: `agents/evelynn/memory/evelynn.md` + `agents/sona/memory/sona.md` — two commits per migration invariant. DoD: legacy shards summarised into durable memory; follow-up Phase 3 cleanup removes `sessions/legacy/`. blockedBy: T8.4. blocks: phase-gate-2.

**Phase-2 gate** — cutover complete. Coordinators run `/close-coordinator-session`. Old skills are thin deprecation aliases. `live-threads.md` is the only live-state surface. **Observe for 7 days before Phase 3** per OQ5-a.

### Phase 3 — cleanup (one week after T5 lands stable, per OQ5-a)

Phase 3 substeps MUST NOT start until the calendar gate `T5 land-date + 7 days` passes AND no regressions are reported in `agents/evelynn/learnings/` or `agents/sona/learnings/` during the window.

#### T9 — Remove old close-session skill files (25 min)

Paired xfail test: **T-DEP-2** (hard-fail post-T9 on retired-path invocation).

- [ ] **T9.1** — Confirm the 7-day window has elapsed since T5 land-date; confirm no regression learnings filed. Document the check in T9.2 commit body. estimate_minutes: 3. tier: sonnet. STAGED_SCOPE: none (gate check). DoD: check result captured; phase-3 gate clears. blocks: T9.2.
- [ ] **T9.2** — `git rm -r .claude/skills/end-session/`. estimate_minutes: 4. tier: sonnet. STAGED_SCOPE: `.claude/skills/end-session/`. DoD: directory absent. blockedBy: T9.1. blocks: T9.3.
- [ ] **T9.3** — `git rm -r .claude/skills/pre-compact-save/`. estimate_minutes: 4. tier: sonnet. STAGED_SCOPE: `.claude/skills/pre-compact-save/`. DoD: directory absent; T-DEP-2 passes. blockedBy: T9.2. blocks: T9.4.
- [ ] **T9.4** — Grep for stale references to `/end-session`, `/pre-compact-save` across `.claude/agents/**`, `agents/**/CLAUDE.md`, `architecture/**`. Replace with `/close-coordinator-session <mode>`. Split commits by top-level directory to preserve migration invariants. estimate_minutes: 12. tier: sonnet. STAGED_SCOPE: one commit per top-level directory touched. DoD: grep returns zero hits outside documented historical sections. blockedBy: T9.3. blocks: T9.5.
- [ ] **T9.5** — Update `CLAUDE.md` Rule 8 text — `/close-coordinator-session` replaces `/end-session` + `/pre-compact-save` references. estimate_minutes: 2. tier: sonnet. STAGED_SCOPE: `CLAUDE.md`. DoD: rule mentions `/close-coordinator-session`; old names appear only in a parenthetical "(was: /end-session)". blockedBy: T9.4. blocks: T10.

#### T10 — Clean coordinator-referencing `.remember/` files (20 min)

Paired xfail test: **T-DEP-3** (coordinator-referencing `.remember/` files absent; `remember.md` preserved).

Risk/rollback: `.remember/` is plugin-managed — the `git rm` substeps only touch tracked files. Untracked files left to the plugin's own lifecycle.

- [ ] **T10.1** — Enumerate tracked files via `git ls-files .remember/`. Capture list in T10.2 commit body. estimate_minutes: 3. tier: sonnet. STAGED_SCOPE: none. DoD: list captured. blocks: T10.2.
- [ ] **T10.2** — `git rm` coordinator-referencing buffers: `now.md`, `today-*.md`, `recent.md`, `archive.md`. Preserve `remember.md` schema file (T-DEP-3 guard). estimate_minutes: 7. tier: sonnet. STAGED_SCOPE: `.remember/`. DoD: listed files absent; `remember.md` preserved. T-DEP-3 passes. blockedBy: T10.1. blocks: T10.3.
- [ ] **T10.3** — Add `.remember/.subagents-only.md` — "This directory is subagent-only post-2026-04-30 migration. Coordinators neither read nor write here. See `plans/implemented/personal/2026-04-23-memory-flow-simplification.md` §3.2." estimate_minutes: 5. tier: sonnet. STAGED_SCOPE: `.remember/.subagents-only.md`. DoD: file exists; content matches spec. blockedBy: T10.2. blocks: T10.4.
- [ ] **T10.4** — Verify `.gitignore` — ensure subagent `.remember/` writes remain ignored as today. estimate_minutes: 5. tier: sonnet. STAGED_SCOPE: `.gitignore`. DoD: `git status` shows no `.remember/` noise in a clean repo. blockedBy: T10.3. blocks: T11.

#### T11 — Fold `journal/cli-*.md` into snapshot shape (doc-only) (20 min)

No direct test pair.

- [ ] **T11.1** — Update `agents/evelynn/CLAUDE.md` — describe `## Journal` section of the snapshot as canonical first-person-reflection location; note historical `journal/cli-*.md` stays on disk but no new writes. estimate_minutes: 8. tier: sonnet. STAGED_SCOPE: `agents/evelynn/CLAUDE.md`. DoD: grep `## Journal` in CLAUDE.md ≥ 1; no instruction to write new `journal/` files. blocks: T11.2.
- [ ] **T11.2** — Same for `agents/sona/CLAUDE.md`. estimate_minutes: 6. tier: sonnet. STAGED_SCOPE: `agents/sona/CLAUDE.md`. DoD: same assertion, sona side. blockedBy: T11.1. blocks: T11.3.
- [ ] **T11.3** — Update `.claude/agents/evelynn.md` + `.claude/agents/sona.md` boot prompts if they mention the journal file pattern. Two commits (one per agent-def). estimate_minutes: 6. tier: sonnet. STAGED_SCOPE: per-agent-def, separate commits. DoD: boot prompts reference `## Journal` section, not `journal/cli-*.md`. blockedBy: T11.2. blocks: T12.

#### T12 — Rewrite `architecture/coordinator-memory.md` (45 min)

No direct test pair (doc-only). Builder verifies the six-surface rewrite matches §3.1–§3.7 of this ADR.

- [ ] **T12.1** — Rewrite §1–§2 (coordinator memory purpose, six-surface topology). estimate_minutes: 12. tier: opus. STAGED_SCOPE: `architecture/coordinator-memory.md`. DoD: references six surfaces — `<coordinator>.md`, `live-threads.md`, `sessions/<uuid>.md`, `sessions/INDEX.md`, `inbox/`, `learnings/` — and zero references to `.remember/`, `open-threads.md`, `last-sessions/`. blocks: T12.2.
- [ ] **T12.2** — Rewrite §3 file-layout tree per §3.1 of this ADR. estimate_minutes: 8. tier: sonnet. STAGED_SCOPE: same. DoD: tree diagram verbatim per §3.1; paths exist on disk post-T2/T3/T6. blockedBy: T12.1. blocks: T12.3.
- [ ] **T12.3** — Rewrite §4 single-source-of-truth rules S1–S4 from §3.2. estimate_minutes: 8. tier: sonnet. STAGED_SCOPE: same. DoD: all four rules present, worded as §3.2. blockedBy: T12.2. blocks: T12.4.
- [ ] **T12.4** — Rewrite §5 close-skill dispatch (§3.6) — `/close-coordinator-session` modes table. estimate_minutes: 8. tier: sonnet. STAGED_SCOPE: same. DoD: modes table present; old skill names only appear as "was: /end-session". blockedBy: T12.3. blocks: T12.5.
- [ ] **T12.5** — Rewrite §6 boot order per §3.7 — update the position-7/8/9 table. estimate_minutes: 6. tier: sonnet. STAGED_SCOPE: same. DoD: positions 1–6 preserved; 7=`live-threads.md`, 8=`sessions/INDEX.md`, 9=`inbox/`. blockedBy: T12.4. blocks: T12.6.
- [ ] **T12.6** — Add §7 migration history paragraph linking to this plan at its implemented destination. estimate_minutes: 3. tier: sonnet. STAGED_SCOPE: same. DoD: forward-ref link present. blockedBy: T12.5. blocks: T13.

#### T13 — Write migration learning (15 min)

No direct test pair.

- [ ] **T13.1** — Create `agents/swain/learnings/2026-04-23-memory-surface-collapse.md` with three sections: "The O1–O10 collapse" (§1 table), "Single-source-of-truth by construction" (§3.2 Rules S1–S4 paraphrase), "When to apply this pattern" (recognising two-writer drift in other systems). estimate_minutes: 10. tier: opus. STAGED_SCOPE: `agents/swain/learnings/2026-04-23-memory-surface-collapse.md`. DoD: file exists; three sections present; ≥ 400 words. blocks: T13.2.
- [ ] **T13.2** — Append index entry to `agents/swain/learnings/index.md`. estimate_minutes: 5. tier: sonnet. STAGED_SCOPE: `agents/swain/learnings/index.md`. DoD: new row references the 2026-04-23 learning with a one-line abstract. blockedBy: T13.1. blocks: n/a (terminal).

### Substep totals

Parent tasks: 13. Substeps: **59** (T1: 6, T2: 5, T3: 3, T4: 5, T5: 5, T6: 4, T7: 5, T8: 5, T9: 5, T10: 4, T11: 3, T12: 6, T13: 2 — double-counted phase-gate checkpoints not included).

Sum of substep estimates: 400 min (exactly matches parent budget). Opus-tier substeps (design / architecture judgement): T1.2, T1.3, T1.4, T3.2, T4.5, T12.1, T13.1 — 7 total. Remaining 52 substeps are Sonnet-tier mechanical edits each guarded by Kayn's xfail matrix where applicable.

### Execution sequencing — suggested agent routing

- **Viktor** (precise mechanical edits, single-file, no architectural judgement) — majority of Phase 1 & 2 Sonnet substeps: T2.2–T2.5, T3.3, T4.1–T4.4, T5.1–T5.5, T6.1–T6.4, T7.3–T7.5, and most of Phase 3 T9–T11 doc touches.
- **Jayce** (cross-cutting refactors, shell + JSON + hook wiring) — T2.1 (migration script), T3.1 (seed script), T7.1–T7.2 (`.claude/settings.json` hook guard), T8 in full (memory-consolidate.sh rewrite + fixture run).
- **Seraphine** (schema + doc rewrites with structural judgement) — T1.2–T1.5 (skill Modes + Steps + mode tails), T3.2 (schema normalisation on evelynn side), T4.5 (boot-chain trace helper), T12.1 (§1–§2 rewrite).
- **Soraka** (learnings + journal-shape documentation) — T6.4 (rename learning), T11.1–T11.3 (journal-fold docs), T13 in full.
- **Rakan** — owns all 20 Kayn xfail test commits; lands each before its paired implementation substep per the coverage matrix at line 435.

### Open questions carried forward

None. All 7 ADR OQs are pre-locked (1a, 2b, 3a, 4a, 5a, 6a, 7a per caller's instruction). Xayah's three gap observations (lines 462–468) are addressed inside this breakdown: gap 1 → T2.1 / T3.1 / T5.1 add `--dry-run` + pre-mutation `git tag`; gap 2 → T4.5 adds the boot-chain trace hook; gap 3 → T9.3 hard-fail shape is "file deleted → unknown-skill error" per the caller's OQ5-a pick. If implementation surfaces new ambiguity, flag as `OQ-K<n>` on the relevant substep line.

Total estimate: 400 min (6h 40m) across 13 parent tasks / 59 substeps, distributed over 3 phases with a 7-day observation gate between Phase 2 and Phase 3.

## Orianna approval

- **Date:** 2026-04-23
- **Agent:** Orianna
- **Transition:** approved → in-progress
- **Rationale:** Plan is comprehensively authored — all 7 ADR open questions are pre-locked, all tasks are concrete and substep-decomposed with estimates, STAGED_SCOPE, and DoD, and the full xfail test suite (20 tests across 5 categories) is authored by Xayah and paired to implementation substeps. The `tests_required: true` constraint is satisfied by Xayah's test tasks (T-INV-*, T-MIG-*, T-DEP-*, T-INT-*, T-REG-*). Under the v2 gate, the v1 `tests_required` + `kind: test` blocker is dropped. Ready for Phase 1 implementation.

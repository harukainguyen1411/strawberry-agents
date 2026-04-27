---
status: approved
concern: personal
project: coordinator-memory-improvement-v1
owner: azir
created: 2026-04-27
complexity: complex
tier: complex
tests_required: true
qa_plan: none
qa_plan_none_justification: ADR is infra-only — no user-observable surface. Implementation plans broken out from this ADR will declare their own qa_plan.
architecture_changes:
  - architecture/agent-network-v1/coordinator-memory.md
  - architecture/agent-network-v1/coordinator-boot.md
tags: [architecture, adr, coordinator, memory, concurrency]
related:
  - projects/personal/active/coordinator-memory-improvement-v1.md
  - architecture/agent-network-v1/coordinator-memory.md
  - architecture/agent-network-v1/coordinator-boot.md
  - runbooks/agent-team-mode.md
---

# ADR: Coordinator Memory v1 — Queryable State Store

> **Status:** proposed — first ADR for project `coordinator-memory-improvement-v1`.
> **Authored:** Azir, 2026-04-27. Deadline 2026-04-28.
> **Scope guard:** This ADR is design-only. Implementation tasks live under §Tasks for later breakdown by Aphelios. No production files outside this ADR are touched.

---

## Context

The project doc (`projects/personal/active/coordinator-memory-improvement-v1.md`) names three problems. Restated here verbatim from the project — not redefined:

1. **Boot cost > 100k tokens.** Starting a coordinator session is too expensive. Today the eager read chain (CLAUDE.md → coordinator CLAUDE.md → profile → evelynn.md → duong.md → agent-network.md → learnings index → open-threads.md → feedback INDEX → preferences → axes → last-sessions/INDEX.md) plus per-shard reads pulled from references blows the boot budget.
2. **Open-threads goes stale.** `agents/<coordinator>/memory/open-threads.md` is hand-maintained text. PRs merge, plans archive, inbox messages land — none of these update the file. The file diverges from ground truth between coordinator close and next coordinator open.
3. **No concurrency safety.** Two parallel sessions of the same coordinator (Evelynn ↔ Evelynn) can both read `open-threads.md`, both write, and the loser's edit is silently lost on push (or produces a merge conflict that requires manual resolution).

### Current empirical baseline (informational, not authoritative)

- `agents/evelynn/memory/evelynn.md` — 679 lines.
- `agents/evelynn/memory/open-threads.md` — 786 lines (~30 KB of prose).
- `last-sessions/` — 30+ shards in active set; many archived.
- Total `agents/evelynn/memory/` on disk — 772 KB.
- The two-layer design shipped in `architecture/agent-network-v1/coordinator-memory.md` reduced boot from a noisy-busy ~13–14k input tokens to a smaller eager surface, but the open-threads prose has grown back since.

The authoritative pre-project boot-cost number is **deliberately not asserted in this ADR** — Talon will measure it as the first task. Without that number we cannot validate the DoD.

---

## Decisions

Each decision below states the choice space, names the trade-offs, picks a recommendation, and gives reasoning. Where a recommendation is contingent on the baseline measurement, that is called out.

### D1. State store technology — **SQLite**

**Choice space:**

| Option | Query power | Locking | Tooling ubiquity | Hand-editable | FTS-ready |
|---|---|---|---|---|---|
| (a) Structured JSON tree on disk (one file per entity) | weak (grep/jq) | none — file-system races | universal | yes | no |
| (b) Single JSON file (`state.json`) | weak | full-file write — coarse | universal | yes | no |
| (c) **SQLite** (`state.db`) | full SQL, indexes, joins | per-DB file lock + WAL mode for readers, BEGIN IMMEDIATE for writers | universal (`sqlite3` ships on macOS, Windows, every CI image) | no — requires `sqlite3` CLI | yes — `FTS5` built in |
| (d) DuckDB | full SQL + columnar; great for analytical queries | single-writer; weaker concurrency story than SQLite | growing but not ubiquitous | no | yes (FTS extension) |
| (e) LMDB / other in-process kv | fast kv only | reader-writer lock | requires bindings; less common in shell tooling | no | no |

**Recommendation: (c) SQLite.**

**Reasoning:**
- The project constraint is "boring, free, well-supported primitives." SQLite is the maximally boring durable store on the planet.
- We need **transactional concurrent writes** (two coordinator sessions writing decisions or session shards at the same time). SQLite with `journal_mode=WAL` and `BEGIN IMMEDIATE` gives us deadlock-free serializable writes with concurrent readers. JSON files cannot.
- Every CI image, mac, and Git-Bash install ships `sqlite3`. We do not introduce a new runtime dependency.
- FTS5 gives us a credible path to full-text search across decisions/learnings/shards in v2 without changing the store.
- Hand-editability is a real loss versus JSON — mitigated by (i) `sqlite3 state.db ".dump"` produces a readable SQL transcript, (ii) all authored writes go through helper scripts (`scripts/state/*.sh`), (iii) ad-hoc reads are `sqlite3 state.db "SELECT ..."`, which is pleasant.
- DuckDB is rejected because its single-writer model is *worse* than SQLite for our workload, and its tooling is not yet universally pre-installed.

**Open risk:** SQLite locking on macOS network/synced filesystems (iCloud Drive) is historically fragile. This repo lives in `~/Documents/Personal/strawberry-agents/` which **is** under iCloud's purview on Duong's machine. Mitigated by D2 (gitignored runtime DB outside the iCloud sync zone if necessary) — see Open Question O1.

---

### D2. Storage location — **Hybrid: schema committed, runtime DB gitignored, located outside repo**

**Choice space:**

| Option | Portability across machines | Merge pain | Audit trail |
|---|---|---|---|
| (a) Committed in-repo (`agents/_state/state.db`) | excellent — clone-and-go | severe — binary blob, every write produces a merge conflict | excellent — git log of every coordinator decision |
| (b) Gitignored per-machine (state never pushed) | poor — new machine boots empty | none | none — local-only |
| (c) **Hybrid: schema migrations committed under `agents/_state/migrations/*.sql`, runtime `state.db` gitignored, located at `~/.strawberry-state/state.db` (outside the repo tree)** | good — schema replays; data is local-but-recoverable from session shards | none — DB is gitignored | partial — derived projections are recoverable from committed sources (PRs, plans, inbox); authored entities (decisions, learnings) are also written as committed markdown shards (existing behavior preserved) so the DB can be rebuilt |

**Recommendation: (c) Hybrid.**

**Reasoning:**
- Committing a SQLite file is a known-bad pattern: every coordinator close produces a binary diff, and parallel sessions produce a guaranteed merge conflict on the binary that git cannot resolve.
- Pure gitignored is too lossy — a fresh clone (or a second machine) starts blind.
- The hybrid keeps the DB ephemeral and **rebuildable**. Every authored entity (decision, session-end shard, learning) continues to be written to a committed markdown file in `agents/<coordinator>/memory/` (existing behavior). The DB is a *projection* over those files plus derived sources (PRs, plans, inbox). A `scripts/state/rebuild.sh` reconstructs the DB from the committed source-of-truth files — this is the disaster-recovery path AND the new-machine bootstrap path.
- **Path is locked at `~/.strawberry-state/state.db`** (configurable via `STRAWBERRY_STATE_DB` env var, but the default is canonical). Rationale, recorded inline so future readers do not move it back: this repo lives under `~/Documents/Personal/` which **is** under macOS iCloud Drive sync by default. SQLite WAL files (`-wal`, `-shm`) under iCloud sync have produced documented corruption (the syncer races with WAL checkpointing). A home-root dotfile directory like `~/.strawberry-state/` is **not** under iCloud sync and is the safe location. Do not relocate the DB back into the repo tree without first re-validating WAL behaviour under whatever sync agent the new location sits under.

---

### D3. Schema shape — authored vs derived entities

**Entities and authorship classification:**

| Entity | Authored or Derived | Source of truth | Why |
|---|---|---|---|
| `sessions` | **Authored** | Written by coordinator at `/end-session` and `/pre-compact-save` | Session events are first-class facts the coordinator emits. |
| `decisions` | **Authored** | Written by coordinator via `decision-capture` skill | Already authored today as markdown under `agents/<c>/memory/decisions/log/`; DB row is added at write time. |
| `learnings` | **Authored** | Written by any agent at session close | Already authored today as markdown under `agents/<agent>/learnings/`; DB row is added at write time. |
| `open_threads` | **Derived** (with override) | Refreshed projection from `plans_index` ∪ `pr_index` ∪ `inbox_index` ∪ `decisions` ∪ `projects_index`; coordinator may *annotate* a thread with a `note` column but cannot create a thread that has no underlying source. | This is the project's #2 problem ("open-threads goes stale"). Removing manual authorship of thread existence is the fix. |
| `plans_index` | **Derived** | Refresh from `find plans/ -name '*.md'` + frontmatter parse | Plans live as markdown; DB indexes them. |
| `projects_index` | **Derived** | Refresh from `find projects/ -name '*.md'` + frontmatter parse | Same. |
| `prs_index` | **Derived** | Refresh from `gh pr list --json ...` | GitHub is source of truth. |
| `inbox_index` | **Derived** | Refresh from `find agents/<c>/inbox/ -name '*.md'` | Inbox files are source of truth. |
| `feedback_index` | **Derived** | Refresh from `find feedback/ -name '*.md'` + frontmatter parse | Already file-backed. |

**Validation of the team-lead's instinct:**

- Team-lead wrote: "decisions/sessions/learnings are authored; plans/projects/PRs/inbox are derived." **Confirmed.**
- Adding `feedback_index` as derived (not on the original list) — feedback files exist, the coordinator already reads `feedback/INDEX.md` at boot, projecting them into the DB lets us query by severity/category without re-parsing on every boot.
- `open_threads` is the interesting case. The temptation is to make it authored (preserving today's hand-maintained file). **Rejected** — that is the source of problem #2. Open threads are a *view* over (open PRs assigned to me, in-progress plans I own, unread inbox messages, recent decisions, active projects). The coordinator may annotate a thread with a `note` (free-text rationale, "blocker is X waiting on Y") but cannot conjure a thread that has no underlying source artifact.

**v1 cross-coordinator readiness (locked decision):** every authored table carries a non-null `coordinator TEXT NOT NULL` column from day one (values: `'evelynn'` or `'sona'`). Cost in v1 is trivial — a few bytes per row. Benefit: v2 cross-coordinator views (Evelynn seeing Sona's open threads, joint decision history) become a query-shape change rather than a schema migration. Default value at insert is the current coordinator's identity (`$STRAWBERRY_AGENT` lowercased); helper library enforces non-null at the write boundary.

**Schema sketch (illustrative, not final — Aphelios will refine in breakdown):**

```sql
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,                    -- shard UUID
  coordinator TEXT NOT NULL,              -- 'evelynn' | 'sona'
  started_at TEXT NOT NULL,               -- ISO-8601
  ended_at TEXT,                          -- NULL while open
  shard_path TEXT NOT NULL,               -- agents/<c>/memory/last-sessions/<uuid>.md
  tldr TEXT,                              -- 3-line summary (today's INDEX content)
  branch TEXT                             -- coordinator's branch at close, if any
);

CREATE TABLE decisions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  coordinator TEXT NOT NULL,
  decided_at TEXT NOT NULL,
  slug TEXT NOT NULL,
  shard_path TEXT NOT NULL,               -- decisions/log/<date>-<slug>.md
  summary TEXT NOT NULL,
  axis TEXT,                              -- nullable; per coordinator-decision-feedback
  UNIQUE(coordinator, slug, decided_at)
);

CREATE TABLE learnings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  agent TEXT NOT NULL,
  learned_at TEXT NOT NULL,
  slug TEXT NOT NULL,
  path TEXT NOT NULL,
  topic TEXT,
  UNIQUE(agent, slug, learned_at)
);

CREATE TABLE prs_index (
  number INTEGER PRIMARY KEY,
  repo TEXT NOT NULL,
  title TEXT NOT NULL,
  state TEXT NOT NULL,                    -- open|closed|merged
  author TEXT,
  base_ref TEXT,
  head_ref TEXT,
  updated_at TEXT NOT NULL,
  refreshed_at TEXT NOT NULL              -- when projection ran
);

CREATE TABLE plans_index (
  path TEXT PRIMARY KEY,                  -- relative path
  status TEXT NOT NULL,                   -- proposed|approved|in-progress|implemented|archived
  concern TEXT NOT NULL,
  owner TEXT,
  project TEXT,                           -- nullable
  created TEXT NOT NULL,
  refreshed_at TEXT NOT NULL
);

CREATE TABLE projects_index (
  slug TEXT PRIMARY KEY,
  status TEXT NOT NULL,                   -- proposed|active|completed|archived
  concern TEXT NOT NULL,
  deadline TEXT,
  refreshed_at TEXT NOT NULL
);

CREATE TABLE inbox_index (
  path TEXT PRIMARY KEY,
  recipient TEXT NOT NULL,
  arrived_at TEXT NOT NULL,
  archived INTEGER NOT NULL DEFAULT 0,
  refreshed_at TEXT NOT NULL
);

CREATE TABLE feedback_index (
  path TEXT PRIMARY KEY,
  category TEXT,
  severity TEXT NOT NULL,                 -- low|medium|high
  status TEXT NOT NULL,                   -- open|resolved
  refreshed_at TEXT NOT NULL
);

CREATE TABLE open_threads (
  -- pure VIEW over the derived tables + decisions, with optional note overlay
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  coordinator TEXT NOT NULL,
  source_kind TEXT NOT NULL,              -- pr|plan|project|inbox|decision
  source_ref TEXT NOT NULL,               -- pr#93 | plans/.../foo.md | projects/.../bar.md | ...
  title TEXT NOT NULL,
  status TEXT NOT NULL,                   -- derived from source
  note TEXT,                              -- coordinator-authored annotation (only authored field)
  pinned INTEGER NOT NULL DEFAULT 0,      -- coordinator can pin a thread to keep it surfaced
  last_touched TEXT NOT NULL,
  UNIQUE(coordinator, source_kind, source_ref)
);

CREATE TABLE refresh_log (
  projection TEXT PRIMARY KEY,            -- 'prs_index' | 'plans_index' | etc
  last_refreshed_at TEXT NOT NULL,
  duration_ms INTEGER,
  rows_in INTEGER,
  rows_out INTEGER
);
```

---

### D4. Boot pattern — **Cached projection, refreshed on boot, with a thin top-N read into context**

**Choice space:**

| Option | Boot cost | Freshness | Complexity |
|---|---|---|---|
| (a) Full snapshot read on boot — read all open_threads + recent sessions + decisions into prompt | high | high | low |
| (b) Lazy index-only — read nothing; coordinator queries the DB on demand | minimal | high | medium — coordinator must remember to query |
| (c) **Cached projection refreshed at boot, render top-N into context as a thin markdown table** | low–medium | high | medium |

**Recommendation: (c).**

**Reasoning:**
- (a) reproduces today's bloat. Rejected.
- (b) is conceptually clean but in practice the coordinator never queries — agents anchor on what's already in context. Empirically, Evelynn does not run `find` or `gh pr list` mid-session unless prodded. Pure lazy will leave the coordinator blind.
- (c) is the boring middle. At boot, `scripts/state/coordinator-context.sh <coordinator>` (i) refreshes derived projections, (ii) emits a small markdown report (open threads with status, recent decisions, last-N sessions TL;DR, high-severity feedback) to stdout, (iii) the coordinator's startup chain reads this single rendered report instead of `open-threads.md` + `feedback/INDEX.md` + `last-sessions/INDEX.md`.
- The rendered report is bounded (e.g. top 20 open threads, last 10 sessions, top 5 high-severity feedback). The coordinator queries the DB directly when it needs more — the existing Skarner agent gets a SQL-query tool path for deep digs.

**Eliminated from boot under (c):**
- `agents/<c>/memory/open-threads.md` — derived; replaced by the rendered report.
- `agents/<c>/memory/last-sessions/INDEX.md` — derived; folded into the rendered report.
- `feedback/INDEX.md` — derived; folded into the rendered report.
- `agents/<c>/memory/decisions/preferences.md`, `axes.md` — kept eager (these are authored slow-churn axis-digests; small enough to keep).

**Estimated boot saving (informal, pending Talon's measurement):** open-threads.md alone is ~30 KB. Replacing it with a 2–5 KB rendered table is the single biggest lever.

---

### D5. Refresh cadence for derived state — **Boot + on-demand + change-event hooks for known fast paths**

**Choice space:**

| Option | Open-threads correctness | Cost | Complexity |
|---|---|---|---|
| (a) Every boot only | stale within a session | low | low |
| (b) On-demand via skill (coordinator runs `/refresh-state` when it cares) | depends on coordinator discipline | low | low |
| (c) Periodic background (cron / launchd) | high background freshness; battery cost | medium | medium |
| (d) **Change-notification-driven on known fast paths + boot refresh + on-demand command** | highest | low–medium | medium |

**Recommendation: (d), implemented in this order:**

1. **Boot refresh** (always) — `scripts/state/refresh.sh --all` runs as part of `coordinator-boot.sh`. Bounded by SLA: must complete in <2s wall clock or it's emitting a warning and continuing. (`gh pr list` is the dominant cost — cached for 60s.)
2. **On-demand `/refresh-state` skill** — coordinator can force a refresh mid-session.
3. **Change-event hooks on known fast paths:**
    - PostToolUse hook on `Bash` calls matching `gh pr (merge|close|create)` → enqueue a `prs_index` refresh.
    - PostToolUse hook on `Bash` calls matching Orianna's plan promotions → enqueue a `plans_index` refresh.
    - Inbox watcher (already armed per INV-3) → enqueue an `inbox_index` refresh on file landing.
    - "Enqueue" = touch a sentinel file at `~/.strawberry-state/refresh-pending/<projection>`. Next time any state-read script runs, it consumes the sentinel and refreshes that projection only.

This gives the DoD's "stays correct after PRs merge, plans archive, and inbox messages land — without manual upkeep."

**Explicitly NOT building:** a long-running background daemon. The hook+sentinel pattern gives us event-driven freshness without a process to manage. This honors the "limited tools budget."

---

### D6. Concurrency model — **WAL mode + `BEGIN IMMEDIATE` writes + busy-timeout 5s + SELECT-after-COMMIT for read-your-writes**

**Write protocol:**

```
PRAGMA journal_mode=WAL;          -- once at DB creation; persists in DB header
PRAGMA busy_timeout=5000;         -- per connection
PRAGMA synchronous=NORMAL;        -- WAL-safe and faster than FULL

-- Per write transaction:
BEGIN IMMEDIATE;                  -- acquires RESERVED lock immediately; fails fast if another writer holds it
  INSERT/UPDATE/DELETE ...;
COMMIT;
```

**Why each piece:**
- **WAL mode**: readers do not block writers, writers do not block readers. Two coordinator sessions reading the DB concurrently is a no-op. Required for parallel-coordinator DoD.
- **`BEGIN IMMEDIATE`**: the standard `BEGIN` is deferred — SQLite only takes the write lock at the first write inside the transaction, which can produce SQLITE_BUSY mid-transaction (deadlock risk under concurrency). `BEGIN IMMEDIATE` takes the lock up front, so the second writer either waits (busy-timeout) or fails cleanly.
- **`busy_timeout=5000`**: gives a contending writer up to 5s to acquire the lock before failing. Coordinator sessions write infrequently (sessions, decisions); 5s is comfortably long enough that real contention is rare.
- **`synchronous=NORMAL`**: durable enough for our use (loses at most the last transaction on a hard kernel crash; we don't care — we can rebuild from committed sources).

**Consistency guarantee delivered:** A coordinator that just successfully `COMMIT`s a write can immediately `SELECT` the written row and see it (read-your-writes). Other coordinator sessions see the write within their next `SELECT` after the commit (snapshot isolation per WAL semantics).

**Retry-on-busy:** The helper scripts (`scripts/state/_lib_db.sh`) wrap every write in a 3-try retry loop with 250ms backoff. SQLITE_BUSY after 3 retries is a hard error reported to the coordinator (an actual concurrency disaster — coordinator decides whether to wait or escalate).

**Deadlock avoidance:** SQLite has no true deadlocks because there is at most one writer at a time (RESERVED lock is exclusive). The only failure shape is busy-wait timeout, handled above.

**What this does NOT cover:** a coordinator session that has read state, *thought about it for 5 minutes*, and then wants to write based on that read. Between read and write, another session can have advanced state. We accept this — the operations a coordinator performs (record a decision, record a session close, annotate an open thread) are write-once and idempotent. Cross-session "compare-and-swap" is not in scope for v1.

---

### D7. Migration approach — **Hard cutover** (validates team-lead's stated preference)

**Choice space:**

| Option | Risk | Effort | Reversibility |
|---|---|---|---|
| (a) Hard cutover — flip boot chain to the DB-rendered context, archive `open-threads.md` + `last-sessions/INDEX.md` + `feedback/INDEX.md` from boot reads in one PR | medium | low | revert the PR |
| (b) Parallel-run-then-switch — coordinator boots both old and new for N sessions, compare, then flip | low | high | trivial |
| (c) Derive-only-from-static-files (don't introduce DB) | low | low | n/a — sidesteps the project |

**Recommendation: (a) Hard cutover. Team-lead's stated preference holds.**

**Validation reasoning:**
- The risk class is "regression in coordinator boot context." If the rendered context misses something, the coordinator notices on the first session post-cutover and we revert. There is no data loss path — authored entities (decisions, learnings, session shards) keep being written as markdown files exactly as today; only the *boot read shape* changes.
- Parallel-run doubles boot cost during the trial period — exactly what the project is trying to reduce. Anti-goal.
- The rebuild script (`scripts/state/rebuild.sh` from D2) is the rollback insurance: nuking the DB and rebuilding from committed sources is always safe.

**One gotcha worth noting (does not change the recommendation):** the existing `open-threads.md` contains coordinator-authored notes that are NOT recoverable from any other source (the prose rationale on each thread). The cutover plan must include a one-time migration that parses today's `open-threads.md` into `open_threads.note` rows keyed by `source_ref`, so we don't lose the coordinator's annotations. Aphelios should call this out as a dedicated migration task.

---

### D8. Boot-cost measurement methodology — first §Tasks item

**Definition of "boot cost":**

The token count of the input prompt at the moment the coordinator session is ready to accept its first user message — i.e. after the entire startup-chain read sequence has completed but before any user-prompt-driven tool calls.

**Measurement protocol (Talon executes):**

1. **Environment fix.** Fresh coordinator launch via `scripts/coordinator-boot.sh Evelynn` on a clean session (no resume, no compact). Record git SHA at boot.
2. **Three runs.** Repeat 3x and record min/median/max. Coordinator boot is deterministic in principle but `find` / `gh` calls have variable latency.
3. **What to count:**
    - **Input tokens at boot completion** — the dominant metric. Captured via Claude Code's session telemetry (the `/cost` command after the boot chain settles, or by reading the session log file). Talon documents the exact extraction technique he chose.
    - **Wall-clock seconds from `claude` exec to first-user-message-ready** — secondary metric.
    - **Per-file byte count** — Talon outputs a table: file path → bytes → tokens (approx 4 bytes/token for English; he can use the actual tokenizer if needed).
4. **Output artifact.** `assessments/2026-04-27-coordinator-boot-baseline.md` containing the run table, methodology, and the chosen "official" pre-project number. This artifact is referenced by the project doc as the DoD baseline.
5. **Repeat for Sona** — same protocol, separate baseline. The DoD applies to both coordinators.

**What counts as boot:** every read in the `agents/<coordinator>/CLAUDE.md` Startup Sequence (positions 1–10 today) plus the repo-root `CLAUDE.md` plus any SessionStart-hook-injected context. Excludes anything triggered by Duong's first prompt.

**Post-implementation re-measurement:** the same protocol re-runs after the cutover lands. **Reduction target is set after baseline measurement (T1) lands, documented in `assessments/2026-04-27-coordinator-boot-baseline.md`, and applied as the validation target for the implementation phase.** We deliberately do not pin a percentage here to avoid anchoring against an unknown — the achievable reduction depends on what the baseline actually measures. The implementation phase plans will reference the documented target when validating the DoD.

---

## Tasks

High-level — Aphelios will break each into per-agent tasks during the breakdown pass.

1. **Baseline measurement** — Talon executes D8's protocol on Evelynn AND Sona. Output: `assessments/2026-04-27-coordinator-boot-baseline.md`. **This is the first task; downstream tasks block on its delivery.**
2. **Schema migration files** — author `agents/_state/migrations/0001-init.sql` (the schema sketch from D3, refined). Commit the migration; runtime DB stays gitignored (D2).
3. **State-store helper library** — `scripts/state/_lib_db.sh` (open connection with WAL+busy-timeout+IMMEDIATE wrappers + retry loop per D6).
4. **Refresh scripts** — one per derived projection: `refresh-prs.sh`, `refresh-plans.sh`, `refresh-projects.sh`, `refresh-inbox.sh`, `refresh-feedback.sh`. Each writes to `refresh_log` on success.
5. **Boot context renderer** — `scripts/state/coordinator-context.sh <coordinator>` (D4). Renders the markdown report consumed at boot.
6. **Authored-entity write paths** — modify `decision-capture` skill, `/end-session` skill (Step 6/6b), and `/end-subagent-session` (for learnings) to also write a row to the DB. Markdown files remain the source of truth.
7. **Open-threads annotation migration** — one-time parser that ingests today's `agents/evelynn/memory/open-threads.md` and `agents/sona/memory/open-threads.md` into `open_threads.note` rows (D7 gotcha).
8. **Change-event hooks** — PostToolUse hook for `gh pr (merge|close|create)` and Orianna plan promotion → sentinel-touch (D5).
9. **Boot-chain swap** — modify `agents/evelynn/CLAUDE.md` and `agents/sona/CLAUDE.md` Startup Sequences to read the rendered context instead of the three eager files retired at D4. Update `architecture/agent-network-v1/coordinator-memory.md` and `architecture/agent-network-v1/coordinator-boot.md` to describe the new shape.
10. **Rebuild script** — `scripts/state/rebuild.sh` reconstructs the DB from committed sources (D2 disaster recovery).
11. **Skarner SQL access** — extend Skarner's tool surface to include `sqlite3 ~/.strawberry-state/state.db "<query>"` for deep historical digs.
12. **Post-implementation re-measurement** — Talon re-runs D8's protocol against the new boot chain. Output appended to the baseline assessment. DoD validation.

---

## Test plan

(Note: this section governs the eventual implementation; tests do not apply to the ADR document itself. Per `qa_plan: none` justification, no user-observable surface here — the test surface is operational.)

The implementation plans broken out from this ADR will inherit `tests_required: true` and must contain xfail tests committed before implementation per Rule 12.

**Test surfaces the implementation must cover:**

| Surface | Test shape | Owner |
|---|---|---|
| Schema migration apply + rollback | `tests/state/test-migration.sh` — applies migration to fresh DB, verifies tables/indexes, rolls back via `DROP`, replays | Vi |
| Concurrent writes (D6 invariant) | `tests/state/test-concurrent-writes.sh` — fork two writer processes, each does 100 inserts; assert all 200 land, no SQLITE_BUSY hard failures | Vi |
| Refresh idempotency | `tests/state/test-refresh-idempotent.sh` — run each refresh twice, assert row counts identical | Vi |
| Open-threads correctness vs ground truth | `tests/state/test-open-threads-projection.sh` — seed fixture PRs/plans/inbox, run refresh, assert projection matches expected set | Vi |
| Rebuild from committed sources | `tests/state/test-rebuild.sh` — nuke DB, run rebuild, assert authored-entity row counts match committed shard counts | Vi |
| Boot context renderer output bound | `tests/state/test-context-render-bound.sh` — assert rendered output ≤ 8 KB under realistic seed | Vi |
| Annotation migration preserves notes | `tests/state/test-open-threads-annotation-migration.sh` — input today's `open-threads.md` content, assert every `## <thread>` heading lands as an `open_threads.note` row keyed by inferred `source_ref` | Vi |
| Change-event hook fires | `tests/hooks/test-state-refresh-hook.sh` — invoke a fake `gh pr merge` → assert sentinel created → run state-read script → assert refresh ran | Vi |

---

## Out of scope (explicit, in addition to the project doc's exclusions)

The following are intentionally deferred. Each is a deliberate v1 boundary, not an oversight.

**OOS-1. `decisions/preferences.md` and `decisions/axes.md` stay as static markdown in v1.** These authored axis-digest files remain read eagerly at boot (positions 8–9 of today's startup chain are preserved). They are small and slow-churn; the boot-cost lever is much lower priority than open-threads. Migration to DB-derived is a v2 question, not a v1 one. Adding them to v1 would expand scope without proportional boot-cost return.

**OOS-2. Lissandra `/pre-compact-save` Step 2b becomes a no-op once open-threads is derived.** Today Lissandra writes into `open-threads.md` per `architecture/agent-network-v1/coordinator-memory.md` §4. With `open_threads` as a derived projection in v1, Lissandra's hand-write loses its target — the DB refreshes itself from underlying sources, and there is nothing for Lissandra to write. **Coordination required with the separate Lissandra-retirement ADR (TBD owner).** This ADR does not modify Lissandra's behaviour; the Lissandra ADR must absorb the no-op semantics, or sequence Lissandra retirement to land before/alongside this v1 cutover.

**OOS-3.** Project doc exclusions still apply: cross-coordinator shared brain (Evelynn ↔ Sona joined views), Lissandra retirement, and CLAUDE.md rules-layer optimization are all out of v1. The schema is built v2-ready (per D3's `coordinator` column) but no v2 views or cross-coordinator queries are wired in v1.

---

## Open questions

All five Open Questions raised in the first draft of this ADR have been resolved by team-lead direction and folded into the decisions above. No outstanding questions block Orianna's gate. Recap for traceability:

| OQ | Resolution | Where it lives in this ADR |
|---|---|---|
| O1 — state path | Locked at `~/.strawberry-state/state.db`; iCloud-WAL rationale recorded inline | §D2 reasoning |
| O2 — `coordinator` column in v1 schema | Yes, every authored table carries it from day one; default = current coordinator identity | §D3 (locked-decision callout above the schema sketch) |
| O3 — boot-cost reduction target | Not pinned now; set after Talon's T1 baseline lands and documented in the baseline assessment | §D8 post-implementation re-measurement paragraph |
| O4 — `preferences.md` / `axes.md` migration | Deferred to v2; remain static markdown in v1 | §Out of scope OOS-1 |
| O5 — Lissandra Step 2b no-op | Flagged for the separate Lissandra-retirement ADR (TBD owner); this ADR does not solve it | §Out of scope OOS-2 |

---

## Cross-references

- Project: `projects/personal/active/coordinator-memory-improvement-v1.md`
- Existing memory architecture this ADR supersedes: `architecture/agent-network-v1/coordinator-memory.md`
- Existing boot architecture this ADR amends: `architecture/agent-network-v1/coordinator-boot.md`
- Concurrency context: `runbooks/agent-team-mode.md` (parallel coordinator sessions are now the operational norm under team mode)
- Plan frontmatter contract: `architecture/agent-network-v1/plan-frontmatter.md`
- Decision-capture skill (write path that becomes a DB write): `.claude/skills/decision-capture/SKILL.md`
- Session-close skill (write path): `.claude/skills/end-session/SKILL.md`

## Orianna approval

- **Date:** 2026-04-27
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Structural gates pass (qa_plan frontmatter + body, UX Spec linter). Frontmatter is complete with `project:` linkage and `qa_plan: none` justified for an infra-only ADR. All 8 decisions present full choice-space/trade-off/recommendation/reasoning; all 5 prior open questions resolved and folded into decisions with a traceability table. §Tasks ordered with T1 (baseline) explicitly blocking downstream; §Test plan enumerates 8 concrete operational test surfaces with owner. v2-readiness (`coordinator` column) is justified, trivial-cost, and OOS-3 confirms no v2 wiring lands in v1 — appropriately scoped for a complex-track ADR.

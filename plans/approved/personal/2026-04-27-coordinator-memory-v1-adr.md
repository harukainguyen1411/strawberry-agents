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
| `schema_migrations` | **System** | Written by `db_apply_migrations()` in `_lib_db.sh`; one row per applied migration filename | Bookkeeping for safe re-application of `0001-init.sql` and any future migration. Not authored (no human writes it), not derived (not a projection of a markdown source) — a runtime system table. No `coordinator` column needed; migration state is per-DB, not per-coordinator. Added by amendment 2026-04-28 — see §Amendment log. |

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
  id INTEGER PRIMARY KEY,                 -- plain rowid alias; no AUTOINCREMENT (see §D3.1)
  coordinator TEXT NOT NULL,
  decided_at TEXT NOT NULL,
  slug TEXT NOT NULL,
  shard_path TEXT NOT NULL,               -- decisions/log/<date>-<slug>.md
  summary TEXT NOT NULL,
  axis TEXT,                              -- nullable; per coordinator-decision-feedback
  UNIQUE(coordinator, slug, decided_at)
);

CREATE TABLE learnings (
  id INTEGER PRIMARY KEY,                 -- plain rowid alias; no AUTOINCREMENT (see §D3.1)
  agent TEXT NOT NULL,                    -- author of the learning (any agent, incl. sub-agents)
  coordinator TEXT NOT NULL,              -- dispatching coordinator: 'evelynn' | 'sona' (see §D3.1)
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
  id INTEGER PRIMARY KEY,                 -- plain rowid alias; no AUTOINCREMENT (see §D3.1)
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

-- System table — tracks which migration files have been applied to this DB.
-- Written exclusively by db_apply_migrations() in scripts/state/_lib_db.sh.
-- Not authored (no human writes it), not derived (not a projection); per-DB bookkeeping.
CREATE TABLE schema_migrations (
  filename TEXT PRIMARY KEY,              -- e.g. '0001-init.sql' (basename, lex-sortable)
  applied_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

---

### D3.1. Schema details surfaced by implementation — `agent` vs `coordinator` on `learnings`, and no `AUTOINCREMENT` on rowid PKs

**Added by amendment 2026-04-28** (see §Amendment log). Two tactical refinements that the T6b / PR #103 implementation arc and the T2a clean-rollback test (PR #96) surfaced as under-specified in the original §D3 sketch.

#### D3.1.a — `learnings` carries BOTH `agent` and `coordinator`

The original sketch had only `agent` on `learnings`, which collapsed two distinct identities into one column and broke v2-readiness for cross-coordinator queries (the same reason every other authored table carries `coordinator NOT NULL` per §D3's locked decision).

The live schema (`agents/_state/migrations/0001-init.sql`) splits them:

- **`agent TEXT NOT NULL`** — author of the learning. Any agent in the roster: a sub-agent like Vi, Talon, Senna, etc., or a coordinator authoring its own learning.
- **`coordinator TEXT NOT NULL`** — the dispatching coordinator at the time the learning was written. Always `'evelynn'` or `'sona'`. For coordinator-authored learnings, `agent == coordinator`.

This resolves the open question Lucian raised on PR #96 about what `coordinator` means when a sub-agent writes a learning: the sub-agent records *its own identity* in `agent` AND the dispatching coordinator's identity in `coordinator`.

**Write contract (system-level outcome — mechanism-agnostic):** every `learnings` row, every `sessions` row, and every authored-entity row generally MUST be inserted with a non-null `coordinator` value resolved to the dispatching coordinator's identity (`'evelynn'` or `'sona'`). The schema enforces non-null at the storage boundary; correct *value* selection is the caller's responsibility. How callers obtain that value is an implementation detail that may evolve:

- **Currently shipped (PR #103 r3, `db-write-session.sh`, `db-write-learning.sh`):** callers pass `coordinator` as a positional argument. The lower-level `db_write_tx` in `_lib_db.sh` is a generic SQL wrapper and is not learnings-aware — no env defaulting at the library layer today.
- **Reserved future option:** higher-level write helpers MAY adopt env-default behaviour (e.g. `COORDINATOR="${N:-${STRAWBERRY_COORDINATOR:-}}"`), with the dispatching coordinator's identity plumbed into the sub-agent's environment at Agent-tool dispatch time. This is a non-breaking enhancement — positional callers continue to work — and does not require an ADR amendment to adopt.

The contract that matters across both the current and future shape is the same: dispatching coordinator's identity reaches the row, every time. Tightened by amendment 3 (2026-04-28) to match the shipped helper signature surfaced in Lucian's PR #103 r3 review — see §Amendment log.

Query consequence: cross-coordinator views (which sub-agent has been most active under each coordinator? which coordinator owns which knowledge surface?) become trivial — `SELECT coordinator, agent, COUNT(*) FROM learnings GROUP BY coordinator, agent`. Without the column we'd have to back-derive the dispatcher from filesystem path conventions, which is exactly the brittleness the v2-readiness column was added to avoid.

#### D3.1.b — Plain `INTEGER PRIMARY KEY`, no `AUTOINCREMENT`, on `learnings.id`, `decisions.id`, `open_threads.id`

The original sketch used `INTEGER PRIMARY KEY AUTOINCREMENT`. The live schema uses plain `INTEGER PRIMARY KEY`.

**Why the change:** SQLite's `AUTOINCREMENT` keyword has a side effect — it materialises a system table named `sqlite_sequence` to enforce the "monotonic, never-reuse-deleted-rowids" guarantee. That system table broke the rollback-clean-state assertion in T2a (`tests/state/test-migration.sh`): after `DROP`-ing all user tables on rollback, `sqlite_sequence` persisted and the "DB is clean" assertion failed. PR #96 review (Talon) caught it; the pragmatic fix landed by removing `AUTOINCREMENT`.

**What we lose by removing it:** monotonic-never-reuse on rowids. After deletion of the highest-id row, the next insert can reuse that id.

**Why we don't care:** these are runtime projection tables. `decisions`, `learnings`, `open_threads` rows are keyed by their UNIQUE constraints (`(coordinator, slug, decided_at)`, `(agent, slug, learned_at)`, `(coordinator, source_kind, source_ref)`) — the integer `id` is an internal rowid alias for join convenience, not a stable external reference. Nothing outside the DB names a row by integer id, so reuse is invisible.

Plain `INTEGER PRIMARY KEY` still gives auto-assignment of unique rowids on insert (SQLite's default rowid behaviour). The only thing we give up is the monotonic guarantee — which we never relied on.

**Test surface (T2a covers):** rollback (`DROP TABLE` for every user table) leaves zero residual system tables; second migration apply on the cleaned DB succeeds.

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

### D6.1. Migration-tracking contract — `db_apply_migrations()` is the sole writer of `schema_migrations`

**Added by amendment 2026-04-28** (see §Amendment log). This sub-decision formalises the runtime migration-state contract that PR #96 review and the T3a/T3b implementation arc surfaced as an under-specified gap in the original ADR.

**Contract:**

- The `schema_migrations` table (defined in §D3) is the single source of truth for which migration files have been applied to a given `state.db`.
- Exactly one writer: `db_apply_migrations()` in `scripts/state/_lib_db.sh`. No other script, skill, or agent writes this table. No coordinator-facing helper exposes a write path.
- Algorithm:
  1. Open the DB (creating it if absent; first connection is responsible for the WAL/busy-timeout PRAGMAs from §D6).
  2. Ensure `schema_migrations` itself exists (idempotent `CREATE TABLE IF NOT EXISTS`); this bootstrap step is the only write outside the per-migration loop.
  3. Enumerate `agents/_state/migrations/*.sql` in **lexicographic filename order** (the `0001-`, `0002-`, … prefix convention makes lex-order = apply-order).
  4. For each file: `SELECT 1 FROM schema_migrations WHERE filename = ?`. If present, skip. If absent, apply the file inside a `BEGIN IMMEDIATE … COMMIT` transaction that **also** inserts the `schema_migrations` row in the same transaction — so an applied migration and its bookkeeping land atomically, or neither does.
  5. On any SQL error mid-application, the transaction rolls back and `db_apply_migrations()` exits non-zero with a diagnostic naming the offending file.
- Re-runnability invariant: `db_apply_migrations()` is safe to call on every coordinator boot. If all migrations have been applied, it is a near-noop (one indexed lookup per file). This is what makes the boot-refresh pattern in §D5 safe.

**Why no `coordinator` column on `schema_migrations`:** migration state is per-DB, not per-coordinator. Both Evelynn and Sona share the single DB at `~/.strawberry-state/state.db` (per §D2) and therefore share the migration ledger. Adding a `coordinator` column would imply per-coordinator migration application, which is wrong — schema is global.

**Test surface (covered by T3a, the xfail Rakan pre-emptively wrote):** apply on fresh DB lands all rows; second apply on the same DB is a noop; partial-failure (mock SQL error in second migration of three) leaves migrations 1 applied + recorded, migration 2 not applied + not recorded, migration 3 not attempted.

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

## Amendment log

Post-approval inline amendments to this ADR. Each entry: date, driver, change, locations touched. Tactical inline amendments only — substantive direction changes warrant a successor ADR rather than an amendment row here.

### 2026-04-28 — Add `schema_migrations` as 11th table + §D6.1 migration-tracking contract

**Driver:** Lucian's PR #98 fidelity review surfaced that `schema_migrations` was being implemented (Viktor's T3b `db_apply_migrations`) without being formally enumerated in the ADR. Senna's PR #96 IMPORTANT finding identified the same gap, and Rakan pre-emptively wrote the T3a xfail test covering the apply / re-apply / partial-failure invariants. The team converged on amending the ADR rather than treating it as a silent implementation detail.

**Change:**
1. Added `schema_migrations` row to the §D3 entity table, classified as **System** (neither authored nor derived). No `coordinator` column — schema state is per-DB, not per-coordinator.
2. Added the `CREATE TABLE schema_migrations` block to the §D3 schema sketch (after `refresh_log`).
3. Added new §D6.1 formalising the migration-tracking contract: `db_apply_migrations()` is the sole writer; lex-order enumeration of `agents/_state/migrations/*.sql`; per-migration apply + bookkeeping inside a single `BEGIN IMMEDIATE` transaction so they land atomically; safe to call on every coordinator boot.

**Locations touched in this file:** §D3 entity table; §D3 schema sketch; new §D6.1 inserted between §D6 and §D7; this Amendment log.

**No downstream task changes:** T3a (xfail) and T3b (impl) already cover the contract — this amendment makes the ADR catch up to the implementation, not the other way around.

### 2026-04-28 — Schema-sketch fidelity: drop `AUTOINCREMENT`; add `learnings.coordinator`; clarify agent-vs-coordinator semantic

**Driver:** Two real drifts between §D3's schema sketch and the live `agents/_state/migrations/0001-init.sql` surfaced via implementation review:

1. **Talon, PR #96 review (T2a clean-rollback finding)** — `AUTOINCREMENT` on integer-PK columns materialises a `sqlite_sequence` system table that survives `DROP` of user tables, breaking T2a's "rollback leaves DB clean" assertion. Pragmatic fix landed by switching to plain `INTEGER PRIMARY KEY` on `learnings.id`, `decisions.id`, and `open_threads.id`. ADR sketch still showed `AUTOINCREMENT`.
2. **Viktor, T6b implementation + Senna PR #103 review** — `learnings` was implemented with BOTH `agent` (author) and `coordinator` (dispatcher) columns, the latter satisfying the §D3 v2-readiness convention. Original ADR sketch had only `agent`, leaving Lucian's PR #96 question — "what does `coordinator` mean for a sub-agent's learning?" — unanswered at the schema level. The agent-vs-coordinator split resolves it: `agent` = author (any agent, incl. sub-agents); `coordinator` = dispatcher (always evelynn or sona).

**Change:**
1. §D3 schema sketch — `decisions`, `learnings`, `open_threads` now show plain `INTEGER PRIMARY KEY` (annotated "no AUTOINCREMENT — see §D3.1").
2. §D3 schema sketch — `learnings` now enumerates `coordinator TEXT NOT NULL` directly under `agent`, with column comment naming the semantic.
3. New §D3.1 inserted between §D3 and §D4: §D3.1.a documents the `agent` vs `coordinator` semantic split on `learnings` (incl. helper-library default behaviour and the cross-coordinator query consequence); §D3.1.b documents the `AUTOINCREMENT` removal (mechanism, what we lose, why we don't care, T2a coverage).

**Locations touched in this file:** §D3 schema sketch (`decisions`, `learnings`, `open_threads` blocks); new §D3.1 inserted; this Amendment log.

**No downstream task changes:** T2a (xfail) and T6b (skill integration) already cover the contracts in their live shape — this amendment makes the ADR catch up to the implementation, same pattern as the §D6.1 amendment above.

**Re-author note (2026-04-28):** Original commit `8ef6bad1` was authored 2026-04-27 but became unreachable from origin/main following Ekko's history-rewrite session that scrubbed leaked secrets. Re-authored verbatim here. Original semantic intent and attribution preserved; SHA chain rebuilds from the post-rewrite main.

### 2026-04-28 — §D3.1.a tighten: write contract is system-level, helper mechanism is implementation detail

**Driver:** Lucian's PR #103 r3 review (commit `9dbe39d9`) flagged a NON-BLOCKING gap between §D3.1.a (just landed at amendment 2) and the shipped helper surface. The amendment-2 prose said: *"Helper-library write path (`db_write_tx` in `_lib_db.sh`) defaults `coordinator` to `$STRAWBERRY_COORDINATOR` (or equivalent) at insert."* Reality: the new helpers `db-write-session.sh` and `db-write-learning.sh` take `coordinator` as a positional arg from the caller; `db_write_tx` itself is a generic SQL wrapper, not learnings-aware, with no env defaulting. Functional contract held (every authored row carries the right coordinator because callers pass it), but the named *mechanism* in the ADR didn't literally exist.

**Change:**
- §D3.1.a — replaced the single mechanism-naming sentence with an explicit "Write contract" paragraph that states the system-level invariant (every authored row MUST carry a non-null `coordinator` resolved to the dispatching coordinator's identity), then enumerates two implementation shapes: (a) **currently shipped** = positional arg from caller (`db-write-session.sh`, `db-write-learning.sh` per PR #103 r3); (b) **reserved future option** = higher-level helpers MAY adopt env-default with `$STRAWBERRY_COORDINATOR` fallback as a non-breaking enhancement.
- Closing line clarifies the contract is shape-invariant and points to this amendment row for traceability.

**Locations touched in this file:** §D3.1.a (replaced one paragraph with a tightened multi-paragraph block); this Amendment log.

**No downstream task changes:** PR #103 r3 functional contract already holds and Lucian APPROVED on that basis. This amendment is the spec-catches-up-to-shipped-code pass — same pattern as the §D6.1 amendment and amendment 2 (the §D3 schema sketch update). No follow-up Viktor commit required; the env-default fallback is reserved as an option, not a gap.

**Re-author note (2026-04-28):** Original commit `b6ff1224` was authored 2026-04-27 but became unreachable from origin/main following Ekko's history-rewrite session. Re-authored verbatim here. Original semantic intent and attribution preserved.

---

## Cross-references

- Project: `projects/personal/active/coordinator-memory-improvement-v1.md`
- Existing memory architecture this ADR supersedes: `architecture/agent-network-v1/coordinator-memory.md`
- Existing boot architecture this ADR amends: `architecture/agent-network-v1/coordinator-boot.md`
- Concurrency context: `runbooks/agent-team-mode.md` (parallel coordinator sessions are now the operational norm under team mode)
- Plan frontmatter contract: `architecture/agent-network-v1/plan-frontmatter.md`
- Decision-capture skill (write path that becomes a DB write): `.claude/skills/decision-capture/SKILL.md`
- Session-close skill (write path): `.claude/skills/end-session/SKILL.md`

## Breakdown

Authored by Aphelios on 2026-04-27. Translates the 12 high-level §Tasks above into per-agent executable entries. Each entry names: subject, owner agent, files-to-touch, dependencies, complexity, `parallel_slice_candidate`, and (for code-producing tasks) the xfail-test pair-mate per Rule 12.

**Track decisions locked in this breakdown:**

- **Helper library (T3) and concurrency model (T6)** — **complex track** (Rakan xfail → Viktor impl). Rationale: D6's WAL + `BEGIN IMMEDIATE` + busy-timeout + retry-loop + read-your-writes invariants are non-trivial to test correctly. Concurrent-writer test (T-VI-2 in Azir's test plan) requires fork/exec choreography, race-window verification, and assertion of zero hard SQLITE_BUSY failures — that is Rakan-grade test authorship. Routine-track Vi handles the simpler refresh / migration / projection tests.
- **Migration (T7 — annotation migration)** — **Talon multi-step plan**, not a Yuumi errand. Touches both coordinator memory trees (`evelynn/`, `sona/`), parses today's `open-threads.md` prose into `open_threads.note` rows by inferring `source_ref` per heading, AND is one-shot but irreversible (annotation prose lost if mis-parsed). Talon owns multi-file one-time migrations; Yuumi is sized for single-file errands. Pair-mate xfail by Vi (deterministic fixture-based).
- **Boot-cost re-measurement (T12)** — Talon, re-runs D8 protocol against the new boot path, **appends** results to `assessments/2026-04-27-coordinator-boot-baseline.md` (same artifact T1 creates, post-impl section). DoD validation gate.

**Universal dependency:** every task except T1 is `blockedBy: T1` because the baseline assessment artifact is the validation reference for the entire project. Implementation can begin on schema/library scaffolding pre-baseline ONLY if Duong explicitly waives — default is hard-block.

---

### T1 — Baseline measurement (Evelynn + Sona boots)

- **Owner:** Talon
- **Subject:** Execute D8 protocol against fresh Evelynn AND Sona boots; produce baseline assessment.
- **Files:** `assessments/2026-04-27-coordinator-boot-baseline.md` (new); reads existing `scripts/coordinator-boot.sh`, `agents/evelynn/CLAUDE.md`, `agents/sona/CLAUDE.md`.
- **DoD:** Assessment file committed with: 3-run table per coordinator (input tokens, wall-clock seconds), per-file byte/token table, official "pre-project" number for each coordinator, methodology section reproducible by re-running. Boot-cost reduction TARGET also written into this same file (per D8 / OQ O3 resolution).
- **Dependencies:** none — this is the gate.
- **Complexity:** moderate (measurement choreography + telemetry extraction technique selection).
- **xfail-test-first?** No — measurement / assessment task, not code.
- **`parallel_slice_candidate: no`** — single Talon flow; Evelynn and Sona measurements share the methodology authoring step.

---

### T2a — xfail test for schema migration (apply + rollback + replay)

- **Owner:** Vi
- **Subject:** Author `tests/state/test-migration.sh` as xfail (impl absent); covers apply on fresh DB → assert tables/indexes per D3 schema → rollback via DROP → replay clean.
- **Files:** `tests/state/test-migration.sh` (new); `agents/_state/migrations/.gitkeep` if needed for path discoverability.
- **DoD:** Test committed; runs red with clear "migration file not present" failure; references this ADR slug + T2 in test header.
- **Dependencies:** T1.
- **Complexity:** simple.
- **`parallel_slice_candidate: yes`** — independent of T3a/T4a/T5a.

### T2b — Implement schema migration `0001-init.sql`

- **Owner:** Talon
- **Subject:** Author the initial schema migration file from D3's schema sketch, refined with explicit indexes (`coordinator`, `decided_at`, `refreshed_at`) and the `refresh_log` projection table. WAL pragma is set by helper library, not migration.
- **Files:** `agents/_state/migrations/0001-init.sql` (new); `agents/_state/README.md` (new — one-paragraph "what lives here" pointer to D2/D3).
- **DoD:** T2a passes green; migration applies cleanly to a fresh `state.db`; all 9 tables from D3 created with the `coordinator` column on every authored table; FTS5 not wired in v1 (deferred per OOS).
- **Dependencies:** T1, T2a.
- **Complexity:** simple.
- **`parallel_slice_candidate: no`** — single SQL file authoring step, dependent on T2a green.

---

### T3a — xfail tests for state helper library (concurrency invariants)

- **Owner:** Rakan (complex track — concurrent-writer choreography is non-trivial)
- **Subject:** Author `tests/state/test-concurrent-writes.sh` AND `tests/state/test-helper-lib-pragmas.sh` as xfail. Concurrent-writer test forks two writer processes each doing 100 inserts, asserts 200 rows land with zero hard SQLITE_BUSY failures (per D6). Pragma test asserts `journal_mode=WAL`, `busy_timeout=5000`, `synchronous=NORMAL` are applied by the connection wrapper.
- **Files:** `tests/state/test-concurrent-writes.sh` (new); `tests/state/test-helper-lib-pragmas.sh` (new).
- **DoD:** Both tests committed; run red against missing `_lib_db.sh`; reference D6 invariants in headers.
- **Dependencies:** T1, T2b (needs schema present to insert against).
- **Complexity:** complex (race-window assertions, timing tolerance, fork-and-join shell choreography).
- **`parallel_slice_candidate: no`** — pair tests authored together to share fixture scaffolding.

### T3b — Implement `_lib_db.sh` helper library

- **Owner:** Viktor (complex track — concurrency primitives + retry semantics)
- **Subject:** POSIX-portable bash library exposing: `db_open`, `db_write_tx <sql>` (wraps BEGIN IMMEDIATE + retry 3x with 250ms backoff per D6), `db_read <sql>`, `db_apply_migrations`. Sets all D6 pragmas on connection open.
- **Files:** `scripts/state/_lib_db.sh` (new).
- **DoD:** T3a's two tests pass green; library passes shellcheck; portable on macOS + Git Bash (per Rule 10).
- **Dependencies:** T1, T2b, T3a.
- **Complexity:** complex.
- **`parallel_slice_candidate: no`** — single library file, sequential after tests.

---

### T4a — xfail tests for refresh scripts (idempotency + per-projection)

- **Owner:** Vi
- **Subject:** Author `tests/state/test-refresh-idempotent.sh` as xfail — runs each of the 5 refresh scripts twice against a seeded fixture, asserts row counts identical between runs and `refresh_log` updated. Plus stub per-projection tests that assert basic seed-and-reflect behavior.
- **Files:** `tests/state/test-refresh-idempotent.sh` (new); `tests/state/fixtures/` (new — seed PRs JSON, plan markdown, inbox markdown).
- **DoD:** Tests committed; run red against missing refresh scripts.
- **Dependencies:** T1, T2b, T3b (needs helper library).
- **Complexity:** moderate.
- **`parallel_slice_candidate: yes`** — independent of T5a/T6a.

### T4b — Implement 5 refresh scripts

- **Owner:** Jayce (normal track — refresh logic is straightforward parse-and-INSERT)
- **Subject:** Author `refresh-prs.sh`, `refresh-plans.sh`, `refresh-projects.sh`, `refresh-inbox.sh`, `refresh-feedback.sh`. Each reads source-of-truth files / `gh` output, upserts into the corresponding `*_index` table, writes a row into `refresh_log`. Plus parent `refresh.sh --all | --<projection>` dispatcher.
- **Files:** `scripts/state/refresh.sh` (new); `scripts/state/refresh-prs.sh`, `refresh-plans.sh`, `refresh-projects.sh`, `refresh-inbox.sh`, `refresh-feedback.sh` (all new).
- **DoD:** T4a passes green; each refresh script bounded to <2s wall-clock per D5 SLA; `gh pr list` cached for 60s as specified.
- **Dependencies:** T1, T2b, T3b, T4a.
- **Complexity:** moderate (5 distinct projections; all share parse-and-upsert pattern).
- **`parallel_slice_candidate: yes`** — five distinct scripts can be implemented in parallel by sub-streams of Jayce dispatch (each script is its own commit; merge friction zero because each touches disjoint files).

---

### T5a — xfail test for boot context renderer (output bound + content shape)

- **Owner:** Vi
- **Subject:** Author `tests/state/test-context-render-bound.sh` as xfail — runs renderer against realistic seed, asserts output ≤ 8 KB (per D4 plus test-plan row), asserts presence of "open threads", "recent decisions", "recent sessions", "high-severity feedback" sections.
- **Files:** `tests/state/test-context-render-bound.sh` (new).
- **DoD:** Test committed; runs red against missing renderer.
- **Dependencies:** T1, T2b, T3b, T4b.
- **Complexity:** simple.
- **`parallel_slice_candidate: yes`** — independent of T6a/T7a.

### T5b — Implement `coordinator-context.sh` renderer

- **Owner:** Jayce
- **Subject:** Bash script that takes `<coordinator>` arg, runs `refresh.sh --all` (bounded), queries DB for top-20 open threads / last-10 sessions / top-5 high-severity feedback, renders to a single markdown report on stdout per D4.
- **Files:** `scripts/state/coordinator-context.sh` (new).
- **DoD:** T5a passes green; output bounded; rendered shape matches D4 specification.
- **Dependencies:** T1, T2b, T3b, T4b, T5a.
- **Complexity:** moderate.
- **`parallel_slice_candidate: no`** — single script.

---

### T6a — xfail tests for authored-entity write paths (skill DB-write integration)

- **Owner:** Rakan (complex track — exercises three skill integrations + idempotency under retry)
- **Subject:** Author `tests/state/test-authored-writes.sh` as xfail — invokes `decision-capture`, `/end-session` Step 6/6b, and `/end-subagent-session` learning-write code paths against a fixture DB; asserts each writes both the markdown shard AND the corresponding DB row; asserts re-running the skill is idempotent (UNIQUE constraint per D3).
- **Files:** `tests/state/test-authored-writes.sh` (new).
- **DoD:** Test committed; runs red against unmodified skills.
- **Dependencies:** T1, T2b, T3b.
- **Complexity:** complex (multi-skill integration test surface).
- **`parallel_slice_candidate: no`** — single test file scoping all three skill paths.

### T6b — Modify three write-path skills to also write DB rows

- **Owner:** Viktor (complex track — touches three coordinator-critical skills, must not regress markdown write behavior)
- **Subject:** Modify `.claude/skills/decision-capture/SKILL.md` (decision write), `.claude/skills/end-session/SKILL.md` (Step 6/6b session shard write), and `/end-subagent-session` skill (learning write) so each authored markdown write is followed by a DB INSERT via `_lib_db.sh`. Markdown remains source of truth.
- **Files:** `.claude/skills/decision-capture/SKILL.md`, `.claude/skills/end-session/SKILL.md`, `.claude/skills/end-subagent-session/SKILL.md` (all modified).
- **DoD:** T6a passes green; all three skills idempotent under re-run; markdown write semantics unchanged.
- **Dependencies:** T1, T2b, T3b, T6a.
- **Complexity:** complex.
- **`parallel_slice_candidate: yes`** — three skills are independent edits, each its own commit; can run in parallel sub-streams.

---

### T7a — xfail test for open-threads annotation migration

- **Owner:** Vi
- **Subject:** Author `tests/state/test-open-threads-annotation-migration.sh` as xfail — feeds today's `open-threads.md` content (snapshotted as fixture) into the migration script, asserts every `## <thread>` heading lands as an `open_threads.note` row keyed by inferred `source_ref`, asserts no annotation text lost.
- **Files:** `tests/state/test-open-threads-annotation-migration.sh` (new); `tests/state/fixtures/open-threads-evelynn-snapshot.md`, `open-threads-sona-snapshot.md` (new).
- **DoD:** Test committed; runs red against missing migration script.
- **Dependencies:** T1, T2b, T3b.
- **Complexity:** moderate (fixture authoring + heading parse semantics).
- **`parallel_slice_candidate: yes`** — independent of T8a/T9.

### T7b — Implement annotation migration script

- **Owner:** Talon (multi-step one-shot migration touching both coordinator trees; irreversible-ish, hence Talon over Yuumi per the locked decision above)
- **Subject:** Bash script that parses `agents/evelynn/memory/open-threads.md` AND `agents/sona/memory/open-threads.md`, infers `source_ref` per `## <thread>` heading (per-coordinator regex tuned to today's heading conventions), inserts `open_threads.note` rows, archives the source file post-migration to `agents/<c>/memory/_migrated/open-threads-2026-04-27.md`.
- **Files:** `scripts/state/migrate-open-threads-notes.sh` (new); reads `agents/evelynn/memory/open-threads.md`, `agents/sona/memory/open-threads.md`; writes archives under `agents/{evelynn,sona}/memory/_migrated/`.
- **DoD:** T7a passes green; both source files archived (not deleted); annotation row count matches fixture-derived expectation.
- **Dependencies:** T1, T2b, T3b, T7a.
- **Complexity:** moderate.
- **`parallel_slice_candidate: no`** — single script, sequential after T7a.

---

### T8a — xfail test for change-event hook firing

- **Owner:** Vi
- **Subject:** Author `tests/hooks/test-state-refresh-hook.sh` as xfail — invokes a fake `gh pr merge` Bash event → asserts sentinel file created at `~/.strawberry-state/refresh-pending/prs_index` → runs `coordinator-context.sh` → asserts refresh consumed sentinel and re-projected `prs_index`.
- **Files:** `tests/hooks/test-state-refresh-hook.sh` (new).
- **DoD:** Test committed; runs red against missing hook.
- **Dependencies:** T1, T2b, T3b, T4b, T5b.
- **Complexity:** moderate (hook simulation + sentinel-consumption semantics).
- **`parallel_slice_candidate: yes`** — independent of T9.

### T8b — Implement PostToolUse change-event hook

- **Owner:** Jayce
- **Subject:** Hook script that pattern-matches `Bash` tool calls for `gh pr (merge|close|create)` and Orianna's plan-promotion `git mv` invocations; on match, touches sentinel `~/.strawberry-state/refresh-pending/<projection>`. Wire into `.claude/settings.json` PostToolUse. Modify refresh dispatcher to consume sentinels at next read.
- **Files:** `scripts/hooks/posttooluse-state-refresh-sentinel.sh` (new); `.claude/settings.json` (modified — add hook entry); `scripts/state/refresh.sh` (modified — sentinel-consumption pass on entry).
- **DoD:** T8a passes green; hook runs cleanly with no spurious sentinels on unrelated Bash calls.
- **Dependencies:** T1, T2b, T3b, T4b, T5b, T8a.
- **Complexity:** moderate.
- **`parallel_slice_candidate: no`** — single hook + dispatcher edit.

---

### T9 — Boot-chain swap (coordinator startup + architecture docs)

- **Owner:** Talon (multi-file orchestration: 2 coordinator CLAUDE.md files + 2 architecture docs in one coherent flip per D7 hard-cutover)
- **Subject:** Modify Evelynn and Sona Startup Sequences to (i) call `scripts/state/coordinator-context.sh <coordinator>` and read its output instead of reading `open-threads.md`, `last-sessions/INDEX.md`, `feedback/INDEX.md`. Update `architecture/agent-network-v1/coordinator-memory.md` and `architecture/agent-network-v1/coordinator-boot.md` to describe the new boot shape. Preserve eager reads of `decisions/preferences.md` and `decisions/axes.md` per OOS-1.
- **Files:** `agents/evelynn/CLAUDE.md`, `agents/sona/CLAUDE.md`, `architecture/agent-network-v1/coordinator-memory.md`, `architecture/agent-network-v1/coordinator-boot.md` (all modified).
- **DoD:** Both coordinators boot via the new chain; rendered context appears at the position previously occupied by the three retired files; architecture docs reflect the new shape.
- **Dependencies:** T1, T5b (renderer must exist), T6b (write paths must populate the DB), T7b (annotation migration must have run so notes are present in renderer output), T8b (event hooks armed).
- **Complexity:** moderate (cross-file consistency, irreversible-ish without revert).
- **xfail-test-first?** No — boot-chain wiring is doc + invocation glue; integration verified by T12 re-measurement.
- **`parallel_slice_candidate: no`** — single coherent cutover; T5b/T6b/T7b/T8b must all be green first.

---

### T10a — xfail test for rebuild-from-sources

- **Owner:** Vi
- **Subject:** Author `tests/state/test-rebuild.sh` as xfail — nukes DB, runs `rebuild.sh`, asserts authored-entity row counts match counts of committed shard files (decisions, learnings, session shards). Derived projections asserted to refresh on rebuild path.
- **Files:** `tests/state/test-rebuild.sh` (new).
- **DoD:** Test committed; runs red against missing rebuild script.
- **Dependencies:** T1, T2b, T3b, T4b, T6b.
- **Complexity:** moderate.
- **`parallel_slice_candidate: yes`** — independent of T11.

### T10b — Implement `rebuild.sh`

- **Owner:** Jayce
- **Subject:** Script that wipes runtime DB, applies migrations via `_lib_db.sh`, walks committed sources (`agents/*/memory/decisions/log/*.md`, `agents/*/memory/last-sessions/*.md`, `agents/*/learnings/*.md`) re-inserting authored rows, then runs `refresh.sh --all` for derived projections.
- **Files:** `scripts/state/rebuild.sh` (new).
- **DoD:** T10a passes green; rebuild idempotent; new-machine bootstrap flow described in `agents/_state/README.md`.
- **Dependencies:** T1, T2b, T3b, T4b, T6b, T10a.
- **Complexity:** moderate.
- **`parallel_slice_candidate: no`** — single script.

---

### T11 — Skarner SQL access tool surface

- **Owner:** Yuumi (single-file errand — append a tool entry to Skarner's def + brief usage note)
- **Subject:** Add `sqlite3 ~/.strawberry-state/state.db "<query>"` invocation pattern to Skarner's tool list and document the read-only query convention in Skarner's CLAUDE.md.
- **Files:** `.claude/agents/skarner.md` (modified); optionally `agents/skarner/CLAUDE.md` (modified) for usage examples.
- **DoD:** Skarner can run a `SELECT` against `state.db` and surface the result to coordinator.
- **Dependencies:** T1, T2b, T3b.
- **Complexity:** trivial.
- **xfail-test-first?** No — agent-def edit, not code under test.
- **`parallel_slice_candidate: yes`** — independent edit, can run alongside any T*b stream after T3b lands.

---

### T12 — Post-implementation re-measurement (DoD validation)

- **Owner:** Talon
- **Subject:** Re-execute D8 protocol against the post-cutover boot path for both Evelynn and Sona; append "Post-implementation results" section to `assessments/2026-04-27-coordinator-boot-baseline.md` with min/median/max input tokens + wall-clock; compare against pre-project baseline AND the target documented in T1; emit PASS / FAIL verdict against project DoD.
- **Files:** `assessments/2026-04-27-coordinator-boot-baseline.md` (modified — append-only).
- **DoD:** Post-impl section committed; verdict line states PASS or FAIL against the T1-documented target. On FAIL, opens follow-up plan; on PASS, project moves to `completed/` (Orianna handles).
- **Dependencies:** T1 (baseline reference), T9 (boot chain swapped), T7b (annotation migration done), T8b (hooks live).
- **Complexity:** moderate (re-measurement choreography + comparison reporting).
- **`parallel_slice_candidate: wait-bound`** — duration dominated by 3-run re-measurement on each of two coordinators; cannot usefully parallelise the runs themselves (boot is the metric).

---

### Dependency map (compact)

```
T1 ──┬── T2a ── T2b ──┬── T3a ── T3b ──┬── T4a ── T4b ──┬── T5a ── T5b ──┐
     │                │                │                │                │
     │                │                ├── T6a ── T6b ──┤                │
     │                │                ├── T7a ── T7b ──┤                │
     │                │                ├── T10a ── T10b ┤                │
     │                │                └── T11          │                │
     │                │                                 ├── T8a ── T8b ──┤
     │                │                                                  │
     │                                                                   ├── T9 ── T12
     │                                                                   │
     └───────────────────────────────────────────────────────────────────┘
```

**Critical path:** T1 → T2a → T2b → T3a → T3b → T5a → T5b → T9 → T12. Eight sequential gates plus T1.

---

## Orianna approval

- **Date:** 2026-04-27
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Structural gates pass (qa_plan frontmatter + body, UX Spec linter). Frontmatter is complete with `project:` linkage and `qa_plan: none` justified for an infra-only ADR. All 8 decisions present full choice-space/trade-off/recommendation/reasoning; all 5 prior open questions resolved and folded into decisions with a traceability table. §Tasks ordered with T1 (baseline) explicitly blocking downstream; §Test plan enumerates 8 concrete operational test surfaces with owner. v2-readiness (`coordinator` column) is justified, trivial-cost, and OOS-3 confirms no v2 wiring lands in v1 — appropriately scoped for a complex-track ADR.

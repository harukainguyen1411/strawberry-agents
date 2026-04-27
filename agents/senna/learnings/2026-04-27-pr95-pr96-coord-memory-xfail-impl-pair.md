---
date: 2026-04-27
prs: [95, 96]
project: coordinator-memory-improvement-v1
verdict: APPROVE / APPROVE
---

# Reviewing paired xfail/impl PRs for SQLite migration

## Setup

PR #95 added `tests/state/test-migration.sh` as the Rule 12 xfail anchor — exits 1 with `XFAIL: migration file not present` when run before PR #96's `0001-init.sql` exists. PR #96 added the migration SQL (10 tables, WAL pragma, `coordinator TEXT NOT NULL` on all 4 authored tables per ADR §D3 v2-readiness lock).

## Things worth remembering for next time

### 1. Verify xfail behavior standalone, not just paired-green

For a Rule 12 xfail-first PR, the silent-pass risk is "test exits 0 even when migration absent." The safe way to verify is to check out the xfail PR alone (no impl in tree) and run the test — it must exit non-zero with a diagnostic message (not just `command not found`). PR #95's anchor is the explicit `[ ! -f "$MIGRATION_FILE" ] && exit 1` guard before any sqlite3 call. Without that guard, a missing file would still cause `sqlite3 < missing_file` to fail, but the failure shape would be opaque.

### 2. Test-driven schema constraints can be subtle

PR #95's §3 rollback test asserts `SELECT COUNT(*) FROM sqlite_master WHERE type='table'` equals 0 after DROP. This silently forbids `AUTOINCREMENT` (which creates a `sqlite_sequence` system table that also has `type='table'`). Talon discovered this empirically while implementing PR #96 — the test "told" the impl to use plain `INTEGER PRIMARY KEY`. I flagged a NIT to add a clarifying comment so future migration authors don't have to re-derive the constraint.

### 3. WAL pragma persists in DB header

`PRAGMA journal_mode=WAL` modifies the DB file header (bytes 18-19 per SQLite file format). Once set in a migration, every subsequent `sqlite3 db.file` opens in WAL mode — verified by `sqlite3 /tmp/test.db < migration.sql; sqlite3 /tmp/test.db "PRAGMA journal_mode;"` returning `wal` on a fresh connection. This is unlike most SQLite pragmas (e.g. `busy_timeout`) which are connection-scoped. Talon's "belt-and-suspenders" approach (set in migration AND in helper library `_lib_db.sh`) is defensively correct but the migration set is the durable one.

### 4. Idempotency at the SQL level vs the runner level

PR #96's migration has no `IF NOT EXISTS` guards. I considered this a BLOCKER initially, then downgraded to IMPORTANT-not-blocking because the right place to track applied migrations is a `schema_migrations` versions table managed by the migration runner (T3a/T10b in this project), not via SQL guards on every CREATE. Inline `IF NOT EXISTS` would actually be a footgun — it lets `0001-init.sql` succeed against a DB that has only some of the tables (partial state from a prior failure), masking the real bug.

### 5. Spec deviation auth — ADR sketch vs lock

ADR §125 said "Schema sketch (illustrative, not final — Aphelios will refine in breakdown)." ADR §123 (the v2-readiness lock) said "every authored table carries a non-null `coordinator TEXT NOT NULL`." The illustrative sketch at §149 (`learnings`) omitted `coordinator`. Talon implemented the lock, not the sketch. This is the right precedence (locked decision > illustrative sketch) and I called it out in the review so it's clear the deviation was intentional and correct, not drift.

### 6. AUTOINCREMENT vs plain INTEGER PRIMARY KEY — downstream impact analysis

When asked by Evelynn to flag downstream risk for T3b (concurrency helper), I checked: `last_insert_rowid()` is unaffected by AUTOINCREMENT presence/absence, and `sqlite_sequence` is only consulted internally for AUTOINCREMENT tables. Plain `INTEGER PRIMARY KEY` increments monotonically except across explicit deletes-of-max — irrelevant for append-only workloads like decisions/learnings/sessions. Verdict: no downstream risk. Worth recording so the next reviewer doesn't have to re-derive.

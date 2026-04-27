-- Migration 0001: initial schema
-- Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md §D3
-- WAL mode is set here for fresh DB creation; helper library (_lib_db.sh) also
-- sets it per-connection, but applying it in the migration ensures it survives
-- if the DB is ever populated outside the helper.
PRAGMA journal_mode=WAL;

-- ── Authored entities ────────────────────────────────────────────────────────
-- coordinator column is non-null on all authored tables from day one (D3 v2-readiness).

CREATE TABLE sessions (
  id          TEXT PRIMARY KEY,
  coordinator TEXT NOT NULL,
  started_at  TEXT NOT NULL,
  ended_at    TEXT,
  shard_path  TEXT NOT NULL,
  tldr        TEXT,
  branch      TEXT
);
CREATE INDEX idx_sessions_coordinator ON sessions (coordinator);
CREATE INDEX idx_sessions_started_at  ON sessions (started_at);

CREATE TABLE decisions (
  id           INTEGER PRIMARY KEY,
  coordinator  TEXT NOT NULL,
  decided_at   TEXT NOT NULL,
  slug         TEXT NOT NULL,
  shard_path   TEXT NOT NULL,
  summary      TEXT NOT NULL,
  axis         TEXT,
  UNIQUE(coordinator, slug, decided_at)
);
CREATE INDEX idx_decisions_coordinator ON decisions (coordinator);
CREATE INDEX idx_decisions_decided_at  ON decisions (decided_at);

CREATE TABLE learnings (
  id         INTEGER PRIMARY KEY,
  agent      TEXT NOT NULL,
  coordinator TEXT NOT NULL,
  learned_at TEXT NOT NULL,
  slug       TEXT NOT NULL,
  path       TEXT NOT NULL,
  topic      TEXT,
  UNIQUE(agent, slug, learned_at)
);
CREATE INDEX idx_learnings_coordinator ON learnings (coordinator);
CREATE INDEX idx_learnings_learned_at  ON learnings (learned_at);

CREATE TABLE open_threads (
  id           INTEGER PRIMARY KEY,
  coordinator  TEXT NOT NULL,
  source_kind  TEXT NOT NULL,
  source_ref   TEXT NOT NULL,
  title        TEXT NOT NULL,
  status       TEXT NOT NULL,
  note         TEXT,
  pinned       INTEGER NOT NULL DEFAULT 0,
  last_touched TEXT NOT NULL,
  UNIQUE(coordinator, source_kind, source_ref)
);
CREATE INDEX idx_open_threads_coordinator ON open_threads (coordinator);
CREATE INDEX idx_open_threads_last_touched ON open_threads (last_touched);

-- ── Derived projections ───────────────────────────────────────────────────────

CREATE TABLE plans_index (
  path         TEXT PRIMARY KEY,
  status       TEXT NOT NULL,
  concern      TEXT NOT NULL,
  owner        TEXT,
  project      TEXT,
  created      TEXT NOT NULL,
  refreshed_at TEXT NOT NULL
);
CREATE INDEX idx_plans_index_status      ON plans_index (status);
CREATE INDEX idx_plans_index_refreshed_at ON plans_index (refreshed_at);

CREATE TABLE projects_index (
  slug         TEXT PRIMARY KEY,
  status       TEXT NOT NULL,
  concern      TEXT NOT NULL,
  deadline     TEXT,
  refreshed_at TEXT NOT NULL
);
CREATE INDEX idx_projects_index_status ON projects_index (status);

CREATE TABLE prs_index (
  number       INTEGER PRIMARY KEY,
  repo         TEXT NOT NULL,
  title        TEXT NOT NULL,
  state        TEXT NOT NULL,
  author       TEXT,
  base_ref     TEXT,
  head_ref     TEXT,
  updated_at   TEXT NOT NULL,
  refreshed_at TEXT NOT NULL
);
CREATE INDEX idx_prs_index_state        ON prs_index (state);
CREATE INDEX idx_prs_index_refreshed_at ON prs_index (refreshed_at);

CREATE TABLE inbox_index (
  path         TEXT PRIMARY KEY,
  recipient    TEXT NOT NULL,
  arrived_at   TEXT NOT NULL,
  archived     INTEGER NOT NULL DEFAULT 0,
  refreshed_at TEXT NOT NULL
);
CREATE INDEX idx_inbox_index_recipient ON inbox_index (recipient);

CREATE TABLE feedback_index (
  path         TEXT PRIMARY KEY,
  category     TEXT,
  severity     TEXT NOT NULL,
  status       TEXT NOT NULL,
  refreshed_at TEXT NOT NULL
);
CREATE INDEX idx_feedback_index_severity ON feedback_index (severity);
CREATE INDEX idx_feedback_index_status   ON feedback_index (status);

-- ── Refresh log ───────────────────────────────────────────────────────────────

CREATE TABLE refresh_log (
  projection       TEXT PRIMARY KEY,
  last_refreshed_at TEXT NOT NULL,
  duration_ms      INTEGER,
  rows_in          INTEGER,
  rows_out         INTEGER
);

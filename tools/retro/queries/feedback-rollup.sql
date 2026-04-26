-- feedback-rollup.sql
-- Guards: T.P2.2 DoD (a)
-- Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md §T.P2.2
-- Read contract: plans/approved/personal/2026-04-21-agent-feedback-system.md §D12 (lines 623–637)
-- events-source: feedback-events.jsonl
--
-- Returns one row per (category, severity, status) with:
--   open_count      — count of entries where status = 'open'; 0 for non-open rows
--   latest_entry_ts — MAX(created) frontmatter field (NOT file mtime; deterministic per §D12)
--
-- Schema contract (§D12 bind-points — breaking-change-locked):
--   category        string   feedback category enum (§D1)
--   severity        string   low | medium | high
--   status          string   open | triaged | closed
--   open_count      BIGINT   entries with status='open' in this (category, severity, status) group
--   latest_entry_ts VARCHAR  ISO-like timestamp string of the most recent entry's created field
--
-- Phase-2 boundary: exactly 5 columns — extra columns fail the TP2.T1-A schema guard.
--
-- Source: reads from `file` — DuckDB auto-loads the dedicated feedback-events.jsonl
-- passed as the database argument by render.mjs (via the events-source annotation above).
-- In the xfail test, fixtures/feedback-rollup-events.jsonl is passed as the database argument.

SELECT
    category,
    severity,
    status,
    CASE WHEN status = 'open' THEN COUNT(*)::BIGINT ELSE 0::BIGINT END        AS open_count,
    strftime(MAX(CAST(created AS TIMESTAMP)), '%Y-%m-%d %H:%M:%S')            AS latest_entry_ts
FROM file
WHERE kind = 'feedback-entry'
GROUP BY category, severity, status
ORDER BY category, severity, status;

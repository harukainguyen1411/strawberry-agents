-- decision-rollup.sql
-- Guards: T.P2.3 DoD (a)-(d), TP2.T2-A through TP2.T2-D
-- Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md §T.P2.3
-- Read contract: plans/approved/personal/2026-04-21-coordinator-decision-feedback.md §3.5
-- events-source: events.jsonl (shared-stream — decisions are kind:'decision-log' rows)
--
-- Returns one row per (coordinator, axis) with:
--   decisions_total          — total decisions in this (coordinator, axis) slice
--   decisions_matched        — sum of decisions where match = true
--   match_rate               — 4-decimal string: decisions_matched / decisions_total
--   avg_confidence_at_time   — average numeric confidence (low=1, medium=2, high=3)
--
-- Schema contract (§3.5 bind-points — breaking-change-locked):
--   coordinator              VARCHAR  coordinator slug (evelynn | sona)
--   axis                     VARCHAR  axis slug from the axes[] array (per-decision expansion)
--   decisions_total          BIGINT   count of decisions in this coordinator/axis slice
--   decisions_matched        BIGINT   count where match = true
--   match_rate               VARCHAR  4-decimal string 'NNN.NNNN'
--   avg_confidence_at_time   DOUBLE   average mapped confidence score (low=1,medium=2,high=3)
--
-- Axis expansion: `axes` is a JSON array per event. Each axis from a decision is counted
-- independently in the per-axis rollup — a decision with axes:["a","b"] contributes to both
-- axis a and axis b rows. This is the "axis-explosion" pattern per TP2.T2-C.
--
-- duong_concurred_silently: true → match: true (derived at ingest time in lib/sources.mjs;
--   stored as match=true in events.jsonl; SQL reads the pre-computed boolean field directly).
--
-- Phase-2 boundary: exactly 6 columns — extra columns fail the TP2.T2-A schema guard.
--
-- Schema note (C3 lesson from PR #89): render.mjs uses runDuckDBQueryWithFileDb which passes
-- events.jsonl as the DuckDB database argument, creating a `file` table. This approach
-- avoids read_ndjson_auto inference failures on mixed-kind sparse files: the file table
-- is typed from all rows at open time, and `WHERE kind = 'decision-log'` filters cleanly.
-- Tests also use `duckdb -json <eventsPath>` (FROM file pattern) matching this approach.

WITH
-- Load all decision events from the shared-stream file table.
-- `file` is the DuckDB auto-loaded table when events.jsonl is passed as the DB argument.
-- Filter by kind='decision-log' to isolate decision-log events from other kinds (turn, dispatch, etc).
decisions_raw AS (
    SELECT
        coordinator,
        decision_id,
        match,
        coordinator_confidence,
        axes
    FROM file
    WHERE kind = 'decision-log'
      AND coordinator IS NOT NULL
),

-- Map coordinator_confidence string to numeric score for avg computation.
-- low → 1.0, medium → 2.0, high → 3.0.
-- NULL or unknown confidence gets score 0.0 (excluded from meaningful averages).
decisions_with_score AS (
    SELECT
        coordinator,
        decision_id,
        match,
        CASE coordinator_confidence
            WHEN 'low'    THEN 1.0
            WHEN 'medium' THEN 2.0
            WHEN 'high'   THEN 3.0
            ELSE           0.0
        END AS confidence_score,
        axes
    FROM decisions_raw
),

-- Axis explosion: unnest the axes array so each (decision, axis) pair becomes a row.
-- A decision with axes:["routing-track","scope-vs-debt"] produces two rows — TP2.T2-C.
-- DuckDB infers axes as VARCHAR[] from JSONL; UNNEST(axes) works directly.
-- TRIM strips any residual double-quotes from JSON string representation.
decisions_per_axis AS (
    SELECT
        d.coordinator,
        d.decision_id,
        d.match,
        d.confidence_score,
        TRIM(axis_val, '"')                                                    AS axis
    FROM decisions_with_score d,
    LATERAL (
        SELECT unnest(axes) AS axis_val
    ) AS unnested
    WHERE axis_val IS NOT NULL
      AND LENGTH(TRIM(axis_val, '"')) > 0
)

-- Rollup: aggregate by (coordinator, axis)
SELECT
    coordinator,
    axis,
    COUNT(*)::BIGINT                                                           AS decisions_total,
    SUM(CASE WHEN match THEN 1 ELSE 0 END)::BIGINT                            AS decisions_matched,
    -- 4-decimal string for deterministic comparison (parallel to delegate_ratio in coordinator-weekly)
    printf('%.4f',
        SUM(CASE WHEN match THEN 1.0 ELSE 0.0 END)
        / NULLIF(COUNT(*), 0)
    )                                                                          AS match_rate,
    ROUND(AVG(confidence_score), 4)                                            AS avg_confidence_at_time
FROM decisions_per_axis
GROUP BY coordinator, axis
ORDER BY coordinator, axis;

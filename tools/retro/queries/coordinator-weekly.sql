-- coordinator-weekly.sql
-- Guards: T.P2.4 DoD (a)-(f), TP2.T3-A through TP2.T3-E
-- Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
--
-- Implements §Q8 inline-vs-delegate ratio + §Q9 prompt-stat columns.
-- Supersedes coordinator-weekly-skeleton.sql (see deprecation header there).
--
-- Returns one row per (coordinator, iso_week) with 14 columns:
--   Phase-1 skeleton (4 structural + 2 grouping):
--     coordinator, iso_week,
--     inline_tool_calls, delegated_tool_calls, delegate_ratio (string "%.4f"), dispatch_count
--   Phase-2 prompt-stat (8 columns per DoD-(a) / T.P2.1 DoD-(e)):
--     prompt_chars_p50, prompt_chars_p95,
--     header_count_avg,
--     concern_tag_present_pct, plan_citation_present_pct,
--     compression_ratio_p50, compression_ratio_p95
--   Health flag (DoD-(c)):
--     delegate_health_flag   healthy (>0.7) / drift [0.5, 0.7] inclusive / no-data (NULL ratio) / executor-mode (<0.5)
--
-- §Q8 discriminator: role='coordinator-inline' turns = inline; role='delegated' turns = delegated.
--   kind='turn' — ingest (parseParentSession / parseSubagentSession in lib/sources.mjs) emits
--   kind:'turn' for every assistant-row event; there is no kind:'tool_call' in production data.
--
-- §Q9 plan-citation regex pinned to:
--   plans/(proposed|approved|in-progress|implemented|archived)/(personal|work)/.+\.md  (DoD-(f))
--   (regex evaluated in prompt-stats.mjs at ingest time; SQL reads pre-computed boolean field)
--
-- Source: reads via read_ndjson_auto('events.jsonl').
-- duckdb-runner.mjs substitutes 'events.jsonl' with the absolute path before execution.
-- In the xfail test, duckdb is invoked without a DB argument; the SQL path placeholder
-- is substituted by the test helper (same duckdb-runner substitution pattern).
--
-- Schema pinned to prevent read_ndjson_auto inference failures when a week's events.jsonl
-- lacks certain kind values (e.g. no dispatch-prompt-stats rows). Without a pinned schema,
-- DuckDB infers column types from a sample and throws a cast error when it later encounters
-- a row with a different type for that column. Pinning ensures all rows parse consistently.
--
-- Boundary note for delegate_health_flag thresholds (I3):
--   healthy    : delegate_ratio > 0.7  (exclusive lower bound)
--   drift      : 0.5 <= delegate_ratio <= 0.7  (inclusive on both ends)
--   no-data    : delegate_ratio IS NULL (denominator was 0 or no turn events in this week)
--   executor-mode : delegate_ratio < 0.5 (exclusive upper bound)

WITH
-- Aggregate turn counts per coordinator session and week.
-- C2 fix: ingest emits kind:'turn' (see parseParentSession + parseSubagentSession in
-- lib/sources.mjs). The SQL now matches that semantic — kind='turn' not kind='tool_call'.
-- Schema pinned (C3 fix): prevents read_ndjson_auto inference failures on sparse files.
turns_raw AS (
    SELECT *
    FROM read_ndjson_auto('events.jsonl',
        columns={
            kind:       'VARCHAR',
            role:       'VARCHAR',
            coordinator:'VARCHAR',
            ts:         'VARCHAR',
            agentId:    'VARCHAR',
            sessionId:  'VARCHAR',
            parentSessionId: 'VARCHAR',
            input_tokens:  'BIGINT',
            output_tokens: 'BIGINT',
            cache_read_input_tokens:    'BIGINT',
            cache_creation_input_tokens:'BIGINT',
            dispatch_start_ts: 'VARCHAR',
            dispatch_end_ts:   'VARCHAR',
            prompt_chars:      'BIGINT',
            dispatch_prompt_tokens: 'BIGINT',
            header_count:      'BIGINT',
            concern_tag_present:    'BOOLEAN',
            plan_citation_present:  'BOOLEAN',
            compression_ratio:      'DOUBLE'
        }
    )
),

tool_counts AS (
    SELECT
        coordinator,
        -- Compute iso_week once per CTE row (I3: eliminates double STRFTIME in main SELECT)
        STRFTIME(CAST(ts AS TIMESTAMP), '%Y-W%V')                           AS iso_week,
        COUNT(CASE WHEN kind = 'turn' AND role = 'coordinator-inline' THEN 1 END)::BIGINT
                                                                             AS inline_tool_calls,
        COUNT(CASE WHEN kind = 'turn' AND role = 'delegated'          THEN 1 END)::BIGINT
                                                                             AS delegated_tool_calls,
        COUNT(CASE WHEN kind = 'dispatch'                              THEN 1 END)::BIGINT
                                                                             AS dispatch_count
    FROM turns_raw
    WHERE kind IN ('turn', 'dispatch')
      AND coordinator IS NOT NULL
    GROUP BY coordinator, STRFTIME(CAST(ts AS TIMESTAMP), '%Y-W%V')
),

-- Aggregate prompt-stat signals from dispatch-prompt-stats events
-- Schema also pinned via turns_raw above.
prompt_agg AS (
    SELECT
        coordinator,
        STRFTIME(CAST(ts AS TIMESTAMP), '%Y-W%V')                           AS iso_week,
        PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY prompt_chars)          AS prompt_chars_p50,
        PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY prompt_chars)          AS prompt_chars_p95,
        AVG(header_count)                                                    AS header_count_avg,
        AVG(CASE WHEN concern_tag_present = true  THEN 100.0 ELSE 0.0 END)  AS concern_tag_present_pct,
        AVG(CASE WHEN plan_citation_present = true THEN 100.0 ELSE 0.0 END) AS plan_citation_present_pct,
        PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY compression_ratio)     AS compression_ratio_p50,
        PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY compression_ratio)     AS compression_ratio_p95
    FROM turns_raw
    WHERE kind = 'dispatch-prompt-stats'
      AND coordinator IS NOT NULL
    GROUP BY coordinator, STRFTIME(CAST(ts AS TIMESTAMP), '%Y-W%V')
)

SELECT
    tc.coordinator,
    tc.iso_week,
    tc.inline_tool_calls,
    tc.delegated_tool_calls,
    -- delegate_ratio as 4-decimal string for deterministic comparison (§Q8)
    printf('%.4f',
        tc.delegated_tool_calls::DOUBLE
        / NULLIF(tc.inline_tool_calls + tc.delegated_tool_calls, 0)
    )                                                                       AS delegate_ratio,
    tc.dispatch_count,
    -- Prompt-stat percentile columns (§Q9)
    pa.prompt_chars_p50,
    pa.prompt_chars_p95,
    ROUND(pa.header_count_avg, 4)                                           AS header_count_avg,
    ROUND(pa.concern_tag_present_pct, 4)                                    AS concern_tag_present_pct,
    ROUND(pa.plan_citation_present_pct, 4)                                  AS plan_citation_present_pct,
    pa.compression_ratio_p50,
    pa.compression_ratio_p95,
    -- Health flag (DoD-(c)):
    --   healthy       : delegate_ratio > 0.7  (strictly above drift ceiling)
    --   drift         : 0.5 <= delegate_ratio <= 0.7  (inclusive on both ends)
    --   no-data (I2)  : ratio IS NULL — denominator 0 or no turn events this week
    --   executor-mode : delegate_ratio < 0.5 (strictly below drift floor)
    CASE
        WHEN tc.delegated_tool_calls::DOUBLE
             / NULLIF(tc.inline_tool_calls + tc.delegated_tool_calls, 0) > 0.7
            THEN 'healthy'
        WHEN tc.delegated_tool_calls::DOUBLE
             / NULLIF(tc.inline_tool_calls + tc.delegated_tool_calls, 0) >= 0.5
            THEN 'drift'
        WHEN tc.delegated_tool_calls::DOUBLE
             / NULLIF(tc.inline_tool_calls + tc.delegated_tool_calls, 0) IS NULL
            THEN 'no-data'
        ELSE 'executor-mode'
    END                                                                     AS delegate_health_flag
FROM tool_counts tc
LEFT JOIN prompt_agg pa
    ON tc.coordinator = pa.coordinator
   AND tc.iso_week    = pa.iso_week
ORDER BY tc.coordinator, tc.iso_week

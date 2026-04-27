-- coordinator-weekly-skeleton.sql
-- DEPRECATED: superseded by coordinator-weekly.sql (T.P2.4).
-- Retained for Phase-1 boundary guard (TP1.T5 DoD (d)) and historical reference.
-- Guards: T.P1.3 DoD (b), TP1.T5 DoD (d) Phase-2 boundary check
-- Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
--
-- Implements §Q8 inline-vs-delegate discrimination: structural skeleton only.
-- Returns one row per coordinator session with:
--   inline_tool_calls, delegated_tool_calls, delegate_ratio, dispatch_count, iso_week.
--
-- Phase-1 ONLY: NO feedback-bound columns.
-- Phase-1 ONLY: NO decision-bound columns.
-- Any Phase-2 column appearing here will trip TP1.T5 DoD (d).
--
-- §Q8 discriminator: sessions containing coordinator-inline turns are coordinator sessions.
-- Subagent sessions (role=delegated) are excluded from the grouping.
-- dispatch events carry sessionId matching the coordinator session (set by ingest.mjs).
--
-- Field names use camelCase for session identifiers (matching events.jsonl schema).

WITH coordinator_sessions AS (
    SELECT DISTINCT sessionId
    FROM read_ndjson_auto('events.jsonl')
    WHERE kind = 'turn' AND role = 'coordinator-inline'
)
SELECT
    e.sessionId                                                    AS coordinator_session_id,
    STRFTIME(CAST(MIN(e.ts) AS TIMESTAMP), '%Y-W%V')              AS iso_week,
    COUNT(CASE WHEN e.role = 'coordinator-inline'
               AND e.kind = 'tool_call'                     THEN 1 END)::BIGINT AS inline_tool_calls,
    COUNT(CASE WHEN e.role = 'delegated'
               AND e.kind = 'tool_call'                     THEN 1 END)::BIGINT AS delegated_tool_calls,
    ROUND(
        COUNT(CASE WHEN e.role = 'delegated' AND e.kind = 'tool_call' THEN 1 END)::DOUBLE
        /
        NULLIF(COUNT(CASE WHEN e.kind = 'tool_call' THEN 1 END), 0)
    , 4)                                                                         AS delegate_ratio,
    COUNT(CASE WHEN e.kind = 'dispatch' THEN 1 END)::BIGINT                     AS dispatch_count
FROM read_ndjson_auto('events.jsonl') AS e
JOIN coordinator_sessions cs ON e.sessionId = cs.sessionId
WHERE e.kind IN ('turn', 'tool_call', 'dispatch')
GROUP BY e.sessionId
ORDER BY e.sessionId;

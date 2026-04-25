-- coordinator-weekly-skeleton.sql
-- Guards: T.P1.3 DoD (b), TP1.T5 DoD (d) Phase-2 boundary check
-- Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
--
-- Implements §Q8 inline-vs-delegate discrimination: structural skeleton only.
-- Returns one row per (coordinator_session_id, iso_week) with:
--   inline_tool_calls, delegated_tool_calls, delegate_ratio, dispatch_count.
--
-- Phase-1 ONLY: NO feedback-bound columns (e.g. open_feedback_count).
-- Phase-1 ONLY: NO decision-bound columns (e.g. decision_match_rate, coordinator_confidence).
-- Any Phase-2 column appearing here will trip TP1.T5 DoD (d).
--
-- §Q8 discriminator: parent-path sessions (role=coordinator-inline) are inline;
-- subagent sessions (role=delegated) are delegated.

SELECT
    e.session_id                                             AS coordinator_session_id,
    STRFTIME(CAST(MIN(e.ts) AS TIMESTAMP), '%Y-W%V')        AS iso_week,
    COUNT(CASE WHEN e.role = 'coordinator-inline'
               AND e.kind = 'tool_call'               THEN 1 END) AS inline_tool_calls,
    COUNT(CASE WHEN e.role = 'delegated'
               AND e.kind = 'tool_call'               THEN 1 END) AS delegated_tool_calls,
    ROUND(
        COUNT(CASE WHEN e.role = 'delegated' AND e.kind = 'tool_call' THEN 1 END)::DOUBLE
        /
        NULLIF(COUNT(CASE WHEN e.kind = 'tool_call' THEN 1 END), 0)
    , 4)                                                           AS delegate_ratio,
    COUNT(CASE WHEN e.kind = 'dispatch' THEN 1 END)               AS dispatch_count
FROM read_ndjson_auto('events.jsonl') AS e
WHERE e.kind IN ('turn', 'tool_call', 'dispatch')
GROUP BY e.session_id
ORDER BY e.session_id;

-- plan-rollup.sql
-- Guards: T.P1.3 DoD (a), TP1.T5 DoD (a)
-- Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
--
-- Implements §Q1 token-cost primary metric and §Q2 plan-stage rollup.
-- Returns one row per (planSlug, stage, agentId) with all four token columns,
-- wall_active_minutes (§3 time-normalization: strips inter-turn gaps >90s via
--   wall_active_delta_s field — gaps >90s set to 0 by ingest.mjs),
-- turn count, and tool_call count.
--
-- Field names follow the events.jsonl schema: camelCase for session/agent/plan
-- identifiers (matching Claude JSONL conventions), snake_case for token counts
-- and custom fields.
--
-- Phase-2 boundary: no feedback-bound or decision-bound columns in this query.

SELECT
    e.planSlug                            AS plan_slug,
    e.stage,
    e.agentId                             AS agent_id,
    SUM(e.input_tokens)::BIGINT            AS tokens_input,
    SUM(e.output_tokens)::BIGINT           AS tokens_output,
    SUM(e.cache_read_input_tokens)::BIGINT AS tokens_cache_read,
    SUM(e.cache_creation_input_tokens)::BIGINT AS tokens_cache_creation,
    ROUND(SUM(
        CASE
            WHEN e.wall_active_delta_s <= 90 THEN e.wall_active_delta_s
            ELSE 0
        END
    ) / 60.0, 4)                          AS wall_active_minutes,
    COUNT(CASE WHEN e.kind = 'turn' THEN 1 END)::BIGINT      AS turns,
    COUNT(CASE WHEN e.kind = 'tool_call' THEN 1 END)::BIGINT AS tool_calls
FROM read_ndjson_auto('events.jsonl') AS e
WHERE e.kind IN ('turn', 'tool_call')
  AND e.planSlug IS NOT NULL
GROUP BY e.planSlug, e.stage, e.agentId
ORDER BY e.planSlug, e.stage, e.agentId;

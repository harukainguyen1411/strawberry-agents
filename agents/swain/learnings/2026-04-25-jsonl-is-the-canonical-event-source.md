# JSONL + per-spawn subagents/ is the canonical event source for plan/coordinator dashboards — not OTel

When designing observability for the agent system, the temptation is to recommend OpenTelemetry as the primary event source (Anthropic-blessed, query_source attribute, retry semantics, etc.). Lux's research did exactly this. But OTel requires `CLAUDE_CODE_ENABLE_TELEMETRY=1` exported per shell — it is opt-in per process, not project-pinned. We have ~1669 historical sentinels worth of pre-OTel data; making OTel primary would force a dual-source bridge for backfill anyway.

The deterministic, unconditionally-produced source is two-tier:

- `~/.claude/projects/<slug>/<session-id>.jsonl` — every assistant turn carries `usage.{input_tokens, output_tokens, cache_read_input_tokens, cache_creation_input_tokens, service_tier, speed, model}`. Verified locally on `db2e8cdf-...jsonl` — schema is real and stable.
- `~/.claude/projects/<slug>/<session-id>/subagents/agent-<id>.{jsonl,meta.json}` — per-spawn ground truth: parent `sessionId`, `agentType`, `description` (= the Task tool's prompt label, ≤80 chars), full per-turn usage, and the verbatim first-user-message (the dispatching coordinator's prompt body). This is what unlocks deterministic prompt-quality metrics WITHOUT a paid API call: prompt length, structured-section count via regex, output-token-vs-prompt-token compression ratio.

Inline-vs-delegate discrimination at the coordinator level: parent JSONL = coordinator inline; child `subagents/agent-<id>.jsonl` = delegated. `CLAUDE_AGENT_NAME` is NOT in JSONL records (env var consumed by hooks only) — use the path discriminator.

Plan-stage attribution: Orianna's `chore: promote <slug> to <stage>` commit subject + `Promoted-By: Orianna` trailer is the canonical signal; plan-file `status:` frontmatter mtime is corroboration; dispatch-prompt slug-match against `plans/(proposed|approved|in-progress)/.+\.md` is fallback for in-flight work where no commit yet exists.

Lesson: when an LLM-research agent hands you a stack recommendation that requires standing up Postgres+ClickHouse+Redis+MinIO (Langfuse) at the scale of "thousands of records and growing single-digit-per-day", reject for v1 even if the trace-tree UI is gorgeous. DuckDB on the JSONL is a 30ms scan. Token cost is the headline metric (deterministic); wall-clock is secondary, idle-detected (>90s gap stripped). Re-evaluate Langfuse only when interactive trace-graph drilling exceeds 1×/week or evals are added.

---
date: 2026-04-25
author: lux (extracted from transcript by skarner)
category: research
concern: personal
target: Build-vs-buy research for the retrospection dashboard cornerstone plan
state: complete
owner: lux
session: db2e8cdf-06d6-4cc9-98f6-885e346b857d
source-session: db2e8cdf-06d6-4cc9-98f6-885e346b857d
purpose: Build-vs-buy research for the retrospection dashboard cornerstone plan
---

# Agent Observability Tooling Research

## Dispatch brief

[

## Lux return (verbatim)

I have everything I need. Composing the deliverable now.

---

# Build vs Buy: Retrospection Dashboard — Research Findings

## 1. What the docs page actually says

Source: [Claude Code — Monitoring](https://code.claude.com/docs/en/monitoring-usage)

- **Native telemetry path is OpenTelemetry, not a hosted dashboard.** Anthropic ships an OTel exporter inside the CLI; the user supplies the collector + storage + UI. Toggle: `CLAUDE_CODE_ENABLE_TELEMETRY=1`. Three signals: metrics, logs/events, and **distributed traces (beta)** behind `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1`.
- **Metrics emitted (8 of them):** `claude_code.session.count`, `lines_of_code.count`, `pull_request.count`, `commit.count`, **`cost.usage` (USD)**, **`token.usage` (count, with `type=input|output|cacheRead|cacheCreation`)**, `code_edit_tool.decision`, `active_time.total`. Crucially the cost & token metrics carry a **`query_source` attribute** with values `"main" | "subagent" | "auxiliary"` and **`model`** + **`effort`** — so subagent token attribution *is* exposed at the OTel layer (just not at the SDK / hooks layer).
- **Events emitted (~16 types):** `user_prompt`, `tool_result`, `api_request`, `api_error`, `api_request_body`, `api_response_body`, `tool_decision`, `permission_mode_changed`, `mcp_server_connection`, `compaction`, `hook_execution_start`, `hook_execution_complete`, `skill_activated`, `plugin_installed`, `api_retries_exhausted`, `internal_error`, `auth`. All carry a **`prompt.id`** correlation UUID linking everything triggered by one user turn.
- **Trace span hierarchy is exactly what we need for a "agent-as-graph" view:** `claude_code.interaction` → (`llm_request` | `tool` | `hook`) → `tool.blocked_on_user` + `tool.execution`; **subagent llm_request / tool spans nest under the parent's `claude_code.tool` span.** `query_source` on a subagent llm_request *is the subagent name*. Bash subprocesses inherit `TRACEPARENT` so we could parent spans from our own scripts (e.g. Orianna promotion, hook scripts) under the same trace.
- **Per-tool-call attribution at the OTel layer is rich:** `tool_result` events include `tool_name`, `tool_use_id`, `success`, `duration_ms`, `tool_input_size_bytes`, `tool_result_size_bytes`, and (with `OTEL_LOG_TOOL_DETAILS=1`) a `tool_parameters` JSON that for Bash calls includes **`git_commit_id`** — meaning we can correlate tool calls to commits without parsing git separately.
- **Anthropic publishes a turnkey self-hosted stack:** [anthropics/claude-code-monitoring-guide](https://github.com/anthropics/claude-code-monitoring-guide) — Docker Compose with OTel collector + Prometheus + Grafana, includes `/grafana` dashboards and a Linear-integration report generator. Per-user / per-session / per-model attribution is built in. **No plan/PR/lifecycle attribution** — that's the gap we'd fill.
- **Privacy gates for sensitive content:** `OTEL_LOG_USER_PROMPTS`, `OTEL_LOG_TOOL_DETAILS`, `OTEL_LOG_TOOL_CONTENT`, `OTEL_LOG_RAW_API_BODIES`. All default off.
- **The docs say nothing about the `~/.claude/projects/<slug>/<session-id>.jsonl` session files.** That file format is undocumented officially; it's reverse-engineered by community projects (ccusage, claude-code-log, claude-JSONL-browser).

## 2. The JSONL story

Sources: [Inside Claude Code session file format (Yi Huang, Feb 2026)](https://databunny.medium.com/inside-claude-code-the-session-file-format-and-how-to-inspect-it-b9998e66d56b), [claude-code-log](https://github.com/daaain/claude-code-log), [Liam ERD: DuckDB analysis](https://liambx.com/blog/claude-code-log-analysis-with-duckdb), [ccusage source](https://github.com/ryoppippi/ccusage).

**Schema (community-derived; stable enough that ccusage & claude-code-log depend on it):**

```
Envelope (every line):
  type, uuid, parentUuid, timestamp, sessionId, cwd, message
Types: user | assistant | tool_result | system | summary | result | file-history-snapshot
assistant.message.usage:
  input_tokens, output_tokens, cache_read_input_tokens,
  cache_creation: { ephemeral_5m_input_tokens, ephemeral_1h_input_tokens }
assistant.message.content[]: text | tool_use | thinking
tool_use shape:  { id, name, input }                  ← Task tool input.subagent_type names the spawned agent
tool_result shape: { tool_use_id, content, is_error }
Subagent linking (per Yi Huang): metadata fields parentToolUseId, agentId, agentType, teamName;
  each subagent's full transcript lives in its own .jsonl in the same projects/<slug>/ dir.
file-history-snapshot at session start: staged/unstaged/untracked git state.
```

**What this gives us for Duong's metrics, deterministically, no LLM:**

| Need | Field/derivation |
|---|---|
| Per-turn input/output/cache tokens | `assistant.message.usage.*` |
| Cost | derive from tokens × Anthropic price table (ccusage already does this with `--offline` cache) |
| Subagent identity | `tool_use` where `name="Task"` → `input.subagent_type`; child `.jsonl` linked via `parentToolUseId` |
| Phase attribution | `tool_use` for Bash → with `OTEL_LOG_TOOL_DETAILS=1` includes `git_commit_id`; otherwise re-parse via cwd + branch + commit hash + plan-file path Edit/Write tool calls |
| Plan-file lifecycle transitions | `tool_use` for `Edit/Write/Bash:git mv` whose path is under `plans/proposed/` → `plans/approved/` etc. (Orianna identity provable via the `STRAWBERRY_AGENT` env / agent-name field) |
| Off-track signals (revision rounds, scope creep) | git log on the plan file's path (status frontmatter changes), branch churn, PR review-comment counts via `gh api` |
| Time on phase | `timestamp` deltas between first and last assistant turn whose tool calls touched the plan path or its associated branch |
| Session boundaries | one session = one `.jsonl`; session start = `file-history-snapshot`; session end = `result` record |

**What's missing from JSONL alone** (and what OTel/git provides):
- **No cost USD** — JSONL gives only tokens; cost is computed (ccusage's job).
- **No `query_source`/`speed`/`effort`** in the JSONL `usage` block — those are OTel-only.
- **No retries / API errors** — silent in JSONL, visible only in OTel `api_error` events.
- **No PostToolUse hook payloads in JSONL** — hook stdout/stderr lives only where we redirect it.

**Sampling we'd want before committing**: pick one recently-implemented plan, walk every `.jsonl` it touched (parent + subagents), confirm we can reconstruct (a) every commit on the plan's branch, (b) every Senna/Lucian review session, (c) Orianna's promotion. About one hour of tooling on a real session would validate this.

## 3. Build-vs-buy table

### A. Anthropic-native

| Tool | What it gives us | Gaps | Local-first | Cost | Verdict |
|---|---|---|---|---|---|
| **OTel exporter** ([docs](https://code.claude.com/docs/en/monitoring-usage)) | Per-prompt traces, per-subagent token attribution via `query_source`, hook spans, MCP events, retries, compaction events, cost in USD | Needs a backend; no plan-lifecycle awareness | Yes | Free | **Adopt.** Strict superset of JSONL for observability. |
| **claude-code-monitoring-guide** ([repo](https://github.com/anthropics/claude-code-monitoring-guide)) | Docker Compose w/ OTel collector + Prometheus + Grafana + dashboards | No plan/PR attribution; Linear-shaped not directory-shaped | Yes | Free | **Partial fit — fork as base.** |
| **ccusage** ([repo](https://github.com/ryoppippi/ccusage)) | JSONL parser, daily/monthly/session/blocks reports, `--instances`, `--project`, `--json`, MCP server, statusline | No subagent attribution ([rejected upstream](https://github.com/anthropics/claude-code-issues/issues/22625) — *but issue is about *runtime* tracking; ccusage with subagent jsonl files can already show per-subagent rollups via `--instances`*); no plan attribution | Yes | Free | **Adopt for cost layer.** Already in our stack. |
| **Hook events (PostToolUse, SubagentStop, Stop)** | Real-time per-tool-call payloads; we already parse them | We must self-record and self-correlate | Yes | Free | **Already used.** Useful for plan-state-transition hooks. |
| **Anthropic Console dashboard** | Org-level cost rollups | Cloud-only, no agent / plan / session granularity | No | Free | **No** for this use case. |
| **Per-subagent token tracking issue** ([#22625](https://github.com/anthropics/claude-code-issues/issues/22625)) | — | **Closed not-planned.** OTel `query_source` is Anthropic's answer. | — | — | Don't wait for it. |

### B. Open-source agent observability

| Tool | What it gives us | Gaps | Local-first | Cost | Verdict |
|---|---|---|---|---|---|
| **Langfuse** ([Claude Agent SDK integration](https://langfuse.com/integrations/frameworks/claude-agent-sdk), [Claude Code Stop-hook recipe](https://langfuse.com/integrations/other/claude-code), [self-hosted template](https://github.com/doneyli/claude-code-langfuse-template)) | Trace tree UI w/ parent→subagent nesting, per-trace cost, tags, session grouping, evals; consumes OTel directly | Heavy stack (Postgres + ClickHouse + Redis + MinIO); plan-lifecycle still our code | Yes (Docker self-host) | Free OSS | **Strongest single candidate for the trace UI.** |
| **Phoenix (Arize OSS)** ([repo](https://github.com/Arize-ai/phoenix), [skill](https://mcpmarket.com/tools/skills/arize-claude-code-tracing)) | OpenInference span schema, local launch, eval framework, simpler than Langfuse | Eval-heavy framing; less polished agent-graph UI than Langfuse | Yes | Free OSS | **Partial fit** — pick if we want evals later. |
| **Helicone** | Proxy-based LLM observability | Proxy model — Claude Code already has an OTel exporter; double instrumentation | Self-host possible | Free OSS tier | **No.** Wrong shape. |
| **AgentOps / PromptLayer / W&B Weave / LangSmith / OpenLIT** | Various dashboards | LangSmith is LangChain-shaped & cloud; AgentOps/PromptLayer/Weave are SaaS-default; OpenLIT is OTel-native but thinner UI | Mixed | Mostly paid SaaS | **No.** |

### C. General-purpose dev observability

| Tool | What it gives us | Gaps | Local-first | Cost | Verdict |
|---|---|---|---|---|---|
| **Grafana + Prometheus + Loki (+ Tempo)** | Already what `claude-code-monitoring-guide` ships; metrics + logs + traces; flexible dashboards | Build dashboards ourselves; no agent-trace-tree UI | Yes | Free | **Adopt** as the metrics surface. |
| **SigNoz / OpenObserve** | Single-binary OTel backend, all-in-one UI | Less polished agent UX; either replaces Grafana or duplicates it | Yes | Free OSS | **Partial fit** if we want one binary instead of three. |
| **Honeycomb / Datadog / New Relic** | Excellent trace UI | Paid, cloud-only | No | $$$ | **No.** |

### D. Plan-lifecycle / engineering metrics

| Tool | What it gives us | Gaps | Local-first | Cost | Verdict |
|---|---|---|---|---|---|
| **DORA dashboards (e.g., Apache DevLake, Sleuth, LinearB)** | Lead time, deploy freq, change-failure rate from git+PR | Org-shaped; expects squads; doesn't model `proposed → approved → in-progress → implemented` directory transitions; doesn't connect to Claude token usage | DevLake = self-host OSS; others = SaaS | DevLake free; rest paid | **No** for the core; **maybe** revisit DevLake later for DORA-style commit-velocity metrics. |
| **GitHub Insights** | Free, already there | Repo-level only; no per-plan attribution | Cloud | Free | **No** — too coarse. |

### E. JSONL-specific tooling

| Tool | What it gives us | Verdict |
|---|---|---|
| [**ccusage**](https://github.com/ryoppippi/ccusage) | Cost & token rollups from JSONL, MCP server, JSON output for piping | **Adopt** (already in use). Use `--json --instances` to feed our own joiner. |
| [**claude-code-log**](https://github.com/daaain/claude-code-log) (daaain) | Python parser → HTML transcript viewer | **Reference implementation** — read source for schema confidence, don't depend on. |
| [**simonw/claude-code-transcripts**](https://github.com/simonw/claude-code-transcripts) | Publishing transcripts | Skip. |
| [**withLinda/claude-JSONL-browser**](https://github.com/withLinda/claude-JSONL-browser) | Web file explorer for JSONL | Skip. |
| [**Liam ERD's DuckDB pattern**](https://liambx.com/blog/claude-code-log-analysis-with-duckdb) | `duckdb` over a directory of `.jsonl` for ad-hoc SQL | **Strong tactical fit.** DuckDB on `~/.claude/projects/**/*.jsonl` is a one-liner that answers most ad-hoc queries deterministically. Use this for the analyst surface. |
| [**TechNickAI/claude_telemetry**](https://github.com/TechNickAI/claude_telemetry) | OTel wrapper that swaps `claude` for `claudia` | Skip — Anthropic's first-party OTel makes this redundant. |

## 4. Recommendation

**Adopt three OSS components and write a thin glue layer. No greenfield dashboard.**

1. **Turn on Anthropic OTel** (`CLAUDE_CODE_ENABLE_TELEMETRY=1` + traces beta). This gives us `query_source=subagent`, retries, hooks, compaction, MCP events that JSONL alone does not.
2. **Run Langfuse self-hosted via Docker Compose.** Point the OTel exporter at it. We get the agent-trace-tree UI for free; subagent spans nest correctly under parent `claude_code.tool` spans (per the docs), so the "Evelynn → Aphelios → Caitlyn" graph view that Duong wants is rendered without any UI code from us.
3. **Keep ccusage for cost rollups + add DuckDB for ad-hoc.** ccusage's `--json --instances` already groups by project. DuckDB over the JSONL tree handles every "how many revision rounds did plan X take" SQL question deterministically.

**What we still write — small, single-responsibility scripts:**

- `tools/plan-lifecycle-events.sh` — emits a custom OTel span (or appends to `~/.claude/strawberry-usage-cache/plan-events.jsonl`) on every plan-status transition. Hook it from the existing `pretooluse-plan-lifecycle-guard.sh` and Orianna's promotion path. Inherits `TRACEPARENT` so the span lives in the same Langfuse trace.
- `tools/plan-cost-rollup.sh` — joins three sources by `(plan_path, branch, commit_sha)`:
  (a) `ccusage --json` for tokens/cost,
  (b) `git log` for phases (proposal → review → merge),
  (c) plan-events stream for status transitions.
  Outputs one row per plan with phase-bucketed cost. This is the "dashboard table" — render in a Grafana panel via Prometheus textfile-collector, or just `column -t`.
- (Optional) `tools/off-track-signals.sh` — pure git+gh queries: PR review-rejection count, force-pushes, plan-status backwards transitions, abandoned branches.

**The "dashboard" we author is a join + skin, not a UI.** Three views:
1. **Per-plan table** (our script, plain text or one Grafana panel) — phase × tier × tokens × cost × wall-clock.
2. **Trace tree** (Langfuse, free) — drill into any plan's session graph.
3. **Off-track signals** (our script) — deterministic counters, no LLM.

**Confidence: medium-high.** The OTel + Langfuse path is well-trodden and Anthropic-blessed. The one risk is whether the JSONL `parentToolUseId`/`agentId` fields (community-documented, not officially specified) survive a Claude Code update — mitigated because OTel `query_source` is the official channel and our scripts can fall back to it.

## 5. Open questions for Duong

1. **Telemetry privacy gate:** `OTEL_LOG_TOOL_DETAILS=1` is needed to get `git_commit_id` and Bash command strings into events — this is the cheapest path to commit-to-plan correlation. Acceptable to enable for personal concern? Work concern? (We'd never need `OTEL_LOG_RAW_API_BODIES`.)
2. **Scope:** Personal concern only, or include the work-concern repo (`mmp/workspace/`) where the same agent system runs? They share `~/.claude/projects/`.
3. **UI tolerance:** Is "Langfuse + a CLI table + the existing Grafana dashboards from `claude-code-monitoring-guide`" enough, or does Duong want a single bespoke web page? The recommendation assumes the former.
4. **Backfill:** ~1655 entries in `subagent-sentinels/` and existing `~/.claude/strawberry-usage-cache/agents.json` (1MB) suggest historical data exists. Do we want to backfill into Langfuse, or only forward-instrument from cutover day? Backfill is feasible (replay JSONL → OTel) but adds work.
5. **Sampling validation:** Should I (or another agent) pick one implemented plan and trace its `.jsonl` graph end-to-end *before* we commit a build path, to confirm the schema fields actually correlate the way we think they do? About 1 hour.
6. **Plan complexity tier:** Where does "complexity tier" live today — frontmatter on the plan file, or assigned post-hoc? The rollup script needs a deterministic source.

---

Sources:
- [Claude Code — Monitoring usage](https://code.claude.com/docs/en/monitoring-usage)
- [anthropics/claude-code-monitoring-guide](https://github.com/anthropics/claude-code-monitoring-guide)
- [ccusage CLI](https://github.com/ryoppippi/ccusage) and [docs](https://ccusage.com/guide/)
- [Per-subagent token usage tracking — issue #22625 (closed not-planned)](https://github.com/anthropics/claude-code-issues/issues/22625)
- [Yi Huang — Inside Claude Code: The Session File Format](https://databunny.medium.com/inside-claude-code-the-session-file-format-and-how-to-inspect-it-b9998e66d56b)
- [daaain/claude-code-log](https://github.com/daaain/claude-code-log)
- [Liam ERD — Analyzing Claude Code logs with DuckDB](https://liambx.com/blog/claude-code-log-analysis-with-duckdb)
- [Langfuse — Claude Agent SDK integration](https://langfuse.com/integrations/frameworks/claude-agent-sdk)
- [Langfuse — Trace Claude Code](https://langfuse.com/integrations/other/claude-code)
- [doneyli/claude-code-langfuse-template (self-hosted)](https://github.com/doneyli/claude-code-langfuse-template)
- [Arize Phoenix](https://github.com/Arize-ai/phoenix) and [OpenInference](https://github.com/Arize-ai/openinference)
- [TechNickAI/claude_telemetry](https://github.com/TechNickAI/claude_telemetry) (referenced for completeness, not recommended)

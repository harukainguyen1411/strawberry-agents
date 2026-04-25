---
status: proposed
concern: personal
owner: swain
created: 2026-04-25
tests_required: true
complexity: complex
tags: [dashboard, observability, retrospection, canonical-v1, otel, plan-lifecycle, coordinator-metrics]
related:
  - plans/approved/personal/2026-04-21-agent-feedback-system.md
  - plans/approved/personal/2026-04-21-coordinator-decision-feedback.md
  - plans/archived/personal/2026-04-21-retrospection-dashboard.md
  - plans/pre-orianna/proposed/2026-04-19-usage-dashboard-subagent-task-attribution.md
  - assessments/research/2026-04-25-agent-observability-tooling.md
  - architecture/plan-lifecycle.md
  - architecture/coordinator-memory.md
architecture_impact: refactor
---

# Retrospection Dashboard + Canonical Agent System v1

## 1. Executive summary

Build a deterministic plan-centric retrospection dashboard sourced from the data we already produce — JSONL transcripts, per-spawn `subagents/agent-<id>.{jsonl,meta.json}`, plan-file mtime/git-history, and Orianna's `Promoted-By` commit trailer. Token cost is the canonical effort metric (deterministic); wall-clock is secondary, annotated with idle-detection. No new database in v1 — DuckDB-over-JSONL + a small static-HTML generator. Lux's Langfuse recommendation is rejected for v1 (heavy stack, premature complexity); reconsidered as v2 if specific trace-graph queries justify it. The dashboard adds a coordinator drill-down — Evelynn and Sona each have a per-session view of dispatch-vs-inline-tool-use, prompt length/structure, and route choice. Canonical v1 freezes the agent system for a one-week measurement window; weekend retro produces a v1→v2 ADR. This plan ships **after** the two approved feedback plans because it consumes their events.

## 2. Position on the seven (now nine) architectural questions

### Q1 — Deterministic metric source

**Position: hybrid, with token cost as primary and a single canonical event log built by a thin scanner.**

The canonical event log is `~/.claude/strawberry-usage-cache/events.jsonl` — append-only, one record per atomic event (turn, tool call, plan-stage transition, dispatch start/end, commit). It is **derived** every 5 minutes from four upstream sources, none authored ourselves:

1. `~/.claude/projects/<slug>/<session-id>.jsonl` for every assistant turn's `usage` block (verified locally — `input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`, `service_tier`, `speed`, `model`).
2. `~/.claude/projects/<slug>/<session-id>/subagents/agent-<id>.{jsonl,meta.json}` for every subagent spawn (parent `sessionId`, `agentType`, `description` = the Task tool's prompt label, full per-turn usage, the verbatim first-user-message = the dispatching coordinator's prompt body).
3. `~/.claude/strawberry-usage-cache/subagent-sentinels/<agent-id>` (zero-byte, mtime = SubagentStop time) for clean-close attestation.
4. `git log` over `plans/**` and over commit messages with `Promoted-By: Orianna` / `Orianna-Phase:` / `Promoted-By:` trailers, plus plain-prefix `chore: promote <slug> to <stage>` subjects.

Token cost is primary because it is byte-deterministic and free of network/idle confounds. Wall-clock is secondary, computed as `last_assistant_ts − first_assistant_ts` per (plan, agent, stage), then **subtracted** of any inter-turn gap > 90 seconds (defined as "idle"). Both numbers ship side-by-side; the UI labels wall-clock as `wall (active)` so its semantics are explicit. USD cost is computed by `ccusage` (already in our stack) — we do not re-implement the price table.

**Why not OTel as primary:** OTel requires every session to start with `CLAUDE_CODE_ENABLE_TELEMETRY=1` exported. It is opt-in per shell, not project-pinned, and we have ~1669 historical sentinels worth of pre-OTel data we'd have to dual-source anyway. JSONL+sentinels are produced unconditionally. **OTel is added as a second-stream enrichment** in Phase 2 — it gives us `query_source`, retry counts, and the subagent dispatch trace tree — but the dashboard works without it.

### Q2 — Plan-stage event detection

**Position: three-signal layered detection — git trailer is canonical, plan-file frontmatter mutation is corroborative, dispatch-prompt text-match is fallback.**

| Signal | Source | Strength | Gap |
|---|---|---|---|
| Orianna promotion commit | `git log` subject `chore: promote <slug> to <stage>` + trailer `Promoted-By: Orianna` | **Canonical for stage transitions** (proposed→approved, approved→in-progress, in-progress→implemented). Already produced today. | Only fires at promotion boundaries. |
| Plan-file `status:` frontmatter mtime | `git log -p plans/**.md` for `^[+-]status:` lines | Strong corroboration; matches the Orianna commit. | Could drift if hand-edited. |
| Dispatch-prompt slug match | the verbatim first-user-message of `agent-<id>.jsonl` searched for the plan slug | Attributes work to a plan when no commit yet exists (e.g. Aphelios is breaking down right now). | Fuzzy — relies on the coordinator citing the plan path in the prompt. |

**Process change required:** none for stage transitions (Orianna already emits the canonical trailer). One soft requirement for in-flight attribution — coordinator dispatch prompts MUST cite the plan slug or file path verbatim within the first 200 chars. This is already the convention but is not enforced. We add a coordinator-side soft-lint, not a hook.

The scanner emits a synthetic `plan-stage` event into `events.jsonl` for each detected (plan, stage, start_ts, end_ts) tuple. End-ts is the next stage's start-ts or `null` if open.

### Q3 — Storage and query layer

**Position: DuckDB on the JSONL event stream, no managed DB. Reject Langfuse for v1.**

Lux's Langfuse self-host stack (Postgres + ClickHouse + Redis + MinIO via Docker Compose) is correct in capability but wrong for our scale. At ~1669 historical subagent spawns and growing at single-digit-per-day, the marginal benefit of Langfuse's trace UI does not justify operating four background services. A 100MB JSONL file is a 30ms DuckDB scan.

**Concrete shape:**

- `events.jsonl` (append-only; the Phase-1 scanner builds it and updates incrementally via per-source mtime cache).
- `tools/retro/queries/*.sql` — DuckDB SQL files, one per query (per-plan rollup, coordinator weekly, etc.).
- `tools/retro/render.mjs` — runs each query, writes `dist/data/*.json`, then a static-HTML generator builds the dashboard.

**Re-evaluate Langfuse if v2** any of these triggers fire: (a) Duong wants to *interactively* drill into single-trace span trees more than 1×/week (DuckDB CLI is fine for queries; trace tree viz is what Langfuse wins on); (b) we add evals; (c) total event volume passes 5M rows.

### Q4 — Dashboard UI

**Position: static-HTML-from-script, regenerated after each ingest tick. Reject SPA framework. Reject Langfuse UI.**

The dashboard's read-pattern is overwhelmingly *list a thing, drill into one*. Plans-list → plan-detail; coordinator-list → coordinator-session-detail. Every state is a URL; every URL is a static file. A pre-rendered static site eliminates the entire client-side data-loading + state-management layer that the archived plan's Vue + Pinia + vue-router proposed. The retro-indexer regenerates the static tree every 5 minutes via the same scanner that produces `events.jsonl`.

**Concrete shape:**

- `tools/retro/render.mjs` reads DuckDB query outputs and emits ~50–500 small HTML files into `tools/retro/dist/`.
- One `index.html`, one `plan-<slug>.html` per plan, one `coordinator-<name>-week-<iso-week>.html` per coordinator-week.
- Plain CSS + a tiny `app.css`. No Vue, no Pinia, no router. One vanilla `<script>` for client-side filter/sort.
- Served as `file://` for v1; `npx serve` for the Bloomberg-density panel work later.

**Why this beats Langfuse-UI:** Langfuse renders span trees beautifully but knows nothing about plan lifecycle. The "drill into a plan" surface — the centerpiece of Duong's brief — is bespoke either way; static HTML is the cheaper bespoke.

### Q5 — Cost ceiling

**Position: $0/month for v1. Hard ceiling $20/month. Anthropic API + paid SaaS only.**

All v1 components (DuckDB, JSONL parsing, ccusage, static HTML) are free and local. The only paid axis we'd cross is if we add an Anthropic API call for, e.g., automated prompt-quality grading (§Q9). Trigger to cross zero: a measured weekly retro that names a specific query unsolvable by deterministic means.

### Q6 — Canonical agent system v1 lock — process design

**Position: a freeze tag, a one-page lock manifest, weekend retro by Evelynn-driven dispatch, two-line bypass discipline.**

**v1 lock manifest** at `architecture/canonical-v1.md`. One page, hand-curated. Names exactly: (a) the agent defs covered (every `.claude/agents/*.md` SHA at lock-tag time); (b) the routing rules in `agents/memory/agent-network.md` SHA; (c) the universal invariants in `CLAUDE.md` rules 1-21 SHAs; (d) the hooks in `.claude/settings.json` SHAs; (e) the lock-tag git ref `canonical-v1`.

**Lock semantics during the measurement week:**

- No edits to any file in (a)–(d) except: bug fixes that restore stated behaviour (not new behaviour), documentation typo fixes, and infrastructure-restoring hotfixes.
- Bypass discipline: any in-week edit MUST add a `Lock-Bypass: <reason>` trailer to the commit AND log to `architecture/canonical-v1-bypasses.md`. No `--no-verify`. No skipping the log.
- Plans may still be authored, promoted, executed, merged. v1-lock is about the *system* (agents/routing/hooks) — not about output.

**Weekend retro (Saturday 09:00 Asia/Bangkok, hand-triggered initially, scheduled in v2):**

- Owner: Evelynn dispatches Lux + Karma + Swain.
- Inputs: the past week's `events.jsonl` slice + `feedback/INDEX.md` open entries + `architecture/canonical-v1-bypasses.md`.
- Output: an ADR `plans/proposed/personal/YYYY-MM-DD-canonical-v2-rationale.md` authored by Swain. Specifies which v1 elements to change and why, with the dashboard query that justified each change cited inline.
- Promotion via Orianna; v2 lock-tag follows the same regime.

**Hotfix-bypass to lock during the week:** anything blocking >2 agents or breaking a paid pipeline is a hotfix candidate. Evelynn marks the bypass file with `severity: high`; Saturday's retro must reconcile (either codify the hotfix into v2 or revert).

### Q7 — Sequencing across the three cornerstone plans

**Position: feedback-system → decision-feedback → dashboard, in that order, with two amendments to lock the schema contracts.**

The dashboard *consumes* events that the other two plans *emit*. Shipping it first would render empty rows. Shipping it last with no schema contract risks a refactor when feedback/decision shapes change.

| Order | Plan | Why this position |
|---|---|---|
| 1 | `2026-04-21-agent-feedback-system.md` (approved) | Defines `feedback/INDEX.md` and the per-entry frontmatter — the dashboard's "system health" tile reads it. Schema is already declared in the approved plan §D8 ("Shared-schema commitments with sibling plans"). No new dependency. |
| 2 | `2026-04-21-coordinator-decision-feedback.md` (approved) | Defines `agents/<coordinator>/memory/decisions/INDEX.md` — the coordinator drill-down (Q8) reads decision pick-vs-prediction match-rates as a calibration metric. |
| 3 | This plan (proposed) | Consumer. |

**Amendments required:**

- (a) Append a §D11 to `2026-04-21-agent-feedback-system.md` listing the dashboard's exact column reads from `feedback/INDEX.md` so any future schema change blocks on the dashboard's compatibility window.
- (b) Append a §3.5 to `2026-04-21-coordinator-decision-feedback.md` declaring `axes`, `match`, `coordinator_confidence`, `decision_id` as the dashboard's bind-points.

Both amendments are 5–15 line appends — Karma's quick-lane.

### Q8 — How is coordinator inline-work vs delegation discriminated?

**Position: top-level session JSONL (no `parentToolUseId`, no `isSidechain: true`) = coordinator inline; subagent transcript (under `subagents/agent-<id>.jsonl`) = delegated. Confirmed by spot-check.**

Every `assistant` row in JSONL carries either `isSidechain: true` (= a subagent) or absence (= the parent/coordinator). The coordinator session is identifiable because it lives at `~/.claude/projects/<slug>/<session-id>.jsonl` (no `subagents/` parent path) and its `cwd` matches the coordinator concern's repo root. `CLAUDE_AGENT_NAME` is **not reliably present** in JSONL records (it's an env var read by hooks). Use the path discriminator.

The dashboard computes per-session: `inline_tool_calls = sum of tool_use rows in the parent jsonl`; `delegated_tool_calls = sum of tool_use rows in any child subagents/*.jsonl whose parent points to this session`. Ratio = `delegated / (inline + delegated)`. Coordinator's prime directive ("coordinate, don't execute") is healthy at >0.7; <0.5 is drift; flag in the dashboard.

### Q9 — How is prompt quality measured deterministically?

**Position: three deterministic signals + one render-and-eyeball, no Anthropic API in v1.**

| Signal | Computed how | What it catches |
|---|---|---|
| Prompt length distribution | char/token count of the first user-message in `subagents/agent-<id>.jsonl` | Too short (under-spec'd dispatches), too long (rambling) |
| Structured-section count | regex count of `^##` headers, `[concern: ...]` tag presence, plan-path citations matching `plans/(proposed|approved|in-progress)/.+\.md` | Missing concern tag, missing plan citation, no section structure |
| Compression signal | `subagent_total_output_tokens / dispatch_prompt_tokens` ratio | Wandering returns vs tight returns; very high = subagent did a lot per byte of guidance, very low = clarification loop |

These three are computed for every dispatch; surfaced in the coordinator drill-down as a histogram and a per-dispatch table. Outliers (top 5 / bottom 5 by each metric, weekly) are linked to the underlying prompt for Duong to eyeball.

**Punt to v1.5 (gated):** an explicit reviewer-agent grading pass — Lux scans recent dispatches and tags them `clear / acceptable / wandering / under-spec'd`. Adds Anthropic cost (~$0.50/week at current dispatch rate); only enabled if deterministic signals miss systematic quality drift in week-1's retro.

## 3. Concrete proposed architecture

```
~/.claude/projects/<slug>/                    [unchanged — Anthropic-managed]
~/.claude/strawberry-usage-cache/
  ├── events.jsonl                            [NEW — single canonical event log]
  ├── events.mtimecache                       [NEW — per-source file mtime tracker]
  ├── ccusage outputs                         [unchanged]
  └── subagent-sentinels/                     [unchanged]

tools/retro/
  ├── ingest.mjs                              [NEW — scans 4 sources, appends events.jsonl]
  ├── queries/
  │   ├── plan-rollup.sql                     [per-plan stage × cost matrix]
  │   ├── coordinator-weekly.sql              [Evelynn/Sona inline-vs-delegate, prompt stats]
  │   ├── coordinator-vs-coordinator.sql      [side-by-side, same-week]
  │   ├── feedback-rollup.sql                 [reads feedback/INDEX.md row counts]
  │   └── decision-rollup.sql                 [coord prediction vs Duong pick match-rate]
  ├── render.mjs                              [DuckDB-runs SQL, writes JSON, generates HTML]
  ├── templates/
  │   ├── index.html.tpl
  │   ├── plan-detail.html.tpl
  │   └── coordinator-detail.html.tpl
  └── dist/                                   [emitted static site, gitignored]

architecture/
  ├── canonical-v1.md                         [NEW — lock manifest]
  └── canonical-v1-bypasses.md                [NEW — bypass log]
```

**Ingest cadence:** every 5 minutes via `tools/retro/ingest.mjs --watch`, or on-demand via `npm run retro:ingest`. The render step reads the events file + queries and rebuilds `dist/` in <2s for the current data scale. No daemon, no service.

**Time normalization (Duong's "strip objective factors"):**

For every per-(plan, agent, stage) duration we report two columns: `tokens` (deterministic) and `wall_active_minutes` = `Σ Δt_i where Δt_i ≤ 90s` between consecutive assistant turns (90s gap = idle break). Network latency is folded into per-turn duration but is small (<3s typical) and dwarfed by reasoning time; we do not subtract it. We do not measure or report `wall_total` — too noisy to be useful. Tokens remain the headline metric.

## 4. Phasing

**Phase 1 — walking skeleton (3 sessions of agent work).** Targets: events.jsonl scanner, DuckDB queries for plan-rollup + coordinator-weekly, static-HTML index + plan-detail page. Ships when Duong can click a plan and see stage × agent × token cost rendered correctly for one historical implemented plan. ~6 tasks, ~280 min.

**Phase 2 — coordinator drill-down + feedback + decision integration.** Targets: coordinator-detail page with inline-vs-delegate ratio, prompt length/structure/compression histograms, decision-feedback match-rate; feedback open-entry tile on the home page. Depends on the two approved plans being in-progress or shipped. ~5 tasks, ~250 min.

**Phase 3 — canonical-v1 lock, weekend retro skill, prompt-quality v1.5 (gated).** Targets: `canonical-v1.md` manifest authored, `Lock-Bypass:` discipline documented, `/canonical-retro` skill scaffolded for Evelynn's Saturday dispatch, optional Lux grading pass behind a config flag. ~4 tasks, ~180 min.

**Total:** ~15 tasks, ~710 min, three phases.

## 5. Integration with the two approved feedback plans

```
                   ┌──────────────────────────────────┐
                   │  feedback/INDEX.md (approved A)  │──┐
                   └──────────────────────────────────┘  │
                                                          ▼
  ┌────────────────────────────────────┐    ┌─────────────────────────────┐
  │ decisions/INDEX.md (approved B)    │───▶│ tools/retro/ingest.mjs      │
  └────────────────────────────────────┘    │ + 4 upstream JSONL sources  │
                                            └─────────────────────────────┘
                                                          │
                                                          ▼
                                            events.jsonl + DuckDB queries
                                                          │
                                                          ▼
                                                    static dashboard
```

Sequencing: A then B then this plan, with two amendments locking the schema contracts so this plan does not re-open A or B.

## 6. v1-lock + weekend-retro process spec

See §Q6 above for the full spec. Summary:

- `architecture/canonical-v1.md` — one-page manifest pinning agent defs + routing + hooks + invariants + git ref.
- During the lock-week: edits to those files require `Lock-Bypass:` trailer + log entry; no `--no-verify`.
- Weekend retro: Evelynn dispatches Swain + Lux + Karma every Saturday 09:00; Swain authors `canonical-v2-rationale.md`; Orianna gates promotion.
- The dashboard surfaces the bypass log directly on its home page so drift is visible.

## 7. Open questions for Duong

**OQ1 — OTel toggle scope.** Enable `CLAUDE_CODE_ENABLE_TELEMETRY=1` and `OTEL_LOG_TOOL_DETAILS=1` for personal-concern only? OTel gives us `query_source` (subagent identity at the OTel layer, Anthropic-blessed) and `git_commit_id` in tool params. Lux flagged this as her OQ1; I concur it's the v1 telemetry-privacy gate question. Recommend: yes for personal, defer work to Sona.

**OQ2 — Backfill scope.** Replay 1669 historical sentinels + their `subagents/agent-<id>.jsonl` transcripts into `events.jsonl`? Cheap (<10 min one-time). Recommend: yes — gives us a real corpus for the first dashboard render. Reject only if Duong wants a clean cutover.

**OQ3 — v1-lock start date.** When does the measurement week begin? My recommendation: start it the Monday after Phase 2 ships. Earlier means we're measuring an unstable system; later means more dashboard delay. Hard limit: must include at least one full Saturday retro within the first lock-week.

## 8. Risks + tradeoffs

| Risk | Severity | Mitigation |
|---|---|---|
| Dispatch-prompt slug-match for in-flight plan attribution is fuzzy | medium | Token-cost numbers are still correct per agent; only the plan attribution may misfile a few percent. Coordinator-side soft-lint prompts a citation when missing. |
| `events.jsonl` grows unbounded | low | Append-only; gitignored; 100MB threshold triggers monthly shard. DuckDB reads sharded just as well. |
| Static-HTML approach makes interactive filtering harder | low | We have a tiny `<script>` for client-side filter/sort over the page's local JSON. If this proves limiting we add htmx, not Vue. |
| Lock-bypass discipline ignored | medium | Bypass log is on the dashboard home page; weekend retro reconciles every entry. Visibility is the enforcement. |
| Subagent transcript schema changes silently | medium | Phase 1 includes a fixture-pinned smoke test on the scanner; CI fails on schema drift. |
| Coordinator path discriminator (Q8) wrong on edge cases (e.g. Lissandra impersonating) | low | Lissandra writes in the coordinator's voice but spawns from a coordinator session; her transcripts live under `subagents/`. The discriminator is correct; we add a `voice_of:` annotation in the rollup to handle her display correctly. |
| Langfuse rejection turns out wrong | low | The events.jsonl format is OTel-compatible (we use the same field names where possible). Adding Langfuse later is a backend swap, not a re-architecture. |
| Weekend retro becomes a chore Duong skips | medium | Skill scaffold makes it a 30-minute dispatch, not a manual session. If skipped 2 weeks running, the dashboard shows a "stale lock" banner. |

## 9. Tasks

The breakdown is deferred to Aphelios per coordinator dispatch — this plan declares the architecture only. Coordinator-level placeholders (T.COORD.1–4) follow the convention from work-concern E2E ADRs:

- [ ] **T.COORD.1** Amend approved plan A (`agent-feedback-system`) with §D11 schema-bind-points for the dashboard. estimate_minutes: 25. kind: coord-amend.
- [ ] **T.COORD.2** Amend approved plan B (`coordinator-decision-feedback`) with §3.5 schema-bind-points. estimate_minutes: 25. kind: coord-amend.
- [ ] **T.COORD.3** Author `architecture/canonical-v1.md` lock manifest. estimate_minutes: 60. kind: coord-arch.
- [ ] **T.COORD.4** Author `/canonical-retro` skill scaffold. estimate_minutes: 45. kind: coord-skill.

Phase 1/2/3 implementation tasks are Aphelios's job; this plan supplies the architecture they break down against.

## Test plan

`tests_required: true`.

- Ingest scanner: fixture-pinned vitest suite — one fixture per source (parent jsonl, subagent jsonl, sentinel, git-log mock); one xfail-first test per discriminator rule.
- DuckDB queries: each `.sql` file has a paired `.expected.json` against a known-answer fixture event log; test runs the query and diffs.
- Static HTML smoke: render against the known-answer fixture; assert each plan-detail page contains the expected stage × agent × token cells.
- Coordinator discriminator (Q8): unit test on a synthetic JSONL pair (parent + child) to confirm path-based attribution.
- Lock bypass discipline: pre-commit hook lint that any commit touching files under `architecture/canonical-v1-locked-paths.txt` carries the `Lock-Bypass:` trailer during a lock-active period (gated by the existence of `architecture/canonical-v1-active.flag`).

## Rollback

- **Phase 1 rollback:** delete `tools/retro/`. `events.jsonl` remains as historical record (gitignored, harmless).
- **Phase 2 rollback:** revert the coordinator-detail page commits; home page degrades to plan-only view.
- **Phase 3 rollback:** delete `architecture/canonical-v1*.md` and the lock-bypass hook lint. The retro skill removal is one commit.
- **Full rollback:** delete `tools/retro/` and the architecture lock files. The two approved feedback plans are unaffected (this plan only consumes their outputs).

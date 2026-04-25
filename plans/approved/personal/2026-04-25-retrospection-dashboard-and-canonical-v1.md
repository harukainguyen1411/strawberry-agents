---
status: approved
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

## 7. Open questions for Duong — RESOLVED 2026-04-25

**OQ1 — OTel toggle scope.** Enable `CLAUDE_CODE_ENABLE_TELEMETRY=1` and `OTEL_LOG_TOOL_DETAILS=1` for personal-concern only? OTel gives us `query_source` (subagent identity at the OTel layer, Anthropic-blessed) and `git_commit_id` in tool params. Lux flagged this as her OQ1; I concur it's the v1 telemetry-privacy gate question. Recommend: yes for personal, defer work to Sona.

> **Duong: yes to both personal and work.** Sona inherits the same toggle posture; cross-coordinator side-by-side comparison (§Q8 cross-coordinator pane) gets a real corpus from day one. Sona will be FYI'd via inbox once this plan is in-progress so she can mirror the env wiring in her concern.

**OQ2 — Backfill scope.** Replay 1669 historical sentinels + their `subagents/agent-<id>.jsonl` transcripts into `events.jsonl`? Cheap (<10 min one-time). Recommend: yes — gives us a real corpus for the first dashboard render. Reject only if Duong wants a clean cutover.

> **Duong: yes.** Backfill the full historical corpus into `events.jsonl` on first ingest. First dashboard render exercises real plan-stage attribution rather than waiting weeks for a forward-only corpus to accumulate.

**OQ3 — v1-lock start date.** When does the measurement week begin? My recommendation: start it the Monday after Phase 2 ships. Earlier means we're measuring an unstable system; later means more dashboard delay. Hard limit: must include at least one full Saturday retro within the first lock-week.

> **Duong: concur.** Lock-tag drops on the Monday following Phase 2 ship-day; first weekend retro fires on the Saturday of that lock-week.

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

### Phase 1 — walking skeleton (Aphelios breakdown 2026-04-25)

Scope per §4: events.jsonl scanner, DuckDB queries (plan-rollup + coordinator-weekly skeleton), static-HTML index + plan-detail render, fixture-pinned smoke tests, paired `.expected.json` per query. Consumes only data sources that exist today — no dependency on the feedback-system or decision-feedback plans being shipped. All implementation lives in `tools/retro/`. Tests are vitest (or node:test if vitest is not yet wired in this repo); xfail-first per Rule 12 — every implementation task is preceded by its test task on the same branch.

Conventions: every task lists `id`, `title`, `owner_role`, `estimate_minutes`, `dependencies`, `acceptance criteria`. Owner roles are `sonnet builder` (executor), `test author` (xfail seeder — same builder tier, distinct commit), and `fixture author` (deterministic data hand-curator). All tasks ≤60 min. Total: 6 tasks, 280 min.

- [ ] **T.P1.1** — Author fixtures + xfail scanner test suite. owner_role: test author + fixture author. estimate_minutes: 55. dependencies: none. Files: `tools/retro/fixtures/parent-session.jsonl`, `tools/retro/fixtures/subagents/agent-fixt001.jsonl`, `tools/retro/fixtures/subagents/agent-fixt001.meta.json`, `tools/retro/fixtures/subagent-sentinels/agent-fixt001`, `tools/retro/fixtures/git-log-plans.json` (mock `git log` JSON for one historical implemented plan with an Orianna `Promoted-By` trailer), `tools/retro/fixtures/expected-events.jsonl` (golden output), `tools/retro/__tests__/ingest.test.mjs`. DoD: (a) fixture set covers all 4 upstream sources from §Q1; (b) test asserts `ingest.mjs` emits the exact `expected-events.jsonl` line-for-line including synthetic `plan-stage` events from §Q2; (c) at least one assertion per discriminator rule (parent vs subagent path, `isSidechain` flag, 90s idle gap stripping for `wall_active_minutes`, three-signal plan-stage detection); (d) suite is committed as xfail (skip-if-not-implemented) with a `Plan-Ref:` trailer citing this ADR; (e) commit prefix `chore:`, no `--no-verify`.

- [ ] **T.P1.2** — Implement `tools/retro/ingest.mjs` scanner over the four upstream sources. owner_role: sonnet builder. estimate_minutes: 60. dependencies: T.P1.1. Files: `tools/retro/ingest.mjs`, `tools/retro/lib/sources.mjs` (per-source readers), `tools/retro/lib/plan-stage-detect.mjs` (three-signal layered detection per §Q2), `tools/retro/lib/mtime-cache.mjs` (`events.mtimecache` per-source mtime tracker for incremental re-scan). DoD: (a) reads `~/.claude/projects/<slug>/<session-id>.jsonl`, `subagents/agent-<id>.{jsonl,meta.json}`, `subagent-sentinels/`, and `git log`-derived plan history; (b) emits append-only `events.jsonl` records with the field shape consumed by T.P1.4 queries (one record per turn / tool call / dispatch boundary / commit / synthetic `plan-stage`); (c) plan-stage detection prefers Orianna trailer, falls back to `status:` frontmatter mtime, then dispatch-prompt slug match; (d) idle-gap stripping (>90s between consecutive assistant turns) computed for `wall_active_minutes` per §3 time-normalization; (e) T.P1.1 suite passes (xfail removed in this commit); (f) `npm run retro:ingest` script wired in `package.json`; (g) zero new runtime deps beyond DuckDB + node stdlib.

- [ ] **T.P1.3** — Author DuckDB query fixtures + paired `.expected.json` golden files. owner_role: test author + fixture author. estimate_minutes: 40. dependencies: T.P1.2. Files: `tools/retro/queries/plan-rollup.sql`, `tools/retro/queries/coordinator-weekly-skeleton.sql`, `tools/retro/queries/plan-rollup.expected.json`, `tools/retro/queries/coordinator-weekly-skeleton.expected.json`, `tools/retro/__tests__/queries.test.mjs`. DoD: (a) `plan-rollup.sql` returns one row per (plan_slug, stage, agent) with `tokens_input`, `tokens_output`, `tokens_cache_read`, `tokens_cache_creation`, `wall_active_minutes`, `turns`, `tool_calls`; (b) `coordinator-weekly-skeleton.sql` returns one row per (coordinator, iso_week) with structural columns only — `inline_tool_calls`, `delegated_tool_calls`, `delegate_ratio`, `dispatch_count` — no feedback-bound or decision-bound columns (those are Phase 2); (c) golden `.expected.json` produced by running the SQL against the known-answer event log derived from T.P1.1 fixtures; (d) test suite runs each `.sql` via DuckDB and diffs against its paired `.expected.json` (deep equal, key-sorted); (e) committed as xfail before any consumer in T.P1.4 binds them; (f) header comment in each `.sql` cites the §Q1/§Q2 metric definitions it implements.

- [ ] **T.P1.4** — Implement `tools/retro/render.mjs` query runner + JSON emitter. owner_role: sonnet builder. estimate_minutes: 45. dependencies: T.P1.3. Files: `tools/retro/render.mjs`, `tools/retro/lib/duckdb-runner.mjs`, `tools/retro/dist/data/.gitkeep`, `.gitignore` updated for `tools/retro/dist/` (except `.gitkeep`). DoD: (a) executes every `.sql` in `tools/retro/queries/` against `events.jsonl` via DuckDB; (b) writes one `tools/retro/dist/data/<query-name>.json` per query; (c) re-running over the T.P1.1 fixture event log produces JSON that matches `tools/retro/queries/*.expected.json` (T.P1.3 suite passes — xfail removed); (d) `npm run retro:render` script wired; (e) total wall time on fixture corpus <2s per §3.

- [ ] **T.P1.5** — Author static-HTML render snapshot test + minimal HTML fixtures. owner_role: test author. estimate_minutes: 25. dependencies: T.P1.4. Files: `tools/retro/templates/index.html.tpl`, `tools/retro/templates/plan-detail.html.tpl`, `tools/retro/__tests__/render-html.test.mjs`, `tools/retro/__tests__/__snapshots__/index.html.snap`, `tools/retro/__tests__/__snapshots__/plan-detail.html.snap`. DoD: (a) hand-authored templates use only plain CSS + a vanilla `<script>` per §Q4 (no Vue, no Pinia, no router, no SPA framework); (b) snapshot test asserts `index.html` lists the historical implemented plan from the fixture corpus; (c) snapshot test asserts the `plan-<slug>.html` page contains every expected `(stage, agent, tokens)` cell from T.P1.3's `plan-rollup.expected.json`; (d) committed xfail (skip-if-not-implemented) before T.P1.6 consumes the templates; (e) snapshots are deterministic (no timestamps, no random IDs in rendered HTML — all derived solely from fixture inputs).

- [ ] **T.P1.6** — Wire HTML generator into `render.mjs` and ship Phase-1 walking-skeleton end-to-end. owner_role: sonnet builder. estimate_minutes: 55. dependencies: T.P1.5. Files: `tools/retro/render.mjs` (extended), `tools/retro/lib/html-generator.mjs`, `tools/retro/lib/template.mjs` (zero-dep `{{token}}` interpolator + escape-HTML helper), `tools/retro/dist/index.html` (gitignored output verified via fixture run only), `tools/retro/README.md`. DoD: (a) `npm run retro:render` produces `tools/retro/dist/index.html` and one `plan-<slug>.html` per plan in `events.jsonl`; (b) T.P1.5 snapshot suite passes (xfail removed); (c) `README.md` documents the four-step pipeline (`ingest → events.jsonl → query → render`) with the §3 directory tree; (d) end-to-end smoke: running `npm run retro:ingest && npm run retro:render` against the T.P1.1 fixture set then opening `tools/retro/dist/index.html` and clicking the historical plan reaches a fully-populated plan-detail page (verified in test via DOM-parse of the emitted file, not a real browser — Phase 1 ships file:// only per §Q4); (e) Phase-1 acceptance gate from §4 satisfied: "Duong can click a plan and see stage × agent × token cost rendered correctly for one historical implemented plan."

**Phase 1 dependency chain:** T.P1.1 → T.P1.2 → T.P1.3 → T.P1.4 → T.P1.5 → T.P1.6. Strictly serial because each implementation task removes the xfail seeded by the preceding test task; parallelism is unsafe under Rule 12.

**Phase 1 commit cadence:** 6 commits minimum (one per task). All `chore:` prefix (work lives in `tools/retro/` outside `apps/**`). Per Rule 12, T.P1.2 / T.P1.4 / T.P1.6 commits MUST be preceded on the same branch by their respective test commits (T.P1.1 / T.P1.3 / T.P1.5).

### Phase 2 — coordinator drill-down + feedback/decision integration

Out of scope for this 2026-04-25 breakdown. Defer until (a) `2026-04-21-agent-feedback-system.md` is in-progress with §D11 schema-bind amendment landed (T.COORD.1), (b) `2026-04-21-coordinator-decision-feedback.md` is in-progress with §3.5 schema-bind amendment landed (T.COORD.2), and (c) Phase 1 (T.P1.1–T.P1.6) is shipped. Estimated ~5 tasks, ~250 min per §4.

### Phase 3 — canonical-v1 lock + retro skill + prompt-quality v1.5

Out of scope for this 2026-04-25 breakdown. Defer until Phase 2 is shipped and the v1-lock start date (§7 OQ3 — Monday after Phase 2 ship) is confirmed. Estimated ~4 tasks, ~180 min per §4.

Phase 1 implementation may begin immediately under the worktree-isolation discipline of Rule 20. Phase 2/3 implementation tasks remain Aphelios's job pending a follow-up breakdown.

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

## Orianna approval

- **Date:** 2026-04-25
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has a clear owner (Swain), all three open questions resolved inline by Duong in §7 with citations, concrete coordinator-level tasks (T.COORD.1–4) with estimates and kinds, explicit test plan satisfying `tests_required: true`, three-phase scoping with task counts and minute estimates, integration sequencing locked against the two approved sibling plans via 5–15 line schema-bind amendments, and a documented rollback per phase. Architecture choices are explicitly justified against rejected alternatives (Langfuse, Vue/SPA) on cost-vs-scale grounds. Ready for breakdown.

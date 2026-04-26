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

- [x] **T.COORD.1** Amend approved plan A (`agent-feedback-system`) with §D11 schema-bind-points for the dashboard. estimate_minutes: 25. kind: coord-amend. parallel_slice_candidate: no. **Status: DONE 2026-04-25** — landed as §D12 in `plans/approved/personal/2026-04-21-agent-feedback-system.md` (numbered §D12 because §D11 was already used for the sync-shared-rules boundary; the dashboard plan §Q7 nominates this as "§D11" by convention but the actual section number is §D12 — see commentary at line 750 of plan A).
- [x] **T.COORD.2** Amend approved plan B (`coordinator-decision-feedback`) with §3.5 schema-bind-points. estimate_minutes: 25. kind: coord-amend. parallel_slice_candidate: no. **Status: DONE 2026-04-25** — landed as §3.5 in `plans/approved/personal/2026-04-21-coordinator-decision-feedback.md` (line 210). Reads `axes`, `match`, `coordinator_confidence`, `decision_id` per the binding in §Q7 of this plan.
- [ ] **T.COORD.3** Author `architecture/canonical-v1.md` lock manifest. estimate_minutes: 60. kind: coord-arch. parallel_slice_candidate: no. Detail: hand-curated one-pager per §Q6. Lists agent-def SHAs at lock time, `agents/memory/agent-network.md` SHA, `CLAUDE.md` rule-1-21 SHAs, `.claude/settings.json` SHAs, lock-tag git ref `canonical-v1`. Owner: Evelynn (coordinator authorship — not a builder task). Files: `architecture/canonical-v1.md`. DoD: file exists; lists every `.claude/agents/*.md` SHA at lock-tag time; references `architecture/canonical-v1-bypasses.md`; one-page (≤200 lines).
- [ ] **T.COORD.4** Author `/canonical-retro` skill scaffold. estimate_minutes: 45. kind: coord-skill. parallel_slice_candidate: no. Detail: skill body that Evelynn invokes Saturday 09:00 Asia/Bangkok per §Q6. Dispatches Lux + Karma + Swain over the past week's `events.jsonl` slice + `feedback/INDEX.md` + `architecture/canonical-v1-bypasses.md`; output is `plans/proposed/personal/YYYY-MM-DD-canonical-v2-rationale.md` authored by Swain. Owner: Evelynn (skill author). Files: `.claude/skills/canonical-retro/SKILL.md`. DoD: skill renders the dispatch chain; produces a Swain-authored ADR template; ≤150 lines.

### Phase 1 — walking skeleton (Aphelios breakdown 2026-04-25)

Scope per §4: events.jsonl scanner, DuckDB queries (plan-rollup + coordinator-weekly skeleton), static-HTML index + plan-detail render, fixture-pinned smoke tests, paired `.expected.json` per query. Consumes only data sources that exist today — no dependency on the feedback-system or decision-feedback plans being shipped. All implementation lives in `tools/retro/`. Tests are vitest (or node:test if vitest is not yet wired in this repo); xfail-first per Rule 12 — every implementation task is preceded by its test task on the same branch.

Conventions: every task lists `id`, `title`, `owner_role`, `estimate_minutes`, `dependencies`, `acceptance criteria`. Owner roles are `sonnet builder` (executor), `test author` (xfail seeder — same builder tier, distinct commit), and `fixture author` (deterministic data hand-curator). All tasks ≤60 min. Total: 6 tasks, 280 min.

- [ ] **T.P1.1** — Author fixtures + xfail scanner test suite. owner_role: test author + fixture author. estimate_minutes: 55. dependencies: none. parallel_slice_candidate: no. Files: `tools/retro/fixtures/parent-session.jsonl`, `tools/retro/fixtures/subagents/agent-fixt001.jsonl`, `tools/retro/fixtures/subagents/agent-fixt001.meta.json`, `tools/retro/fixtures/subagent-sentinels/agent-fixt001`, `tools/retro/fixtures/git-log-plans.json` (mock `git log` JSON for one historical implemented plan with an Orianna `Promoted-By` trailer), `tools/retro/fixtures/expected-events.jsonl` (golden output), `tools/retro/__tests__/ingest.test.mjs`. DoD: (a) fixture set covers all 4 upstream sources from §Q1; (b) test asserts `ingest.mjs` emits the exact `expected-events.jsonl` line-for-line including synthetic `plan-stage` events from §Q2; (c) at least one assertion per discriminator rule (parent vs subagent path, `isSidechain` flag, 90s idle gap stripping for `wall_active_minutes`, three-signal plan-stage detection); (d) suite is committed as xfail (skip-if-not-implemented) with a `Plan-Ref:` trailer citing this ADR; (e) commit prefix `chore:`, no `--no-verify`.

- [ ] **T.P1.2** — Implement `tools/retro/ingest.mjs` scanner over the four upstream sources. owner_role: sonnet builder. estimate_minutes: 60. dependencies: T.P1.1. parallel_slice_candidate: no. Files: `tools/retro/ingest.mjs`, `tools/retro/lib/sources.mjs` (per-source readers), `tools/retro/lib/plan-stage-detect.mjs` (three-signal layered detection per §Q2), `tools/retro/lib/mtime-cache.mjs` (`events.mtimecache` per-source mtime tracker for incremental re-scan). DoD: (a) reads `~/.claude/projects/<slug>/<session-id>.jsonl`, `subagents/agent-<id>.{jsonl,meta.json}`, `subagent-sentinels/`, and `git log`-derived plan history; (b) emits append-only `events.jsonl` records with the field shape consumed by T.P1.4 queries (one record per turn / tool call / dispatch boundary / commit / synthetic `plan-stage`); (c) plan-stage detection prefers Orianna trailer, falls back to `status:` frontmatter mtime, then dispatch-prompt slug match; (d) idle-gap stripping (>90s between consecutive assistant turns) computed for `wall_active_minutes` per §3 time-normalization; (e) T.P1.1 suite passes (xfail removed in this commit); (f) `npm run retro:ingest` script wired in `package.json`; (g) zero new runtime deps beyond DuckDB + node stdlib.

- [ ] **T.P1.3** — Author DuckDB query fixtures + paired `.expected.json` golden files. owner_role: test author + fixture author. estimate_minutes: 40. dependencies: T.P1.2. parallel_slice_candidate: no. Files: `tools/retro/queries/plan-rollup.sql`, `tools/retro/queries/coordinator-weekly-skeleton.sql`, `tools/retro/queries/plan-rollup.expected.json`, `tools/retro/queries/coordinator-weekly-skeleton.expected.json`, `tools/retro/__tests__/queries.test.mjs`. DoD: (a) `plan-rollup.sql` returns one row per (plan_slug, stage, agent) with `tokens_input`, `tokens_output`, `tokens_cache_read`, `tokens_cache_creation`, `wall_active_minutes`, `turns`, `tool_calls`; (b) `coordinator-weekly-skeleton.sql` returns one row per (coordinator, iso_week) with structural columns only — `inline_tool_calls`, `delegated_tool_calls`, `delegate_ratio`, `dispatch_count` — no feedback-bound or decision-bound columns (those are Phase 2); (c) golden `.expected.json` produced by running the SQL against the known-answer event log derived from T.P1.1 fixtures; (d) test suite runs each `.sql` via DuckDB and diffs against its paired `.expected.json` (deep equal, key-sorted); (e) committed as xfail before any consumer in T.P1.4 binds them; (f) header comment in each `.sql` cites the §Q1/§Q2 metric definitions it implements.

- [ ] **T.P1.4** — Implement `tools/retro/render.mjs` query runner + JSON emitter. owner_role: sonnet builder. estimate_minutes: 45. dependencies: T.P1.3. parallel_slice_candidate: no. Files: `tools/retro/render.mjs`, `tools/retro/lib/duckdb-runner.mjs`, `tools/retro/dist/data/.gitkeep`, `.gitignore` updated for `tools/retro/dist/` (except `.gitkeep`). DoD: (a) executes every `.sql` in `tools/retro/queries/` against `events.jsonl` via DuckDB; (b) writes one `tools/retro/dist/data/<query-name>.json` per query; (c) re-running over the T.P1.1 fixture event log produces JSON that matches `tools/retro/queries/*.expected.json` (T.P1.3 suite passes — xfail removed); (d) `npm run retro:render` script wired; (e) total wall time on fixture corpus <2s per §3.

- [ ] **T.P1.5** — Author static-HTML render snapshot test + minimal HTML fixtures. owner_role: test author. estimate_minutes: 25. dependencies: T.P1.4. parallel_slice_candidate: no. Files: `tools/retro/templates/index.html.tpl`, `tools/retro/templates/plan-detail.html.tpl`, `tools/retro/__tests__/render-html.test.mjs`, `tools/retro/__tests__/__snapshots__/index.html.snap`, `tools/retro/__tests__/__snapshots__/plan-detail.html.snap`. DoD: (a) hand-authored templates use only plain CSS + a vanilla `<script>` per §Q4 (no Vue, no Pinia, no router, no SPA framework); (b) snapshot test asserts `index.html` lists the historical implemented plan from the fixture corpus; (c) snapshot test asserts the `plan-<slug>.html` page contains every expected `(stage, agent, tokens)` cell from T.P1.3's `plan-rollup.expected.json`; (d) committed xfail (skip-if-not-implemented) before T.P1.6 consumes the templates; (e) snapshots are deterministic (no timestamps, no random IDs in rendered HTML — all derived solely from fixture inputs).

- [ ] **T.P1.6** — Wire HTML generator into `render.mjs` and ship Phase-1 walking-skeleton end-to-end. owner_role: sonnet builder. estimate_minutes: 55. dependencies: T.P1.5. parallel_slice_candidate: no. Files: `tools/retro/render.mjs` (extended), `tools/retro/lib/html-generator.mjs`, `tools/retro/lib/template.mjs` (zero-dep `{{token}}` interpolator + escape-HTML helper), `tools/retro/dist/index.html` (gitignored output verified via fixture run only), `tools/retro/README.md`. DoD: (a) `npm run retro:render` produces `tools/retro/dist/index.html` and one `plan-<slug>.html` per plan in `events.jsonl`; (b) T.P1.5 snapshot suite passes (xfail removed); (c) `README.md` documents the four-step pipeline (`ingest → events.jsonl → query → render`) with the §3 directory tree; (d) end-to-end smoke: running `npm run retro:ingest && npm run retro:render` against the T.P1.1 fixture set then opening `tools/retro/dist/index.html` and clicking the historical plan reaches a fully-populated plan-detail page (verified in test via DOM-parse of the emitted file, not a real browser — Phase 1 ships file:// only per §Q4); (e) Phase-1 acceptance gate from §4 satisfied: "Duong can click a plan and see stage × agent × token cost rendered correctly for one historical implemented plan."

**Phase 1 dependency chain:** T.P1.1 → T.P1.2 → T.P1.3 → T.P1.4 → T.P1.5 → T.P1.6. Strictly serial because each implementation task removes the xfail seeded by the preceding test task; parallelism is unsafe under Rule 12.

**Phase 1 commit cadence:** 6 commits minimum (one per task). All `chore:` prefix (work lives in `tools/retro/` outside `apps/**`). Per Rule 12, T.P1.2 / T.P1.4 / T.P1.6 commits MUST be preceded on the same branch by their respective test commits (T.P1.1 / T.P1.3 / T.P1.5).

### Phase 2 — coordinator drill-down + feedback/decision integration (Aphelios breakdown 2026-04-26)

Scope per §4: coordinator-detail page with `inline_tool_calls / (inline + delegated)` ratio per §Q8, prompt length/structure/compression histograms per §Q9, decision-feedback match-rate column reading the contract from plan B §3.5, feedback open-entries tile on the home page reading the contract from plan A §D12. Pre-conditions: T.COORD.1 ✅ (plan A §D12 landed) and T.COORD.2 ✅ (plan B §3.5 landed) — the read contracts the queries bind against are already frozen. Phase 1 (T.P1.1–T.P1.6) must be shipped before Phase 2 starts: Phase 2 extends `events.jsonl`, the existing queries, and the existing render pipeline; it does not stand alone. All implementation lives in `tools/retro/`. xfail-first per Rule 12. Total: 5 tasks, 250 min.

- [ ] **T.P2.1** — Extend fixtures + xfail tests for Phase-2 queries (feedback-rollup, decision-rollup, coordinator-weekly full). owner_role: test author + fixture author. estimate_minutes: 50. dependencies: T.P1.6 (Phase 1 walking skeleton shipped). parallel_slice_candidate: no. Files: `tools/retro/fixtures/feedback-index.md` (mock `feedback/INDEX.md` matching plan A §D12's four-field read contract — `category`, `severity`, `status`, `author`), `tools/retro/fixtures/decisions/evelynn/INDEX.md` + `tools/retro/fixtures/decisions/evelynn/2026-04-NN-<slug>.md` ×3 (mock decision logs matching plan B §3.5's bind-points — `axes`, `match`, `coordinator_confidence`, `decision_id`), `tools/retro/fixtures/parent-session-with-prompts.jsonl` (extends T.P1.1's parent fixture with three subagent dispatches whose prompt lengths, header counts, and compression ratios sit at known histogram percentiles), `tools/retro/fixtures/expected-events.jsonl` (extended with `kind: feedback-entry`, `kind: decision-log`, and prompt-stat synthetic events), `tools/retro/queries/feedback-rollup.expected.json`, `tools/retro/queries/decision-rollup.expected.json`, `tools/retro/queries/coordinator-weekly.expected.json` (full version superseding the Phase-1 skeleton), `tools/retro/__tests__/queries-phase2.test.mjs`. DoD: (a) every Phase-2 query has a paired golden `.expected.json`; (b) tests committed xfail (skip if respective `.sql` files absent) per Rule 12; (c) feedback-rollup expected output reads `category × severity × open_count` exactly as plan A §D12 specifies; (d) decision-rollup expected output reads per-axis match-rate over the three fixture decisions; (e) coordinator-weekly expected output adds `prompt_chars_p50/p95`, `header_count_avg`, `concern_tag_present_pct`, `plan_citation_present_pct`, `compression_ratio_p50/p95` columns to the Phase-1 skeleton's `inline_tool_calls / delegated_tool_calls / delegate_ratio / dispatch_count`; (f) `Plan-Ref:` trailer cites this ADR; (g) commit prefix `chore:`.

- [ ] **T.P2.2** — Implement `feedback-rollup.sql` + ingest extension to read `feedback/INDEX.md` rows. owner_role: sonnet builder. estimate_minutes: 45. dependencies: T.P2.1. parallel_slice_candidate: yes. Files: `tools/retro/queries/feedback-rollup.sql`, `tools/retro/lib/sources.mjs` (extended with a `feedback-index` reader producing `kind: feedback-entry` events keyed on plan A §D12's column shape), `tools/retro/ingest.mjs` (wires the new source into the per-source mtime cache so a `feedback/INDEX.md` change triggers re-ingest). DoD: (a) `feedback-rollup.sql` returns one row per `(category, severity, status)` with `open_count` and `latest_entry_ts`; (b) header comment cites plan A §D12 line range as the read contract; (c) T.P2.1 feedback-rollup xfail flips green; (d) zero new runtime deps; (e) re-running `npm run retro:ingest && npm run retro:render` over the fixture corpus produces a `dist/data/feedback-rollup.json` matching the golden. Parallel-able because feedback-rollup is fully independent of decision-rollup (T.P2.3) and coordinator-weekly (T.P2.4) — three disjoint SQL files, three disjoint source readers, three disjoint test golden files.

- [ ] **T.P2.3** — Implement `decision-rollup.sql` + ingest extension to read `agents/<coord>/memory/decisions/*.md`. owner_role: sonnet builder. estimate_minutes: 45. dependencies: T.P2.1. parallel_slice_candidate: yes. Files: `tools/retro/queries/decision-rollup.sql`, `tools/retro/lib/sources.mjs` (extended with a `decision-log` reader keyed on plan B §3.5's frontmatter contract), `tools/retro/lib/decision-axes.mjs` (parses YAML frontmatter — `axes`, `match`, `coordinator_confidence`, `decision_id` — into normalized event records). DoD: (a) `decision-rollup.sql` returns one row per `(coordinator, axis)` with `decisions_total`, `decisions_matched`, `match_rate`, `avg_confidence_at_time` (mapping `low/medium/high` to `1/2/3`); (b) header comment cites plan B §3.5 lines as the read contract; (c) T.P2.1 decision-rollup xfail flips green; (d) source reader handles the `duong_concurred_silently: true → match: true` rule from plan B §3.1 line 136; (e) zero new runtime deps. Parallel-able with T.P2.2 and T.P2.4 — disjoint files, disjoint contracts, disjoint goldens.

- [ ] **T.P2.4** — Implement `coordinator-weekly.sql` full + ingest extension for prompt-stat synthetic events. owner_role: sonnet builder. estimate_minutes: 60. dependencies: T.P2.1. parallel_slice_candidate: yes. Files: `tools/retro/queries/coordinator-weekly.sql` (supersedes the Phase-1 `coordinator-weekly-skeleton.sql` — keep the skeleton file but mark `-- DEPRECATED: superseded by coordinator-weekly.sql` in its header), `tools/retro/lib/prompt-stats.mjs` (computes the three §Q9 deterministic signals — char/token length of dispatch prompt, regex count of `^##` headers + `[concern: ...]` tag presence + plan-citation regex match, and `subagent_total_output_tokens / dispatch_prompt_tokens` compression ratio — emitted as one event per dispatch with `kind: dispatch-prompt-stats`), `tools/retro/ingest.mjs` (wires the prompt-stats emitter into the subagent-jsonl source). DoD: (a) `coordinator-weekly.sql` returns the eight prompt-stat columns from T.P2.1 DoD-(e) on top of the Phase-1 skeleton's four columns; (b) inline-vs-delegate ratio computed via the path-discriminator from §Q8 (top-level session JSONL = inline, `subagents/*.jsonl` = delegated); (c) ratio flagged `healthy / drift / executor-mode` at thresholds `>0.7 / 0.5–0.7 / <0.5` per §Q8; (d) T.P2.1 coordinator-weekly xfail flips green; (e) prompt-stats regex pinned to plan-path pattern `plans/(proposed|approved|in-progress|implemented|archived)/(personal|work)/.+\.md` (covers the live plan-tree shape); (f) zero new runtime deps. Parallel-able with T.P2.2 and T.P2.3 — disjoint columns, disjoint sources, disjoint goldens.

- [ ] **T.P2.5** — Coordinator-detail HTML page + home-page Phase-2 tile integration (xfail snapshot pair → impl in same task). owner_role: test author + sonnet builder. estimate_minutes: 50. dependencies: T.P2.2 + T.P2.3 + T.P2.4. parallel_slice_candidate: no. Files: `tools/retro/templates/coordinator-detail.html.tpl`, `tools/retro/templates/index.html.tpl` (extended — adds two tiles: feedback open-entries by severity, top-1 axis-with-lowest-match-rate per coordinator), `tools/retro/lib/html-generator.mjs` (extended — new `coordinator-<name>-week-<iso-week>.html` route per the §Q4 file naming), `tools/retro/__tests__/render-html-phase2.test.mjs`, `tools/retro/__tests__/__snapshots__/coordinator-detail-evelynn-week-NN.html.snap`, `tools/retro/__tests__/__snapshots__/index-with-phase2-tiles.html.snap`. Test-first sub-commits: (1) commit the snapshot xfail suite first per Rule 12, (2) commit the template + html-generator wiring that flips it green. DoD: (a) coordinator-detail page contains an inline-vs-delegate ratio panel, three histogram canvases (prompt length, header count, compression ratio) rendered as inline SVG bars (no chart library), and a per-axis match-rate table; (b) home-page feedback tile lists open-entry counts grouped by severity (`high / medium / low`) with a deep link to the underlying `feedback/INDEX.md`; (c) home-page decision tile shows the three axes with lowest match-rate across both coordinators and their sample sizes; (d) snapshot determinism guard from Phase-1 TP1.T6 DoD-d carries forward — no `Date.now()`, `Math.random()`, `process.pid` leaks; (e) HTML-shape lint: still no `<script src="vue` / `pinia` / `vue-router` (§Q4 SPA-rejection guard); (f) end-to-end smoke: `npm run retro:ingest && npm run retro:render` over the Phase-2 fixture corpus produces both `coordinator-evelynn-week-<iso>.html` and an updated `index.html` with the new tiles, and the existing Phase-1 `plan-<slug>.html` pages remain unchanged (regression check); (g) Phase-2 acceptance gate satisfied — Duong can click "Evelynn / Sona" on the home page and reach a populated coordinator-detail page.

**Phase 2 dependency chain:** T.P2.1 → {T.P2.2 ∥ T.P2.3 ∥ T.P2.4} → T.P2.5. The middle tier is the parallel jackpot — three independent SQL+source-reader pairs land concurrently in three worktrees off the same base branch (the T.P2.1 commit). T.P2.5 awaits all three because the coordinator-detail page consumes all three goldens.

**Phase 2 commit cadence:** 5 task lines but 6+ commits — T.P2.5 is a paired commit (xfail snapshot, then impl) per Rule 12. All `chore:` prefix. T.P2.2/3/4 each remove the corresponding xfail seeded by T.P2.1 in their landing commit.

### Phase 3 — canonical-v1 lock + retro skill + prompt-quality v1.5 (Aphelios breakdown 2026-04-26)

Scope per §4 + §Q6: `canonical-v1.md` lock manifest authored (T.COORD.3 — coordinator job, not in this builder breakdown), `Lock-Bypass:` discipline detected and surfaced on the dashboard, weekend-retro skill scaffolded for Evelynn (T.COORD.4 — coordinator job), optional Lux grading pass behind a config flag for §Q9's "v1.5 punt". Pre-conditions: Phase 2 (T.P2.1–T.P2.5) shipped + v1-lock start date confirmed (Duong-resolved §7 OQ3 = Monday after Phase 2 ship-day). T.COORD.3 and T.COORD.4 sit alongside the builder tasks below — they are coordinator-authored docs/skills and run in parallel with the builder work without contention. xfail-first per Rule 12. Total: 4 tasks, 180 min.

- [ ] **T.P3.1** — Lock-bypass detection — `Lock-Bypass:` trailer scan in ingest + bypass-log file scaffold + xfail test pair. owner_role: test author + sonnet builder. estimate_minutes: 60. dependencies: T.P2.5 (Phase 2 shipped) + T.COORD.3 (`architecture/canonical-v1.md` exists so the manifest's lock-set is enumerable). parallel_slice_candidate: no. Files: `architecture/canonical-v1-bypasses.md` (initial empty bypass log with header schema — `date | sha | author | severity | reason | reconciled-by`), `tools/retro/lib/lock-bypass.mjs` (parses commit messages for `Lock-Bypass: <reason>` trailer + asserts touched-file set is a subset of the lock manifest's enumerated paths from `canonical-v1.md`), `tools/retro/ingest.mjs` (wires the lock-bypass scanner — emits `kind: lock-bypass` events with `severity` field copied from the bypass-log row), `tools/retro/queries/lock-bypass-rollup.sql`, `tools/retro/queries/lock-bypass-rollup.expected.json`, `tools/retro/__tests__/lock-bypass.test.mjs`, `tools/retro/fixtures/git-log-with-bypass.json` (mock git log carrying one `severity: high` bypass + one `severity: low` bypass within the lock-week). Test-first sub-commit (xfail) lands before impl sub-commit. DoD: (a) `Lock-Bypass:` trailer detected on commits whose touched-file set intersects the manifest paths; (b) trailer-absent commits to manifest paths flagged `kind: lock-violation` (no bypass declared = violation); (c) `lock-bypass-rollup.sql` returns one row per `(iso_week, severity)` with `count` and `reconciled` boolean (`reconciled` = referenced in the next Saturday retro's output ADR); (d) test fixtures cover both clean-bypass and missing-trailer-violation cases; (e) `architecture/canonical-v1-bypasses.md` schema header documents the row format; (f) `Plan-Ref:` trailer cites this ADR.

- [ ] **T.P3.2** — Home-page lock tile — bypass log surface + "stale lock" banner + Phase-3 snapshot tests. owner_role: test author + sonnet builder. estimate_minutes: 50. dependencies: T.P3.1. parallel_slice_candidate: yes. Files: `tools/retro/templates/index.html.tpl` (extended — adds a "Lock status" tile listing the active lock-tag, days-since-last-retro, current-week bypass count by severity, and a banner element when `days-since-last-retro > 14`), `tools/retro/lib/html-generator.mjs` (computes `days_since_last_retro` from the latest `canonical-vN-rationale.md` plan in `plans/{proposed,approved,in-progress,implemented}/personal/` matching the Saturday-retro filename pattern), `tools/retro/__tests__/__snapshots__/index-with-lock-tile.html.snap`, `tools/retro/__tests__/render-lock-tile.test.mjs`, `tools/retro/fixtures/canonical-v2-rationale-fixture.md` (3-week-old retro-output ADR fixture that triggers the stale banner). Test-first sub-commit (xfail) lands before impl. DoD: (a) lock tile renders the active lock-tag (`canonical-v1` from `architecture/canonical-v1.md`), days-since-last-retro, and current-week bypass-by-severity counts; (b) stale-banner appears when `days-since-last-retro > 14` per §8 Risk row "Weekend retro becomes a chore Duong skips"; (c) snapshot determinism guard from Phase-1 TP1.T6 DoD-d still passes; (d) parallel-able with T.P3.3 because the home-page tile and the optional grading pass touch disjoint files (`templates/index.html.tpl` + `html-generator.mjs` vs `lib/quality-grader.mjs`). Merge friction is low — only `index.html.tpl` could conflict if both phases edit the home page, but T.P3.3 emits its grades into a separate page section keyed off the `RETRO_QUALITY_GRADE=1` flag.

- [ ] **T.P3.3** — Optional Lux prompt-quality grading pass behind `RETRO_QUALITY_GRADE=1` config flag (§Q9 v1.5 punt). owner_role: test author + sonnet builder. estimate_minutes: 45. dependencies: T.P3.1. parallel_slice_candidate: yes. Files: `tools/retro/lib/quality-grader.mjs` (default-disabled stub when `process.env.RETRO_QUALITY_GRADE !== '1'` — emits no events; when enabled, calls Anthropic API via `@anthropic-ai/sdk` to grade the past week's bottom-5/top-5 dispatches by each §Q9 deterministic signal as `clear / acceptable / wandering / under-spec'd`), `tools/retro/queries/quality-grade-rollup.sql`, `tools/retro/queries/quality-grade-rollup.expected.json` (golden ASSUMES `RETRO_QUALITY_GRADE=0` — empty result set; gated-on path is smoke-tested in T.P3.4), `tools/retro/__tests__/quality-grader.test.mjs`, `tools/retro/README.md` (extended — documents the env flag, the ~$0.50/week cost ceiling per §Q9, and the gating semantics). Test-first sub-commit (xfail) lands before impl. DoD: (a) default-off behaviour: ingest produces zero `kind: quality-grade` events when env flag absent — golden `.expected.json` reflects empty rollup; (b) flag-on behaviour: when `RETRO_QUALITY_GRADE=1`, top-5 + bottom-5 dispatches by each of three §Q9 signals are graded; total weekly cost stays ≤$1 (asserted via dry-run token-count check before any Anthropic call); (c) Anthropic SDK added as an OPTIONAL dep (lazy-import inside the flag-on branch so default install does not pull it); (d) cost-ceiling kill-switch: aborts with non-zero exit if estimated weekly spend exceeds $5 (hard ceiling per §Q5); (e) parallel-able with T.P3.2 — disjoint files, disjoint env path. Merge friction with T.P3.2 limited to README.md ordering, which is trivially resolvable.

- [ ] **T.P3.4** — Phase-3 acceptance smoke + lock-week-active badge + end-to-end bats test. owner_role: test author. estimate_minutes: 25. dependencies: T.P3.2 + T.P3.3 (both must land before the smoke can assert their combined behaviour). parallel_slice_candidate: no. Files: `tools/retro/__tests__/e2e-phase3.bats`, `tools/retro/templates/index.html.tpl` (small extension — adds a `lock-week-active` badge that appears between the Monday-after-Phase-2 lock-tag date and the end of that week, computed from the lock-tag's commit date), `tools/retro/__tests__/__snapshots__/index-lock-week-active.html.snap`, `tools/retro/README.md` (Phase-3 section — pipeline now ingests git-log lock-bypass trailers, renders bypass tile, surfaces stale-lock banner, optionally grades prompts). DoD: (a) bats e2e seeds a fixture tree containing `architecture/canonical-v1.md` + a bypass-log entry + a 3-day-old `canonical-v2-rationale.md` (within retro window) + the Phase-2 fixture corpus; (b) runs `npm run retro:ingest && npm run retro:render`; (c) asserts `dist/index.html` carries the lock tile, the lock-week-active badge, NO stale banner, the bypass count, and the (default-off) absence of a quality-grade tile; (d) re-runs with `RETRO_QUALITY_GRADE=1` against a mocked Anthropic endpoint (record-replay fixture under `tools/retro/fixtures/anthropic-graded.json` — no live API calls in test) and asserts the grade tile appears; (e) total wall time <8s; (f) Phase-3 acceptance gate satisfied — dashboard surfaces the lock manifest, the bypass log, the retro freshness, and (gated) the quality grades.

**Phase 3 dependency chain:** T.P3.1 → {T.P3.2 ∥ T.P3.3} → T.P3.4. T.COORD.3 and T.COORD.4 run in parallel with this chain — they are coordinator-authored manifests/skills, not on the builder critical path. T.P3.1 hard-depends on T.COORD.3 (`canonical-v1.md` must exist for the lock-bypass scanner to enumerate manifest paths).

**Phase 3 commit cadence:** 4 task lines but 7+ commits — each impl task is preceded by its xfail commit per Rule 12. T.COORD.3 and T.COORD.4 are 2 additional commits (coordinator-authored). All `chore:` prefix.

Phase 1 implementation may begin immediately under the worktree-isolation discipline of Rule 20. Phase 2 dispatch is unblocked once Phase 1 ships. Phase 3 dispatch is unblocked once Phase 2 ships AND Duong sets the v1-lock start date per §7 OQ3.

### Phase 2 + 3 totals + slicing recap (Aphelios 2026-04-26)

| Phase | Tasks | Estimate (min) | Parallel-yes count | Critical-path tasks |
|---|---|---|---|---|
| Coord (T.COORD.1–4) | 4 (2 done, 2 open) | 130 (50 done + 80 open) | 0 | T.COORD.3 → gates T.P3.1 |
| Phase 1 (T.P1.1–T.P1.6) | 6 | 280 | 0 (strict serial per Rule 12 chain) | T.P1.1 → T.P1.2 → T.P1.3 → T.P1.4 → T.P1.5 → T.P1.6 |
| Phase 2 (T.P2.1–T.P2.5) | 5 | 250 | 3 (T.P2.2, T.P2.3, T.P2.4) | T.P2.1 → {T.P2.2 ∥ T.P2.3 ∥ T.P2.4} → T.P2.5 |
| Phase 3 (T.P3.1–T.P3.4) | 4 | 180 | 2 (T.P3.2, T.P3.3) | T.P3.1 → {T.P3.2 ∥ T.P3.3} → T.P3.4 |
| **Builder totals (P1+P2+P3)** | **15** | **710** | **5** | — |
| **Grand totals (incl. T.COORD)** | **19** | **840** (50 already done) | **5** | — |

Slicing notes for the coordinator dispatch (Evelynn / Sona):

- **Phase 2 fan-out window:** after T.P2.1 lands, the coordinator can dispatch three concurrent worktrees (one each for T.P2.2 / T.P2.3 / T.P2.4) off the post-T.P2.1 commit SHA. Files are disjoint by design — three separate `.sql` files, three separate source-readers in distinct sub-modules of `lib/sources.mjs` (recommend the impl tasks each create their own `lib/sources/<name>.mjs` and only T.P2.5 consolidates the wiring if needed). Convergence at T.P2.5.
- **Phase 3 fan-out window:** after T.P3.1 lands, T.P3.2 (home-page lock tile) and T.P3.3 (optional Lux grading pass) can run concurrently. Both touch `tools/retro/README.md`; everything else is disjoint. Recommend the coordinator merges T.P3.2's worktree first, then T.P3.3 — README.md merge is trivial when ordered.
- **No parallel slicing within Phase 1:** Rule 12 forces strict xfail-first → impl serialisation; six tasks, six commits, single chain.
- **T.COORD.3 ↔ T.P3.1 hard dependency:** the lock-bypass scanner enumerates manifest paths, which only exist once `architecture/canonical-v1.md` is written. T.COORD.3 must complete before T.P3.1 dispatch.

Wait-bound tasks: none in this breakdown. Every task is bounded by author/builder time, not by external waits.

## Test plan

`tests_required: true`. Authored by Xayah 2026-04-25 — Phase-1-only expansion against the T.P1.1–T.P1.6 breakdown. Phase 2 / 3 test plans deferred until those phases are broken down.

### Framework recommendation

**Recommendation: `node:test` (built-in) for the JS/.mjs suites, `bats` for shell-level smoke, no vitest.**

- Vitest is not currently wired in this repo (no `vitest` in any `package.json`; no `vitest.config.*`; no `__tests__` consumer infra). Adding it imports a transitive dep tree (esbuild + vite + happy-dom) for what amounts to deep-equal + snapshot needs. Reject for v1.
- `node:test` ships with Node >=18 and covers all Phase-1 needs: the scanner suite, DuckDB query diff, and HTML render-snapshot tests are pure deep-equal / string-equal. Snapshots can be plain `*.snap.html` text files compared via `assert.strictEqual` + a `--update-snapshots` env flag (vanilla, ~30 LOC helper).
- `bats` is already entrenched (`scripts/__tests__/*.xfail.bats`, `scripts/tests/*.bats`) and is the right hammer for the `npm run retro:ingest && npm run retro:render` end-to-end smoke in T.P1.6.
- POSIX-portable: both `node:test` and `bats` run identically on macOS and Git Bash on Windows. No platform-specific affordances required.
- T.P1.1's task line currently says "vitest (or node:test)" in §266. Aphelios's note is satisfied by node:test; no breakdown amendment needed.

### Per-task test specs (T.P1.1–T.P1.6)

Every xfail test task lands as its own commit on the same branch BEFORE the implementation task it pairs with, per Rule 12. Test commit prefix `chore:`. xfail test-task titles include the literal word **xfail**.

#### Level 1 — Unit / fixture-level

- [ ] **TP1.T1** — xfail unit suite for events.jsonl scanner per source. estimate_minutes: 50. Files: `tools/retro/__tests__/ingest-sources.test.mjs`, `tools/retro/fixtures/parent-session.jsonl`, `tools/retro/fixtures/subagents/agent-fixt001.jsonl`, `tools/retro/fixtures/subagents/agent-fixt001.meta.json`, `tools/retro/fixtures/subagent-sentinels/agent-fixt001`, `tools/retro/fixtures/git-log-plans.json`. DoD: (a) one `node:test` `describe` block per upstream source from §Q1 — parent jsonl, subagent jsonl, sentinel, git-log mock — each asserts the scanner emits the exact event records expected for that source in isolation; (b) parent-jsonl test asserts every `assistant` row with absent `isSidechain` is tagged `kind: turn, role: coordinator-inline`; (c) subagent-jsonl test asserts `isSidechain: true` rows are tagged `role: delegated` and carry the parent `sessionId` from `meta.json`; (d) sentinel test asserts the zero-byte file's mtime becomes the `dispatch_end_ts` for its `agent-<id>`; (e) git-log-mock test asserts `Promoted-By: Orianna` trailer commits emit `kind: plan-stage` events with the correct `(plan_slug, stage)` tuple; (f) suite is xfail (skip via `{ skip: !existsSync(ingestPath) }`) with a `Plan-Ref:` trailer citing this ADR. Guards: T.P1.1 / T.P1.2. Committed before T.P1.2 per Rule 12.

- [ ] **TP1.T2** — xfail invariant test: token cost byte-deterministic rollup. estimate_minutes: 25. Files: `tools/retro/__tests__/invariant-token-cost.test.mjs`, `tools/retro/fixtures/known-token-counts.jsonl`. DoD: (a) fixture is a hand-curated JSONL with three assistant turns whose `usage` blocks declare `input_tokens=100, output_tokens=200, cache_read=50, cache_creation=25` (one turn each, summing to known totals); (b) test runs `ingest.mjs` then runs `plan-rollup.sql` via DuckDB; (c) asserts the rollup row's four token columns equal the hand-summed totals **exactly** (no float math, integer compare); (d) asserts running the same fixture twice produces byte-identical `events.jsonl` (deterministic emission order); (e) xfail until T.P1.2 + T.P1.4 land. Guards: T.P1.2 + T.P1.4 (cross-task invariant). Committed before T.P1.2 per Rule 12.

- [ ] **TP1.T3** — xfail invariant test: wall-active-minutes strips gaps >90s. estimate_minutes: 20. Files: `tools/retro/__tests__/invariant-wall-active.test.mjs`, `tools/retro/fixtures/idle-gap-session.jsonl`. DoD: (a) fixture has 5 assistant turns with deltas `{30s, 120s, 45s, 91s, 60s}` between consecutive turns — gaps `120s` and `91s` are above the 90s threshold from §3; (b) test asserts `wall_active_minutes` for the session = `(30+45+60)/60 = 2.25` minutes (the >90s gaps stripped, only intra-active intervals summed); (c) edge-case rows: gap of exactly `90s` IS counted (boundary inclusive per §3 wording "<=90s"); test asserts a fixture with one `90s` gap is NOT stripped; (d) xfail until T.P1.2 lands. Guards: T.P1.2. Committed before T.P1.2 per Rule 12.

- [ ] **TP1.T4** — xfail invariant test: plan-stage three-signal layered detection. estimate_minutes: 35. Files: `tools/retro/__tests__/invariant-plan-stage.test.mjs`, `tools/retro/fixtures/plan-stage-signals/`. DoD: (a) three sub-fixtures: (i) trailer-only — git log carries `Promoted-By: Orianna` for slug X with no frontmatter mtime change; assert `plan-stage` event emitted with `signal: trailer`; (ii) frontmatter-only — `status:` line mutation in `plans/**.md` git history but no Orianna trailer; assert event emitted with `signal: frontmatter-mtime`; (iii) dispatch-prompt-only — neither trailer nor frontmatter, but a subagent dispatch prompt cites `plans/in-progress/personal/<slug>.md`; assert event emitted with `signal: dispatch-prompt-slug-match`; (b) precedence test: when ALL THREE signals exist concurrently for the same `(slug, stage)`, assert the emitted event's `signal` field = `trailer` (canonical wins) and the other two are recorded as corroborating in `signal_corroborators: [...]`; (c) **R3 rank-tie xfail probe** — when a `Promoted-By: Orianna` trailer for slug X says `proposed->approved` but the SAME plan's `status:` frontmatter mtime in git history shows `approved->in-progress` 30 seconds LATER (i.e. trailer and mtime disagree on which stage the plan currently sits in), assert behavior is documented; this sub-test stays xfail UNTIL Swain answers OQ-R3 (see below). Guards: T.P1.2. Committed before T.P1.2 per Rule 12.

- [ ] **TP1.T5** — xfail unit suite for paired DuckDB query `.expected.json` golden files. estimate_minutes: 35. Files: `tools/retro/__tests__/queries.test.mjs`, `tools/retro/queries/plan-rollup.expected.json`, `tools/retro/queries/coordinator-weekly-skeleton.expected.json`. DoD: (a) test loads `tools/retro/fixtures/expected-events.jsonl`, runs each `.sql` in `tools/retro/queries/` via DuckDB CLI as a subprocess (no DuckDB-node dep wrangling at the test level — same binary T.P1.4 will use); (b) deep-equal diff (key-sorted JSON) against the paired `.expected.json`; (c) failure message prints unified diff via `node:util.styleText` for fast triage; (d) `coordinator-weekly-skeleton.expected.json` MUST NOT contain feedback-bound or decision-bound columns (Phase 2 boundary check — fails build if a Phase-2 column leaks early); (e) xfail until T.P1.4 lands. Guards: T.P1.3 + T.P1.4. Committed before T.P1.4 per Rule 12.

- [ ] **TP1.T6** — xfail static-HTML render snapshot suite. estimate_minutes: 30. Files: `tools/retro/__tests__/render-html.test.mjs`, `tools/retro/__tests__/__snapshots__/index.html.snap`, `tools/retro/__tests__/__snapshots__/plan-detail-<historical-slug>.html.snap`, `tools/retro/__tests__/lib/snapshot.mjs` (~30-LOC vanilla snapshot helper). DoD: (a) snapshot helper compares emitted HTML to `*.snap` text files; `UPDATE_SNAPSHOTS=1` env flag rewrites; (b) `index.html` snapshot asserts the historical implemented plan from T.P1.1 fixtures appears in the listing with its expected `(stage_count, total_tokens, wall_active_minutes)` cells; (c) `plan-<slug>.html` snapshot asserts every `(stage, agent, tokens_input, tokens_output, wall_active_minutes)` row from `plan-rollup.expected.json` is present in a `<table>` with stable column order; (d) **R2 snapshot-determinism guard**: re-run the render twice in the same test invocation, assert both runs produce byte-identical HTML; assert NO `Date.now()`, `new Date()`, `Math.random()`, or `process.pid` substring leaks into the snapshot (regex scan); (e) HTML-shape lint inside the snapshot: assert presence of `<link rel="stylesheet" href="app.css">`, no `<script src="vue` / `pinia` / `vue-router` (§Q4 SPA-rejection guard), exactly one inline `<script>` block; (f) xfail until T.P1.6 lands. Guards: T.P1.5 + T.P1.6. Committed before T.P1.6 per Rule 12.

#### Level 2 — Integration

- [ ] **TP1.T7** — xfail end-to-end pipeline integration test (bats). estimate_minutes: 40. Files: `tools/retro/__tests__/e2e-pipeline.bats`, `tools/retro/fixtures/e2e/` (fixture-pinned superset of T.P1.1's source fixtures + a second historical plan slug for multi-row coverage). DoD: (a) `setup()` points `HOME` and `STRAWBERRY_USAGE_CACHE` at a temp dir seeded from the fixture tree; (b) test runs `npm run retro:ingest` then `npm run retro:render`; (c) asserts `events.jsonl` exists, line count matches expected, last line's JSON parses; (d) asserts `tools/retro/dist/data/plan-rollup.json` deep-equals `plan-rollup.expected.json`; (e) asserts `tools/retro/dist/index.html` exists and contains every fixture plan's slug as an anchor `href="plan-<slug>.html"`; (f) asserts at least one `plan-<slug>.html` exists and contains the expected stage x agent x token cells; (g) end-to-end wall time on fixture corpus <5s (asserted via `time` capture) per §3 budget; (h) `teardown()` cleans temp dir; (i) xfail (skipped via bats `skip` if `tools/retro/render.mjs` missing) until T.P1.6 lands. Guards: T.P1.6 acceptance gate (§4 "Duong can click a plan and see stage x agent x token cost rendered correctly"). Committed before T.P1.6 per Rule 12.

#### Level 3 — Cross-cutting / pre-existing (carried forward)

- Coordinator discriminator (§Q8): subsumed by TP1.T1 sub-cases (b) and (c) — path-based attribution is asserted there; no separate task.
- Lock bypass discipline: deferred to Phase 3 breakdown (the `canonical-v1-active.flag` and `Lock-Bypass:` trailer hook live in T.COORD.3 / Phase 3 scope). Not a Phase-1 test.

### Coverage matrix (test -> task it guards)

| Test task | Guards impl task(s) | Rule 12 commit-before |
|---|---|---|
| TP1.T1 | T.P1.1, T.P1.2 | T.P1.2 |
| TP1.T2 | T.P1.2, T.P1.4 | T.P1.2 |
| TP1.T3 | T.P1.2 | T.P1.2 |
| TP1.T4 | T.P1.2 (R3 sub-test stays xfail) | T.P1.2 |
| TP1.T5 | T.P1.3, T.P1.4 | T.P1.4 |
| TP1.T6 | T.P1.5, T.P1.6 (R2 guard) | T.P1.6 |
| TP1.T7 | T.P1.6 (acceptance gate) | T.P1.6 |

Total: **7 test tasks, 235 minutes.** All <=60 min. All committed xfail-first per Rule 12.

### Determinism and POSIX guarantees

- Every fixture is hand-curated text — no generated timestamps, no UUIDs from runtime.
- `node:test` and `bats` both run on macOS + Git Bash on Windows. Suites avoid `find -printf`, GNU-only `sed -i ''` quirks, and `readarray`.
- The R2 snapshot-determinism guard (TP1.T6 DoD-d) is the canonical defense against `Date.now()` injection in `render.mjs`; it fires on every CI run, not just on snapshot update.

### Open question for Swain — R3 rank-tie rule

**OQ-R3 (NEW, raised by Xayah 2026-04-25 during Phase 1 test-plan authoring):** §Q2's three-signal table declares `Orianna trailer` "canonical" and `status:` frontmatter mtime "strong corroboration matching the Orianna commit" — but it does NOT specify behavior when the two **disagree on current stage** (e.g. trailer says `approved`, frontmatter mtime indicates the plan moved to `in-progress` 30s later via a hand-edit or a non-Orianna commit). Three candidate rules:

1. **Trailer wins, log warning** — frontmatter discrepancy emits `events.jsonl` annotation `signal_conflict: frontmatter-newer-than-trailer` for retro inspection. Simplest. Trailer-canonical aligns with Rule 19.
2. **Newest-timestamp wins** — whichever signal is timestamp-latest determines current stage. Risks legitimizing hand-edits as state transitions.
3. **Hard-fail ingest** — the scanner aborts with non-zero exit and a diagnostic; Duong reconciles before rebuild. Safest correctness, worst ergonomics.

Xayah recommendation: **(1) trailer wins, log warning** — Rule 19 already establishes Orianna as the canonical promoter; frontmatter discrepancies are recoverable observations, not fatal. TP1.T4 sub-test (c) stays xfail with `Plan-Ref:` annotation `BLOCKED-ON-OQ-R3` until Swain rules. On Swain ruling: the xfail flips to assert the chosen rule and lands as part of T.P1.2 commit (or a follow-up commit if T.P1.2 has already shipped).

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

---
status: proposed
concern: personal
owner: swain
created: 2026-04-21
tests_required: true
tags: [dashboard, observability, retrospection, otel, local-first]
related:
  - plans/proposed/2026-04-19-claude-usage-dashboard.md
  - plans/proposed/2026-04-19-usage-dashboard-subagent-task-attribution.md
  - plans/proposed/2026-04-19-tests-dashboard.md
---

# Retrospection & Observability Dashboard

## 1. Problem & motivation

Duong needs one surface that answers three questions at once:

1. **What did the agent system do?** — per-session, per-subagent work records: the task brief, the outcome, the duration, the cost, the tool calls, the exit signal.
2. **What did Duong do?** — the ideas, goals, and tracked tasks he wants to carry across sessions ("I want to build X") so they don't evaporate when a session closes.
3. **What is the balance?** — time-sliced views of the week and the month, split on a first-class **system-building vs product-building** axis so Duong can see and steer that ratio.

Today the signal is scattered across five places that do not compose:

| Signal | Where it lives | Queryable? |
|---|---|---|
| Per-session tokens + cost | existing `ccusage` pipeline into `dashboards/usage-dashboard/data.json` <!-- orianna: ok --> | yes — JSON, agent-attributed by the first-user-message heuristic |
| Per-subagent per-task attribution | planned but not yet emitted — `subagents.json` from the v1 capture pipeline in plan `2026-04-19-usage-dashboard-subagent-task-attribution.md` <!-- orianna: ok --> | partial — v1 capture exists in plan; v2 UI does not |
| Raw session transcripts | `~/.claude/projects/<slug>/<session-id>.jsonl` (3.8 GB local) <!-- orianna: ok --> | expensive — ~231 jsonl files in one project slug alone; each up to 6 MB |
| Agent memory / journals / learnings | `agents/<name>/memory/*.md`, `agents/<name>/journal/*.md`, `agents/<name>/learnings/*.md` <!-- orianna: ok --> | grep-only, no structured index |
| Duong's own tracked work | `tasklist/tasklist.json` served by the Fly.io task-list app <!-- orianna: ok -->; plus his ideas scattered in Telegram / notes / head | partial — task list is structured, ideas are not captured |

There is no single surface that joins these. There is no retrospection view. There is no system-vs-product label on any record.

**This plan** specifies a new app — the **Retrospection Dashboard** — that joins the five sources, categorizes work on the system/product axis, and gives Duong a weekly / monthly review page plus an always-on capture flow for new ideas.

### Explicit non-rewrite

The existing `usage-dashboard` pipeline (`ccusage` → `agent-scan.mjs` → `merge.mjs` → `data.json` → static HTML) is load-bearing and stays. The retrospection dashboard **reuses its output** as its primary cost/token source. The subagent-task-attribution plan's v1 capture (`subagents.json`) is also reused wholesale. This ADR does not reopen either decision.

## 2. Decision

Build a single-page application called **Retro Dashboard** that:

1. Lives at `~/Documents/Personal/strawberry-retro/` as a **new sibling of `strawberry-app`** (not inside this repo, not inside `strawberry-app/apps/`). Justified in §D1.
2. Uses the **same stack as `apps/myapps` in `strawberry-app`**: Vite, Vue 3 with TypeScript, Tailwind, Pinia, vue-router, date-fns, Chart.js / vue-chartjs. No new runtime dependencies on paid services. <!-- orianna: ok -->
3. Reads data from **flat local files via a tiny Node-based ingestor that writes a single denormalized `retro.json` at a 5-minute cadence**. No SQLite, no DuckDB, no Anthropic API calls, no Prometheus scraper in v1. Storage trade-offs are justified in §D3. <!-- orianna: ok -->
4. Consumes **four input sources**, unified by `sessionId`:
   - the existing `~/.claude/strawberry-usage-cache/*.json` outputs (`ccusage` session/blocks/daily) <!-- orianna: ok -->
   - the existing roster attribution `agents.json` <!-- orianna: ok -->
   - the planned `subagents.json` per-spawn capture (from plan `2026-04-19-usage-dashboard-subagent-task-attribution.md`) <!-- orianna: ok -->
   - a new **retrospection index** at `agents/retro/retro-index.json` generated from agent memory, journals, learnings, last-sessions, and git log. <!-- orianna: ok -->
5. Labels every record on a **system-vs-product axis** via two complementary signals (repo-based + tag-based), surfaced as a ratio in the header chrome and as a stacked bar in the weekly/monthly views. Full labeling spec in §D4.
6. Provides a **capture flow for Duong's ideas and goals** via a simple drop-in: `agents/retro/captures/` append-only markdown with frontmatter, plus a `/retro` skill to scaffold one file. No new MCP. No new fly.io service. Full flow in §D5.
7. Ships in **three phases** (walking skeleton → retro queries → capture + polish). Full rollout in §D9.
8. Is **localhost-only in v0/v1**. Phone access is deferred to a v2 gating question (§OQ1). Security + scrubbing policy in §D8.

### Scope — out

- Real-time streaming. The dashboard reads a 5-minute-stale snapshot.
- Anthropic API calls of any kind. The dashboard never calls the API. No summarization model, no embedding model, no Claude-generated labels. <!-- orianna: ok -->
- Paid service dependencies — no Datadog, no Honeycomb, no Grafana Cloud, no Vercel, no Firebase Firestore. <!-- orianna: ok -->
- Absorbing `usage-dashboard`. That page stays standalone; Retro Dashboard links to it for raw token drill-downs.
- Absorbing `tests-dashboard`. Retro Dashboard renders a test-health widget sourced from its emitted `tests.json`, but does not replace it.
- Work-concern data. `[concern: personal]` only. Work sessions in `~/.claude/projects/-Users-duongntd99-Documents-Work-*` are filtered out at ingest. <!-- orianna: ok -->
- AI-generated retrospection narratives. All summaries are query-generated (deterministic aggregation), not LLM-generated.
- Mobile-first design. Responsive down to tablet is a v1 goal; phone-native is a v2 goal.

## 3. Design

### D1. Location & stack choice

**Pick: `~/Documents/Personal/strawberry-retro/` as a new sibling repo.** Not `apps/retro-dashboard/` in `strawberry-agents`, not `apps/retro-dashboard/` in `strawberry-app`.

Justification — evaluated against the three candidates:

| Option | Pro | Con | Verdict |
|---|---|---|---|
| Inside `strawberry-agents` at `apps/retro-dashboard/` | Zero relocation cost; co-located with agent memory it indexes | `strawberry-agents` is the system-building repo, not a product-deploy repo; it has no `apps/` convention today (no existing directory); mixing a user-facing app into the ops repo violates the current "system" vs "product" split Duong is trying to measure | Reject |
| Inside `strawberry-app` at `apps/retro-dashboard/` or `dashboards/retro-dashboard/` | Reuses turbo + husky + tooling; lives next to `usage-dashboard` and `test-dashboard` | Retro Dashboard reads from `strawberry-agents` (agent memory) — a sibling-path import (`../strawberry-agents/agents/**/*.md`) is brittle and re-introduces the problem a separate repo would clean up; also couples deploy / release-please cadence of the apps monorepo to a tool that is local-only | Reject |
| New sibling repo `~/Documents/Personal/strawberry-retro/` | Clean boundary — reads from both `strawberry-agents` and `strawberry-app` via explicit sibling paths (not imports); local-only so no deploy coupling; its own git history and commit rhythm; mirrors how `tasklist/` was set up as a standalone Fly service <!-- orianna: ok --> | One more repo to keep in sync; no shared tooling with apps monorepo | **Accepted** |

**Stack — Vite + Vue 3 + TS + Tailwind + Pinia + vue-router + date-fns + Chart.js + vue-chartjs.** This is the exact stack `apps/myapps` uses in `strawberry-app`. <!-- orianna: ok --> Duong already knows it; Neeko already has design conventions for it; `dashboards/test-dashboard` is the one React/Vite outlier and its choice has not propagated. Defaulting to the dominant convention keeps future contributors (human or agent) in one mental model.

Node ≥ 20, npm. One `package.json`, one `vite.config.ts`, one `tailwind.config.js`. No monorepo, no turbo.

### D2. Data model — canonical source per surface

| Surface | Canonical source | Why | ETL cadence |
|---|---|---|---|
| Per-session tokens + cost | `~/.claude/strawberry-usage-cache/sessions.json` (from `ccusage session -j -i -p`) <!-- orianna: ok --> | Already normalized, already agent-attributed via the existing `agent-scan.mjs` heuristic; re-parsing raw jsonl would duplicate that work and is prohibitively expensive (3.8 GB total) | 10-minute existing cadence — Retro Dashboard reads what the usage-dashboard build produces |
| 5-hour billing-window state | `~/.claude/strawberry-usage-cache/blocks.json` <!-- orianna: ok --> | Same reasoning — reuse the existing extraction | 10-minute existing cadence |
| Per-subagent per-task spawn records | `~/.claude/strawberry-usage-cache/subagents.json` (produced by v1 of plan `2026-04-19-usage-dashboard-subagent-task-attribution.md`) <!-- orianna: ok --> | This is the ONLY source that joins the parent session's `Task` tool call (carrying `subagent_type` + prompt) to the child session's tokens. Reconstructing it by re-parsing jsonl would re-implement the v1 scanner | 10-minute existing cadence (v1 scanner runs in the same `build.sh` tick) |
| Session goals / outcomes / durations | `agents/<name>/memory/last-sessions/*.md` + `agents/<name>/journal/*.md` <!-- orianna: ok --> | These are the structured handoffs `/end-session` and `/end-subagent-session` already emit; they contain goal + outcome + pointers in a consistent shape | 5-minute poll — retro-indexer watches these dirs and regenerates `retro-index.json` |
| Agent learnings (cross-session knowledge) | `agents/<name>/learnings/*.md` + `agents/<name>/learnings/index.md` <!-- orianna: ok --> | Already topic-indexed; the index file gives a stable slug per learning | Same 5-minute poll |
| Git activity (commits, diffs as change-volume signal) | `git log` in both `strawberry-agents` and `strawberry-app` | Primary source of truth for "what actually shipped"; commit prefix (`chore:` / `feat:` / `fix:` / `ops:`) is the first-pass system-vs-product signal (§D4) | 5-minute poll, only `git log --since='<last_run>'` |
| Duong's tracked tasks | `tasklist/tasklist.json` from the existing Fly service, mirrored locally at `agents/retro/tasklist-mirror.json` <!-- orianna: ok --> | Already structured; the Fly service exposes GET `/api/tasks` unauthenticated (LAN-only) — safe to pull | 5-minute poll via HTTP GET |
| Duong's ideas / goals (new) | `agents/retro/captures/YYYY-MM-DD-<slug>.md` — new directory created by this plan <!-- orianna: ok --> | Markdown + frontmatter is the lingua franca of this repo; readable by humans, diffable, grep-able | Same 5-minute poll |

All eight sources are joined into a single denormalized `retro.json` written atomically to the dashboard's `public/data/retro.json` by the ingestor. The dashboard reads that one file on page load (and a poll-to-refresh every 60 seconds in-browser).

### D3. Storage choice — SQLite vs DuckDB vs flat files

**Pick: flat JSON files in v1.** Defer any database to v2 gated on measured cost.

Evaluated trade-offs:

| Option | Pro | Con |
|---|---|---|
| SQLite (e.g. `better-sqlite3`) <!-- orianna: ok --> | Real queries, indexes, joins in the ingestor; durable; one-file; no external process | Schema migration burden; requires a native module build; 5 MB of JSON is not large enough to justify |
| DuckDB (in-process OLAP) <!-- orianna: ok --> | Columnar + window functions are perfect for the retro queries in §D6 | Same binary-build pain as SQLite; overkill at Duong's data scale (months of sessions fits comfortably in a 20 MB JSON) |
| Flat files — `retro.json` + optional monthly shards | Zero dependency; diff-able in git if ever useful; trivial backup; no migration | No joins — ingestor must do them; file bloat if we don't shard |

The total data volume Duong is generating today is small: 231 sessions in a project slug over ~3 weeks, ~20 agents each with memory under 50 lines and learnings under 10 topics, one tasklist of ~40 items. Even with 12 months of accumulation, a fully-joined denormalized JSON fits in under 10 MB — well within browser fetch + parse budgets.

**Sharding policy:** When `retro.json` exceeds 5 MB on disk, the ingestor shards by calendar month: `public/data/retro-index.json` (always loaded, summary + cross-month aggregates) + `public/data/retro-YYYY-MM.json` (loaded on demand when that month is viewed). The shard boundary is ISO week-safe: a session starting 2026-04-30 23:50 that bleeds into May is filed in April by `startedAt`.

### D4. System-vs-product axis — labeling model

The axis is a first-class attribute on every record (session, subagent-spawn, commit, task, capture). Labels are derived by the ingestor, not user-supplied at write-time.

**Two-signal derivation, AND-combined with a tiebreak:**

| Signal | Source | Values | Weight |
|---|---|---|---|
| **Repo signal** | For git-sourced records, the repo of the commit: `strawberry-agents` or `strawberry-retro` → `system`; `strawberry-app` → `product`; `tasklist/` → `system-tool` | system / product / system-tool | primary |
| **Commit-prefix signal** | For git-sourced records, the conventional-commit prefix: `ops:` or `chore:` → `system`; `feat:` / `fix:` / `perf:` / `refactor:` → `product` (in `strawberry-app`) or `system` (in `strawberry-agents`) | system / product | secondary |
| **Path-tag signal** (sessions / subagent spawns) | The dominant `cwd` of the parent session and the dominant touched-path prefix from the session's tool events: `agents/`, `plans/`, `scripts/`, `architecture/`, `.claude/` → `system`; `apps/`, `dashboards/`, `packages/` → `product` <!-- orianna: ok --> | system / product / mixed | primary for non-git records |
| **Tag override** (captures, tasks) | Explicit `axis: system` or `axis: product` in the frontmatter of a capture file or in the tag field of a tracked task | system / product / neither | wins when present |

**Combination rule:** For each record, compute the two applicable signals (repo+prefix for commits; path-tag alone for sessions/spawns; tag override for captures/tasks). If they agree, the label is `system` or `product`. If they disagree, the label is `mixed` and the record contributes 0.5 to each axis in aggregations. The rule is deliberately boring so results are reproducible.

**Surface:** A sticky header ratio strip shows `System: N minutes / $X  |  Product: M minutes / $Y  |  Mixed: K minutes / $Z` for the currently selected time window. The weekly/monthly pages show this as a stacked horizontal bar plus a week-over-week delta.

**Anti-goal:** The ratio is not a quota. Duong uses it to notice drift, not to enforce a target.

### D5. Capture flow for ideas and goals

**Pick: append-only markdown files in `agents/retro/captures/` in `strawberry-agents`, plus a new `/retro capture` skill to scaffold them. No new MCP tool.** <!-- orianna: ok -->

Evaluated candidates:

| Candidate | Pro | Con | Verdict |
|---|---|---|---|
| New MCP task tool (extend `mcp__evelynn__task_*`) <!-- orianna: ok --> | Structured, queryable, shared with tracked tasks | MCP is the heaviest mechanism and couples to Evelynn's MCP server which is Mac-only; captures can happen from any session | Reject |
| Inbox-channel-style drop (write to `agents/retro/inbox/`) | Mirrors existing inbox pattern agents already know <!-- orianna: ok --> | Inbox is per-agent; a cross-cutting "idea bucket" is not one agent's job | Reject shape; keep concept (append-only file drop) |
| Direct markdown file edit in `agents/retro/captures/` via a new `/retro capture` skill <!-- orianna: ok --> | Zero infra; portable; the skill is model-invocable so Duong can say "capture this: I want to build X" in any session and the agent scaffolds a file; diff-able; the retro-indexer picks it up on the next tick | Requires the skill to exist | **Accepted** |

**Capture file schema** — `agents/retro/captures/YYYY-MM-DD-<slug>.md` <!-- orianna: ok -->

```markdown
---
captured_at: 2026-04-21T14:30:00Z
from_session: <session-id-or-null>
axis: system|product|neither
kind: idea|goal|todo|retro-note
status: open|doing|done|dropped
target_date: <YYYY-MM-DD or null>
tags: [<tag1>, <tag2>]
---

# <one-line title>

<body — free-form markdown>
```

The `/retro capture` skill prompts the invoking agent to fill the title, kind, axis, and body, then writes the file and echoes the path. Status transitions are edits to the same file (no second file). The dashboard's "Ideas" page lists all captures, filterable by status, axis, kind.

**Tasks vs captures:** Tracked tasks stay in the Fly `tasklist/tasklist.json`. Captures are a superset — every tracked task has a one-time "I want to build X" phase that belongs in captures; when Duong commits to doing it, the capture's `status: doing` is the handoff signal and a task-list entry is created (by Duong or by any agent with the `/retro promote` skill, v2). v1 ships capture → view only; promotion automation is v2.

### D6. UI structure — navigation and landing view

**Landing view:** "This Week". Header strip + three panels:

1. **Ratio strip** (always-visible sticky header) — System / Product / Mixed minutes + cost for current time window.
2. **Agent activity** — a horizontal bar per active agent, width = minutes active this week, stacked by axis. Click → drill to that agent's sessions.
3. **What shipped this week** — a reverse-chron feed of merged PRs, promoted plans, and completed captures, grouped by day. Click any item → detail pane with linked session.
4. **Ideas & goals** — the three most-recent `open` captures + a "+ capture" button that opens a small modal which writes to `agents/retro/captures/`.

**Top-level nav** (left rail, collapsible to icons on narrow viewports):

| Section | What lives here |
|---|---|
| **Now** | Current 5-hour billing window, currently-running sessions, last 24h activity feed |
| **This Week** (default landing) | The landing view above |
| **This Month** | Monthly version of the landing view — monthly ratio, top agents, top sessions by cost, shipped list grouped by week |
| **Retro** | Free-form retro query builder (§D7): pick a time range + axis filter + agent filter, get the 10 named-query answers rendered as cards |
| **Agents** | Per-agent detail — sessions, learnings, memory excerpt, cost trend, axis ratio |
| **Sessions** | Flat table of all sessions (paginated), filterable by agent / date / axis / cost threshold; click → session drill-down |
| **Ideas** | All captures, filterable; + the capture modal |
| **Tasks** | Mirror of the Fly tasklist (read + click-through to the Fly app for edits in v1; inline edit v2) |
| **System** | Health panel — ingestor last run, data freshness, any source errors, link to raw `ccusage` dashboard <!-- orianna: ok --> |

**Information-architecture principle:** Time-sliced pages (Now / This Week / This Month) are the retrospection surface. Entity pages (Agents / Sessions / Ideas / Tasks) are the drill-down surface. Retro is the ad-hoc query surface. System is the self-observation surface. Every data point on a time-sliced page links to its entity-page home.

**Visual polish bar** (deferred in concrete form to Neeko for the post-ADR design pass):
- Typography: a single serif / sans pair — Neeko to select per her design principles.
- Color: no dark-theme-or-light — a single muted palette tuned for long looking, not neon. The existing `usage-dashboard` Catppuccin Mocha palette (`#1e1e2e` / `#cdd6f4` / `#cba6f7`) is a candidate but not binding.
- Density: information-dense but not crowded — Bloomberg-terminal-inspired for the Now page, magazine-inspired for the Retro pages.
- Motion: no entrance animations; transitions only on state change and only on interactive elements.

### D7. The ten named retrospection queries

Each is a deterministic aggregation over `retro.json`. These drive the Retro page cards and are runnable by any developer with `jq` or equivalent against the same JSON. <!-- orianna: ok -->

1. **Axis ratio for window** — `(sum(minutes) by axis in window) / total` + week-over-week delta.
2. **Top 5 most-expensive sessions in window** — sessions sorted by cost desc, grouped by agent.
3. **Top 5 most-expensive subagent tasks in window** — subagent spawns sorted by cost desc, showing parent session + task brief.
4. **Loop detection** — subagents that spawned ≥ 3 times on the same task brief within 24 h (fuzzy-match on first 80 chars of brief).
5. **Learning velocity** — count of new learning files created per week, grouped by agent.
6. **Plan throughput** — plans that moved from `proposed/` → `approved/` → `in-progress/` → `implemented/` per week (derived from git-log on `plans/**`). <!-- orianna: ok -->
7. **PR lifecycle time** — for each merged PR, time from first commit on branch to merge (from `git log` + `gh pr view`).
8. **Capture-to-action latency** — for each capture that later transitioned `open` → `doing`, the time elapsed.
9. **Orphaned captures** — captures `open` for > 14 days with no edits — the "did I forget this?" list.
10. **Cost attribution by axis** — total `cost.usage` for the window split by axis, with a stacked area chart over the window.

All ten are pure functions of `retro.json`. None calls out to Anthropic's API or any paid service.

### D8. Security and scrubbing

The `ccusage` pipeline already operates on the session jsonl files with the existing filesystem permissions. The retrospection indexer touches three additional kinds of content: agent memory, agent journals, and the new captures. All three are committed to `strawberry-agents` and therefore already under Duong's review control.

**Session-jsonl scrubbing** — v1 does NOT read raw `.jsonl` files directly for content display. It only consumes the already-extracted `ccusage` outputs (token counts, cost, session ID, cwd) and the planned `subagents.json` (which carries the Task prompt brief — a potential PII vector). Policy:

| Risk | Mitigation |
|---|---|
| Subagent task brief contains Duong's raw prompt text (secrets, private thoughts) | `subagents.json` is gitignored (already in v1 plan). Retro Dashboard reads it but renders task briefs **truncated to the first 120 chars** in any visible panel. "Show full brief" is behind an explicit expand click. The data never leaves localhost in v1. |
| Captures may contain personal information | Captures live in `agents/retro/captures/` — Duong controls what he commits. The dashboard reads filesystem, not git. A separate `agents/retro/captures/private/` subdirectory is `.gitignore`d to hold captures Duong does not want committed; the indexer reads from both. |
| Agent memory / journals may contain session prompts | Already committed today; no new exposure. |
| The ingestor writes `public/data/retro.json` — if Duong ever serves this app over network, the whole join is on the wire | v1 binds to `127.0.0.1` only; the `npm run dev` and `npm run preview` scripts pin `--host 127.0.0.1`. §OQ1 handles v2 phone access. |

**No auth in v1.** localhost-only. If §OQ1 answers "yes, phone access": add Tailscale-scoped access only (no internet-exposed endpoint). Never Basic Auth, never a shared token. <!-- orianna: ok -->

### D9. Rollout — phased, walking skeleton first

Duong's pace is one engineer, one channel at a time. Phased rollout with a working walking skeleton at the end of Phase 1 is the safer default.

**Phase 1 — Walking skeleton (ship in one day of agent work).** Estimate: 5 tasks, 175 minutes.
- Scaffold the `strawberry-retro` repo with Vite + Vue 3 + TS + Tailwind + Pinia + vue-router.
- Ingestor reads `sessions.json` + `agents.json` from the existing usage-dashboard cache and writes a stub `retro.json`.
- Dashboard renders "Now" page: current 5-hour window state + last 24h sessions list. No axis labels yet.
- `npm run dev` serves on `127.0.0.1:5173`.
- Commit-prefix `chore:` since the new sibling repo does not touch `apps/**` — new repo has no `apps/**` yet; see §6 tasks for the first commit in the retro repo itself which uses `feat:` scoped to its own repo. <!-- orianna: ok -->

**Phase 2 — Retro queries + axis labels (2-3 days).** Estimate: 6 tasks, 285 minutes.
- Retro-indexer reads agent memory / journals / learnings / git-log / tasklist-mirror and produces `retro-index.json`.
- Axis-labeling implemented per §D4.
- "This Week" and "This Month" pages.
- The ten named queries in §D7 backed by real data.
- Agents, Sessions pages as plain tables.
- Depends on Phase 1.

**Phase 3 — Capture flow + polish (2 days).** Estimate: 5 tasks, 220 minutes.
- Captures directory + schema + indexer pickup.
- `/retro capture` skill scaffold.
- Ideas page.
- Sharding policy when `retro.json` > 5 MB.
- Neeko design pass + Seraphine implementation of the polish palette / typography / layout refinements.
- Depends on Phase 2.

**Rollout gate between phases:** After each phase, Duong runs the dashboard for at least 3 days of his normal work before Phase N+1 starts. This is a rubber-meets-road gate — if data is wrong, the query is wrong, or the ratio lies, we fix it before adding more surfaces.

## 4. Non-goals

- **Not a replacement for `ccusage` or `usage-dashboard`.** Retro Dashboard is a higher-level retrospection layer; the raw usage view stays.
- **Not a multi-user dashboard.** Single-user, Duong only. No auth, no roles.
- **Not a test-health dashboard.** That is `test-dashboard`'s job; Retro Dashboard shows a single widget sourced from its output.
- **Not a plan-lifecycle dashboard.** The plan-viewer (`2026-04-05-plan-viewer.md`) is the authority on plan state; Retro Dashboard shows a throughput metric only.
- **Not a calendar / schedule view.** No "Duong's week" time-blocking — this is retrospection, not planning.
- **Not a commit-grade code-review surface.** No diff rendering; cost/time attribution only.
- **No AI-generated insights.** All summaries are query-generated.

## 5. Risks & mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| Subagent-task-attribution plan (v1 capture) has not shipped yet; Retro Dashboard cannot show per-subagent-task cost until it does | medium | Phase 1 + Phase 2 do NOT depend on `subagents.json`. The per-subagent-task panel is a Phase 2 ADD that renders a "pending" state if the file is absent. Absence is a soft gate, not a hard one. |
| Ingestor walks 3.8 GB of jsonl to compute axis path-tags, becomes slow | medium | v1 does not parse raw jsonl. Axis tagging uses only (a) the parent session's `cwd` (already in `sessions.json`) and (b) commit metadata from `git log`. Full-jsonl path-tag derivation is deferred behind a v2 gate. |
| `retro.json` grows past 10 MB and page load gets slow | low | Shard at 5 MB per §D3. Also: the Now page loads only the last-24h slice; weekly/monthly load their specific shards on demand. |
| Axis labeling disagrees with Duong's intuition often enough that he stops trusting the ratio | high | Ship §D4's `mixed` bucket as a legitimate category (not a bug). Provide a "re-label" UI in v2 that writes an override file. In v1, the override mechanism is: add `axis: system` (or `product`) to the capture file or commit body and the indexer respects it. |
| The new sibling repo drifts out of sync with `strawberry-agents` conventions (lint, TDD gate, commit hooks) | medium | The `strawberry-retro` repo ships with the same pre-commit hook + `install-hooks.sh` copied from `strawberry-agents`. <!-- orianna: ok --> First task in Phase 1 is to install the hooks. Duong's `harukainguyen1411` identity owns the repo; `Duongntd` is the push identity (same two-identity model as the other repos). |
| Ingestor polls every 5 min and wastes CPU | low | The ingestor is an `inotify` / `fs.watch` wrapper on the four source dirs, not a blind poll; it regenerates only when at least one source has a newer mtime than `retro.json`. Empty ticks cost one `stat()` per source. |
| The `/retro capture` skill writes files as Duong is talking to an agent, and the agent doesn't realize the skill exists | medium | Capture is also possible by just creating the file by hand or via any agent with Write access. The skill is sugar, not the only path. Document the file format in `agents/retro/README.md`. |
| Session jsonl scrubbing misses an edge case where a capture file or memory file contains a secret | medium | Captures with `private/` prefix are gitignored. Memory files are already reviewed by Duong before commit per CLAUDE.md Rule 2. The dashboard adds no new exposure — it only reads what's already on disk. |
| Read-dependency on `usage-dashboard` build.sh cadence means a broken `ccusage` upstream breaks Retro Dashboard too | low | The "System" page shows each source's last-updated timestamp and a stale indicator if any source is > 20 min old. Retro Dashboard degrades to "stale" visibly rather than silently; query pages that depend on stale data show a banner. |

## 6. Tasks

**Phase 1 — Walking skeleton**

- [ ] **T1** — Scaffold `~/Documents/Personal/strawberry-retro/` repo: `npm init`, add Vite + Vue 3 + TS + Tailwind + Pinia + vue-router + date-fns + vue-chartjs + chart.js; install the `strawberry-agents` pre-commit hooks via `install-hooks.sh`; commit initial scaffold. estimate_minutes: 45. Files: `~/Documents/Personal/strawberry-retro/package.json` (new), `~/Documents/Personal/strawberry-retro/vite.config.ts` (new), `~/Documents/Personal/strawberry-retro/tailwind.config.js` (new), `~/Documents/Personal/strawberry-retro/tsconfig.json` (new), `~/Documents/Personal/strawberry-retro/index.html` (new), `~/Documents/Personal/strawberry-retro/src/main.ts` (new), `~/Documents/Personal/strawberry-retro/src/App.vue` (new), `~/Documents/Personal/strawberry-retro/.gitignore` (new). <!-- orianna: ok --> DoD: `npm run dev` serves a blank Vue app on 127.0.0.1:5173; pre-commit hook present.
- [ ] **T2** — Write xfail test for the ingestor's `buildRetroJson` function — input fixtures (stub `sessions.json` + `agents.json`) → output `retro.json` has `sessions[]`, `agents[]`, `lastRun`, `sources{}`. Test fails until T3. estimate_minutes: 30. Files: `~/Documents/Personal/strawberry-retro/ingestor/__tests__/build-retro-json.test.ts` (new), `~/Documents/Personal/strawberry-retro/ingestor/__fixtures__/sessions.json` (new), `~/Documents/Personal/strawberry-retro/ingestor/__fixtures__/agents.json` (new). <!-- orianna: ok --> DoD: `npm test` runs, one test present, test is xfail with a skip reason referencing this plan.
- [ ] **T3** — Implement minimal `buildRetroJson` that reads the two usage-dashboard outputs and produces the shape asserted in T2. No axis labels, no memory parsing. estimate_minutes: 45. Files: `~/Documents/Personal/strawberry-retro/ingestor/build-retro-json.ts` (new), `~/Documents/Personal/strawberry-retro/ingestor/index.ts` (new), `~/Documents/Personal/strawberry-retro/ingestor/sources/read-usage-dashboard.ts` (new). <!-- orianna: ok --> DoD: T2 test passes; `npm run ingest` writes `public/data/retro.json`.
- [ ] **T4** — Render the "Now" page: 5-hour billing window strip (reads `retro.json` in-browser) + last-24h session list. estimate_minutes: 40. Files: `~/Documents/Personal/strawberry-retro/src/pages/Now.vue` (new), `~/Documents/Personal/strawberry-retro/src/stores/retro.ts` (new), `~/Documents/Personal/strawberry-retro/src/router.ts` (new), `~/Documents/Personal/strawberry-retro/src/App.vue` (updated). <!-- orianna: ok --> DoD: `npm run dev` shows the Now page with real-ish data from the ingestor fixtures.
- [ ] **T5** — Add an `npm run ingest:watch` script that re-runs the ingestor when any source mtime changes. estimate_minutes: 15. Files: `~/Documents/Personal/strawberry-retro/ingestor/watch.ts` (new), `~/Documents/Personal/strawberry-retro/package.json` (updated). <!-- orianna: ok --> DoD: touching a source fixture triggers a rebuild of `retro.json` visible via page reload in dev.

Phase 1 total: 175 minutes (5 tasks).

**Phase 2 — Retro queries + axis labels**

- [ ] **T6** — Add xfail tests for each of the ten named queries in §D7, against a stub `retro.json` with known-answer data. estimate_minutes: 55. Files: `~/Documents/Personal/strawberry-retro/src/queries/__tests__/named-queries.test.ts` (new), `~/Documents/Personal/strawberry-retro/src/queries/__fixtures__/known-answer.json` (new). <!-- orianna: ok --> DoD: 10 xfail tests, each referencing §D7 query number.
- [ ] **T7** — Implement the retro-indexer: reads `agents/<name>/memory/**`, `agents/<name>/journal/**`, `agents/<name>/learnings/**`, `agents/<name>/memory/last-sessions/**` from `strawberry-agents/`, plus `git log --since='30 days ago'` from both sibling repos; writes `retro-index.json`. Mtime-cached. estimate_minutes: 60. Files: `~/Documents/Personal/strawberry-retro/ingestor/sources/read-agent-memory.ts` (new), `~/Documents/Personal/strawberry-retro/ingestor/sources/read-git-log.ts` (new), `~/Documents/Personal/strawberry-retro/ingestor/build-retro-index.ts` (new). <!-- orianna: ok --> DoD: `retro-index.json` exists, contains per-agent session handoffs + learnings + last N days of git commits from both sibling repos.
- [ ] **T8** — Implement axis labeling per §D4: repo signal + commit-prefix signal + path-tag signal; emit one label per record. Add unit tests covering the four rules + the mixed tiebreak. estimate_minutes: 45. Files: `~/Documents/Personal/strawberry-retro/ingestor/axis-label.ts` (new), `~/Documents/Personal/strawberry-retro/ingestor/__tests__/axis-label.test.ts` (new). <!-- orianna: ok --> DoD: each record in `retro.json` carries `axis: 'system' | 'product' | 'mixed'`; tests green.
- [ ] **T9** — Implement the ten named queries. Each query is a pure function in `src/queries/<query-name>.ts`; each used by exactly one "This Week" / "This Month" / Retro card. estimate_minutes: 55. Files: `~/Documents/Personal/strawberry-retro/src/queries/axis-ratio.ts` (new), `~/Documents/Personal/strawberry-retro/src/queries/top-sessions.ts` (new), `~/Documents/Personal/strawberry-retro/src/queries/top-subagent-tasks.ts` (new), `~/Documents/Personal/strawberry-retro/src/queries/loop-detection.ts` (new), `~/Documents/Personal/strawberry-retro/src/queries/learning-velocity.ts` (new), `~/Documents/Personal/strawberry-retro/src/queries/plan-throughput.ts` (new), `~/Documents/Personal/strawberry-retro/src/queries/pr-lifecycle.ts` (new), `~/Documents/Personal/strawberry-retro/src/queries/capture-latency.ts` (new), `~/Documents/Personal/strawberry-retro/src/queries/orphaned-captures.ts` (new), `~/Documents/Personal/strawberry-retro/src/queries/cost-by-axis.ts` (new), `~/Documents/Personal/strawberry-retro/src/queries/index.ts` (new). <!-- orianna: ok --> DoD: all 10 xfail tests from T6 pass; queries are pure functions with explicit input/output types.
- [ ] **T10** — Build the "This Week" and "This Month" pages wiring queries to cards + the ratio-strip header component. estimate_minutes: 45. Files: `~/Documents/Personal/strawberry-retro/src/pages/ThisWeek.vue` (new), `~/Documents/Personal/strawberry-retro/src/pages/ThisMonth.vue` (new), `~/Documents/Personal/strawberry-retro/src/components/RatioStrip.vue` (new), `~/Documents/Personal/strawberry-retro/src/components/QueryCard.vue` (new). <!-- orianna: ok --> DoD: pages render with real data when ingestor has run.
- [ ] **T11** — Build Agents + Sessions pages (plain tables, filter + sort, no design polish yet). estimate_minutes: 25. Files: `~/Documents/Personal/strawberry-retro/src/pages/Agents.vue` (new), `~/Documents/Personal/strawberry-retro/src/pages/Sessions.vue` (new), `~/Documents/Personal/strawberry-retro/src/components/AgentRow.vue` (new). <!-- orianna: ok --> DoD: both pages load; clicking a row navigates to a stubbed detail view (detail views are deferred to Phase 3).

Phase 2 total: 285 minutes (6 tasks).

**Phase 3 — Capture flow + polish**

- [ ] **T12** — Write the capture file schema doc + xfail test that a capture file with required frontmatter is read by the indexer. estimate_minutes: 25. Files: `agents/retro/README.md` (new), `agents/retro/captures/.gitkeep` (new), `agents/retro/captures/private/.gitkeep` (new), `~/Documents/Personal/strawberry-retro/ingestor/sources/__tests__/read-captures.test.ts` (new). <!-- orianna: ok --> DoD: README spec matches §D5; test exists and xfails.
- [ ] **T13** — Implement capture-source reader in the indexer; make T12 test pass; implement the Ideas page with filter by status/kind/axis. estimate_minutes: 45. Files: `~/Documents/Personal/strawberry-retro/ingestor/sources/read-captures.ts` (new), `~/Documents/Personal/strawberry-retro/src/pages/Ideas.vue` (new), `~/Documents/Personal/strawberry-retro/src/components/CaptureRow.vue` (new). <!-- orianna: ok --> DoD: Ideas page lists all captures with working filters.
- [ ] **T14** — Create the `/retro capture` skill. The skill scaffolds a capture file in `agents/retro/captures/YYYY-MM-DD-<slug>.md` interactively (asks for title, kind, axis) and echoes the path. estimate_minutes: 40. Files: `.claude/skills/retro/SKILL.md` (new), `.claude/skills/retro/capture.md` (new). <!-- orianna: ok --> DoD: `/retro capture "I want to build X"` creates a capture file and returns the path; frontmatter matches §D5 schema.
- [ ] **T15** — Implement the sharding policy (§D3): ingestor detects `retro.json` > 5 MB and splits into monthly shards + an always-loaded `retro-index.json`. Dashboard loader reads index first, fetches month shards on demand. estimate_minutes: 60. Files: `~/Documents/Personal/strawberry-retro/ingestor/shard-retro-json.ts` (new), `~/Documents/Personal/strawberry-retro/ingestor/__tests__/shard-retro-json.test.ts` (new), `~/Documents/Personal/strawberry-retro/src/stores/retro.ts` (updated). <!-- orianna: ok --> DoD: synthetic > 5 MB fixture produces shards; navigating to a month loads the shard lazily.
- [ ] **T16** — Neeko-led design pass: hand off to Neeko via a new plan at `plans/proposed/personal/2026-04-2X-retro-dashboard-design.md` (not in this plan's scope; T16 is the handoff task). estimate_minutes: 50. Files: a new design handoff plan (out of this plan's commit footprint). <!-- orianna: ok --> DoD: Neeko plan exists in `plans/proposed/personal/`; Retro Dashboard implementation deferred until design lands.

Phase 3 total: 220 minutes (5 tasks).

**Grand total estimate: 680 minutes across 16 tasks in 3 phases.**

## Test plan

`tests_required: true`.

- Ingestor unit tests: one xfail-first test per source reader, one per query. Run in `npm test` via vitest. All green before Phase N+1. <!-- orianna: ok -->
- Axis-label tests: fixture-driven — 4 rules × 2 outcomes × tiebreak = ~10 cases, all named after the rule they test.
- Query tests: 10 xfail tests against a known-answer fixture `retro.json`, one per named query in §D7.
- Dashboard smoke test (Phase 1 end, Phase 2 end, Phase 3 end): `npm run dev` serves the landing page, no console errors, 5-hour window + session list render. Manual for v1; Playwright-based in v2 (out of this plan).
- No Playwright E2E required in v1 — localhost-only, single-user; the PR-gate Playwright requirement (CLAUDE.md Rule 15) applies to `strawberry-app` and does not extend to `strawberry-retro`. Confirm via gating question OQ4.

## Rollback

- **Walking skeleton (Phase 1) rollback:** Delete the `strawberry-retro` repo. No data loss — all sources are upstream.
- **Phase 2 rollback:** Revert the ingestor commits to the Phase 1 tag; retro.json regenerates with Phase-1-shape data.
- **Phase 3 rollback:** Revert capture-reader commits; `agents/retro/captures/` stays as historical record.
- **Full rollback:** Remove the sibling repo + delete `agents/retro/` from `strawberry-agents`. Existing `usage-dashboard` / `test-dashboard` / `tasklist` are untouched.

## Open questions

- **OQ1** — Does Duong ever want phone access to this dashboard? If yes, Tailscale-scoped access is the only non-paid option that satisfies the "no paid service" constraint; Phase 3 adds a Tailscale HOWTO to the README. If no, pin `127.0.0.1` forever. Recommendation: defer — pin localhost in v1, revisit after 2 weeks of use.
- **OQ2** — Should the retro-indexer also read the work-concern agent memory (`agents/<name>/memory/*.md` sections tagged work) to give a unified cross-concern view, or keep strict `[concern: personal]` isolation? Recommendation: keep personal-only in v1; work-concern goes through Sona and has its own lifecycle. Cross-concern view is a v2 gate.
- **OQ3** — The subagent-task-attribution v1 plan (`2026-04-19-usage-dashboard-subagent-task-attribution.md`) is still `proposed/` and not implemented. Does Duong want to promote and land it first, or ship Retro Dashboard Phases 1+2 without the subagent-task panel and backfill when v1 lands? Recommendation: **ship Phases 1+2 without**. The panel degrades gracefully and the attribution plan's v1 can land in parallel. <!-- orianna: ok -->
- **OQ4** — Does CLAUDE.md Rule 15 (Playwright E2E on PR creation) apply to the `strawberry-retro` repo? The rule text targets "PR to main" without scoping to a repo. Recommendation: scope the rule to `strawberry-app` by adding an explicit exemption line in the pre-push hook for `strawberry-retro`; retro dashboard gets lighter smoke-test discipline instead. This is a governance change, not a plan change; escalate to Evelynn for a separate hook amendment.
- **OQ5** — Does Duong want `/retro capture` to be runnable from the work-concern Sona session too (writing to the same `agents/retro/captures/`), or personal-only? Recommendation: personal-only in v1 to avoid cross-concern leakage; work-concern gets its own capture directory if Sona ever wants one. The skill's first line can enforce `[concern: personal]`.
- **OQ6** — Do we want the "Tasks" page in the Retro Dashboard to write-through to the Fly tasklist (requires auth on the Fly service, currently trust-based LAN-only), or keep it read-only with a click-through to the Fly app for edits? Recommendation: read-only + click-through in v1. Write-through is a v2 gate.

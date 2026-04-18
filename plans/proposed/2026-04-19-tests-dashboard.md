---
status: proposed
owner: azir
created: 2026-04-19
slug: tests-dashboard
title: Strawberry Tests Dashboard — cross-repo test-run status surface
supersedes: []
related:
  - plans/approved/2026-04-19-claude-usage-dashboard.md
  - plans/in-progress/2026-04-17-deployment-pipeline.md
  - plans/approved/2026-04-17-test-dashboard-architecture.md
---

# Strawberry Tests Dashboard ADR

## Goal

A single dashboard that surfaces test-run status across the Strawberry personal system's two repos — `harukainguyen1411/strawberry-app` (application code, Vitest/TypeScript + Playwright) and `harukainguyen1411/strawberry-agents` (agent brain + infra, bash + shell test harnesses). One pane answers four questions:

1. **Runs list** — what test runs have happened, across both repos, in reverse chronological order.
2. **Per-test detail** — for any node ID, what is its current status, last error, first-seen date.
3. **Failure trends** — over the last N days/runs, which tests fail, which are newly failing, which are flaky.
4. **Per-test history** — for any node ID, the last K runs' pass/fail/xfail/skip with error messages on fail.

v1 scope intentionally small: **static SPA, private hosting or file://, no auth, cross-repo merged data source, two writers (pytest plugin is already proven for work; Vitest adapter is net-new for Strawberry).**

## Context: what we have, what we don't

**Reusable from `company-os/tools/demo-studio-v3` (reference; do not copy files):**

- `conftest_results_plugin.py` — pytest hook that emits `test-results.json` + `test-run-history.json` on every pytest run. Captures totals, per-test status, error messages, tracebacks, new-test detection, history ring (10-run rolling + 50-run history). Drop-in once pytest enters the picture.
- Schema of `test-results.json` (current-run snapshot) and `test-run-history.json` (ring buffer of recent runs with per-test detail). Already battle-tested against a 637-test suite in demo-studio-v3.
- GitHub-dark design tokens: Inter + JetBrains Mono, the color palette used in demo-studio-v3's dashboard shell.
- SSE + polling fallback pattern for live-refresh (optional for v1; polling alone is fine).

**Explicitly not reusable:**

- `dashboard.html` itself — it is a session-monitoring UI over Anthropic SDK events, not a test-results view. Build test-results view from scratch with the demo-studio-v3 design tokens.
- All auth scaffolding (multi-user SSO, CSRF, session cookies). Strawberry is personal/local; zero auth.

**Gap: Strawberry's primary stack is Vitest, not pytest.** The pytest plugin cannot be reused verbatim. A new **Vitest reporter/adapter** must emit the same JSON schema the pytest plugin produces, so a single dashboard can consume both writers uniformly. Nothing in demo-studio-v3 implements this — it is net-new.

**Relationship to the existing strawberry-app test dashboard** (`plans/approved/2026-04-17-test-dashboard-architecture.md`): that ADR scoped a Cloud Run service with a Vite+React frontend at `/test-dashboard`, with Firebase Auth (UID allow-list). It targeted a different data source (the strawberry-app session-monitoring domain) and a different hosting shape (Cloud Run + auth). This new dashboard is **sibling, not replacement** — same design tokens and ideally same `/dashboards/` hosting root, different data domain. See §7.

---

## Decisions

### D1. Hosting — v1 = local file:// only, no phone access in v1

**Decision: v1 = `file://` static SPA. Two files: `index.html`, `app.js`. Chart.js for sparklines via CDN. No phone access in v1. — Duong**

Rationale:

- Cheapest possible option (zero hosting cost, zero GCP surface, zero IAM). Matches the Strawberry "Google + free tier" rule trivially — there is no Google infrastructure to pay for.
- No auth problem to solve because the artifact never leaves the laptop.
- Matches the pattern already adopted for `plans/approved/2026-04-19-claude-usage-dashboard.md` v1 — one local static page per dashboard.
- Data sources (`test-results.json` / `test-run-history.json`) are small enough to ship as static JSON alongside the HTML.

Rejected:

- **Cloud Run** — overkill. No server-side logic, no auth needed, no SSR benefits. Same pattern as the usage-dashboard rejection.
- **Firebase Hosting (public)** — Strawberry test output includes file paths, error messages, and occasional stack traces that reflect private repo structure. Not for public consumption.
- **Firebase Hosting (private surface behind auth)** — valid v2 if Duong wants phone access. Deferred; requires an auth decision and breaks the "zero users, zero logins" posture.

Upgrade path (v2): same SPA, published to `strawberry-app`'s Firebase Hosting project under a private surface gated by the existing Firebase Auth + UID allow-list pattern already approved in the in-progress test-dashboard ADR. Zero rewrite of the frontend.

### D2. Data flow — artifact-style writes into `strawberry-agents/test-dashboard-data/` (gitignored), aggregated by a local build script; no cloud storage

**Decision:** each repo's test runner writes its `test-results.json` + `test-run-history.json` to a **known path inside the repo clone** (e.g., `./.test-dashboard/` — gitignored). A small script (`scripts/test-dashboard/build.sh`) aggregates across both local clones into `strawberry-agents/test-dashboard-data/` (also gitignored), fans the schema out with a `repo` field, and writes one merged `data.json` the dashboard reads. No GCS bucket. No Firestore. No CI artifact plumbing.

Rationale:

- v1 is local-first. Duong runs tests locally; dashboard reads from local disk. This collapses the entire "how do results get from CI back to the dashboard" problem to "don't lose the file the test runner just wrote."
- Matches usage-dashboard precedent (`~/.claude/strawberry-usage-cache/` — gitignored, local-only, regenerable).
- Two repos on one machine = two paths + one aggregator script. That is the minimum viable plumbing.
- Zero secrets, zero cloud surface, zero billable.

Rejected:

- **Commit results to a results repo** — noisy git history, no value over local cache, and risks leaking private error text to public git if the repo is public-default. Reject.
- **GitHub Actions artifacts** — CI-artifact path is a v2 concern, not designed into v1 now. v1 captures the *local* test signal Duong already produces. — Evelynn
- **GCS / Firestore** — same argument as D1: no need for a cloud store when the data is already on disk.

v2 path: swap the local aggregator for a GitHub Actions step that uploads `test-results.json` as an artifact; add a fetch step in `build.sh` that pulls the most recent artifact per workflow via `gh run download`. Schema stays identical; only the read path changes.

### D3. Schema reuse — adopt demo-studio-v3 schema verbatim, add exactly two fields: `repo` and `runner`

**Decision:** keep both JSON schemas (`test-results.json` for current-run snapshot, `test-run-history.json` for rolling history) exactly as demo-studio-v3 defines them, with two additive fields at the top level of each run entry:

- `repo`: `"strawberry-app"` | `"strawberry-agents"` — disambiguates when both repos' runs are aggregated into one view.
- `runner`: `"vitest"` | `"pytest"` | `"bash"` — lets the dashboard render runner-specific UI hints (e.g., `node_modules`-path stripping for Vitest, `::` parametrization parsing for pytest node IDs).

Additive-only. No renamed keys, no type changes. This preserves drop-in compatibility with the pytest plugin as-is; that plugin gains a two-line patch to emit the new keys, nothing else.

Rationale:

- The schema was designed under a 637-test Python suite load and covers everything the dashboard needs (totals by outcome, per-test detail with error text, new-test detection, history ring). Re-inventing gains nothing.
- Additive fields are forward-compatible; old consumers ignore them.
- A single schema across runners = one UI, not two.

Rejected:

- **Redesign for multi-repo** — unnecessary churn; `repo` as an additive top-level field is sufficient.
- **Keep pytest and Vitest on different schemas** — doubles the dashboard's parse code for no gain.

### D4. Vitest adapter — custom **Vitest reporter** (implements Vitest's `Reporter` interface), not post-process of `--reporter=json` and not JUnit XML

**Decision:** implement a Vitest reporter class that plugs into `defineConfig({ test: { reporters: [...] } })`. It listens to `onFinished` / `onTestFinished` and emits `test-results.json` + `test-run-history.json` in the same schema as the pytest plugin, into `./.test-dashboard/`.

**Vitest version lock:** pin to the current major present in `strawberry-app/package.json` at implementation time (reader: Kayn). No planned migration in next 6 months. — Evelynn

**TDD gate:** the tests-dashboard reporter package IS TDD-enabled. xfail-first per Rule 12. — Evelynn

Tradeoff analysis:

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Custom Vitest reporter** | First-class access to `TaskResultPack`, test IDs, durations, error diffs, assertion expected/actual, and test-suite tree. Runs in-process so no extra filesystem walk. Integrates cleanly with existing `vitest.config.ts`. | Must track Vitest's reporter API (stable in 1.x+, but requires version pinning). | **Chosen.** |
| **Post-process `--reporter=json`** | No Vitest API dependency. Parse a single JSON blob produced by stock Vitest. | The stock JSON reporter omits some fields we want (no structured assertion diff, coarser error format). Produces a separate file we must synthesize both outputs from (we lose the history ring unless we re-read the prior file ourselves — which we'd have to do in-reporter anyway). Double work. | Reject. |
| **Post-process JUnit XML** | Universally supported. | Lossy: loses test categories, loses structured error/traceback, does not distinguish `xfail` from `fail`. XML parsing in Node is a step backward. | Reject. |

Implementation shape (Kayn-facing, not an implementation task here):

- Package: `@strawberry/vitest-reporter-tests-dashboard` (private, local workspace in strawberry-app under `packages/vitest-reporter-tests-dashboard/`).
- Entry: a class implementing Vitest's `Reporter` interface. Writes atomically (temp file + rename) so partial writes never corrupt the JSON the dashboard is reading.
- Versioning: pinned to the Vitest major used by strawberry-app's vitest.config.ts; bumped via Renovate/Dependabot like any other internal dep.
- Test strategy: fixture-based. Feed the reporter a synthetic `onFinished` payload, snapshot the emitted JSON against a golden file.

**Parity contract:** the Vitest reporter's output for a given test outcome (pass/fail/xfail/xpassed/skip) MUST match, field-for-field, what the pytest plugin produces for the equivalent outcome. A shared JSON Schema file (`tests-dashboard-data-schema.json`) lives in the dashboard repo and both writers validate against it in their own test suites.

### D5. Auth — none, confirmed

**Decision:** zero auth. v1 is `file://` local-only; v2 (if ever) rides on the existing Firebase Auth + UID allow-list pattern already approved for the strawberry-app test dashboard. No new auth machinery, ever.

This is consistent with the "Strawberry is personal/local" scope and with demo-studio-v3's auth scaffolding being explicitly called out as NOT reusable.

### D6. Relationship to the Claude Code usage dashboard — **siblings under a shared `/dashboards/` shell, kept structurally separate, shared design tokens**

**Decision:** two dashboards, one shell.

- Usage dashboard = cost/attribution domain ("which agent burned Max quota").
- Tests dashboard = quality domain ("which tests are red, newly failing, flaky").

Different data sources, different writers, different refresh cadences, different risks. Forcing them into one data model (or one data.json) creates coupling with zero payoff.

But they share:

- **Hosting root:** `dashboards/` under strawberry-app (once the usage-dashboard lands in that location per its approved plan). Tests dashboard lives at `dashboards/tests-dashboard/`.
- **Design tokens:** single `dashboards/_shared/tokens.css` — GitHub-dark palette, Inter/JetBrains Mono, color scale for pass/fail/xfail/skip. Any UI-consistent primitives (status pill, sparkline) live under `dashboards/_shared/`. Create `dashboards/_shared/tokens.css` up front and amend the approved usage-dashboard plan to depend on it. Dedupe-now is cheaper than dedupe-later. — Evelynn
- **Entry index:** `dashboards/index.html` that lists both dashboards for one-click open. Cheap.

v1 explicitly **does not merge** the two. If a future dashboard needs both test + cost (e.g., "which agent writes the most red tests"), a v3 combined view can read both `data.json` files side by side — no schema change needed.

### D7. Relationship to the deployment-pipeline plan — this dashboard is a **downstream consumer**, not a supersede

**Decision:** this ADR sits *downstream* of the deployment-pipeline plan (`plans/in-progress/2026-04-17-deployment-pipeline.md`) and does NOT supersede any of its phases.

Deployment-pipeline Phase 2 stands up five test-signal producers (per CLAUDE.md rules it enforces):

- **Rule 12** — TDD-gate xfail-first commits, enforced by CI workflow `tdd-gate.yml`. Produces xfail test-run data.
- **Rule 13** — regression tests on bug/bugfix commits. Produces pass/fail signal tied to a commit.
- **Rule 14** — pre-commit unit tests. Produces local pass/fail signal per package.
- **Rule 15** — PR-triggered Playwright E2E via `e2e.yml`. Produces per-PR browser-test signal.
- **Rule 17** — post-deploy smoke tests on stg + prod. Produces deploy-time signal.

All five emit test-run data. The dashboard is the **aggregator and viewer** of that data; it adds a sixth role to the pipeline (observability) without replacing any of the five producers. Concretely:

- The deployment-pipeline plan stays in-progress and completes its Phase 2 work unchanged.
- This dashboard's writers (pytest plugin patch + Vitest reporter) are installed **into** the pipeline's existing test commands (`scripts/test-functions.sh`, `scripts/test-storage-rules.sh`, etc. per §4 of the pipeline ADR). Writers piggyback on existing invocations; no new test run is introduced.
- Phase 2's CI workflows can be extended in a follow-up to upload `test-results.json` as an artifact (the v2 data-flow upgrade described in D2) — but that is a separate follow-up, not part of this ADR.

**Confirmed repo scope:** `harukainguyen1411/strawberry-app` + `harukainguyen1411/strawberry-agents` only. Archive repo `Duongntd/strawberry` and work repos (`~/Documents/Work/mmp/**`) are out of scope. — Duong + Evelynn

**Nothing in the deployment-pipeline plan is retracted or replaced.** This dashboard is a sibling line of work that reads pipeline output.

### D8. Runner coverage — Vitest and pytest are first-class; bash test harnesses are a later concern

**Decision:** v1 covers Vitest (strawberry-app + any TS packages in strawberry-agents) and pytest (should any enter either repo). Bash-based test harnesses (e.g., shellcheck-style scripts under `scripts/test-*.sh`) are **explicitly out of v1 scope** and tracked as a v2 concern.

Rationale: bash test output formats are ad hoc; building a generic bash adapter means defining a convention (e.g., TAP) and retrofitting every test script. Large surface area, low urgency relative to the Vitest adapter gap. Flag and defer.

v2 path: adopt TAP output from bash tests (`tap-harness` or similar), add a TAP->schema adapter. Same downstream schema, same dashboard, no refactor.

### D9. Refresh cadence — v1 polling on page load + manual refresh; v2 SSE (confirmed)

**Decision (v1):** dashboard reads `data.json` on page load and on user-initiated refresh (button). No SSE, no WebSocket, no filesystem watcher in v1.

**Decision (v2):** SSE for live-refresh when hosting moves to Firebase Hosting. — Duong (flips the original default which leaned poll-on-focus + manual refresh)

Rationale: v1 is file://. File reads are synchronous and cheap. Dashboard reload costs a second. Duong's usage pattern is "run tests, then go look" — polling is sufficient for v1. SSE is the confirmed v2 path.

### D10. History retention — keep full history on disk, trim display to last 50 runs per repo (matches demo-studio-v3 default)

**Decision:** `test-run-history.json` stores the full history the writers emit; aggregator script enforces a 50-run cap per repo (matching demo-studio-v3's `_MAX_RUN_HISTORY_ENTRIES = 50`). Older runs spill into a compressed archive file (`test-run-history-archive.jsonl.gz`) that the dashboard does not load by default. Zero data loss; bounded memory footprint.

Rationale: 50 runs is the proven default from the reference system. Archive-on-rotate avoids forcing a retention decision up front.

---

## Architecture (v1)

```
strawberry-app/                                 strawberry-agents/
  .test-dashboard/                                .test-dashboard/
    test-results.json       <-- Vitest reporter     test-results.json      <-- (future pytest/bash writers)
    test-run-history.json       writes here         test-run-history.json
                                                    test-dashboard-data/
                                                      data.json           <-- aggregator merges both
                                                      dashboards/tests-dashboard/
                                                        index.html
                                                        app.js
                                                        tokens.css        (symlink or copy of _shared/tokens.css)
```

**Aggregator (`scripts/test-dashboard/build.sh`):**

1. Discover both repo clones' `.test-dashboard/` directories (paths in a config file, no scanning).
2. For each, read `test-results.json` + `test-run-history.json`.
3. Stamp each entry with its `repo` field if the writer didn't already.
4. Merge into a single `data.json` with two top-level sections: `current` (snapshot of both repos' latest run) and `history` (time-ordered merge, capped at 50 per repo).
5. Write `data.json` atomically.

**Dashboard (`dashboards/tests-dashboard/`):**

- `index.html` — three-panel layout:
  1. **Runs list** (top): one row per test run, newest first, columns: repo, timestamp, trigger, total, passed/failed/xfailed/skipped chips, duration. Click a row to drill into Per-test detail.
  2. **Failure trends** (middle-left): 14-run sparkline per repo, stacked pass/fail bars. Click a bar -> filter Runs list to that run.
  3. **Per-test detail / history** (middle-right + bottom): search box for node ID; selecting a test shows its status in the most recent run of each repo, its history line (last 20 runs, color-coded), and the most recent error message/traceback if it has one.
- `app.js` — `fetch('./data.json')`, render three panels, handle click interactions. No framework; plain DOM. Chart.js via CDN for sparklines (zero build).
- Styling via `tokens.css` from the shared `dashboards/_shared/` root.

---

## Risks and mitigations

- **Schema drift between pytest plugin and Vitest reporter.** Two writers, one schema. Golden-file tests in both writer packages plus a shared JSON Schema validation step catch drift immediately. Dashboard fails loud on schema-invalid `data.json`.
- **Partial writes during concurrent runs.** Two test invocations finishing at the same time could corrupt `test-results.json`. Both writers use atomic temp-file + rename. Aggregator is the sole reader; writers never read their own output.
- **Gitignore discipline.** `.test-dashboard/` and `test-dashboard-data/` both must be in `.gitignore` in both repos. A single mistaken `git add -A` could leak error tracebacks with file paths to a public repo. Mitigation: add path checks to the existing pre-commit hook (`scripts/install-hooks.sh`) — any staged file matching `**/.test-dashboard/**` is blocked, explicit error message.
- **Vitest version pinning.** Reporter API stability across Vitest 1.x -> 2.x is not guaranteed. Pin Vitest major in strawberry-app's workspace; reporter package declares Vitest as a peerDep with the pinned range. Renovate PR upgrades are gated by the reporter's own test suite.
- **Data size.** 50 runs x ~637 tests x ~100 bytes/test ~= 3 MB worst case. Fine for a local fetch. If it grows, move history into a sibling `history.json` and lazy-load on user action.
- **Duplicate dashboards confusion.** There are now three test-related dashboards in play: (a) the approved strawberry-app test-dashboard at `/test-dashboard` (Cloud Run, session monitoring), (b) this cross-repo tests-dashboard, (c) the approved usage dashboard. Mitigation: clear naming and the `dashboards/index.html` landing page described in D6. This dashboard uses `dashboards/tests-dashboard/` to avoid collision with the existing `/test-dashboard` surface.

---

## Features — v1 vs. later

| Feature | v1 | v2 | v3 |
|---------|----|----|----|
| Runs list (both repos, merged) | yes | — | — |
| Per-test detail + most recent error | yes | — | — |
| 14-run failure sparkline per repo | yes | — | — |
| Per-test history (last 20 runs) | yes | — | — |
| Vitest reporter (schema-compliant) | yes (net-new) | — | — |
| pytest plugin drop-in (schema patched for `repo`/`runner`) | yes (if any pytest enters either repo) | — | — |
| Bash/TAP adapter | — | yes | — |
| CI-artifact data flow (vs. local-disk) | — | yes | — |
| Firebase Hosting + Firebase Auth private surface | — | yes (if phone access asked for) | — |
| SSE live-refresh | — | yes (confirmed, v2) | — |
| Flake detection (pass/fail/pass within N runs -> flag) | — | yes | — |
| Duration regression alerts | — | — | yes |
| Agent attribution (which agent committed the code that made a test red) | — | — | yes (cross-joins with usage-dashboard data) |

---

## Open questions for Duong

*(Preserved for history. Resolutions in the Decisions table below.)*

1. **Dashboard name / URL slug.** I propose `dashboards/test-results/` to avoid collision with the existing approved `strawberry-app/test-dashboard/` (Cloud Run, session monitoring). OK to land under that new name? If not, propose an alternative.
2. **Hosting ambition.** v1 = `file://` local only. Do you want phone access on day 1? If yes, that flips v1 to Firebase Hosting (free tier) on a private surface behind the existing Firebase Auth UID allow-list, which adds a small amount of config (same pattern as the approved test-dashboard ADR, no new auth code). Default answer = no, stay local.
3. **Aggregator home.** The aggregator script and `dashboards/tests-dashboard/` static files — which repo hosts them? Options: (a) `strawberry-app/dashboards/tests-dashboard/` (consistent with usage-dashboard precedent per the approved claude-usage-dashboard plan), or (b) `strawberry-agents/dashboards/tests-dashboard/` (this repo, since the aggregator reads multiple clones and strawberry-agents is the "brain" that coordinates). Default = (a) to match precedent. Counter-argument for (b): strawberry-app is public, and a committed aggregator config that hardcodes local clone paths is awkward in public code. Leaning (b) for the aggregator + private config, (a) for the static HTML — but flagging for your call.
4. **Vitest version lock.** strawberry-app currently on Vitest — what major? I need this to pin the reporter peerDep range. Kayn/Aphelios can read this from `package.json` at implementation time, but confirm the major is stable for the next 6 months (no planned migration) so the reporter doesn't get orphaned.
5. **CI-artifact timeline.** D2 v1 reads local disk only. When (if ever) do you expect the deployment-pipeline Phase 2 CI workflows (`test.yml`, `e2e.yml`, `tdd-gate.yml`) to be the *primary* source of test signal for this dashboard? If that's within 30 days, we should design the v2 CI-artifact path into v1 now. If it's further out, keep v1 local-only as scoped.
6. **Archive of the existing `plans/approved/2026-04-17-test-dashboard-architecture.md`.** That plan is for a different surface (session monitoring, Cloud Run). Should we rename it in-place to clarify the distinction once this plan lands (e.g., to `2026-04-17-session-dashboard-architecture.md`), or leave it alone? Non-blocking either way; flagging so we don't have two docs with overlapping names.
7. **TDD gate for this work.** The deployment-pipeline plan's Rule 12 requires xfail-first on TDD-enabled services. The Vitest reporter is a new package with a real test surface (schema parity, atomic writes, etc.). Confirm it counts as TDD-enabled so the implementer starts with xfail tests referencing this plan.
8. **Scope of "both repos."** Confirmed = `harukainguyen1411/strawberry-app` + `harukainguyen1411/strawberry-agents` only. The archive repo `Duongntd/strawberry` is out of scope (90-day retention, no new tests written). Work repos (`~/Documents/Work/mmp/**`) are out of scope (separate system, separate CLAUDE.md). Confirm.
9. **SSE-vs-polling in v2.** If v2 moves to Firebase Hosting, is SSE worth the complexity, or is a poll-on-focus + manual-refresh button enough? My instinct: poll is enough; SSE adds a server component that breaks the "static SPA" simplicity. Flagging for alignment.
10. **Shared `dashboards/_shared/` rollout.** Creating `dashboards/_shared/tokens.css` requires a small follow-up edit to the approved usage-dashboard plan so both dashboards depend on the shared tokens rather than each shipping their own. OK to do that as a tiny amendment commit to the usage-dashboard plan before this plan enters execution, or keep tokens duplicated for v1 and de-duplicate later?

---

## Decisions

| # | Question topic | Decision |
|---|---|---|
| 1 | Slug | `dashboards/tests-dashboard/` — Duong |
| 2 | Hosting ambition | v1 = local `file://` only. No phone access v1. — Duong |
| 3 | Aggregator home | Option (a): `strawberry-app/dashboards/tests-dashboard/`. Matches usage-dashboard precedent. — Duong |
| 4 | Vitest version lock | Pin to the current major present in `strawberry-app/package.json` at implementation time (reader: Kayn). No planned migration in next 6 months. — Evelynn |
| 5 | CI-artifact timeline | Keep v1 local-disk-only. CI-artifact path is a v2 concern, not designed into v1 now. — Evelynn |
| 6 | Existing ADR rename | Yes — rename `plans/approved/2026-04-17-test-dashboard-architecture.md` → `plans/approved/2026-04-17-session-dashboard-architecture.md` in a follow-up commit (tracked as task below). Update its own frontmatter slug + any cross-refs. — Evelynn. TODO: follow-up commit to handle rename (proposed file: `plans/proposed/2026-04-19-session-dashboard-adr-rename.md`) |
| 7 | TDD gate | Tests-dashboard reporter package IS TDD-enabled. xfail-first per Rule 12. — Evelynn |
| 8 | Repo scope | Confirmed: `harukainguyen1411/strawberry-app` + `harukainguyen1411/strawberry-agents` only. Archive and work repos out of scope. — Evelynn |
| 9 | v2 SSE-vs-polling | SSE. (Flips Azir's default, which leaned poll.) — Duong |
| 10 | Shared tokens | Yes — create `dashboards/_shared/tokens.css` up front and amend the approved usage-dashboard plan to depend on it. Dedupe-now is cheaper than dedupe-later. — Evelynn |

---

## Handoff notes (for Kayn once approved)

- Reference implementation to read (DO NOT port): `~/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3/conftest_results_plugin.py`. Copy the schema semantics, not the file.
- Reference implementation to read (port directly with `repo`/`runner` field additions): same path's `test-results.json` and `test-run-history.json` schemas.
- Task-1 candidate: the Vitest reporter package + its golden-file tests. Self-contained, testable without the rest of the stack.
- Task-2 candidate: `scripts/test-dashboard/build.sh` + shared JSON schema file + schema-validation tests for both writers.
- Task-3 candidate: `dashboards/tests-dashboard/{index.html,app.js}` + `dashboards/_shared/tokens.css` + a Playwright smoke test that asserts a golden `data.json` renders the expected DOM.
- Enforcement: per Rule 12, each task opens with an xfail test committed first, referencing this plan's slug (`tests-dashboard`).
- No implementer named in this ADR. Task breakdown is Kayn's.

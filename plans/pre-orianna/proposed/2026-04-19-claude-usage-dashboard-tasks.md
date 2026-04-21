---
status: proposed
owner: kayn
parent: plans/approved/2026-04-19-claude-usage-dashboard.md
---

# Task Breakdown — Claude Usage Dashboard (v1)

Breakdown of `2026-04-19-claude-usage-dashboard.md` into executable, atomic, TDD-first tasks for Sonnet executors (Jayce/Viktor/Seraphine).

## Duong's overrides (supersede the ADR's Open Questions)

1. **Hosting**: local `file://` only. No Firebase, no Firestore. Zero paid lines.
2. **Repo**: public `harukainguyen1411/strawberry-app`. Code under `dashboards/usage-dashboard/`, scripts under `scripts/usage-dashboard/`. <!-- orianna: ok -->
3. **Scope**: attribute both strawberry-repo sessions AND `~/Documents/Work/mmp/workspace/agents/` work sessions, bucketed separately in per-project view.
4. **Subagent cost**: skipped for v1. Roster agents run top-level; regex attribution covers v1. No `isSidechain` handling.
5. **Refresh**: **on-demand only**. Drop cron entirely from v1. The UI has a "Refresh" button that triggers `build.sh` via a tiny local helper (see §Refresh Mechanism below). Plus a `sbu` CLI alias that re-runs `build.sh` then opens the page.
6. **Max-value math**: ccusage default (on-demand API pricing for same model mix). Static footer only.
7. **Retention**: unbounded `data.json`. UI has a date-range selector: 7 / 30 / 90 / 180 / 360 days, default 30.

### Refresh Mechanism (cleanest option)

Two layered affordances, no server needed:

- **Primary (CLI)**: `sbu` shell alias runs `strawberry-app/scripts/usage-dashboard/build.sh` then `open dashboards/usage-dashboard/index.html`. This is the default path and is documented in the README. <!-- orianna: ok -->
- **Secondary (in-page button)**: a tiny Node helper `scripts/usage-dashboard/refresh-server.mjs` — a single-file HTTP server binding `127.0.0.1:4765`, exposing `POST /refresh` that shells out to `build.sh` and returns `{ ok, updatedAt }`. The page polls `GET /health` on load; if the helper is up, it enables the Refresh button, otherwise hides it and shows the `sbu` hint. The helper is started by `sbu --serve` (optional). No auth (localhost-only bind); no dependencies beyond node stdlib. <!-- orianna: ok -->

This keeps the page working from pure `file://` (CLI refresh) while offering a one-click path when the user wants it.

## Cross-repo operating rules for executors

- All implementation tasks operate in `~/Documents/Personal/strawberry-app/` (public repo).
- Commits on that repo follow conventional prefixes; since all new files live under `dashboards/**` and `scripts/**` (outside `apps/**`), `chore:` is the correct prefix for every commit in this feature (see CLAUDE.md rule 5).
- Each task creates a branch via `scripts/safe-checkout.sh` (worktree; never raw `git checkout`).
- Each task MUST land an xfail test commit before the implementation commit on the same branch (CLAUDE.md rule 12). xfail tests reference this plan path.
- No `git rebase`; merge only (rule 11).
- Do not merge own PR (rule 18); handoff to a reviewer (Vi) after E2E green.

## Task Summary

**10 tasks total**, grouped into 4 phases. See dependency graph at end.

| # | Task | Executor | Type | Depends on |
|---|------|----------|------|------------|
| T1 | Scaffold + roster.json generator | Jayce | new | — |
| T2 | `agent-scan.mjs` | Jayce | new | T1 |
| T3 | `merge.mjs` | Jayce | new | T1, T2 |
| T4 | `build.sh` pipeline | Jayce | new | T3 |
| T5 | `refresh-server.mjs` (local helper) | Jayce | new | T4 |
| T6 | `sbu` CLI alias + install docs | Jayce | new | T4 |
| T7 | `index.html` static shell + styling | Seraphine | new | T1 |
| T8 | `app.js` render + date-range selector | Seraphine | new | T3, T7 |
| T9 | Refresh button wiring (UI ↔ helper) | Seraphine | new | T5, T8 |
| T10 | Playwright smoke + fixtures | Vi | tests | T8 |

**Parallel-eligible pairs**:
- T1 unblocks both backend (T2) and frontend (T7). After T1 lands, T2 and T7 run in parallel.
- T5 and T6 are independent once T4 lands — run in parallel.
- T10 runs in parallel with T9 once T8 is merged (Vi uses fixture `data.json`).

**Strict sequential**: T1 -> T2 -> T3 -> T4 (backend pipeline has linear data-flow dependency).

---

## T1 — Scaffold dashboard + scripts directories; roster.json generator

**Executor**: Jayce
**Repo**: `strawberry-app`
**Branch**: `feat/usage-dashboard-scaffold`

**What**: Create directory skeletons and the authoritative roster generator.

**Where**:
- Create `dashboards/usage-dashboard/` with a stub `index.html`, `data.json` (empty `{"sessions":[],"agents":[],"generatedAt":null}`), and `roster.json` (generated). <!-- orianna: ok -->
- Create `scripts/usage-dashboard/` with a placeholder `README.md`. <!-- orianna: ok -->
- Create `scripts/usage-dashboard/generate-roster.mjs` that reads `agents/memory/agent-network.md` from the **strawberry (agents infra) repo** via a configurable path env var `STRAWBERRY_AGENTS_REPO` (default `~/Documents/Personal/strawberry`), parses agent names from the table/list, emits `dashboards/usage-dashboard/roster.json` with shape `{"agents": [{"name": "Jayce", "role": "..."}, ...], "generatedAt": "ISO"}`. <!-- orianna: ok -->
- Add `dashboards/usage-dashboard/package.json` with one dep: none for runtime, `ccusage` pinned to current version as a dev-dep for reproducibility, and a `"scripts": { "build": "bash ../../scripts/usage-dashboard/build.sh", "roster": "node ../../scripts/usage-dashboard/generate-roster.mjs" }`. <!-- orianna: ok -->
- Add `.gitignore` entry for `~/.claude/strawberry-usage-cache/` is not needed (lives outside repo), but do gitignore `dashboards/usage-dashboard/data.json` contents after initial commit — commit the empty shape, let real data regenerate locally. <!-- orianna: ok -->

**Why**: Unblocks parallel backend (T2+) and frontend (T7+) work. Roster is the authority for which sessions fall into `unknown`.

**TDD (xfail first commit)**:
- `scripts/__tests__/generate-roster.test.mjs` (node --test, already used in repo per existing `__tests__` dir). Test cases (all initially xfail): <!-- orianna: ok -->
  1. Given a fixture `agent-network.md` with 3 agents, output contains exactly those 3 names.
  2. Missing input file -> exits non-zero with readable error.
  3. `generatedAt` is a parseable ISO string.

**Acceptance**:
- `node scripts/usage-dashboard/generate-roster.mjs` produces a valid `roster.json` with at least 10 agent names (current roster size).
- Tests pass.
- Empty `data.json` renders as valid JSON (`node -e "JSON.parse(require('fs').readFileSync('.../data.json'))"`).
- `npm --prefix dashboards/usage-dashboard run roster` works.

**Parallelism**: Blocks T2 and T7 but nothing else.

---

## T2 — `agent-scan.mjs`

**Executor**: Jayce
**Branch**: `feat/usage-dashboard-agent-scan`

**What**: Scan all JSONL transcripts and emit `{sessionId -> agentName}` map.

**Where**: `scripts/usage-dashboard/agent-scan.mjs`. <!-- orianna: ok -->

**Behavior**:
- Scans `~/.claude/projects/**/*.jsonl`.
- For each file: read lines sequentially, stop at the first record with `type === "user"`, extract `message.content[0].text`.
- Match patterns in order (first win):
  1. `^Hey (\w+)` -> $1
  2. `^\[autonomous\] (\w+),` -> $1
  3. `^You are (\w+)[,.]` -> $1
  4. `^# (\w+) .* prompt \(pinned` -> $1
  5. fallback -> `"Evelynn"` (no-greeting default)
- Validate the matched name against `roster.json`; if not in roster, tag as `unknown` AND include `rawMatch` in the debug log so the regex can be tuned later.
- Attribute `project`:
  - if `cwd` starts with `~/Documents/Personal/strawberry` -> `"strawberry"`
  - if `~/Documents/Personal/strawberry-app` -> `"strawberry-app"`
  - if `~/Documents/Work/mmp/workspace/agents` or `~/Documents/Work/mmp` -> `"work/mmp"`
  - else -> basename of cwd
- Output path: `~/.claude/strawberry-usage-cache/agents.json`.
- Shape: `{ sessions: [{ sessionId, agent, project, cwd, firstSeen, rawMatch? }], unknowns: [...], generatedAt }`.

**TDD (xfail first)**:
- `scripts/__tests__/agent-scan.test.mjs`: <!-- orianna: ok -->
  1. Fixture JSONL with `Hey Syndra` as first user msg -> agent == "Syndra".
  2. Fixture with `[autonomous] Orianna, proceed` -> agent == "Orianna".
  3. Fixture with no greeting -> agent == "Evelynn".
  4. Fixture whose matched name is not in roster -> agent == "unknown", rawMatch preserved.
  5. Fixture with cwd in work/mmp -> project == "work/mmp".
  6. Perf guard: 100 fixture JSONLs scan in <1000ms.
- Fixtures live under `scripts/__tests__/fixtures/jsonl/`. <!-- orianna: ok -->

**Acceptance**:
- Running against a user's real `~/.claude/projects/` produces JSON with >=50 sessions attributed and <10% `unknown` on Duong's machine.
- No schema drift between roster.json and agents.json (agent names all appear in roster or are tagged `unknown`).

**Parallelism**: Sequential after T1 (needs roster.json). Blocks T3.

---

## T3 — `merge.mjs`

**Executor**: Jayce
**Branch**: `feat/usage-dashboard-merge`

**What**: Join `ccusage session -j` output with `agents.json` and write `data.json`.

**Where**: `scripts/usage-dashboard/merge.mjs`. <!-- orianna: ok -->

**Inputs**: paths passed as CLI args:
- `--sessions <path>`  (ccusage session JSON)
- `--blocks <path>`    (ccusage blocks JSON for 5h window)
- `--daily <path>`     (ccusage daily JSON for sparkline)
- `--agents <path>`    (agents.json from T2)
- `--out <path>`       (data.json destination)

**Behavior**:
- Validate that each ccusage JSON has the expected top-level keys. On unknown schema, **fail loudly** with a diff-style error naming the missing key. (Mitigation for ADR risk: ccusage schema drift.)
- Emit `data.json` with shape:
  ```
  {
    "schemaVersion": 1,
    "generatedAt": "ISO",
    "window": { /* 5h block */ },
    "sessions": [ { sessionId, agent, project, cwd, tokensIn, tokensOut, cacheRead, cacheCreate, cost, model, startedAt } ],
    "daily": [ { date, tokens, cost, byAgent: { Jayce: n, ... } } ],
    "roster": [ "Jayce", ... ],
    "unknownCount": n
  }
  ```
- Sessions with no agent match get `agent: "unknown"`.
- Total size target: <200 KB for ~6 months of history.

**TDD (xfail first)**:
- `scripts/__tests__/merge.test.mjs`: <!-- orianna: ok -->
  1. Golden fixtures (tiny ccusage JSON + tiny agents.json) -> golden data.json diff.
  2. Missing `totals` key in ccusage session JSON -> throws with key name in message.
  3. Session in ccusage but not in agents.json -> agent == "unknown", counted in `unknownCount`.
  4. Sparkline `daily[].byAgent` sums equal `daily[].tokens`.
  5. Output passes `JSON.parse` and matches v1 schema.

**Acceptance**:
- End-to-end: run on real data, `data.json` <200 KB, no validation failures.
- UI-side contract locked: T8 can consume this schema without ambiguity.

**Parallelism**: Sequential after T2. Blocks T4 and T8.

---

## T4 — `build.sh` pipeline

**Executor**: Jayce
**Branch**: `feat/usage-dashboard-build-sh`

**What**: The orchestrator. Invokes ccusage three times, runs `agent-scan.mjs`, runs `merge.mjs`, writes final `data.json`.

**Where**: `scripts/usage-dashboard/build.sh`. <!-- orianna: ok -->

**POSIX-portable** (CLAUDE.md rule 10). No bashisms; runs on macOS and Git Bash on Windows.

**Behavior**:
- `set -euo pipefail` (or POSIX equivalent).
- Require `ccusage` on PATH (`command -v ccusage` else print install hint).
- Create `~/.claude/strawberry-usage-cache/` if missing.
- Run `ccusage session -j -i -p > cache/sessions.json`, `ccusage blocks -j > cache/blocks.json`, `ccusage daily -j > cache/daily.json`.
- Run `node agent-scan.mjs` -> `cache/agents.json`.
- Run `node merge.mjs --sessions ... --out dashboards/usage-dashboard/data.json`.
- Print a one-line summary: `built data.json (X sessions, Y agents, Z unknown)`.
- Exit non-zero on any step failure, cleaning up partial outputs.

**TDD (xfail first)**:
- `scripts/__tests__/build-sh.test.mjs` (spawn subprocess; or bats-style if easier): <!-- orianna: ok -->
  1. Mock ccusage shim that emits fixture JSON -> build.sh runs end-to-end, produces valid data.json.
  2. Mock ccusage that returns non-zero -> build.sh exits non-zero, data.json not clobbered.
  3. Missing ccusage binary -> prints install hint, exits non-zero.

**Acceptance**:
- `bash scripts/usage-dashboard/build.sh` on Duong's machine regenerates data.json in <5s. <!-- orianna: ok -->
- Idempotent (safe to re-run).

**Parallelism**: Sequential after T3. Blocks T5 and T6.

---

## T5 — `refresh-server.mjs` local helper

**Executor**: Jayce
**Branch**: `feat/usage-dashboard-refresh-server`

**What**: Tiny single-file Node HTTP server enabling the in-page Refresh button.

**Where**: `scripts/usage-dashboard/refresh-server.mjs`. <!-- orianna: ok -->

**Behavior**:
- Binds `127.0.0.1:4765` only (never `0.0.0.0`).
- Node stdlib only (`http`, `child_process`). Zero npm deps.
- Routes:
  - `GET /health` -> `{ ok: true, version: "1" }`
  - `POST /refresh` -> spawns `bash build.sh`, streams nothing (fire-and-forget with a settled Promise), returns `{ ok, updatedAt, durationMs }` or `{ ok: false, error }`.
- CORS: allow `Origin: null` (file://) and `http://localhost:*` only.
- Prints a one-liner on start: `usage-dashboard refresh helper listening on http://127.0.0.1:4765`.
- Logs each refresh request to stdout.

**TDD (xfail first)**:
- `scripts/__tests__/refresh-server.test.mjs`: <!-- orianna: ok -->
  1. Starts server on ephemeral port; `GET /health` returns 200 with `{ok:true}`.
  2. `POST /refresh` with a stubbed build.sh that succeeds -> 200 with `ok:true`.
  3. Stubbed failing build.sh -> 500 with `ok:false, error`.
  4. Non-local Origin -> 403.

**Acceptance**:
- `node scripts/usage-dashboard/refresh-server.mjs &` starts cleanly, health OK. <!-- orianna: ok -->
- Refresh regenerates `data.json` correctly.

**Parallelism**: Parallel with T6 after T4.

---

## T6 — `sbu` CLI alias + install doc

**Executor**: Jayce
**Branch**: `feat/usage-dashboard-sbu`

**What**: One-command entry point.

**Where**:
- `scripts/usage-dashboard/sbu.sh` — executable. Flags: `--serve` (start refresh-server in background), `--no-open` (skip `open`). <!-- orianna: ok -->
- `scripts/usage-dashboard/README.md` — install instructions (adding `alias sbu=~/Documents/Personal/strawberry-app/scripts/usage-dashboard/sbu.sh` to `~/.zshrc`). <!-- orianna: ok -->

**Behavior**:
- Default: `bash build.sh && open dashboards/usage-dashboard/index.html`. <!-- orianna: ok -->
- With `--serve`: also `nohup node refresh-server.mjs &` (PID recorded at `~/.claude/strawberry-usage-cache/refresh-server.pid`; refuse to start a second instance).
- POSIX-portable.

**TDD (xfail first)**:
- `scripts/__tests__/sbu.test.mjs`: <!-- orianna: ok -->
  1. With `build.sh` stubbed to `true` and `open` shimmed, `sbu` exits 0 and records no PID file.
  2. `sbu --serve` spawns refresh-server and writes PID file.
  3. Second `sbu --serve` while PID file alive refuses.

**Acceptance**:
- `sbu` on Duong's machine opens Chrome to the dashboard with fresh data.

**Parallelism**: Parallel with T5 after T4.

---

## T7 — `index.html` static shell + styling

**Executor**: Seraphine
**Branch**: `feat/usage-dashboard-html-shell`

**What**: The four-panel layout per ADR §View. No logic yet — static markup + CSS.

**Where**: `dashboards/usage-dashboard/index.html`, `dashboards/usage-dashboard/styles.css` (optional if you keep inline). <!-- orianna: ok -->

**Scope**:
- Head: viewport meta, title "Strawberry Usage", link to `styles.css`, Chart.js CDN `<script defer>`.
- Body sections with empty placeholders + ARIA labels:
  1. `#window-strip` (5h billing window)
  2. `#agent-leaderboard` (table shell with THEAD: Agent / Sessions / Tokens / In / Out / Cache / Cost / Avg)
  3. `#project-breakdown` (table shell with THEAD: Project / Sessions / Tokens / Cost)
  4. `#sparkline` (`<canvas id="sparkline-canvas">`)
- Controls bar (top): date-range `<select>` (7/30/90/180/360, default 30), "Hide unknown" checkbox, "Refresh" button (hidden by default; T9 will unhide based on helper presence), last-updated timestamp, static footer with Max-value line (rendered by T8).
- Styling: match `dashboards/test-dashboard/` visual language (look at its Tailwind config / CSS). Plain CSS or CDN Tailwind (prefer CDN Tailwind-Play to avoid build step per ADR "no build step" rule). Target: readable on a 13" laptop, dark-mode honoring `prefers-color-scheme`.

**TDD (xfail first)**:
- `dashboards/usage-dashboard/__tests__/html.test.mjs` (node:test + jsdom or use Playwright's static check): <!-- orianna: ok -->
  1. Required section IDs exist.
  2. Date-range select has exactly 5 options with values 7/30/90/180/360.
  3. Refresh button exists with `hidden` attribute by default.

**Acceptance**:
- Opens via `file://` with no console errors.
- Empty shell renders visually correct (screenshot captured for reference).

**Parallelism**: Parallel with T2-T5 after T1. Blocks T8.

---

## T8 — `app.js` render + date-range selector

**Executor**: Seraphine
**Branch**: `feat/usage-dashboard-app-js`

**What**: Fetch `data.json`, compute filtered views, render each section. Plain JS — no framework (per ADR).

**Where**: `dashboards/usage-dashboard/app.js`. <!-- orianna: ok -->

**Behavior**:
- On load: `fetch('./data.json')`, on failure show an error banner with `sbu` hint.
- Validate `schemaVersion === 1`; otherwise show "Schema mismatch — regenerate with latest build.sh".
- Apply current date-range filter (default 30 days) client-side on `sessions` and `daily`.
- Apply "hide unknown" toggle.
- Render:
  1. **Window strip**: from `data.window` — countdown to end, tokens used, % of 5h budget, per-model breakdown.
  2. **Agent leaderboard**: group `sessions` by `agent`, compute aggregates, sort tokens desc. One row per roster agent appearing in filter window + `unknown` + totals row. Click a row -> expand flat session list.
  3. **Project breakdown**: group by `project` (strawberry / strawberry-app / work/mmp / other). Same columns.
  4. **Sparkline**: top-5 agents by total tokens in range, one line each using Chart.js. Click a dot -> shows flat table of that agent/day's sessions.
- **Max-value footer**: static line "Max x20 plan: $200/mo. On-demand equivalent for this period: $X (ccusage default pricing)." X comes from summing `sessions[].cost` over filter range.
- Date-range `<select>` change re-renders all sections.
- Debounce 50 ms to avoid double-render.

**TDD (xfail first)**:
- `dashboards/usage-dashboard/__tests__/app.test.mjs` (happy-dom or jsdom; fetch mocked): <!-- orianna: ok -->
  1. With fixture data.json (3 sessions, 2 agents), leaderboard has 3 rows (2 agents + totals).
  2. Date range 7 filters out older sessions.
  3. "Hide unknown" toggle removes unknown row and rebalances totals.
  4. Schema version mismatch shows banner.
  5. Empty data.json renders empty states, no crash.

**Acceptance**:
- Opening `file://.../index.html` after running `build.sh` on real data shows all four panels populated.
- Date-range selector re-renders in <300 ms for 1000-session dataset.

**Parallelism**: Sequential after T3 (needs schema) and T7 (needs shell). Blocks T9 and T10.

---

## T9 — Refresh button wiring

**Executor**: Seraphine
**Branch**: `feat/usage-dashboard-refresh-button`

**What**: Connect the in-page Refresh button to `refresh-server.mjs`.

**Where**: extends `dashboards/usage-dashboard/app.js`. <!-- orianna: ok -->

**Behavior**:
- On load, probe `GET http://127.0.0.1:4765/health` with 300 ms timeout.
  - If OK: unhide Refresh button; show small "live-refresh available" indicator.
  - If not OK: keep button hidden; in empty/error state, render "Tip: run `sbu` to regenerate data" hint.
- Click Refresh: disable button, show spinner, `POST /refresh`, on success re-fetch `data.json` and re-render; on failure show error toast.
- Never block initial page render on the health probe.

**TDD (xfail first)**:
- `dashboards/usage-dashboard/__tests__/refresh.test.mjs`: <!-- orianna: ok -->
  1. Mock fetch: `/health` 200 -> button visible.
  2. Mock fetch: `/health` times out -> button hidden, tip visible.
  3. Click Refresh with `/refresh` 200 -> re-fetches data.json exactly once.
  4. Click Refresh with `/refresh` 500 -> toast shown, button re-enabled.

**Acceptance**:
- With `refresh-server.mjs` running, clicking Refresh regenerates and re-renders live.
- With the server not running, the UI stays clean with no broken affordances.

**Parallelism**: Sequential after T5 and T8.

---

## T10 — Playwright smoke + fixtures + QA report

**Executor**: Vi
**Branch**: `feat/usage-dashboard-e2e`

**What**: E2E smoke proving the dashboard loads and renders core sections end-to-end. Also the pre-PR QA report.

**Where**:
- `tests/e2e/usage-dashboard.spec.ts` (Playwright; existing infra in strawberry-app). <!-- orianna: ok -->
- `tests/e2e/fixtures/usage-dashboard-data.json` — a canned data.json with ~10 sessions spanning 60 days, 4 agents, 3 projects. <!-- orianna: ok -->
- `assessments/qa-reports/2026-04-19-usage-dashboard-v1.md` (in strawberry-agents repo, linked from PR body per CLAUDE.md rule 16). <!-- orianna: ok -->

**Scope of the smoke**:
1. Start a local static server pointing at `dashboards/usage-dashboard/` with the fixture copied in as `data.json` (no real ccusage needed). <!-- orianna: ok -->
2. Navigate, assert:
   - Window strip visible with a token count.
   - Leaderboard has >=4 rows (3 agents + totals).
   - Project breakdown has exactly 3 rows.
   - Sparkline canvas renders (>0 px non-empty pixels).
   - Date-range select default is "Last 30 days".
   - Toggling to 7 reduces leaderboard rows as expected.
   - "Hide unknown" toggle hides the unknown row.
3. Screenshot + video captured in `test-results/` per standard Playwright config.

**Pre-PR QA**:
- Since this is a UI PR, Vi produces the QA report (CLAUDE.md rule 16) with Playwright video, screenshots of all four panels at the three breakpoints (1280, 1440, 2560), plus a note comparing against `dashboards/test-dashboard/` visual language (there is no Figma design for v1; state that explicitly in the report).

**TDD (xfail first)**:
- The spec itself lands first with `.fixme()` or `test.fail()` wrappers; gets flipped to `.skip(false)` in the implementation commit.

**Acceptance**:
- `npx playwright test usage-dashboard` green.
- QA report filed; PR body links it.

**Parallelism**: Can run in parallel with T9 once T8 is merged (Vi uses fixture data.json; does not need the real pipeline).

---

## Dependency Graph

```
         T1 (scaffold + roster)
          |
    ______|______
    |           |
    T2 (scan)   T7 (html shell)
    |           |
    T3 (merge)  |
    |           |
    T4 (build.sh)
    |    \
    T5    T6    <-- parallel
    |
    (T3 also feeds) --> T8 (app.js) <-- (T7 feeds)
                         |
                    _____|_____
                    |          |
                    T9         T10 (e2e)   <-- parallel
```

## Parallelism summary

- **Parallel batches**:
  - Batch A (after T1): T2 and T7 run simultaneously.
  - Batch B (after T4): T5 and T6 run simultaneously.
  - Batch C (after T8): T9 and T10 run simultaneously.
- **Strictly sequential**: T1 -> T2 -> T3 -> T4 (data pipeline). T7 -> T8 (UI shell then render). T5 -> T9 (helper then wiring).
- **Minimum wall-clock path**: T1 -> T2 -> T3 -> T4 -> T5 -> T9 (six serial tasks). With full parallelism, a team of 3 Sonnets could ship v1 in ~6 task-cycles instead of 10.

## Risks flagged during breakdown

- **ccusage CLI shape on first invocation**: `ccusage session -j -i -p` flags need verification against the installed version. T4 should include a `ccusage --version` assertion and pin the expected major in `dashboards/usage-dashboard/package.json` devDeps. <!-- orianna: ok -->
- **Chart.js CDN dependency** creates a runtime internet requirement on first load. Acceptable for v1 since the page is opened fresh each session; if Duong wants offline, T7 can vendor Chart.js into `dashboards/usage-dashboard/vendor/`. <!-- orianna: ok -->
- **Work-repo transcript path**: `~/Documents/Work/mmp/workspace/agents/` sessions may have different first-user-message patterns than Strawberry. T2 should log any `unknown` attributions with `rawMatch` so we can tune regexes in a v1.1 patch without schema changes.
- **Commit-prefix scope**: all commits use `chore:` — these files are under `dashboards/**` and `scripts/**`, not `apps/**`, so release-please does not need feat/fix (CLAUDE.md rule 5). If an executor hits the pre-push hook complaining otherwise, check the diff scope before escalating.

## Out of scope (deferred to v2+)

- Cron job / install-cron.sh (dropped per override #5).
- Firestore or any network storage (dropped per override #1).
- Subagent `isSidechain` attribution (dropped per override #4).
- CSV/JSON export, alerts, hosted phone version (ADR v2+).

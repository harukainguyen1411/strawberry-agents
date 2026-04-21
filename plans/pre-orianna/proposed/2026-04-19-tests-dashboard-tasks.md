---
status: proposed
owner: kayn
date: 2026-04-19
title: Tests Dashboard — Task Breakdown
parent_adr: plans/approved/2026-04-19-tests-dashboard.md
related:
  - plans/approved/2026-04-19-claude-usage-dashboard.md
  - plans/approved/2026-04-17-test-dashboard-architecture.md
  - plans/in-progress/2026-04-17-deployment-pipeline.md
---

# Tests Dashboard — Task Breakdown

Executable task list for the approved tests-dashboard ADR
(`plans/approved/2026-04-19-tests-dashboard.md`, Azir, commit e97828d —
amended with Playwright as D4b). The ADR's handoff notes name four task
candidates; this plan refines them to seven tasks (TD.1 through TD.7),
two ADR-tracked follow-ups (TD.F1, TD.F2), and one repo-hygiene task
(TD.H1). Each implementation task is preceded on its branch by a
separate xfail-first test commit per CLAUDE.md Rule 12.

No implementer is named in this plan — task assignment is a separate
concern (see Rule #rule-plan-writers-no-assignment in the ADR). Each
task lists its **home repo** (strawberry-app or strawberry-agents) since
the two-repo split matters for path resolution and PR routing.

---

## Scope reminder (from ADR §9 Decisions + handoff)

- Three writers in v1: Vitest reporter (net-new), Playwright reporter
  (net-new), pytest plugin patch (two-line additive, conditional).
- One aggregator script in `strawberry-agents/scripts/test-dashboard/`
  that merges both repos' `.test-dashboard/` outputs into
  `test-dashboard-data/data.json`.
- One static SPA under `strawberry-app/dashboards/tests-dashboard/`
  (aggregator home = option (a), ADR Decision #3).
- Shared design tokens at `strawberry-app/dashboards/_shared/tokens.css`.
- Shared JSON schema `tests-dashboard-data-schema.json` both writers and
  the aggregator validate against.
- `file://` hosting only in v1; no auth; local-disk-only data flow.
- Repo scope: `harukainguyen1411/strawberry-app` +
  `harukainguyen1411/strawberry-agents` only.

---

## Dependency graph

```
TD.H1 (gitignore hygiene) ──────────────────────────────────┐
                                                            │ (must land before any
TD.F1 (rename existing session-dashboard ADR)               │  writer writes to disk)
TD.F2 (amend usage-dashboard plan to depend on tokens.css)  │
                                                            │
TD.1  (Vitest reporter + package + golden tests) ───┐       │
TD.1b (Playwright reporter + package + golden tests)├──> TD.2 (aggregator + schema) ──> TD.3 (static SPA + Playwright smoke)
TD.1c (pytest plugin patch — conditional)           ┘
```

- **TD.1, TD.1b, TD.1c** are parallelizable. TD.2 requires *at least one*
  writer landed (the ADR handoff §3 schema parity contract means the
  aggregator can be built against the shared schema + any one writer's
  golden fixtures; the other writers join the schema-validation suite as
  they land).
- **TD.3** requires TD.2 (the SPA consumes `data.json`).
- **TD.F1, TD.F2, TD.H1** are independent of everything and can land in
  any order — they are flagged explicitly because they are ADR-tracked
  follow-ups or hygiene that the ADR calls out (gitignore per ADR §Risks
  and mitigations, Orianna flag).

---

## Duong-blocking prerequisites

These must be confirmed by Duong before the dependent task can start.

| Ref | Blocker | Blocks | Notes |
|-----|---------|--------|-------|
| DTD-1 | Confirm the **Vitest major** in `strawberry-app/package.json` is stable for next 6 months (no planned migration). | TD.1 | ADR Decision #4 locks the reporter peerDep to that major. |
| DTD-2 | Confirm the **Playwright major** in `strawberry-app/package.json` (and `playwright.config.ts`) is stable for next 6 months. | TD.1b | ADR Decision #4b locks the reporter peerDep to that major. |
| DTD-3 | Is any pytest suite actually entering either repo in v1? If no, TD.1c ships as a no-op stub (schema file only, no plugin patch). If yes, point to the plugin file. | TD.1c (conditional) | ADR handoff §1 flags this. |
| DTD-4 | Aggregator-home confirmation — ADR Decision #3 says option (a) `strawberry-app/dashboards/tests-dashboard/` for static files, but the aggregator *script* and its config (clone-path map) live in strawberry-agents. Confirm the split. | TD.2, TD.3 | ADR §Open question 3 answered (a); this task plan treats it as resolved but flags for implementer sanity. |
| DTD-5 | Repo scope confirmation from ADR open-question 8 (strawberry-app + strawberry-agents only, no archive, no work). Already resolved in ADR Decision table row 8 — no action, just a reminder. | all | informational |

DTD-1 and DTD-2 should be resolvable by the implementer reading
`package.json` at task start — included as a Duong-blocker because the
ADR explicitly names "no planned migration in next 6 months" as a
confirmation Kayn must extract before implementation begins.

---

## Blocker resolutions (Decided by Evelynn 2026-04-19)

**DTD-1 — Vitest major pin**

Grepped all non-node_modules `package.json` files in `strawberry-app`.
Active workspace packages span majors 3 and 4; the leading edge is
`"vitest": "^4.1.4"` (apps/coder-worker) and `"vitest": "^4.0.18"`
(apps/myapps). Major 4 is the current stable major across the active
surfaces.

Decided by Evelynn 2026-04-19: pin the Vitest reporter peerDep to
`"^4"`. Implementation note for TD.1: declare
`"peerDependencies": { "vitest": "^4" }` in
`packages/vitest-reporter-tests-dashboard/package.json`. No migration
away from major 4 is planned in the next 6 months. DTD-1 closed.

**DTD-2 — Playwright major pin**

Grepped all non-node_modules `package.json` files in `strawberry-app`.
Only one workspace (`apps/myapps`) pins `@playwright/test`, at
`"^1.58.0"`. Major 1 is the current stable major (1.x has been the
stable line for years; 2.0 does not exist at time of writing).

Decided by Evelynn 2026-04-19: pin the Playwright reporter peerDep to
`"^1"`. Implementation note for TD.1b: declare
`"peerDependencies": { "@playwright/test": "^1" }` in
`packages/playwright-reporter-tests-dashboard/package.json`. DTD-2 closed.

**DTD-3 — pytest presence in either repo**

Searched both `strawberry-app` and `strawberry-agents` for
`pyproject.toml`, `requirements*.txt`, `conftest.py`, and `pytest.ini`
(excluding `node_modules/`). Results:

- `node_modules/node-gyp/gyp/pyproject.toml` — vendored node_modules, not a project test suite.
- `node_modules/firebase-tools/templates/init/functions/python/requirements.txt` — vendored node_modules template, not a project test suite.
- `apps/private-apps/bee-worker/tools/requirements.txt` — bee-worker internal tooling, not a pytest suite under test infrastructure.
- No `conftest.py` anywhere. No `pytest.ini` anywhere.

Decided by Evelynn 2026-04-19: no pytest suite is entering either repo
in v1. TD.1c ships as the CONDITIONAL — stub only path: add `"pytest"`
to the `runner` enum in `tests-dashboard-data-schema.json` and add a
README note in `strawberry-agents/schemas/README.md` describing the
one-line patch a future pytest adopter will need. No plugin code.
Activate the non-stub path when pytest first lands in either repo.
DTD-3 closed.

**DTD-4 — Aggregator-home split confirmation**

The ADR Decision #3 specifies option (a) for the static files home and
the architecture diagram names strawberry-agents as the aggregator
script home. Mapping to the ADR's decisions:

- D2 (aggregator): script at
  `strawberry-agents/scripts/test-dashboard/build.sh` — confirmed.
- D6 (static SPA): files at
  `strawberry-app/dashboards/tests-dashboard/` — confirmed.

Neither path exists yet (both are to-be-created by TD.2 and TD.3
respectively), which is expected. The split is correct and matches the
ADR. DTD-4 closed.

**DTD-5 — Repo scope confirmation**

ADR Decision row 8 already resolved this. Repo scope is:
`harukainguyen1411/strawberry-app` + `harukainguyen1411/strawberry-agents`
only. Archive repo `Duongntd/strawberry` and all work repos under
`~/Documents/Work/mmp/**` are explicitly out of scope. No action
required. DTD-5 closed (informational only, as noted in the table).

---

## Task-level conventions

Each task has these fields:

- **Home repo** — `strawberry-app` or `strawberry-agents`. Determines
  which PR lands the work.
- **Goal** — the single outcome.
- **Inputs** — ADR references, prior tasks, Duong blockers.
- **Outputs** — files created/modified.
- **xfail-first commit** — exact content and file path of the xfail
  test that MUST precede the implementation commit on the same branch
  (Rule 12). Named as a **separate bullet** because it is a separate
  commit.
- **Acceptance** — what green looks like at PR review time.
- **Prereqs** — blocking task IDs (not soft dependencies).
- **Parallelizable with** — tasks that share no files / no blocking
  dependencies with this one.

xfail commits reference this plan's slug (`tests-dashboard`) in their
commit body per Rule 12 (e.g., `Refs plan: tests-dashboard, task TD.1`).

---

## TD.H1 — Gitignore hygiene for `.test-dashboard/` and `test-dashboard-data/`

- **Home repo:** both (one commit per repo).
- **Goal:** prevent accidental `git add -A` from leaking error tracebacks
  or local file paths into either repo's public history.
- **Inputs:** ADR §Risks and mitigations bullet 3 (Orianna's flag).
- **Outputs:**
  - `strawberry-app/.gitignore` — add `.test-dashboard/` and
    `test-dashboard-data/` entries.
  - `strawberry-agents/.gitignore` — add the same two entries.
  - (Optional — ADR mentions it but it is a separate concern) update
    `scripts/install-hooks.sh` in strawberry-agents to block any
    staged file matching `**/.test-dashboard/**`. If this is done, it
    is a **separate sub-task TD.H1b** — see below.
- **xfail-first commit:** none required — this is pure-hygiene / non-TDD
  infrastructure (Rule 12 scope is TDD-enabled services only, and
  `.gitignore` is not code). Both `.gitignore` edits can ride a single
  `chore:` commit per repo.
- **Acceptance:**
  - `git check-ignore -v .test-dashboard/foo` returns non-empty in both
    repos.
  - `git check-ignore -v test-dashboard-data/data.json` returns
    non-empty in both repos.
- **Prereqs:** none.
- **Parallelizable with:** everything. Land first for safety.

### TD.H1b — pre-commit path-block hook (optional, gated on Duong)

- **Home repo:** strawberry-agents.
- **Goal:** pre-commit hook rejects any staged path under `.test-dashboard/`
  with an explicit error message. Defense-in-depth against gitignore
  getting stripped or bypassed.
- **Inputs:** ADR §Risks and mitigations bullet 3.
- **Outputs:** patch to `scripts/install-hooks.sh` + the installed
  `.git/hooks/pre-commit` logic (or a helper script sourced by it).
- **xfail-first commit:** a bash test under `scripts/test-*.sh` that
  stages a fixture `.test-dashboard/leak.json`, invokes the pre-commit
  hook, and asserts non-zero exit + the expected error message. Initial
  run: fails (hook not yet wired).
- **Acceptance:** test passes post-implementation. Staging a file under
  `.test-dashboard/` is rejected with a human-readable message.
- **Prereqs:** TD.H1.
- **Parallelizable with:** TD.1, TD.1b, TD.1c, TD.2, TD.3.
- **Gate:** Duong confirms defense-in-depth is wanted; if not, drop.

---

## TD.1 — Vitest reporter package (schema-compliant writer)

- **Home repo:** strawberry-app.
- **Goal:** a private workspace package that plugs into
  `vitest.config.ts` as a custom reporter and emits
  `test-results.json` + `test-run-history.json` into
  `./.test-dashboard/` in the same schema the pytest plugin produces,
  plus `repo`/`runner` top-level fields per ADR Decision #3.
- **Inputs:**
  - ADR Decision #4 (custom reporter path, not post-process).
  - ADR handoff §Reference implementation — semantics of the
    demo-studio-v3 pytest plugin at
    `~/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3/conftest_results_plugin.py`
    (read for semantics only; DO NOT copy source).
  - Shared JSON schema file at
    `strawberry-agents/schemas/tests-dashboard-data-schema.json`
    (produced in TD.2; TD.1 can start by drafting the schema locally
    and moving the canonical copy to strawberry-agents in TD.2).
  - DTD-1 (Vitest major pin confirmation).
- **Outputs:**
  - `strawberry-app/packages/vitest-reporter-tests-dashboard/` — new
    private workspace package.
  - `packages/vitest-reporter-tests-dashboard/package.json` — name
    `@strawberry/vitest-reporter-tests-dashboard`, `peerDependencies`
    pinned to the Vitest major from DTD-1.
  - `packages/vitest-reporter-tests-dashboard/src/index.ts` — default
    export: class implementing Vitest's `Reporter` interface. Hooks:
    `onFinished` / `onTestFinished`. Atomic write: temp file in same
    directory + `fs.renameSync` to final name (ADR §Architecture v1
    atomic-write contract).
  - `packages/vitest-reporter-tests-dashboard/src/schema.ts` — typed
    representation of the shared schema; validates at write time and
    throws on drift.
  - `packages/vitest-reporter-tests-dashboard/test/` — golden-file
    tests driven by synthetic `TaskResultPack` fixtures. Cover:
    all-pass, one-fail-with-error, xfail, xpassed, skip, mixed run
    (new-test detection), atomic-write-no-partial-read.
- **xfail-first commit (separate commit, must precede implementation
  commit on the same branch):**
  - File: `strawberry-app/packages/vitest-reporter-tests-dashboard/test/reporter.xfail.test.ts`
  - Content: a Vitest test imports the (not-yet-existing) default
    export from `../src/index.ts`, constructs a minimal synthetic
    finished-run payload, calls `onFinished`, and asserts
    `fs.existsSync('./.test-dashboard/test-results.json')` is true and
    that the file validates against the shared schema.
  - Marker: `test.fails(...)` (Vitest's xfail equivalent) OR a
    standard `test(...)` that is expected to fail until the package
    is implemented. Commit body: `Refs plan: tests-dashboard, task TD.1
    (xfail-first per CLAUDE.md Rule 12)`.
  - Initial run: fails (module does not exist).
- **Acceptance:**
  - xfail test from the xfail-first commit passes post-implementation.
  - Golden-file fixtures cover all five outcome types (pass/fail/
    xfail/xpassed/skip) plus the new-test-detection case and
    atomic-write case.
  - `@strawberry/vitest-reporter-tests-dashboard` declares the Vitest
    peerDep pin.
  - Reporter output for each fixture validates against
    `schemas/tests-dashboard-data-schema.json` (the schema file in
    strawberry-agents — TD.1 consumes whatever copy exists; TD.2
    establishes the canonical home).
  - Emitted JSON includes `repo: "strawberry-app"` and
    `runner: "vitest"` at the top level per ADR Decision #3.
- **Prereqs:** DTD-1. Soft: TD.H1 (strongly recommended to land first so
  no accidental commit of emitted JSON during test runs).
- **Parallelizable with:** TD.1b, TD.1c, TD.F1, TD.F2, TD.H1, TD.H1b.

---

## TD.1b — Playwright reporter package (schema-compliant writer, E2E first-class)

- **Home repo:** strawberry-app.
- **Goal:** a private workspace package that plugs into
  `playwright.config.ts`'s `reporter: [...]` array and emits
  `test-results.json` + `test-run-history.json` into
  `./.test-dashboard/` in the same schema as TD.1 + pytest, with
  `runner: "playwright"` and the optional `playwright` sub-object
  carrying browser/project/retries/trace/video/screenshots per ADR
  D4b.
- **Inputs:**
  - ADR Decision #4b (custom reporter path, first-class v1 writer).
  - Shared JSON schema as above.
  - DTD-2 (Playwright major pin confirmation).
- **Outputs:**
  - `strawberry-app/packages/playwright-reporter-tests-dashboard/` —
    new private workspace package.
  - `package.json` — name
    `@strawberry/playwright-reporter-tests-dashboard`,
    `peerDependencies` pinned to the Playwright major from DTD-2.
  - `src/index.ts` — default export: class implementing Playwright's
    `Reporter` interface. Hooks: `onTestBegin`, `onTestEnd`, `onEnd`.
    Atomic write contract identical to TD.1. Captures Playwright-
    specific enrichment (browser, project, retries, trace path, video
    path, screenshots[]) under the optional `playwright` sub-object
    per ADR D4b.
  - `src/schema.ts` — shared-schema validator (same contract as TD.1).
  - `test/` — golden-file fixtures for: pass, fail-with-trace-zip,
    retry-then-pass, retry-then-fail, skip, cross-browser matrix.
    Fixtures synthesize `TestCase` + `TestResult` objects.
- **xfail-first commit (separate):**
  - File: `strawberry-app/packages/playwright-reporter-tests-dashboard/test/reporter.xfail.test.ts`
  - Content: test imports the (not-yet-existing) default export,
    synthesizes an `onTestEnd` + `onEnd` sequence, asserts the emitted
    JSON exists, validates against the shared schema, and includes a
    `playwright` sub-object with `browser`, `project`, `retries`.
  - Initial run: fails (module does not exist). Commit body:
    `Refs plan: tests-dashboard, task TD.1b (xfail-first per
    CLAUDE.md Rule 12)`.
- **Acceptance:**
  - xfail test passes post-implementation.
  - Golden fixtures cover the six cases above.
  - Package declares the Playwright peerDep pin.
  - Emitted JSON validates against the shared schema and includes the
    optional `playwright` sub-object with the expected fields.
  - Trace-zip / video / screenshot path strings in the `playwright`
    sub-object are relative paths (portable across Duong's machine
    and any future CI runner).
- **Prereqs:** DTD-2. Soft: TD.H1.
- **Parallelizable with:** TD.1, TD.1c, TD.F1, TD.F2, TD.H1, TD.H1b.

---

## TD.1c — pytest plugin patch (additive `repo` + `runner` fields) — CONDITIONAL

- **Home repo:** wherever the pytest plugin actually lives. ADR handoff
  §3 names it as "additive two-line patch to the demo-studio-v3 plugin";
  the demo-studio-v3 repo is outside Strawberry scope (it is under
  `~/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3/`).
  **For Strawberry v1 this task is conditional on DTD-3** — is any
  pytest suite actually entering strawberry-app or strawberry-agents?
  - If **no** (likely the v1 answer): ship TD.1c as a **no-op stub
    commit** that adds `pytest` to the shared schema's `runner` enum
    (so the schema covers the future case) and a README.md note in
    the schema folder documenting the one-line patch a future pytest
    adopter will need to apply. No actual plugin code changes.
  - If **yes** (a pytest suite enters either repo during v1): ship the
    additive patch on the in-repo plugin file; fields `repo` and
    `runner` added to each run entry; golden-file test covering one
    pytest outcome validates against the shared schema.
- **Inputs:** ADR Decision #3 (additive-only schema), ADR handoff §3,
  DTD-3.
- **Outputs:**
  - Either: README note in
    `strawberry-agents/schemas/README.md` describing the pytest-
    adopter patch, plus `"pytest"` retained in the `runner` enum in
    `tests-dashboard-data-schema.json`; or:
  - A patch to the in-repo pytest plugin + a small pytest test that
    asserts the emitted JSON includes `repo` + `runner` top-level
    fields.
- **xfail-first commit (separate, only if the task is non-stub):**
  - File: `<plugin-dir>/test_schema_parity_xfail.py`.
  - Content: a pytest test that runs a minimal synthetic pytest
    session with the plugin enabled, reads `./.test-dashboard/test-
    results.json`, and asserts `repo` + `runner` keys are present and
    that the JSON validates against the shared schema.
  - Initial run: fails (plugin not yet patched). Commit body:
    `Refs plan: tests-dashboard, task TD.1c (xfail-first per
    CLAUDE.md Rule 12)`.
- **Acceptance:**
  - Non-stub path: xfail passes; emitted JSON validates against the
    shared schema.
  - Stub path: schema-README note exists; no production code changed.
- **Prereqs:** DTD-3. TD.2 may land before or after TD.1c depending on
  path — TD.2's schema file is a prereq if non-stub, a co-prereq if
  stub.
- **Parallelizable with:** TD.1, TD.1b, TD.F1, TD.F2, TD.H1, TD.H1b.

---

## TD.2 — Aggregator script + shared JSON schema + schema-validation test suite

- **Home repo:** strawberry-agents (script + schema live here per ADR
  architecture diagram §v1).
- **Goal:** one POSIX-portable bash script that discovers both repos'
  `.test-dashboard/` outputs, merges them into a single
  `test-dashboard-data/data.json` with atomic write, enforces the 50-
  run-per-repo cap (ADR Decision #10), and validates every input
  against the shared schema. Plus: establish the canonical shared
  schema file and wire each writer's test suite to validate against
  it.
- **Inputs:**
  - ADR §Architecture v1 aggregator contract (5 steps listed in the
    ADR).
  - ADR Decision #10 (50-run cap, archive spill to
    `test-run-history-archive.jsonl.gz`).
  - ADR Decision #3 (additive `repo` + `runner` fields, strict
    additive-only schema).
  - At least one writer's golden fixtures (TD.1 OR TD.1b) to drive the
    aggregator's test suite. The ADR handoff §Task-2 candidate phrasing
    "schema-validation tests for all three writers" implies the
    aggregator's acceptance is strongest once all three land, but the
    aggregator itself is buildable and testable against any one writer
    — later writers extend the fixture set.
- **Outputs:**
  - `strawberry-agents/schemas/tests-dashboard-data-schema.json` — the
    canonical shared schema. JSON Schema draft-07. Covers:
    top-level `repo` + `runner` fields; all per-test entry fields
    from the pytest plugin (totals by outcome, per-test status, error
    text, traceback, first-seen date, history ring entries); optional
    `playwright` sub-object per ADR D4b.
  - `strawberry-agents/schemas/README.md` — short doc naming the
    writers and linking back to this plan + the ADR.
  - `strawberry-agents/scripts/test-dashboard/build.sh` — POSIX-
    portable bash (runs on macOS and Git Bash on Windows per Rule 10).
    Reads a config file of clone paths (no scanning); merges; enforces
    the 50-run cap with archive spill; writes atomically (temp file +
    `mv`).
  - `strawberry-agents/scripts/test-dashboard/config.example.json` —
    example clone-path map.
  - `strawberry-agents/scripts/test-dashboard/build.test.sh` (or a
    Vitest/`bats` file in a convention already used in the repo) —
    end-to-end test: stages synthetic `test-results.json` files for
    two fake repos, runs `build.sh`, asserts the merged `data.json`
    validates against the schema AND that each input was schema-valid
    before being merged AND that partial writes are impossible
    (assert there is no moment where `data.json` exists with
    truncated content).
  - Schema-validation wiring: each writer's package in strawberry-app
    (TD.1 and TD.1b) gains a test that loads
    `tests-dashboard-data-schema.json` from strawberry-agents (via
    a documented relative path or a vendored copy — implementer
    chooses; see OQ-A below) and validates emitted fixtures against
    it. Drift in any writer fails that writer's CI.
- **xfail-first commit (separate):**
  - File: `strawberry-agents/scripts/test-dashboard/build.xfail.test.sh`
    (or `.ts` if the repo's test harness is TS).
  - Content: stages one synthetic `test-results.json` per fake repo,
    invokes (the not-yet-existing) `build.sh`, asserts `data.json` is
    produced, validates against (the not-yet-existing) schema file,
    and asserts the aggregator exits non-zero when fed a
    schema-invalid input.
  - Initial run: fails (script does not exist and schema file does
    not exist). Commit body: `Refs plan: tests-dashboard, task TD.2
    (xfail-first per CLAUDE.md Rule 12)`.
- **Acceptance:**
  - xfail suite passes post-implementation.
  - `scripts/test-dashboard/build.sh` is POSIX-portable bash (passes
    `shellcheck`, runs under Git Bash).
  - 50-run cap enforced; overflow rotated into
    `test-run-history-archive.jsonl.gz`.
  - Atomic write contract: no observable partial-content window
    (demonstrated by the aggregator's test, e.g., start a reader loop
    that repeatedly parses `data.json` while the writer runs; every
    read must parse or ENOENT, never truncated JSON).
  - Schema-validation tests attached to *both* TD.1 and TD.1b (or
    whichever writers have landed) import the schema and pass.
  - Schema covers all runner enum values (`vitest`, `playwright`,
    `pytest`, and `bash` reserved for v2).
- **Prereqs:** at least one of TD.1 or TD.1b landed (for a real writer
  fixture to drive the test). Soft prereq: TD.H1 (so the aggregator's
  output dir is already gitignored).
- **Parallelizable with:** TD.F1, TD.F2, TD.H1, TD.H1b, TD.1c.
- **Open question OQ-A (for implementer):** schema location — canonical
  copy in `strawberry-agents/schemas/` is clear; the writer packages
  in strawberry-app need to reference it somehow. Options: (a) each
  writer vendors a copy (drift risk but zero cross-repo coupling at
  test time), or (b) writer tests pull the schema from a relative path
  assumed by convention (no vendoring but requires both repos checked
  out side-by-side for test runs). **Default recommendation: (a) vendor
  a copy per writer with a CI check that the vendored file matches the
  canonical copy byte-for-byte.** Flag in PR review.

---

## TD.3 — Static dashboard SPA + shared tokens.css + Playwright smoke test

- **Home repo:** strawberry-app (aggregator home option (a), ADR
  Decision #3).
- **Goal:** the three-panel static SPA described in ADR §Architecture
  v1, served via `file://`, reading `data.json` produced by TD.2. Plus:
  create the shared `dashboards/_shared/tokens.css` that both this
  dashboard and the (future) usage dashboard consume.
- **Inputs:**
  - ADR §Architecture v1 (three-panel layout, Chart.js via CDN, no
    framework).
  - ADR Decision #6 (shared `dashboards/_shared/` root, Inter +
    JetBrains Mono, GitHub-dark palette, pass/fail/xfail/skip color
    scale).
  - ADR handoff §Task-3 candidate (includes Playwright smoke test that
    asserts a golden `data.json` renders expected DOM, including
    Playwright-runner rows with browser/project/retry metadata and
    trace.zip deep-link affordances).
  - TD.2 output: a stable `data.json` shape to fetch and render.
- **Outputs:**
  - `strawberry-app/dashboards/_shared/tokens.css` — GitHub-dark
    palette tokens, Inter + JetBrains Mono font-face / font-family
    declarations, pass/fail/xfail/skip status colors, status-pill
    primitive styles, sparkline primitive styles.
  - `strawberry-app/dashboards/tests-dashboard/index.html` — three-
    panel layout (runs list top, failure-trends middle-left, per-test
    detail middle-right + history bottom). Loads Chart.js via CDN.
    Imports `../../_shared/tokens.css`.
  - `strawberry-app/dashboards/tests-dashboard/app.js` — no framework;
    `fetch('./data.json')`, render the three panels, handle click
    interactions (row click → drill-in; bar click → filter runs list).
    Includes Playwright-runner-aware rendering: browser/project
    chips, retry badge, trace.zip deep-link when
    `playwright.trace` is present.
  - `strawberry-app/dashboards/index.html` — one-click landing that
    lists both dashboards (tests + usage). Cheap per ADR Decision #6.
  - `strawberry-app/dashboards/tests-dashboard/e2e/dashboard.smoke.
    spec.ts` — Playwright smoke test: fixture `data.json` with at
    least one Vitest row, one Playwright row (with browser/project/
    retries/trace), and one xfail + one skip; asserts the DOM
    renders the expected row count, the status pills have the right
    colors (token-driven, readable via computed style), and the
    trace.zip anchor exists with the expected `href`.
- **xfail-first commit (separate):**
  - File: `strawberry-app/dashboards/tests-dashboard/e2e/dashboard.smoke.xfail.spec.ts`
  - Content: loads the (not-yet-existing) `dashboards/tests-dashboard/
    index.html` under Playwright with a fixture `data.json` injected
    into a known path; asserts the runs list renders with two rows
    (one per repo), and asserts the Playwright row exposes the
    `data-browser` attribute with value `chromium`.
  - Initial run: fails (files do not exist). Commit body: `Refs plan:
    tests-dashboard, task TD.3 (xfail-first per CLAUDE.md Rule 12)`.
- **Acceptance:**
  - xfail Playwright test passes post-implementation.
  - Three panels render from a fixture `data.json` under `file://`
    (smoke test drives this, no dev server required).
  - Failure trends sparkline renders via Chart.js with at least 2
    data points; clicking a bar filters the runs list.
  - Per-test detail panel responds to node-ID search and shows the
    most recent error message + a 20-run history line.
  - `dashboards/_shared/tokens.css` is the ONLY source of color
    tokens used by `tests-dashboard/`; no hardcoded hex values in
    `app.js` or inline styles (enforced by a linter rule OR a
    grep-based assertion in the smoke test).
  - `dashboards/index.html` lists both dashboards (tests +
    placeholder link for the usage dashboard).
  - No Vite/React build step required — pure static, Chart.js via
    CDN, matches ADR Decision #1.
- **Prereqs:** TD.2. Soft: TD.1 and TD.1b both landed so realistic
  fixture data is available.
- **Parallelizable with:** TD.F1, TD.F2, TD.H1b, TD.1c.
- **UI-PR gate:** per CLAUDE.md Rule 16, before the TD.3 PR opens for
  merge, a QA agent must run the full Playwright flow with video +
  screenshots and file a report under `assessments/qa-reports/`. The
  smoke test in this task is the *author's* test; the QA run is
  separate. Flag on the PR body template.

---

## TD.F1 — Rename the existing session-dashboard ADR (ADR follow-up)

- **Home repo:** strawberry-agents.
- **Goal:** rename `plans/approved/2026-04-17-test-dashboard-architecture.md`
  to `plans/approved/2026-04-17-session-dashboard-architecture.md` and
  update its frontmatter slug + any cross-refs, per ADR Decision row 6.
- **Inputs:** ADR Decision row 6 in the tests-dashboard ADR; Evelynn
  sign-off in the ADR itself.
- **Outputs:**
  - Renamed file at
    `plans/approved/2026-04-17-session-dashboard-architecture.md`
    (original path no longer exists).
  - Frontmatter `slug:` updated from `test-dashboard-architecture` to
    `session-dashboard-architecture` (match the new filename).
  - Grep sweep across `plans/`, `agents/`, `assessments/`,
    `architecture/` for any string referencing the old slug or
    filename; each hit updated to the new slug/filename. Sweep
    command: `Grep pattern test-dashboard-architecture` (case-
    sensitive is fine; the slug form is stable).
- **xfail-first commit:** none required — this is an in-place ADR
  rename, not a TDD-enabled service.
- **Acceptance:**
  - Old filename no longer resolves (`Glob pattern
    **/2026-04-17-test-dashboard-architecture.md` returns empty).
  - New filename exists at the right path.
  - `Grep pattern test-dashboard-architecture` returns zero hits
    across the repo (excluding git history and this tasks plan's
    prose).
  - ADR's own frontmatter slug matches the new filename.
- **Prereqs:** none.
- **Parallelizable with:** everything.
- **Process note:** per Rule 7, plans leaving `proposed/` use
  `scripts/plan-promote.sh`. This task is an **in-place rename within
  `approved/`**, which plan-promote.sh does not cover. Use `git mv`
  directly (it is allowed within a single plan-status directory — Rule
  7 specifically prohibits raw `git mv` for plans *leaving*
  `proposed/`). Commit prefix: `chore:` (plans are non-code).

---

## TD.F2 — Amend the approved usage-dashboard plan to depend on shared tokens.css (ADR follow-up)

- **Home repo:** strawberry-agents.
- **Goal:** add a tiny amendment to
  `plans/approved/2026-04-19-claude-usage-dashboard.md` noting that it
  depends on `strawberry-app/dashboards/_shared/tokens.css` (produced
  by TD.3), per ADR Decision row 10.
- **Inputs:** ADR Decision row 10 in the tests-dashboard ADR.
- **Outputs:** patch to the approved usage-dashboard plan — either an
  inline note in the relevant section, or a new subsection "Shared
  tokens (2026-04-19 amendment)" cross-referencing this tasks plan and
  the tests-dashboard ADR's D6.
- **xfail-first commit:** none (plan edit).
- **Acceptance:**
  - The approved usage-dashboard plan contains a clear statement that
    its SPA styles come from `dashboards/_shared/tokens.css` and not
    from a sibling-duplicated copy.
  - Cross-reference to this tasks plan + to the tests-dashboard ADR's
    D6.
- **Prereqs:** none (can land before TD.3 — it is a plan-level
  dependency declaration, not a code dependency).
- **Parallelizable with:** everything.
- **Process note:** editing a plan in `approved/` is allowed in place;
  `plan-promote.sh` is for directory moves. Commit prefix: `chore:`.

---

## Dispatch order (recommended)

1. **Hygiene first (parallel, any order):** TD.H1 → TD.F1 → TD.F2.
   These are cheap and unblock/insulate everything else. TD.H1b is
   optional (gated on Duong's defense-in-depth call).
2. **Writers fan-out (parallel):** TD.1, TD.1b, TD.1c. Three
   independent packages with no shared files. TD.1c may be a stub
   per DTD-3.
3. **Aggregator join:** TD.2 lands after the first writer lands
   (TD.1 or TD.1b). The other writers' schema-validation tests join
   as they land.
4. **SPA join:** TD.3 lands after TD.2.

If only one executor is available, serial order is: TD.H1 → TD.F1 →
TD.F2 → TD.1 → TD.1b → TD.1c → TD.2 → TD.3.

---

## Out-of-scope confirmations (reviewer aid)

The following are explicitly **not** in this task plan, to prevent
scope creep during PR review:

- **Bash / TAP adapter** — ADR Decision #8 defers to v2.
- **CI-artifact data flow** (uploading `test-results.json` from GitHub
  Actions, downloading via `gh run download`) — ADR Decision #5 defers
  to v2.
- **Firebase Hosting** — ADR Decision #1 keeps v1 at `file://`.
- **Firebase Auth + UID allow-list** — ADR Decision #5 zero-auth v1.
- **SSE / WebSocket / filesystem watcher** — ADR Decision #9 v1 polls
  on page load only.
- **Flake detection**, **duration regression alerts**, **agent
  attribution** — ADR §Features table v2/v3.
- **Merging tests and usage dashboards into a single view** — ADR
  Decision #6 keeps them sibling-under-shell, separate.
- **Touching the existing approved session-dashboard ADR (Cloud Run,
  Vite+React, Firebase Auth) beyond the rename in TD.F1** — that ADR
  is a different surface and untouched otherwise.
- **Archive repo `Duongntd/strawberry` and work repos
  `~/Documents/Work/mmp/**`** — ADR Decision row 8 confirms
  out-of-scope.

---

## Traceability — task → ADR section

| Task | ADR sections |
|------|---|
| TD.H1 | §Risks and mitigations (gitignore discipline) |
| TD.H1b | §Risks and mitigations (gitignore discipline, defense-in-depth) |
| TD.1 | D3, D4, §Architecture v1, handoff §Task-1 |
| TD.1b | D3, D4b, §Architecture v1, handoff §Task-1b |
| TD.1c | D3, handoff §Task-4 (re-numbered here as TD.1c) |
| TD.2 | D2, D3, D10, §Architecture v1 (aggregator contract), handoff §Task-2 |
| TD.3 | D1, D6, D9, §Architecture v1 (dashboard shell), handoff §Task-3 |
| TD.F1 | Decision row 6 |
| TD.F2 | Decision row 10 |

---

## Commit-prefix guidance (Rule 5)

- Plan file itself (this file): `chore:` — lives in `plans/proposed/`.
- TD.1, TD.1b, TD.1c, TD.3 code commits: touch
  `strawberry-app/packages/**` or `strawberry-app/dashboards/**`; in
  strawberry-agents terms these are *external repo* changes. In
  strawberry-app terms these are non-`apps/**` (no `apps/myapps/`
  touched) so `chore:` is correct unless the package is wired into
  the release-please surface. Implementer verifies against
  strawberry-app's `release-please` config at task start; default
  assumption is `chore:`.
- TD.2 code commit: `chore:` (script in `scripts/`, not `apps/**`).
- TD.F1, TD.F2, TD.H1, TD.H1b: `chore:` — plans / infra / docs.

---

## End

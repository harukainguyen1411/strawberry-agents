---
status: proposed
owner: caitlyn
created: 2026-04-17
slug: test-dashboard-qa-plan
---

# Test Dashboard — QA & Testing Plan

## Purpose

Define the full testing strategy for the test-dashboard service. Six layers: xfail-first TDD, regression, unit, E2E Playwright, pre-PR QA Playwright review, and smoke. Each layer has a clear trigger, owner, success criteria, artifact location, and failure path.

This plan is QA strategy only. Architecture decisions (stack, framework, deployment) live in Azir's ADR. Implementation tasks for each layer are handed off to Vi after this plan is approved.

## Guiding principles

- Test behavior, not implementation.
- Fast feedback close to the author; slow/expensive gates close to the merge.
- Every failure produces a durable artifact someone can review offline.
- A test that never fails is not a test — xfail-first proves the test actually detects the thing.

---

## Layer 1 — xfail-first TDD workflow

**What it is.** Every new feature or bug-fix task begins by writing a failing test marked `xfail` (or the framework's equivalent — `test.fail` in Playwright, `@pytest.mark.xfail` in pytest, `it.failing` in Vitest). The test encodes the intended behavior. Implementation is done when the xfail flips to pass and the marker is removed in the same commit.

**What gets tested.** The new behavior under development — the smallest observable contract the task is meant to deliver.

**Trigger.** Author (Vi), at task start. No CI trigger — this is a workflow discipline, not a gate.

**Success criteria.**
- First commit on the task branch contains the xfail test.
- Final commit on the branch flips xfail → pass and deletes the marker.
- PR description links the xfail commit SHA and the flip commit SHA.

**Fail criteria.**
- PR merges with xfail markers still present (pre-merge check should block).
- Implementation commit lands before the xfail commit on the branch (git log order check).

**Artifacts.** None beyond git history. The commit trail is the artifact.

**Failure report path.** PR review comment; reviewer requests changes.

**Enforcement.** A lightweight pre-merge check script (Vi to implement) greps the diff for `xfail`/`test.fail`/`it.failing` markers added but not removed, and inspects branch commit order.

---

## Layer 2 — Regression tests

**What it is.** Every bug fix ships with a test that reproduces the bug and fails on the parent commit (pre-fix) and passes on the fix commit. Zero exceptions.

**What gets tested.** The exact failure mode reported in the bug. Not a proxy, not a general area — the specific input/state that triggered the bug.

**Trigger.** Author, as part of the fix PR. CI verifies the test exists and runs.

**Success criteria.**
- PR title or body references a bug ID / issue / incident.
- Diff adds at least one test in a `regression/` subdirectory or tagged `@regression`.
- Reviewer can checkout the parent commit, run the new test, and watch it fail.

**Fail criteria.**
- Bug-fix PR with no added test.
- Test passes on the parent commit (didn't actually reproduce the bug).

**Artifacts.** Test file lives permanently under `tests/regression/<layer>/YYYY-MM-DD-<slug>.spec.ts` (or language equivalent). File name carries the date and bug slug so history is grep-able.

**Failure report path.** CI run page; linked in PR.

**Enforcement.** PR template checkbox "regression test added (or N/A — explain)". Reviewer rejects if skipped without justification.

---

## Layer 3 — Unit tests (pre-commit)

**What it is.** Fast, hermetic unit tests covering pure functions, component rendering, and isolated module behavior. No network, no filesystem beyond temp, no real database.

**What gets tested.**
- All exported functions in `src/lib/` and `src/utils/`.
- Component render output and event handlers (React Testing Library or framework equivalent).
- Data transformations, parsers, validators, reducers.
- Error branches — every `throw` and every error-return path.

**Trigger.** Pre-commit hook (husky or lefthook) runs `<framework> test --related` against staged files. Full suite runs in CI on every push.

**Success criteria.**
- Pre-commit suite completes in under 10 seconds on staged diff.
- Full suite completes in under 60 seconds.
- Coverage on `src/lib/` and `src/utils/` is tracked (no hard gate initially — watch the trend).
- Zero network calls (enforced via a test-env guard that throws on `fetch`/`http` imports in unit-test mode).

**Fail criteria.**
- Pre-commit hook blocks commit on failure. Author fixes or explicitly `--no-verify` with a justification comment on the subsequent PR (rare).
- Any test takes longer than 500ms → flagged as a candidate to move to integration tier.

**Artifacts.**
- CI: JUnit XML uploaded as GH Actions artifact, retained 30 days.
- Coverage: HTML report uploaded per run, retained 14 days.

**Failure report path.** Pre-commit: terminal. CI: GH Actions check on PR.

---

## Layer 4 — E2E Playwright tests (PR gate)

**What it is.** Full browser-driven user flows against a deployed preview environment. Triggered on PR creation and every push to the PR branch.

**What gets tested.**
- Critical user journeys: dashboard load, test-run drilldown, filter/search, auth flow, error states.
- Visual assertions on key views (Playwright's `toHaveScreenshot`, masked timestamps).
- API-backed flows that unit tests can't cover (real backend, real data fetch).

**Trigger.** GitHub Actions workflow on `pull_request` events. Matrix below.

**Test matrix.**

| Axis | Values |
|---|---|
| Browser | chromium, firefox, webkit |
| Viewport | desktop (1440x900), mobile (390x844 — iPhone 13) |
| Auth state | logged-out, logged-in (via stored auth state fixture) |

Total shards: 3 browsers × 2 viewports × 2 auth = 12 parallel jobs. Playwright's sharding splits tests across jobs for under-10-minute wall time.

**Environment.** Each PR gets a preview deployment (Azir's ADR defines how). E2E targets the preview URL. No production traffic.

**Success criteria.**
- All matrix cells pass.
- Flakiness budget: a test may retry once; two retries required → flagged as flaky and owner paged via PR comment.
- Wall-clock under 10 minutes per PR.

**Fail criteria.**
- Any red cell blocks merge (branch protection).
- Flaky test (2+ retries) files an auto-issue for Caitlyn/Vi triage.

**Artifacts.**
- Playwright HTML report uploaded to GH Actions artifacts (retained 30 days).
- Video recording on failure only (retain-on-failure mode).
- Trace file on failure (zip — openable in `playwright show-trace`).
- Screenshots of every failing assertion.

**Failure report path.** GH Actions check on PR, links to the HTML report artifact. Summary comment posted to PR by a small action step.

**Reporting.** Per-run HTML report; aggregate flakiness dashboard (weekly, Vi to wire up later).

---

## Layer 5 — QA Playwright review (pre-PR, human/agent-driven)

**What it is.** Before opening a PR, the author (or a dedicated QA agent) runs a Playwright-driven walkthrough of the feature in `headed` mode, recording video and taking deliberate screenshots at checkpoint states. The output is compared against the Figma/design spec and reviewed for bugs the automated tests would miss: layout glitches, copy errors, loading-state jank, accessibility regressions, unexpected console errors.

**What gets tested.**
- The feature as a user sees it — not just assertions.
- Visual fidelity vs. design mock.
- Hover/focus/keyboard states.
- Loading and empty states with realistic data volume.
- Console + network panel: no unexpected 4xx/5xx, no React warnings.
- Cross-tab / browser-back / refresh behavior.

**Trigger.** Author, locally or in a dedicated QA environment, before marking PR ready-for-review. Required for any PR touching UI. Non-UI PRs (pure backend, config) can skip with a checkbox justification.

**Checklist (lives in `docs/qa/pre-pr-checklist.md` — Vi creates).**

1. Feature opened in all three browsers at desktop + mobile viewports.
2. Golden-path flow video recorded end to end.
3. Screenshot captured at every distinct UI state (empty, loading, populated, error, success).
4. Design spec opened side-by-side; deltas annotated.
5. Browser console clean (no uncaught errors, no React key warnings).
6. Network panel: no unexpected requests, no failed requests on happy path.
7. Keyboard-only navigation works for primary actions.
8. Screen reader smoke: primary landmark + button labels sensible (axe-core scan optional but recommended).
9. Error injection: disable network, submit invalid input, log out mid-flow — does the UI degrade gracefully?
10. Accessibility audit (axe-core or Playwright's `@axe-core/playwright`) — zero critical violations.

**Artifact handoff format.** A single directory per PR:

```
qa-artifacts/pr-<number>/
  video-chromium-desktop.webm
  video-chromium-mobile.webm
  video-firefox-desktop.webm
  video-webkit-desktop.webm
  screenshots/
    01-empty-state.png
    02-loading.png
    03-populated.png
    04-error-network-down.png
    ...
  design-deltas.md         # bullet list of any visual deviations + justification
  checklist.md             # the filled-in checklist above with pass/fail per item
  axe-report.json          # axe-core output
```

Directory is uploaded as a GH Actions artifact via a one-shot `gh` command, OR attached to the PR as a zip via PR comment. (Azir's ADR picks the storage — likely GCS bucket with a signed URL per PR.)

**Success criteria.**
- Checklist fully completed; every item pass or waived-with-justification.
- Video shows the golden path working end-to-end.
- Zero critical axe violations.
- Design deltas either resolved or explicitly accepted by the reviewer.

**Fail criteria.**
- Any checklist item fails without justification → PR not ready for review.
- Critical axe violation → must fix before PR.
- Design delta present without acknowledgment → reviewer pushes back.

**Failure report path.** Author fixes before opening PR. If discovered during PR review, reviewer requests changes and links to the artifact.

---

## Layer 6 — Smoke tests (post-deploy)

**What it is.** A tiny, fast set of Playwright tests that runs against stg immediately after deploy, and against prod immediately after promotion. Proves the deploy didn't brick the service.

**What gets tested.**
- Home page loads, returns 200, renders the app shell.
- Auth endpoint responds.
- One read-only API call to the backend returns expected shape.
- One critical user flow (e.g., "load dashboard, see at least one test run").
- Health-check endpoint (`/health` or equivalent) returns 200.

Smoke tests are deliberately minimal — 5 to 8 assertions, under 90 seconds total. Not a replacement for E2E.

**Trigger.**
- stg: GitHub Actions deploy workflow runs smoke as its final step after `deploy-stg`. Failure rolls back automatically (Azir's ADR defines rollback mechanism).
- prod: same, after `deploy-prod`. Failure fires an alert and triggers rollback.

**Environment.** Runs against the real stg/prod URL. Uses a dedicated smoke-test service account with read-only permissions.

**Success criteria.**
- All smoke assertions pass.
- Total wall time under 90 seconds.
- Runs automatically — no human in the loop.

**Fail criteria.**
- Any smoke assertion fails → deploy marked failed → rollback triggered → alert fires.
- Smoke takes longer than 90 seconds → flagged for trimming (smoke must stay small).

**Artifacts.**
- Smoke run log uploaded to GH Actions artifacts, retained 90 days (longer than E2E — deploy forensics matter).
- Screenshot on failure only.
- On prod failure: incident auto-created (wiring to be defined; for now, a Slack ping to #strawberry-alerts).

**Failure report path.**
- stg: GH Actions failed check + PR comment if triggered from a merge.
- prod: Slack alert + rollback + incident record.

**Alert routing.** Evelynn-as-oncall for the personal system. Prod smoke failure = page immediately. Stg smoke failure = next-business-day review.

---

## Cross-cutting concerns

### Test data

- Unit: inline fixtures, no shared DB.
- E2E / QA / smoke: seeded test account with deterministic data. Seed script lives in `tests/fixtures/seed.ts` and runs as part of preview-env setup.
- Never use real user data. Never use production data in stg.

### Flakiness policy

- One retry allowed in E2E. Two retries = flaky = auto-issue.
- Smoke: zero retries. Smoke must be rock-solid; if it's flaky, it's wrong.
- Unit: zero retries. A flaky unit test is a bug.
- Quarantine lane: flagged-flaky tests move to `tests/quarantine/` and run in a non-blocking job until fixed or deleted within 7 days.

### Coverage

- Not a gate initially. Track the trend. If `src/lib/` drops below 70%, Caitlyn opens a task.
- E2E coverage tracked as "critical flows covered" (a handwritten list in `docs/qa/e2e-coverage.md`), not instruction coverage.

### Secrets in tests

- Test accounts use dedicated credentials stored in GH Actions secrets.
- Never decrypt strawberry's age-encrypted secrets in CI. If a test needs a secret, it uses a test-only value injected via GH Actions env.

### Artifact retention summary

| Layer | Retention | Location |
|---|---|---|
| Unit (JUnit + coverage) | 30 / 14 days | GH Actions artifacts |
| E2E (HTML + video + trace) | 30 days | GH Actions artifacts |
| QA pre-PR bundle | Lifetime of the PR + 90 days | GCS `strawberry-test-artifacts-<env>/` |
| Smoke logs | 90 days | GH Actions artifacts |
| Regression test files | Forever | Repo `tests/regression/` |

---

## Handoff to Vi

Implementation tasks, in order. Each is a separate PR.

1. **Unit-test scaffold** — framework install, pre-commit hook, one example test per source module, CI job.
2. **Regression directory + PR template** — `tests/regression/` created, PR template with regression checkbox, enforcement check.
3. **xfail enforcement check** — pre-merge script validating xfail flip discipline.
4. **E2E Playwright scaffold** — config, matrix, sharding, one golden-path spec per critical flow, GH Actions workflow on `pull_request`.
5. **QA pre-PR checklist + artifact bundler** — `docs/qa/pre-pr-checklist.md`, a small script that packages the artifacts directory, instructions for authors.
6. **Smoke-test scaffold** — 5-8 minimal assertions, GH Actions post-deploy job for stg and prod, rollback wiring coordinated with Azir's ADR.
7. **Flakiness quarantine lane** — `tests/quarantine/` + non-blocking job + auto-issue creation on 2+ retries.
8. **Coverage trend tracking** — coverage upload + dashboard (optional; can slip if time-pressed).

Each task starts with an xfail test (Layer 1 discipline applies to the QA infra itself).

---

## Open questions for Azir (architecture) — resolved

- Preview environment URL convention — **resolved**: per deployment-pipeline ADR.
- Rollback mechanism — **resolved**: `scripts/deploy/rollback.sh`, invoked when smoke fails post-deploy.
- Artifact storage — **resolved**: GCS bucket `strawberry-test-artifacts-<env>/` (per-env).
- Alert destination for prod smoke failure — **interim**: Evelynn-as-oncall; durable destination TBD via follow-up.

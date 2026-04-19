---
title: E2E CI performance — speed-up plan
status: proposed
owner: heimerdinger
created: 2026-04-19
tags: [ci, e2e, playwright, performance]
---

# E2E CI performance — speed-up plan

Audit of the two Playwright-running workflows in `harukainguyen1411/strawberry-app`
(`e2e.yml` and `myapps-test.yml`) and a ranked list of wins. Advisor output only —
execution to be handed to Ekko after approval.

## 1. Baseline

### 1.1 Real run used for timings

- Run: `24620828113` — PR "feat: V0.10 BaseCurrencyPicker onboarding modal"
  (https://github.com/harukainguyen1411/strawberry-app/actions/runs/24620828113)
- Workflow: `myapps-test.yml`, job `E2E tests (Playwright / Chromium)`
- Outcome: failure (tests failed, unrelated to perf — Firebase env vars were empty
  so almost every test hit the full retry storm; see §1.4).
- Every recent **passing** myapps-test run on `main` is a no-op skip (the
  diff filter `apps/(myapps|platform|shared|myApps|yourApps)` didn't match),
  so this is the only recent run where Playwright actually executed. Timings
  for setup/install/browser-install steps are trustworthy; test-runtime
  numbers are inflated by retries and should be treated as an upper bound.

### 1.2 Step-by-step wall-clock (E2E job)

| # | Step | Duration |
|---|------|----------|
| 1 | Set up job | 1s |
| 2 | Checkout (fetch-depth: 0) | 1s |
| 3 | Check if myapps changed (git diff) | <1s |
| 4 | Set up Node (20, cache: npm) | 2s |
| 5 | `npm ci` (workdir `apps/myapps`) | **14s** |
| 6 | Restore Playwright browsers cache | 3s |
| 7 | `npx playwright install chromium --with-deps` | **21s** (cache miss — see §2.1) |
| 8 | Run E2E tests (`test:e2e:ci`) | **7m 46s** |
| 9 | Upload Playwright report | 1s |
| — | **Total E2E job** | **~8m 30s** |

Within step 8, from Playwright log: webServer boot (`npm run build && vite preview`)
takes ~8s before `Running 30 tests using 1 worker` prints. The remaining ~7m 38s
is pure test execution, heavily inflated by `retries: 2` on an almost-fully-failing
suite. A clean green run of 30 tests with `workers: 1` and no retries, at ~10–15s
average per test (typical for Firebase-dependent flows), would run ~5–7 minutes —
still dominated by the sequential worker.

### 1.3 Slowest 3 steps (by seconds, E2E job)

1. Run E2E tests — **466s** (7m 46s)
2. Install Playwright browsers — **21s** (cache present but missing on this key)
3. `npm ci` — **14s**

Everything else combined is <10s.

### 1.4 `e2e.yml` separate baseline

- Skipped entirely on the autoprefixer/dependabot runs we inspected because
  TDD detection didn't trigger. When it does run, its steps mirror
  `myapps-test.yml` minus the Playwright cache and minus the per-app workdir
  (it iterates `dashboards/*`/`apps/*`). It would add a second ~8m E2E job
  every time a dashboard or non-myapps TDD package changed in the same PR
  that also changed myapps. Today Ekko's deduping via path-filter (recent
  PR `chore: scope e2e.yml out of apps/myapps`) already resolves the
  overlap — so optimization focus is `myapps-test.yml`.

### 1.5 Playwright config (`apps/myapps/playwright.config.ts`)

- `fullyParallel: true` — set, but overridden by `workers: 1` in CI
- `workers: process.env.CI ? 1 : undefined` — **serial execution on CI**
- `retries: process.env.CI ? 2 : 0` — 3x execution on every failure
- `webServer.command: 'npm run build && npx vite preview'` — full prod build every run
- `webServer.reuseExistingServer: !process.env.CI` — cannot reuse across shards as-is
- Single `chromium` project, no shard flag

## 2. Findings

### 2.1 Caching coverage

| Cache | Status | Notes |
|-------|--------|-------|
| `actions/setup-node` npm cache | ON (both workflows) | keyed on `apps/myapps/package-lock.json` in myapps-test.yml; `e2e.yml` uses the root lockfile. |
| Playwright browsers (`~/.cache/ms-playwright`) | ON in myapps-test.yml, **OFF in e2e.yml** | `actions/cache@v5` present in myapps-test but the key uses only `package-lock.json` hash — misses whenever a dep bumps, which is constant (dependabot). No fallback to bare `restore-keys` beyond the OS prefix. |
| Vite build cache (`node_modules/.vite`) | OFF | Not cached — Vite rebuilds fully every run. |
| Turbo remote cache | OFF | `turbo.json` exists at repo root but no `TURBO_TOKEN`/`TURBO_TEAM` wiring in workflows. |
| Dist / build output | OFF | `apps/myapps/dist` is rebuilt each run; no carry between jobs. |

### 2.2 Cold install pain

- `npm ci` for myapps-only install: **14s** with npm cache hit. Acceptable.
- `npx playwright install chromium --with-deps`: **21s** — apt-get for system
  deps + ~170 MB browser download. When the browser cache hits (same
  `package-lock.json` hash), this drops to ~2s. Today it misses on virtually
  every dependabot PR because the key churns.

### 2.3 Parallelism

- Playwright `workers: 1` on CI — the single biggest win. ubuntu-latest
  has 2 cores / 7 GB RAM, easily handles `workers: 2` for a Vue+Vite app.
- No `--shard=N/M` matrix. Suite is 30 tests in 7 files; sharding 2 ways
  halves wall-clock of the test step.

### 2.4 Build reuse

- webServer command is `npm run build && npx vite preview` — runs `vite build`
  inside Playwright's startup every run. No artifact hand-off from a prior
  "build" job. ~8s observed, not dominant but compounds if sharded naively.
- `reuseExistingServer: !process.env.CI` means shards would each rebuild
  unless we either (a) split into a build-once / test-shard-many pipeline
  or (b) accept the ~8s × N penalty.

### 2.5 Firebase emulator startup

- No emulator in the Playwright flow as configured. Tests talk to real
  Firebase via the `VITE_FIREBASE_*` secrets. On the failing baseline those
  secrets were empty, causing global failure. Not a perf axis — but it is
  a correctness/cost axis (real Firebase on every PR).

### 2.6 Trigger filters

- `myapps-test.yml`: `on: pull_request: branches: [main]`, **no paths filter
  by design** (so the required check always reports). The in-workflow diff
  gate works, but the runner is still allocated, checkout runs, and
  `actions/setup-node` initializes even on a no-op — ~10–20s of billable
  minutes per PR per required job, plus queue time.
- `e2e.yml`: same trigger shape, no `paths-ignore`. Docs-only and root-level
  non-code PRs still spin up runners.
- Neither workflow excludes drafts (`if: github.event.pull_request.draft == false`).
- Dependabot PRs run the full E2E — high noise, ~20 dependabot PRs visible
  in the last batch alone.

### 2.7 Container vs. host node runtime

- Host Node 20 via `actions/setup-node` every run. No use of the official
  `mcr.microsoft.com/playwright:v1.58.0-jammy` container (browsers and
  system deps preinstalled) which would eliminate the 21s Playwright
  install step cold and the ~2s warm.

## 3. Ranked wins

Each row: **[est. minutes saved per run]** · **[complexity]** · **[risk]**.
Savings assume a clean green run of the current suite; stacking is noted
where wins overlap.

| # | Win | Saved | Complexity | Risk |
|---|-----|-------|------------|------|
| 1 | Raise `workers` from 1 to 2 in `playwright.config.ts` on CI | ~3m 30s (cuts test step roughly in half) | trivial | low — Firebase tests can race on shared user docs; Vue render is CPU-light so 2 workers on 2 cores is safe. Needs a green run to confirm no test-level shared state. |
| 2 | Matrix-shard Playwright `--shard=1/2` and `--shard=2/2` across two runner jobs | ~3m additional on top of #1 (parallel wall-clock) | medium | low-medium — requires merging shard reports (`playwright-merge-reports`) or accepting 2 separate HTML artifacts; doubles billable minutes. Stacks with #1. |
| 3 | Fix Playwright browser cache key to include the Playwright version, not just the full lockfile hash | ~18s per dependabot PR (turns cache misses into hits) | trivial | low — use `key: playwright-${{ runner.os }}-${{ <playwright version from package-lock> }}` with a `restore-keys` fallback. |
| 4 | Drop `retries: 2` to `retries: 1` in CI | 0 on green runs, ~40% on flaky reds | trivial | medium — masks real flakes less. Worth pairing with a flake dashboard. Gating question for Duong. |
| 5 | `paths-ignore` for docs-only changes (`**.md`, `plans/**`, `.claude/**`) on both workflows | ~30s runner allocation per ignored PR, plus 0 queue time on busy days | trivial | low — required-status-check contract still holds if the workflow itself is not listed as required on those paths. Needs branch-protection review. |
| 6 | Skip dependabot PRs touching only non-myapps packages at the workflow trigger level (`if: github.actor == 'dependabot[bot]' && paths!=...`) or add a `concurrency` group so only the latest dependabot commit runs | ~8m per superseded dependabot run | low | low — `concurrency: group: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true` already-idiomatic. |
| 7 | Switch to `container: mcr.microsoft.com/playwright:v1.58.0-jammy` and drop `playwright install` step | ~21s cold, ~2s warm | low | low-medium — container pulls are cached on hosted runners but add their own ~10s pull on cold. Net positive on cold, neutral warm. Conflicts with #3 (no longer needed). |
| 8 | Split webServer: add a `build` step in the workflow producing `apps/myapps/dist`, then have Playwright config `webServer.command: 'npx vite preview'` (skip rebuild). Upload-artifact → shard jobs download | ~8s × (shards − 1) | medium | low — cleaner once sharding (#2) lands. Standalone value small. |
| 9 | Cache `node_modules/.vite` keyed on `vite.config.*` + lockfile | ~3–4s on webServer startup | low | low — small win on its own; worth pairing with #8. |
| 10 | Gate Playwright workflows on `github.event.pull_request.draft == false` | 8m per draft push | trivial | low — matches project convention of not running heavy checks on drafts. Gating question for Duong (some drafts want CI). |
| 11 | Turbo remote cache for unit/typecheck upstream of E2E | tangential — doesn't directly affect E2E step but cuts sibling `ci.yml` / `unit-tests.yml` duration | medium | low — needs a Vercel/Turbo account or self-hosted S3 backend. Out of scope of this plan; mention only. |

## 4. Top 3 to ship first

1. **Win #1 — bump `workers` to 2** in `apps/myapps/playwright.config.ts`.
   One-line change. Expected ~3m 30s savings on the dominant step. Validate
   with one run; if any test exposes a shared-state race, revert and
   address the test before retrying.
2. **Win #3 — fix the Playwright cache key**. Swap the key from
   `playwright-${{ runner.os }}-${{ hashFiles('apps/myapps/package-lock.json') }}`
   to `playwright-${{ runner.os }}-${{ hashFiles('apps/myapps/package-lock.json') }}`
   **parsed for `@playwright/test` version only**, or simpler: cache keyed on
   `jq -r '.packages["node_modules/@playwright/test"].version' apps/myapps/package-lock.json`.
   Restores the cache on every dependabot PR that doesn't bump Playwright
   itself. ~18s every PR, near-zero risk.
3. **Win #6 — add `concurrency` + `paths-ignore`** for docs on both
   workflows. Cheapest form of queue-cost control. Supersedes stale
   dependabot/feature-branch pushes and drops docs-only PRs from the
   pipeline entirely.

After these three land and we have a clean green baseline, re-measure and
then consider #2 (sharding) — which is the next biggest win but adds
meaningful complexity around report merging.

## 5. Gating questions for Duong

1. **`retries: 2 → 1`?** Acceptable to trade some flake-masking for a
   cleaner signal, or keep 2 until a flake dashboard exists? (Win #4)
2. **Shard reporting:** if we adopt `--shard=N/M` (Win #2), do you want a
   single merged HTML report (requires `playwright-merge-reports` job) or
   are N separate artifacts per PR fine?
3. **Draft PR policy:** skip E2E on drafts (Win #10), or keep it running
   so drafts can be reviewed with signal already green?
4. **`paths-ignore` and branch protection:** `myapps-test.yml` is a
   required check. If we add `paths-ignore: ['**.md', 'plans/**', '.claude/**']`,
   docs-only PRs will never fire the workflow, which means the required
   check never reports — and branch protection will block the merge.
   Two options: (a) keep the always-report in-workflow diff gate (current
   design) and don't add `paths-ignore`, or (b) split into a lightweight
   "always-green reporter" job + a heavy path-filtered real job. Your call.
5. **Playwright container image (Win #7):** willing to pin the Docker
   image version alongside the npm `@playwright/test` version? Drift
   between the two is the usual pain with the container approach.
6. **Firebase in E2E:** the failing baseline shows tests depending on
   real Firebase with empty secrets. Out of scope of this perf plan, but
   worth flagging: either fix the secrets wiring or switch E2E to the
   Firebase emulator suite. The emulator adds ~15–20s startup but
   removes the cost/correctness dependency on live Firebase on every PR.

## 6. Non-goals

- Rewriting tests for speed. Tests are not inspected here; savings in
  this plan come entirely from infra/config.
- Turbo remote cache setup (mentioned only as win #11 for completeness).
- Resolving the Ekko-handled `e2e.yml`/`myapps-test.yml` deduplication —
  that's already landed on `chore/e2e-scope-myapps`.

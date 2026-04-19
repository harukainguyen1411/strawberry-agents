---
status: proposed
owner: azir
created: 2026-04-19
slug: apps-restructure-darkstrawberry-layout
repo: harukainguyen1411/strawberry-app
related:
  - plans/approved/2026-04-17-deployment-pipeline.md
  - plans/approved/2026-04-17-branch-protection-enforcement.md
---

# ADR — `apps/` restructure to the darkstrawberry layout

## Context

Today `harukainguyen1411/strawberry-app` has grown an inconsistent `apps/` tree:
`myapps` is a single Vite app that pretends to be four apps via client routing;
`yourApps/bee` and `private-apps/bee-worker` use different casing conventions;
`dashboards/` lives at the repo root instead of under `apps/`; and there is no
agreed separation between public (`myApps`), private (`yourApps`), worker,
discord, dashboard, and contributor code. The existing `apps/myapps/firebase.json`
owns all hosting surfaces through a single site, which makes per-app preview,
per-app deploy, and per-app path-filter CI impossible.

The target shape locks this down:

```
apps/
  darkstrawberry-apps/        → serves app.darkstrawberry.com
    myApps/                   (public apps) — e.g. read-tracker
    yourApps/                 (private apps) — e.g. bee, portfolio-tracker
  workers/
    bee-worker/
    coder-worker/
  discord/                    (all discord-related services)
  dashboards/                 (all dashboard-related, e.g. usage-dashboard)
  contributor/
```

This ADR captures the inventory, the collision surface, a phased migration,
and the removal gates. Implementation is out of scope — this plan only decides
shape, order, and gates.

---

## 1. Current inventory (as of 2026-04-19)

Pulled via `gh api repos/harukainguyen1411/strawberry-app/contents/...`.

### 1a. Everything under `apps/`

| Path                              | `package.json` name             | What it is                                                                                                           |
| --------------------------------- | ------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `apps/myapps/`                    | `myapp`                         | Vite + Vue app. Single SPA that currently serves all four hosting surfaces via client-side router. Owns `functions/`, `firestore.rules`, `storage.rules`, `firebase.json`, `e2e/`. |
| `apps/myapps/portfolio-tracker/`  | `@ds/portfolio-tracker`         | Sibling workspace already scaffolded (vite.config, index.html). Parallel to embedded `src/views/PortfolioTracker/`.  |
| `apps/myapps/read-tracker/`       | `@ds/read-tracker`              | Sibling workspace scaffold. Parallel to embedded `src/views/ReadTracker/`.                                           |
| `apps/myapps/task-list/`          | `@ds/task-list`                 | Sibling workspace scaffold. Parallel to embedded `src/views/TaskList/`.                                              |
| `apps/myapps/src/views/bee/`      | (embedded, no package.json)     | Bee intake UI views — **not** yet promoted to a top-level workspace. Promotion candidate.                            |
| `apps/myapps/src/views/PortfolioTracker/` | (embedded)              | Legacy embedded portfolio views. To be retired once `@ds/portfolio-tracker` owns the surface.                        |
| `apps/myapps/src/views/ReadTracker/`      | (embedded)              | Legacy embedded read-tracker views. Retire after promotion.                                                          |
| `apps/myapps/src/views/TaskList/`         | (embedded)              | Legacy embedded task-list views. Removal candidate (see §4).                                                         |
| `apps/yourApps/bee/`              | `@ds/bee`                       | Bee as its own Vite app (index.html, vite.config, src/). Not yet wired into hosting.                                 |
| `apps/private-apps/bee-worker/`   | `@strawberry/bee-worker`        | Bee GitHub-issue poller that runs Claude Code headlessly for OOXML comment injection. Windows worker.                |
| `apps/coder-worker/`              | `@strawberry/coder-worker`      | Windows coder worker — polls GitHub issues and invokes Claude Code headlessly.                                       |
| `apps/contributor-bot/`           | `contributor-bot`               | Discord bot for the contributor pipeline.                                                                            |
| `apps/discord-relay/`             | `@strawberry/discord-relay`     | Discord triage bot — routes messages to GitHub issues via Gemini 2.0 Flash.                                          |
| `apps/deploy-webhook/`            | `@strawberry/deploy-webhook`    | GitHub push webhook receiver (HMAC-SHA256 verify) that triggers the Windows auto-deploy path.                        |
| `apps/landing/`                   | (no package.json — static)      | Static landing site (`index.html`, `favicon.*`, its own `firebase.json` targeting site `darkstrawberry-landing`).    |
| `apps/platform/`                  | (no package.json; has `src/`)   | Shared platform module consumed by myapps. Not a deployable surface.                                                 |
| `apps/shared/`                    | (no package.json; `firebase/`, `types/`, `ui/`) | Shared lib code consumed by myapps. Not a deployable surface.                                         |

### 1b. Anything outside `apps/` that belongs in the new layout

| Path                                 | `package.json` name                 | What it is                                                                                |
| ------------------------------------ | ----------------------------------- | ----------------------------------------------------------------------------------------- |
| `dashboards/usage-dashboard/`        | `usage-dashboard`                   | Usage dashboard — moves into `apps/dashboards/usage-dashboard/`.                          |
| `dashboards/server/`                 | `@strawberry/dashboards-server`     | Dashboard server. Moves into `apps/dashboards/server/` (or merge with `usage-dashboard`, see §7). |
| `dashboards/test-dashboard/`         | `@strawberry/test-dashboard`        | Test dashboard. Moves into `apps/dashboards/test-dashboard/`.                             |
| `dashboards/dashboard/`              | (no package.json)                   | Unclear — audit before move (see §7).                                                     |
| `dashboards/shared/`                 | (no package.json)                   | Shared dashboard lib. Moves with rest of `dashboards/`.                                   |
| `packages/vitest-reporter-tests-dashboard/` | (reporter)                   | Stays under `packages/` — not an app.                                                     |

### 1c. Firebase hosting surfaces — current owner

| Surface                          | Owner today                                     | Target owner                                                       |
| -------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------ |
| `darkstrawberry-landing` (landing) | `apps/landing/firebase.json`                  | `apps/landing/firebase.json` (unchanged — landing stays at root of `apps/`). |
| `app.darkstrawberry.com`         | `apps/myapps/firebase.json` — single-site SPA  | `apps/darkstrawberry-apps/firebase.json` — multi-site targets, one per app. |
| Firestore rules + Functions      | `apps/myapps/firestore.rules`, `apps/myapps/functions/` | Moves with the `darkstrawberry-apps` umbrella.              |

### 1d. Promotion candidates — `apps/myapps/src/views/*` going top-level

Per user direction, these three are the named promotions:

| Embedded view                        | Promote to                                                         | Classification  |
| ------------------------------------ | ------------------------------------------------------------------ | --------------- |
| `apps/myapps/src/views/ReadTracker/`        | `apps/darkstrawberry-apps/myApps/read-tracker/`             | `myApps` (public)  |
| `apps/myapps/src/views/bee/`                | `apps/darkstrawberry-apps/yourApps/bee/`                    | `yourApps` (private) |
| `apps/myapps/src/views/PortfolioTracker/`   | `apps/darkstrawberry-apps/yourApps/portfolio-tracker/`      | `yourApps` (private) |

`TaskList` is called out in §4 as a removal candidate — **user must confirm**
before any delete.

---

## 2. Gap / collision analysis

### 2a. In-flight portfolio PR stack (#29, #32, #33, #34, #36, #40, #41, #42, #43, #44, #45)

Open PRs on `feature/portfolio-v0-V0.*` branches, all touching
`apps/myapps/src/views/PortfolioTracker/` **and** `apps/myapps/portfolio-tracker/`
(the scaffold workspace). They stack on each other (base of one is head of the
previous).

**Options considered:**

1. **Restructure first, rebase the stack onto the new layout.**
   Pros: the stack lands in its final home; no second migration.
   Cons: 10+ PRs, all currently stacked, must be re-targeted simultaneously.
   Breaks the "never rebase" invariant (Rule 11) — we would have to close and
   reopen each PR with new branches cut from post-restructure `main`.
   Reviewer cost is high; portfolio authors lose days of in-flight context.

2. **Land the full stack first, then restructure.**
   Pros: no rebase; stack merges cleanly to its existing `apps/myapps/` home.
   Cons: every future portfolio PR in V0.12+ keeps landing in the old location
   until the stack drains. Delays the restructure by the stack's cycle time.

3. **Restructure on a long-lived branch, merge after the stack lands.**
   Pros: restructure work can proceed in parallel on its own worktree.
   Cons: merge conflicts grow linearly with every portfolio PR merged into
   `main`. Also violates the invariant that plans leave the repo buildable at
   every commit if the branch diverges too far.

**Recommendation: Option 2 — land the stack first, then restructure.**

Justification: the stack is a contiguous feature increment (V0.1 through V0.11)
that was designed against the current layout. Rule 11 (no rebase) makes
Option 1 the most expensive. Option 3 invites mid-flight merge conflicts that
would be paid for on every portfolio PR merge. The restructure itself is
mechanical once the in-flight work is out of the way.

Phase 1 (§3) therefore begins only after PR #45 (V0.11 CSV Import Step 1) has
merged and the `feature/portfolio-v0-*` branch chain is empty.

### 2b. `apps/myapps/firebase.json` — single hosting surface owns four apps

Current state: one Vite app, one `dist/`, one hosting config, one rewrite rule
`** → /index.html`. Per-app previews and per-app prod deploys are impossible
without a split.

Plan:

- Introduce `apps/darkstrawberry-apps/firebase.json` with **hosting targets**
  (Firebase multi-site). One target per app:
  - `target: read-tracker` → site `dark-read-tracker`
  - `target: bee` → site `dark-bee`
  - `target: portfolio-tracker` → site `dark-portfolio-tracker`
  - (task-list target only if user confirms it survives §4)
- Each promoted app owns its own `public` (its own `dist/`) and rewrites.
- `.firebaserc` grows a `targets` block mapping each target to its hosted sites.
- Functions codebase stays singular (`darkstrawberry-functions`) but source
  moves to `apps/darkstrawberry-apps/functions/`.
- `firestore.rules`, `storage.rules`, `firestore.indexes.json` move to
  `apps/darkstrawberry-apps/` (they are per-project, not per-app).
- **Gating question §7** — does `app.darkstrawberry.com` become a reverse-proxy
  landing or does each app get its own subdomain (`read.darkstrawberry.com`,
  `bee.darkstrawberry.com`, `portfolio.darkstrawberry.com`)? This changes the
  Firebase Hosting site names and DNS plan.

### 2c. CI workflows referencing `apps/myapps/**`

Every workflow in the table below path-filters or `working-directory`-pins to
`apps/myapps` and siblings. All need update in lockstep with the move:

| Workflow                         | References                                                                                                   | Required edit                                                                       |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| `ci.yml`                         | `working-directory: apps/myapps` (×2); upload-artifact path `apps/myapps/playwright-report/`, `apps/myApps/*/playwright-report/`, `apps/yourApps/*/playwright-report/` | Repoint to `apps/darkstrawberry-apps/**` and the new myApps/yourApps child paths. |
| `e2e.yml`                        | Detects `apps/myapps/` scope via `grep -qE '^apps/myapps/'`; iterates `dashboards/* apps/*`                  | Update scope detection to `^apps/darkstrawberry-apps/` and add `apps/dashboards/*`. |
| `myapps-pr-preview.yml`          | `grep -qE '^apps/(myapps\|platform\|shared\|myApps\|yourApps)/'`; `working-directory: apps/myapps`; `entryPoint: apps/myapps` | Split into per-app preview workflows under `apps/darkstrawberry-apps/**`, or rename workflow and repoint scope. |
| `myapps-prod-deploy.yml`         | `paths: apps/myapps/**`, `apps/platform/**`, `apps/shared/**`, `apps/myApps/**`, `apps/yourApps/**`; `working-directory: apps/myapps` | Repoint paths to `apps/darkstrawberry-apps/**`. Decide: one deploy job or one per hosting target (see §3 Phase 4). |
| `myapps-test.yml`                | Same grep scope as pr-preview; `cache-dependency-path: apps/myapps/package-lock.json`; artifact path          | Repoint. If per-app lockfiles emerge, matrix over them.                              |
| `preview.yml`                    | `Build myapps`; `cp apps/myapps/firebase.json firebase.json`; `cp apps/myapps/.firebaserc .firebaserc`       | Update copy sources to `apps/darkstrawberry-apps/firebase.json` + `.firebaserc`.    |
| `landing-prod-deploy.yml`        | `paths: apps/landing/**`; `working-directory: apps/landing`                                                  | **No change** — landing stays where it is.                                          |
| `release.yml`                    | `cp apps/myapps/firebase.json firebase.json`; functions path check `apps/myapps/functions/`; rules check `apps/myapps/firestore.rules`/`storage.rules`; `working-directory: apps/myapps` (×2) | Repoint all paths to `apps/darkstrawberry-apps/`. release-please config must also be updated (see §2d). |
| `validate-scope.yml`             | `apps/myapps/` scope grep                                                                                    | Repoint to `apps/darkstrawberry-apps/`.                                             |
| `pr-lint.yml`                    | `apps/*/src/*\|dashboards/*/src/*`                                                                           | Update to `apps/darkstrawberry-apps/*/*/src/*\|apps/dashboards/*/src/*`.           |
| `unit-tests.yml`, `tdd-gate.yml`, `lint-slugs.yml`, `auto-label-ready.yml` | no hard path refs found                                                      | Re-scan as part of Phase 5 cleanup.                                                 |

### 2d. Monorepo config — root `package.json`, `turbo.json`, `tsconfig.base.json`, release-please

- **Root `package.json` `workspaces`** currently:
  `['apps/portal', 'apps/myapps', 'apps/landing', 'apps/shared', 'apps/myapps/*', 'apps/yourApps/*', 'apps/myapps/functions', 'dashboards/*', 'packages/*']`.
  - Stale: `apps/portal` — does not exist in `apps/` listing. Remove in Phase 0.
  - Target:
    ```
    workspaces: [
      'apps/darkstrawberry-apps',
      'apps/darkstrawberry-apps/myApps/*',
      'apps/darkstrawberry-apps/yourApps/*',
      'apps/darkstrawberry-apps/functions',
      'apps/landing',
      'apps/workers/*',
      'apps/discord/*',
      'apps/dashboards/*',
      'apps/contributor/*',
      'apps/shared',
      'apps/platform',
      'packages/*'
    ]
    ```
- **`turbo.json`** — task graph today does not pin package names, so the globs
  above pick up the new workspaces for free. No edits needed unless per-app
  caching hints get added.
- **`tsconfig.base.json`** — **does not exist** at repo root today (confirmed
  via `gh api` 404). If path aliases are added during the restructure they
  should live in a new `tsconfig.base.json`; otherwise this subtask is a no-op.
  Called out in §7 so we do not silently grow a new file.
- **release-please** — `release-please-config.json` and
  `.release-please-manifest.json` exist at repo root. They pin package
  directories; every moved package needs a config + manifest rewrite in the
  same PR as its move (otherwise release-please stops bumping that package).
- **`ecosystem.config.js`** — PM2 config at repo root. If it references any
  moved worker (bee-worker, coder-worker, deploy-webhook), update in the same
  PR as the worker move.
- **`.firebaserc` at repo root** — currently default only. Add a `targets`
  block in Phase 4 when hosting multi-site lands.

---

## 3. Migration plan — phased

Each phase is atomic: one PR, repo builds and deploys green at HEAD of the
phase. No phase depends on a phase landing silently in the background — every
phase is gated by the previous phase's PR merging to `main`.

### Phase 0 — Prerequisites (blocking)

- Portfolio stack #29–#45 fully merged to `main`.
- Root `package.json` `workspaces` drops stale `apps/portal` entry.
- Duong has answered the gating questions in §7.
- No outstanding `feature/portfolio-v0-*` branches.

**Rollback surface:** none — this phase modifies no code paths, just clears
the runway.

### Phase 1 — Create `apps/darkstrawberry-apps/` shell + move myapps wholesale

Mechanical rename, no content changes:

- `git mv apps/myapps apps/darkstrawberry-apps` (preserving history).
- `apps/myapps/portfolio-tracker/` → `apps/darkstrawberry-apps/portfolio-tracker/`
  (still at the pre-split sibling location — promotion happens in Phase 3).
- Update root `package.json` workspaces glob.
- Update `.firebaserc` if needed (likely unchanged at this phase).
- Update every CI workflow in §2c.
- Update `release-please-config.json` package paths.

**Rollback surface:** single revert of this PR restores `apps/myapps/` intact
because it is a pure rename.

**Build/deploy contract after Phase 1:** `app.darkstrawberry.com` still serves
from the single-site `firebase.json`, but sourced from
`apps/darkstrawberry-apps/firebase.json` and `apps/darkstrawberry-apps/dist/`.

### Phase 2 — Move non-app services (workers, discord, dashboards, contributor)

Still pure moves, no behavior change:

- `apps/coder-worker/` → `apps/workers/coder-worker/`
- `apps/private-apps/bee-worker/` → `apps/workers/bee-worker/`
- `apps/deploy-webhook/` → `apps/workers/deploy-webhook/` (see §7 — is
  deploy-webhook a "worker"? It is a webhook receiver, not a poller. Gating
  question.)
- `apps/discord-relay/` → `apps/discord/discord-relay/`
- `apps/contributor-bot/` → `apps/contributor/contributor-bot/`
- `dashboards/*` → `apps/dashboards/*` (entire subtree).

Workflow updates:

- `pr-lint.yml` UI glob now includes `apps/dashboards/*/src/*`.
- `e2e.yml` iteration list changes from `dashboards/* apps/*` to `apps/*` (and
  a deeper walk for the `darkstrawberry-apps/myApps/*` and `yourApps/*`
  children — gated by Phase 3).
- `ecosystem.config.js` pm2 app paths for any moved worker.
- `release-please-config.json` for every moved package.
- Root `package.json` workspaces glob.

**Rollback surface:** revert the PR; packages land back at old paths. No
deployments reshape in this phase — workers are long-running services, not
hosted.

### Phase 3 — Promote `src/views/*` to top-level apps inside `darkstrawberry-apps/`

This is the first phase that changes deployable surfaces.

- `apps/darkstrawberry-apps/src/views/ReadTracker/` →
  `apps/darkstrawberry-apps/myApps/read-tracker/` (merge with existing scaffold
  at `apps/darkstrawberry-apps/read-tracker/`, which itself moves under
  `myApps/` in this phase).
- `apps/darkstrawberry-apps/src/views/bee/` + `apps/yourApps/bee/` →
  `apps/darkstrawberry-apps/yourApps/bee/` (merge the two; the top-level
  `apps/yourApps/bee/` is the more complete scaffold, the views become its
  source).
- `apps/darkstrawberry-apps/src/views/PortfolioTracker/` +
  `apps/darkstrawberry-apps/portfolio-tracker/` →
  `apps/darkstrawberry-apps/yourApps/portfolio-tracker/`.
- `apps/darkstrawberry-apps/src/views/TaskList/` — **gated by §4
  confirmation.** If Duong says "keep," move to
  `apps/darkstrawberry-apps/myApps/task-list/` (or `yourApps/`, see §7).
  If Duong says "remove," delete in Phase 4.
- Legacy `apps/darkstrawberry-apps/src/` SPA shell retires once all views are
  promoted.

**Rollback surface:** each promotion is a git-mv plus a references fix-up;
revert restores the embedded view. Because this phase deletes the combined
SPA's `src/App.vue` router, a revert needs the same PR revert, not partial
cherry-pick.

**Build/deploy contract after Phase 3:** `app.darkstrawberry.com` still points
at the composite SPA at HEAD — so this phase must land **with** Phase 4's
hosting-target split, or produce a temporary composite build that still routes
to all four apps. **Preferred:** land Phase 3 and Phase 4 as the same PR to
keep the repo deployable. If that PR is too large, land Phase 3 behind a
feature flag that keeps the SPA build path alive until Phase 4 lands.

### Phase 4 — Firebase multi-site split

- Rewrite `apps/darkstrawberry-apps/firebase.json` to a `hosting: []` array
  with one target per app.
- Add `.firebaserc` `targets` block.
- Update `myapps-prod-deploy.yml` and `myapps-pr-preview.yml` to deploy all
  targets (matrix) or matrix per target.
- DNS records for any new subdomains (gated by §7 decision).
- `preview.yml` copy step (`cp apps/myapps/firebase.json firebase.json`) must
  handle multi-site — likely becomes a no-op because the root `firebase.json`
  can reference the child via `projects` / `targets`.

**Rollback surface:** revert the PR; single-site hosting returns. Firebase
Hosting retains prior deploys per site, so a revert plus a redeploy restores
the previous SPA.

**Build/deploy contract after Phase 4:** each promoted app has its own
preview URL and its own prod site. `app.darkstrawberry.com` either becomes a
landing/redirector or dies (gating §7).

### Phase 5 — Cleanup and renames

- Delete `apps/private-apps/` shell (now empty).
- Delete `apps/yourApps/` shell at the old top-level (now empty — real
  `yourApps` lives under `darkstrawberry-apps/`).
- Rename any stragglers still using `myapps` (lowercase) inside workflows,
  scripts, comments, README.
- Update `docs/` references.
- Sweep for dead workflow files after the split.

**Rollback surface:** these are deletions of empty directories and comment/
README fixups. A revert is cheap.

---

## 4. Removal list — gated on Duong confirmation

Each item requires an explicit "yes, delete" from Duong in thread or in the
plan's promotion PR **before** any deletion lands. No speculative deletes.

| # | Path                                                        | Reason to propose removal                                                                                                                             | Confirmation gate |
| - | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| 1 | `apps/myapps/src/views/TaskList/`                           | Target layout does not name `task-list` as a surviving app; the sibling scaffold `apps/myapps/task-list/` also has no stated home.                    | **Duong explicit yes**. If yes → delete in Phase 5. If no → promote to `darkstrawberry-apps/myApps/task-list/` (Phase 3). |
| 2 | `apps/myapps/task-list/` (sibling workspace)                | Same reason as #1.                                                                                                                                    | Same as #1.       |
| 3 | `apps/platform/`                                            | Target layout has no `platform/` slot; likely a shared lib that should fold into `apps/shared/` or `packages/`.                                       | **Duong explicit yes** to fold-into-shared vs delete vs keep at root. |
| 4 | `apps/shared/` (top-level, if fully absorbed into `packages/`) | Target layout has no `apps/shared/`. But shared libs are consumed widely; may just move to `packages/shared/` instead of being deleted.             | **Duong explicit yes** on destination. Default: **keep** (low risk) unless Duong says move. |
| 5 | `dashboards/dashboard/` (unclear, no `package.json`)        | Unknown purpose; may be obsolete scratch code.                                                                                                        | **Duong explicit yes** after a content audit of the subtree. |
| 6 | `dashboards/shared/` (no `package.json`)                    | Same as #5 — audit first.                                                                                                                             | **Duong explicit yes** (likely keep and move with dashboards/). |
| 7 | Empty shell `apps/private-apps/`                            | Empty after Phase 2 move.                                                                                                                             | Delete in Phase 5 — no per-item gate beyond "phase 5 merges."                                          |
| 8 | Empty shell `apps/yourApps/`                                | Empty after Phase 3 move.                                                                                                                             | Delete in Phase 5 — no per-item gate beyond "phase 5 merges."                                          |
| 9 | Legacy `apps/darkstrawberry-apps/src/views/*` after promotions | Superseded by promoted apps.                                                                                                                        | Delete in Phase 3 as part of the promotion PR.        |

Removals 1–6 block their respective phases until answered. Removals 7–9 are
mechanical fallout of earlier phases.

---

## 5. Name conventions — `myApps` / `yourApps` (camelCase) vs kebab-case rest

Duong's explicit direction is `myApps/` and `yourApps/` (camelCase) as the
two public/private buckets, while the rest of the tree is kebab-case
(`read-tracker`, `portfolio-tracker`, `bee-worker`, `coder-worker`,
`discord-relay`, `contributor-bot`, `usage-dashboard`, `darkstrawberry-apps`).

This is inconsistent in isolation, but the camelCase is load-bearing as a
visual marker for the two buckets — kebab-case for every leaf app, camelCase
for the two groupers. Locking this convention:

- `apps/darkstrawberry-apps/myApps/<kebab-case-app>/`
- `apps/darkstrawberry-apps/yourApps/<kebab-case-app>/`
- every other path is kebab-case.

Enforcement: add a line to `.github/workflows/lint-slugs.yml` (if it lints
paths) or `validate-scope.yml` that rejects new directories under
`apps/darkstrawberry-apps/` that are neither `myApps/` nor `yourApps/` nor
`functions/`. Deferred to Phase 5 as a guardrail.

Old casing collisions found in `myapps-pr-preview.yml` (`myApps` vs `myapps`
in the same grep) are silently broken today; Phase 1 workflow updates will
normalize.

---

## 6. Testing strategy

Per-phase verification gate. Each phase's PR must pass all checks below
before merge.

### Phase 0
- `pnpm install` (or `npm install`) at root resolves with updated workspaces glob.
- `turbo run build` green.
- No change to CI matrix; all existing checks pass.

### Phase 1 (myapps → darkstrawberry-apps rename)
- `turbo run build` green at new path.
- `myapps-test.yml` E2E still green (renamed workflow or same workflow hitting new path).
- `myapps-pr-preview.yml` successfully deploys preview from the new `working-directory`.
- Manual: visit preview URL; all four app routes load (composite SPA still intact).
- release-please dry-run produces no spurious version bumps.

### Phase 2 (workers, discord, dashboards, contributor moves)
- `turbo run build` green for every moved package.
- `ecosystem.config.js` pm2 start dry-run on a scratch host.
- Each worker's unit test suite green in CI.
- No dashboard preview regression (dashboards-server still serves).

### Phase 3 (promote views → top-level apps)
- Every promoted app (`read-tracker`, `bee`, `portfolio-tracker`) builds on
  its own via `turbo run build --filter=@ds/<name>`.
- Playwright E2E for each promoted app (one spec file each, smoke-level) —
  can reuse the existing `apps/darkstrawberry-apps/e2e/` specs until split.
- Composite SPA's integration tests still pass if the composite build path
  is kept alive until Phase 4 lands.
- Spot check: Firestore Security Rules emulator smoke (from the portfolio V0.3
  harness) still passes after the functions/rules path move.

### Phase 4 (firebase multi-site split)
- Preview deploy produces one preview channel per target; all preview URLs
  resolve and serve the correct app.
- Prod deploy dry-run (`firebase deploy --only hosting --dry-run`) lists every
  expected target.
- Post-deploy smoke: Rule 17's smoke-test harness runs against each new prod
  host and asserts a 200 on `/` and `/healthz` (or equivalent).
- DNS TTL verification on any new subdomain (gated by §7).

### Phase 5 (cleanup)
- `git status` clean; no orphaned workflow files.
- `validate-scope.yml` passes — no stray references to old paths anywhere in
  the tree.
- `grep -R "apps/myapps" .` returns nothing outside historical plan files.

### Cross-phase invariants
- Rule 14: pre-commit runs unit tests for changed packages — never bypassed.
- Rule 15: PR cannot merge red.
- Rule 17: post-deploy smoke runs on stg and prod. For Phase 4 this is the
  primary safety net against multi-site misconfiguration.
- Rule 18: no `--admin` merges, no PR-author self-merge.

---

## 7. Gating questions for Duong

Do not start Phase 0 until these are answered.

1. **Subdomain strategy for `app.darkstrawberry.com`.** Does each promoted
   app get its own subdomain (e.g. `read.darkstrawberry.com`,
   `bee.darkstrawberry.com`, `portfolio.darkstrawberry.com`), or does
   `app.darkstrawberry.com` remain a single host that routes client-side?
   The answer drives the Phase 4 Firebase Hosting target names and DNS work.

2. **Does `task-list` survive?** If yes, does it belong in `myApps/` (public)
   or `yourApps/` (private)? (Removal list §4 item #1.)

3. **`apps/platform/` disposition.** Fold into `apps/shared/`, move to
   `packages/platform/`, or keep at `apps/platform/` as a non-deployable
   shared module? (Removal list §4 item #3.)

4. **`apps/shared/` disposition.** Same three options. Default is "keep at
   `apps/shared/`" since it is not a deployable surface.

5. **Is `deploy-webhook` a worker?** It is a webhook receiver rather than a
   poller. Options: `apps/workers/deploy-webhook/`, `apps/discord/deploy-webhook/`
   (if discord-adjacent), or a new `apps/webhooks/` slot. The target layout
   does not name it.

6. **`dashboards/dashboard/` and `dashboards/shared/` content audit.** Do
   these contain anything current, or are they scratch that can be removed?
   (Removal list §4 items #5, #6.)

7. **Should `tsconfig.base.json` exist?** It is referenced in the task
   description but does not exist at repo root today. If TS path aliases are
   desired as part of the restructure, this is where they'd live — but that
   is a separate design decision, not mechanical to this plan.

8. **Commit/PR granularity.** Each phase = one PR is the default. Is that OK,
   or does Duong want Phase 3 + Phase 4 merged as a single PR (preferred by
   this plan for deploy-integrity reasons) or split further?

9. **Preserve git history via `git mv`?** All moves in this plan assume
   `git mv` to preserve blame. Confirm.

10. **Release-please cutover.** Changing a package's directory resets
    release-please's per-package version memory unless the manifest is
    rewritten with the old version pinned at the new path. Confirm the
    rewrite strategy is acceptable (or we deliberately reset versions to 0.x
    for reshuffled packages).

---

## Handoff

Once Duong has approved this ADR:

- Promote via `scripts/plan-promote.sh` to `plans/approved/`.
- Kayn or Aphelios breaks the phases into concrete task lists under
  `plans/in-progress/` — one task list per phase PR.
- Azir is available for follow-up on any cross-phase architecture questions
  (multi-site hosting, DNS, workspace graph).

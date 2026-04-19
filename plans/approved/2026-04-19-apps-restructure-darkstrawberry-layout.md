---
status: approved
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
  darkstrawberry-apps/        → serves app.darkstrawberry.com (single host,
                                client-side routed — per Duong 2026-04-19 Q1)
    myApps/                   (public apps) — e.g. read-tracker
    yourApps/                 (private apps) — e.g. bee, portfolio-tracker
  workers/
    bee-worker/
    coder-worker/
  webhooks/
    deploy-webhook/
  discord/                    (all discord-related services)
  dashboards/                 (all dashboard-related, e.g. usage-dashboard)
  contributor/
  shared/                     (kept as-is, not folded — per Duong 2026-04-19 Q4)
  platform/                   (darkstrawberry launcher shell — see §1e)
```

This ADR captures the inventory, the collision surface, a phased migration,
and the removal gates. Implementation is out of scope — this plan only decides
shape, order, and gates.

> **Decisions recorded 2026-04-19 (Duong):** Single-host client-routed
> `app.darkstrawberry.com` (Q1); `task-list` removed (Q2); `apps/shared/` stays
> as-is (Q4); `deploy-webhook` gets a new `apps/webhooks/` slot (Q5); dashboards
> move under `apps/dashboards/` (Q6); Phase 3 + Phase 4 land as one PR (Q8);
> `git mv` used throughout to preserve blame (Q9). Q3 (platform), Q7 (tsconfig),
> Q10 (release-please) resolved below by audit / architect call — see §7.

---

## 1. Current inventory (as of 2026-04-19)

Pulled via `gh api repos/harukainguyen1411/strawberry-app/contents/...` and
`gh api repos/.../git/trees/main?recursive=1`.

### 1a. Everything under `apps/`

| Path                              | `package.json` name             | What it is                                                                                                           |
| --------------------------------- | ------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `apps/myapps/`                    | `myapp`                         | Vite + Vue app. Single SPA that currently serves all four hosting surfaces via client-side router. Owns `functions/`, `firestore.rules`, `storage.rules`, `firebase.json`, `e2e/`. |
| `apps/myapps/portfolio-tracker/`  | `@ds/portfolio-tracker`         | Sibling workspace already scaffolded (vite.config, index.html). Parallel to embedded `src/views/PortfolioTracker/`.  |
| `apps/myapps/read-tracker/`       | `@ds/read-tracker`              | Sibling workspace scaffold. Parallel to embedded `src/views/ReadTracker/`.                                           |
| `apps/myapps/task-list/`          | `@ds/task-list`                 | Sibling workspace scaffold. **Removal target — Duong Q2.**                                                           |
| `apps/myapps/src/views/bee/`      | (embedded, no package.json)     | Bee intake UI views — **not** yet promoted to a top-level workspace. Promotion candidate.                            |
| `apps/myapps/src/views/PortfolioTracker/` | (embedded)              | Legacy embedded portfolio views. To be retired once `@ds/portfolio-tracker` owns the surface.                        |
| `apps/myapps/src/views/ReadTracker/`      | (embedded)              | Legacy embedded read-tracker views. Retire after promotion.                                                          |
| `apps/myapps/src/views/TaskList/`         | (embedded)              | **Removal target — Duong Q2.**                                                                                       |
| `apps/yourApps/bee/`              | `@ds/bee`                       | Bee as its own Vite app (index.html, vite.config, src/). Not yet wired into hosting.                                 |
| `apps/private-apps/bee-worker/`   | `@strawberry/bee-worker`        | Bee GitHub-issue poller that runs Claude Code headlessly for OOXML comment injection. Windows worker.                |
| `apps/coder-worker/`              | `@strawberry/coder-worker`      | Windows coder worker — polls GitHub issues and invokes Claude Code headlessly.                                       |
| `apps/contributor-bot/`           | `contributor-bot`               | Discord bot for the contributor pipeline.                                                                            |
| `apps/discord-relay/`             | `@strawberry/discord-relay`     | Discord triage bot — routes messages to GitHub issues via Gemini 2.0 Flash.                                          |
| `apps/deploy-webhook/`            | `@strawberry/deploy-webhook`    | GitHub push webhook receiver (HMAC-SHA256 verify) that triggers the Windows auto-deploy path. → `apps/webhooks/` (Q5). |
| `apps/landing/`                   | (no package.json — static)      | Static landing site (`index.html`, `favicon.*`, its own `firebase.json` targeting site `darkstrawberry-landing`).    |
| `apps/platform/`                  | **(no package.json — but live code, see §1e)** | **Darkstrawberry launcher shell.** Full Vue app shell (main.ts, App.vue, router, registry, core/appLoader, views, components). Not yet wired to hosting but not scratch. **Keep at `apps/platform/`** (Q3 resolution). |
| `apps/shared/`                    | (no package.json; `firebase/`, `types/`, `ui/`) | Shared lib code consumed by myapps via `@shared` Vite alias. **Kept as-is** (Q4). |

### 1b. Anything outside `apps/` that belongs in the new layout

| Path                                 | `package.json` name                 | What it is                                                                                |
| ------------------------------------ | ----------------------------------- | ----------------------------------------------------------------------------------------- |
| `dashboards/usage-dashboard/`        | `usage-dashboard`                   | Usage dashboard — moves into `apps/dashboards/usage-dashboard/`.                          |
| `dashboards/server/`                 | `@strawberry/dashboards-server`     | Dashboard server. Moves into `apps/dashboards/server/`.                                   |
| `dashboards/test-dashboard/`         | `@strawberry/test-dashboard`        | Test dashboard. Moves into `apps/dashboards/test-dashboard/`.                             |
| `dashboards/dashboard/`              | **Only `.gitkeep` — empty placeholder** | **Remove** (Q6 audit: no content, no dependents).                                     |
| `dashboards/shared/`                 | **Only `.gitkeep` — empty placeholder** | **Remove** (Q6 audit: no content, no dependents).                                     |
| `packages/vitest-reporter-tests-dashboard/` | (reporter)                   | Stays under `packages/` — not an app.                                                     |

### 1c. Firebase hosting surfaces — current owner

| Surface                          | Owner today                                     | Target owner                                                       |
| -------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------ |
| `darkstrawberry-landing` (landing) | `apps/landing/firebase.json`                  | `apps/landing/firebase.json` (unchanged — landing stays at `apps/landing/`). |
| `app.darkstrawberry.com`         | `apps/myapps/firebase.json` — single-site SPA  | `apps/darkstrawberry-apps/firebase.json` — **single site** serving the `apps/platform/` shell, client-side routed into promoted sub-apps (Q1). |
| Firestore rules + Functions      | `apps/myapps/firestore.rules`, `apps/myapps/functions/` | Moves with the `darkstrawberry-apps` umbrella.              |

### 1d. Promotion candidates — `apps/myapps/src/views/*` going top-level

Per user direction, these three are the named promotions (`task-list` is
dropped per Q2):

| Embedded view                        | Promote to                                                         | Classification  |
| ------------------------------------ | ------------------------------------------------------------------ | --------------- |
| `apps/myapps/src/views/ReadTracker/`        | `apps/darkstrawberry-apps/myApps/read-tracker/`             | `myApps` (public)  |
| `apps/myapps/src/views/bee/`                | `apps/darkstrawberry-apps/yourApps/bee/`                    | `yourApps` (private) |
| `apps/myapps/src/views/PortfolioTracker/`   | `apps/darkstrawberry-apps/yourApps/portfolio-tracker/`      | `yourApps` (private) |

### 1e. `apps/platform/` — audit findings

Audit via `gh api .../git/trees/main?recursive=1`:

```
apps/platform/src/
  App.vue                      239 B
  main.ts                      280 B
  core/appLoader.ts            1307 B
  registry/appRegistry.ts      1965 B
  registry/firestoreRegistry.ts 2702 B
  firebase/platformFirestore.ts 11828 B
  router/index.ts              3142 B
  router/vue-router.d.ts       167 B
  views/{Home,Settings,YourApps,AppSuggestionsPage,AccessDenied,NotFound}.vue
  components/{access,collaboration,fork,icons,layout,ui}/*.vue
```

No `package.json`, no `vite.config.ts`, no `index.html`, no `tsconfig.json` —
i.e. not yet wired as a runnable workspace. But the file contents
(PlatformLayout, PlatformHeader, appRegistry with dynamic loading, access
request flow, fork badges, app suggestions) clearly describe the
**darkstrawberry launcher shell** — the Home / YourApps screen that
dynamically mounts `myApps/*` and `yourApps/*` sub-apps.

This is not scratch, not a shared lib, and does not belong under `apps/shared/`
or `packages/`. It is a first-class deployable surface that hasn't been wired
yet. **Disposition: keep at `apps/platform/`, mark as a future promotion
target to `apps/darkstrawberry-apps/` once it grows a `package.json` and a
Vite config.** Out of scope for this restructure; called out here so nothing
deletes it by accident.

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

### 2b. `apps/myapps/firebase.json` — single hosting surface (kept single — Q1)

Current state: one Vite app, one `dist/`, one hosting config, one rewrite rule
`** → /index.html`.

Per Duong Q1, `app.darkstrawberry.com` **remains a single host** — no
per-app subdomains. Client-side routing continues to split paths between
promoted sub-apps. This simplifies the Firebase hosting plan:

- `apps/darkstrawberry-apps/firebase.json` keeps a **single hosting entry**
  (no `targets` array, no `.firebaserc` `targets` block).
- The single-site build is a composite: either (a) one Vite build that imports
  all promoted apps via the `apps/platform/` registry, or (b) a top-level Vite
  config at `apps/darkstrawberry-apps/` that code-splits per promoted app and
  produces one `dist/` served by one hosting entry.
- Functions codebase stays singular (`darkstrawberry-functions`) but source
  moves to `apps/darkstrawberry-apps/functions/`.
- `firestore.rules`, `storage.rules`, `firestore.indexes.json` move to
  `apps/darkstrawberry-apps/` (they are per-project, not per-app).
- Per-app **preview** deploys are still possible via Firebase Hosting preview
  channels keyed by PR number, even on a single site.

**Implication:** the original Phase 4 ("Firebase multi-site split") is
**descoped**. Hosting stays single-site. Phase 4 is re-purposed as "composite
build wiring" — see §3.

### 2c. CI workflows referencing `apps/myapps/**`

Every workflow in the table below path-filters or `working-directory`-pins to
`apps/myapps` and siblings. All need update in lockstep with the move:

| Workflow                         | References                                                                                                   | Required edit                                                                       |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| `ci.yml`                         | `working-directory: apps/myapps` (×2); upload-artifact path `apps/myapps/playwright-report/`, `apps/myApps/*/playwright-report/`, `apps/yourApps/*/playwright-report/` | Repoint to `apps/darkstrawberry-apps/**` and the new myApps/yourApps child paths. |
| `e2e.yml`                        | Detects `apps/myapps/` scope via `grep -qE '^apps/myapps/'`; iterates `dashboards/* apps/*`                  | Update scope detection to `^apps/darkstrawberry-apps/` and iterate `apps/dashboards/* apps/*`. |
| `myapps-pr-preview.yml`          | `grep -qE '^apps/(myapps\|platform\|shared\|myApps\|yourApps)/'`; `working-directory: apps/myapps`; `entryPoint: apps/myapps` | Rename to `darkstrawberry-apps-pr-preview.yml`; scope repoints to `apps/darkstrawberry-apps/` + `apps/platform/` + `apps/shared/`; single preview channel per PR (single-host model). |
| `myapps-prod-deploy.yml`         | `paths: apps/myapps/**`, `apps/platform/**`, `apps/shared/**`, `apps/myApps/**`, `apps/yourApps/**`; `working-directory: apps/myapps` | Rename to `darkstrawberry-apps-prod-deploy.yml`; repoint paths to `apps/darkstrawberry-apps/**` + `apps/platform/**` + `apps/shared/**`; single deploy job (single hosting entry, Q1). |
| `myapps-test.yml`                | Same grep scope as pr-preview; `cache-dependency-path: apps/myapps/package-lock.json`; artifact path          | Rename; repoint. If per-app lockfiles emerge, matrix over them.                      |
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
      'apps/webhooks/*',
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
  via `gh api` 404 + full tree scan). Every package carries its own
  `tsconfig.json`. **Decision (Q7): do not create one as part of this
  restructure.** Rationale: adding a shared base tsconfig is a separate
  concern (path-alias unification across workspaces), introduces new compile
  behavior, and violates the "surgical changes" rule when the restructure is
  already 5 phases. If path-alias unification is wanted later, it deserves its
  own plan. This restructure leaves per-package tsconfigs untouched.
- **release-please** — Repo state: `release-please-config.json` enrolls
  **only `dashboards`** (`{ "dashboards": { "tag-name-prefix":
  "test-dashboard-v", ... } }`); `.release-please-manifest.json` is
  `{ "dashboards": "0.1.0" }`. No other packages are version-tracked by
  release-please today. **Decision (Q10):** when `dashboards/` moves to
  `apps/dashboards/`, update `release-please-config.json` so the `packages`
  **map key** becomes `apps/dashboards` (release-please keys by repo-relative
  path). The manifest also re-keys from `"dashboards"` to `"apps/dashboards"`
  with the same `"0.1.0"` value. This preserves version memory — release-please
  reads the manifest keyed by the config's directory path, so as long as the
  two stay in sync at the new path, bumping continues from `0.1.0`. No version
  reset. (Any future enrollment of other packages starts from fresh scratch —
  not this plan's concern.)
- **`ecosystem.config.js`** — PM2 config at repo root. If it references any
  moved worker (bee-worker, coder-worker, deploy-webhook), update in the same
  PR as the worker move.
- **`.firebaserc` at repo root** — currently default only. **Unchanged** — no
  `targets` block needed (single-host model, Q1).

---

## 3. Migration plan — phased

Each phase is atomic: one PR, repo builds and deploys green at HEAD of the
phase. No phase depends on a phase landing silently in the background — every
phase is gated by the previous phase's PR merging to `main`. Per Duong Q8,
**Phase 3 and Phase 4 land as a single PR** for deploy-integrity.

### Phase 0 — Prerequisites (blocking)

- Portfolio stack #29–#45 fully merged to `main`.
- Root `package.json` `workspaces` drops stale `apps/portal` entry.
- No outstanding `feature/portfolio-v0-*` branches.

**Rollback surface:** none — this phase modifies no code paths, just clears
the runway.

### Phase 1 — Create `apps/darkstrawberry-apps/` shell + move myapps wholesale

Mechanical rename, no content changes. All moves use `git mv` to preserve
blame (Q9):

- `git mv apps/myapps apps/darkstrawberry-apps` (preserving history).
- `apps/darkstrawberry-apps/portfolio-tracker/`, `.../read-tracker/`,
  `.../task-list/` all ride along at their current sibling location —
  promotion happens in Phase 3.
- Update root `package.json` workspaces glob.
- Update `.firebaserc` only if needed (likely unchanged at this phase).
- Update every CI workflow in §2c.
- Update `release-please-config.json` if any path under the move is tracked
  (today: none).

**Rollback surface:** single revert of this PR restores `apps/myapps/` intact
because it is a pure rename.

**Build/deploy contract after Phase 1:** `app.darkstrawberry.com` still serves
from the single-site `firebase.json`, but sourced from
`apps/darkstrawberry-apps/firebase.json` and `apps/darkstrawberry-apps/dist/`.

### Phase 2 — Move non-app services (workers, webhooks, discord, dashboards, contributor)

Still pure moves, no behavior change. All `git mv` (Q9):

- `apps/coder-worker/` → `apps/workers/coder-worker/`
- `apps/private-apps/bee-worker/` → `apps/workers/bee-worker/`
- `apps/deploy-webhook/` → `apps/webhooks/deploy-webhook/` (Q5)
- `apps/discord-relay/` → `apps/discord/discord-relay/`
- `apps/contributor-bot/` → `apps/contributor/contributor-bot/`
- `dashboards/usage-dashboard/` → `apps/dashboards/usage-dashboard/`
- `dashboards/server/` → `apps/dashboards/server/`
- `dashboards/test-dashboard/` → `apps/dashboards/test-dashboard/`
- Delete `dashboards/dashboard/` (only `.gitkeep` — Q6 audit).
- Delete `dashboards/shared/` (only `.gitkeep` — Q6 audit).
- Delete empty `dashboards/` root after the moves.

Workflow updates:

- `pr-lint.yml` UI glob now includes `apps/dashboards/*/src/*`.
- `e2e.yml` iteration list changes from `dashboards/* apps/*` to `apps/*` (and
  a deeper walk for the `darkstrawberry-apps/myApps/*` and `yourApps/*`
  children — gated by Phase 3).
- `ecosystem.config.js` pm2 app paths for every moved worker/webhook.
- `release-please-config.json` re-key from `dashboards` → `apps/dashboards`;
  `.release-please-manifest.json` re-key same.
- Root `package.json` workspaces glob adds `apps/workers/*`,
  `apps/webhooks/*`, `apps/discord/*`, `apps/dashboards/*`,
  `apps/contributor/*`.

**Rollback surface:** revert the PR; packages land back at old paths. No
deployments reshape in this phase — workers are long-running services, not
hosted.

### Phase 3 + Phase 4 — Promote views + wire composite build (single PR, per Q8)

This combined PR is the first to change deployable surfaces. Landing them
together avoids a window where `app.darkstrawberry.com` either serves a
half-promoted SPA or a half-wired composite build.

**3a. Promote `src/views/*` to top-level apps inside `darkstrawberry-apps/`:**

- `apps/darkstrawberry-apps/src/views/ReadTracker/` +
  `apps/darkstrawberry-apps/read-tracker/` (sibling scaffold) →
  `apps/darkstrawberry-apps/myApps/read-tracker/`.
- `apps/darkstrawberry-apps/src/views/bee/` + `apps/yourApps/bee/` →
  `apps/darkstrawberry-apps/yourApps/bee/` (the top-level scaffold is more
  complete; views become its source).
- `apps/darkstrawberry-apps/src/views/PortfolioTracker/` +
  `apps/darkstrawberry-apps/portfolio-tracker/` →
  `apps/darkstrawberry-apps/yourApps/portfolio-tracker/`.
- **Delete** `apps/darkstrawberry-apps/src/views/TaskList/` and
  `apps/darkstrawberry-apps/task-list/` (Q2 — task-list does not survive).
- Legacy `apps/darkstrawberry-apps/src/` SPA shell retires once all views are
  promoted.

**4a. Single-host composite build wiring (per Q1):**

- `apps/darkstrawberry-apps/firebase.json` keeps a **single `hosting` entry**
  targeting the `darkstrawberry-apps` site (no `targets` array).
- Top-level Vite config at `apps/darkstrawberry-apps/` produces one `dist/`
  that imports promoted sub-apps via the existing `apps/platform/` registry
  (see §1e). Client-side router splits by path.
- `.firebaserc` unchanged (no `targets` block).
- `preview.yml` `cp apps/myapps/firebase.json firebase.json` step becomes
  `cp apps/darkstrawberry-apps/firebase.json firebase.json`. Preview channels
  stay one-per-PR on the single site.
- No DNS work (no new subdomains).

**Rollback surface:** combined PR revert restores the composite SPA at
`apps/myapps/` (after Phase 2 revert, if also needed). Because the PR both
moves views and rewires the build, revert must be whole-PR — no partial
cherry-pick. Firebase Hosting retains prior deploys, so revert + redeploy
restores the previous site.

**Build/deploy contract after Phase 3+4:** `app.darkstrawberry.com` serves
the composite build assembled from `apps/darkstrawberry-apps/myApps/*` and
`apps/darkstrawberry-apps/yourApps/*` via the platform registry. Single
hosting entry. Per-PR preview on the same site.

### Phase 5 — Cleanup and renames

- Delete `apps/private-apps/` shell (now empty).
- Delete `apps/yourApps/` shell at the old top-level (now empty — real
  `yourApps` lives under `darkstrawberry-apps/`).
- Delete `apps/myapps/task-list/` sibling scaffold if not removed in Phase 3
  (Q2 — belt-and-suspenders).
- Rename any stragglers still using `myapps` (lowercase) inside workflows,
  scripts, comments, README.
- Update `docs/` references.
- Sweep for dead workflow files after the split.

**Rollback surface:** these are deletions of empty directories and comment/
README fixups. A revert is cheap.

---

## 4. Removal list — gated on Duong confirmation

Duong approved removals conditionally on "yes if not needed" (2026-04-19).
Audit results folded in below.

| # | Path                                                        | Audit finding                                                                                                                                         | Final disposition |
| - | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| 1 | `apps/myapps/src/views/TaskList/`                           | Q2: Duong confirmed removal.                                                                                                                          | **Delete in Phase 3+4 PR.** |
| 2 | `apps/myapps/task-list/` (sibling workspace)                | Q2: Duong confirmed removal.                                                                                                                          | **Delete in Phase 3+4 PR** (backup: Phase 5). |
| 3 | `apps/platform/`                                            | Audit (§1e): **live code** — darkstrawberry launcher shell (main.ts, App.vue, router, registry, appLoader, full view + component tree). Not scratch, not a shared lib. No `package.json` yet, but file structure is a deployable surface in progress. | **KEEP at `apps/platform/`.** Promotion to `apps/darkstrawberry-apps/` deferred until it grows a `package.json` + Vite config — out of scope for this restructure. |
| 4 | `apps/shared/`                                              | Q4: Duong said keep as-is. Audit confirms live code: `firebase/appFirestore.ts`, `firebase/index.ts`, `types/AppManifest.ts`, `ui/icons/`. Consumed by `apps/myapps` via `@shared` Vite alias.          | **KEEP at `apps/shared/`.** No fold, no move. |
| 5 | `dashboards/dashboard/`                                     | Audit: contents = **only `.gitkeep`**. No code, no dependents, no references in any workflow or package.json.                                         | **Delete in Phase 2** (folded into dashboards move). |
| 6 | `dashboards/shared/`                                        | Audit: contents = **only `.gitkeep`**. Same as #5.                                                                                                    | **Delete in Phase 2.** |
| 7 | Empty shell `apps/private-apps/`                            | Empty after Phase 2 move.                                                                                                                             | Delete in Phase 5.        |
| 8 | Empty shell `apps/yourApps/`                                | Empty after Phase 3 move.                                                                                                                             | Delete in Phase 5.        |
| 9 | Legacy `apps/darkstrawberry-apps/src/views/*` after promotions | Superseded by promoted apps.                                                                                                                        | Delete in Phase 3+4 as part of the promotion PR.        |

No open removal gates remain. All six Duong-approved items are resolved.

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
- `npm install` at root resolves with updated workspaces glob.
- `turbo run build` green.
- No change to CI matrix; all existing checks pass.

### Phase 1 (myapps → darkstrawberry-apps rename)
- `turbo run build` green at new path.
- Test workflow (renamed) E2E still green.
- PR-preview workflow (renamed) successfully deploys preview from the new `working-directory`.
- Manual: visit preview URL; all four app routes load (composite SPA still intact).
- release-please dry-run produces no spurious version bumps.

### Phase 2 (workers, webhooks, discord, dashboards, contributor moves)
- `turbo run build` green for every moved package.
- `ecosystem.config.js` pm2 start dry-run on a scratch host.
- Each worker's unit test suite green in CI.
- No dashboard preview regression (dashboards-server still serves).
- release-please config re-key verified (dry-run shows `apps/dashboards`
  recognized with version `0.1.0`, no spurious bump).

### Phase 3+4 (promote views + composite build wiring — single PR per Q8)
- Every promoted app (`read-tracker`, `bee`, `portfolio-tracker`) builds on
  its own via `turbo run build --filter=@ds/<name>`.
- Composite build at `apps/darkstrawberry-apps/` produces a single `dist/`
  that mounts all three promoted apps via the `apps/platform/` registry.
- Playwright E2E for each promoted app (one spec file each, smoke-level) —
  can reuse the existing `apps/darkstrawberry-apps/e2e/` specs until split.
- Preview deploy produces one preview channel per PR (single site, Q1); all
  three app paths resolve inside that channel.
- Prod deploy dry-run (`firebase deploy --only hosting --dry-run`) lists the
  single `darkstrawberry-apps` site.
- Post-deploy smoke: Rule 17's smoke-test harness runs against the prod host
  and asserts 200 on `/`, `/read-tracker`, `/bee`, `/portfolio-tracker` (or
  whatever paths the platform router assigns).
- Spot check: Firestore Security Rules emulator smoke (from the portfolio
  V0.3 harness) still passes after the functions/rules path move.

### Phase 5 (cleanup)
- `git status` clean; no orphaned workflow files.
- `validate-scope.yml` passes — no stray references to old paths anywhere in
  the tree.
- `grep -R "apps/myapps" .` returns nothing outside historical plan files.

### Cross-phase invariants
- Rule 14: pre-commit runs unit tests for changed packages — never bypassed.
- Rule 15: PR cannot merge red.
- Rule 17: post-deploy smoke runs on stg and prod. For Phase 3+4 this is the
  primary safety net against composite-build misconfiguration.
- Rule 18: no `--admin` merges, no PR-author self-merge.

---

## 7. Resolved questions — Duong answers + architect decisions

All 10 original gating questions are now resolved. Recorded here for history.

| #  | Question                                                                                                      | Resolution                                                                                                                                             |
| -- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1  | Subdomain strategy for `app.darkstrawberry.com`                                                               | **Duong: single host, client-side routed.** No per-app subdomains.                                                                                     |
| 2  | Does `task-list` survive?                                                                                     | **Duong: remove.** Delete both the embedded view and the sibling scaffold.                                                                             |
| 3  | `apps/platform/` disposition                                                                                  | **Audit + architect: KEEP at `apps/platform/`.** Live code (darkstrawberry launcher shell), not scratch. Promotion to `darkstrawberry-apps/` deferred. |
| 4  | `apps/shared/` disposition                                                                                    | **Duong: keep as-is.** Audit confirms live consumers via `@shared` Vite alias.                                                                         |
| 5  | Is `deploy-webhook` a worker?                                                                                 | **Duong: new `apps/webhooks/` slot.**                                                                                                                  |
| 6  | `dashboards/dashboard/` and `dashboards/shared/` content audit                                                | **Audit: both contain only `.gitkeep`.** Empty placeholders. Delete in Phase 2.                                                                        |
| 7  | Should `tsconfig.base.json` exist?                                                                            | **Architect: no.** Do not add one in this restructure. Every package has a working tsconfig. Defer path-alias unification to a separate plan.          |
| 8  | Commit/PR granularity                                                                                         | **Duong: merge Phase 3 + Phase 4 as a single PR** (deploy-integrity).                                                                                   |
| 9  | Preserve git history via `git mv`?                                                                            | **Duong: confirmed.** All moves in this plan use `git mv`.                                                                                             |
| 10 | Release-please cutover                                                                                        | **Architect: re-key config + manifest.** Only `dashboards` is enrolled today (manifest: `{"dashboards": "0.1.0"}`). Rename the map key to `apps/dashboards` in both `release-please-config.json` and `.release-please-manifest.json` within the same PR as the dashboards move. Version preserved at `0.1.0`. No reset. |

No open questions remain. Ready for promotion.

---

## Handoff

Once Duong has approved this ADR:

- Promote via `scripts/plan-promote.sh` to `plans/approved/`.
- Kayn or Aphelios breaks the phases into concrete task lists under
  `plans/in-progress/` — one task list per phase PR (Phase 3+4 is one task
  list, not two).
- Azir is available for follow-up on any cross-phase architecture questions
  (composite-build wiring, platform-registry integration, workspace graph).

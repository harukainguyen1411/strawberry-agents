---
status: proposed
owner: azir
date: 2026-04-17
title: Test Dashboard Architecture ADR — service boundary, ingestion, artifacts, UI, monitoring seam
---

# Test Dashboard Architecture ADR

Architecture-level plan for a **test dashboard service** that surfaces results from every rung of the strawberry TDD ladder: xfail-first tests, regression tests, unit tests, Playwright E2E, QA Playwright recording+screenshot review, and post-deploy smoke tests. A follow-on monitoring dashboard is explicitly planned for but out of scope here — this ADR defines the seam it will plug into.

Implementation is not in scope. Breakdown goes to Kayn/Aphelios after approval.

**Relationship to `plans/proposed/2026-04-17-deployment-pipeline.md`.** That ADR defines *how code deploys* and owns `logs/deploy-audit.jsonl`. This ADR defines *how test results are reported* and owns the test-results data plane. The two meet at smoke tests — smoke is a *test type* this dashboard ingests, and it is simultaneously a *gate* the deploy pipeline runs. The dashboard reads smoke results as one input among six. It does not gate deploys.

---

## 1. Scope

**In scope:**

- A dashboard service that ingests, stores, and displays test results from six test types:
  1. **xfail-first** — every new task begins with a failing test (TDD discipline marker).
  2. **Regression** — one test per fixed bug.
  3. **Unit** — pre-commit hook.
  4. **Playwright E2E** — PR workflow.
  5. **QA Playwright** — pre-PR recording + screenshot diff against design.
  6. **Smoke** — post-deploy on stg/prod.
- Ingestion contracts for each test type.
- Artifact storage (Playwright traces, videos, screenshots, design-diff images).
- Frontend UI (personal-scale, one user).
- Auth (Duong-only).
- A stable read-side contract for the future monitoring dashboard.

**Seams left (not built now):**

- Monitoring dashboard (service health, error rates, deploy audit visualization). It reuses the auth + host + ingestion spine defined here.
- Flaky-test detection and quarantine UI.
- Coverage visualization.
- Multi-user / team access.

**Explicitly out of scope:**

- Changing any existing test framework or CI workflow beyond adding a thin ingestion call.
- Replacing the deploy audit log. The deploy pipeline owns `logs/deploy-audit.jsonl`; the dashboard *reads* it for the monitoring view later.
- Running tests. The dashboard only *receives* results.
- Notifications / paging (Discord alerts are a future feature; for now the dashboard is pull-only).

---

## 2. Service boundary — decision: **separate Cloud Run service under a new top-level `dashboards/`**

Three options considered:

| Option | Pros | Cons |
|---|---|---|
| **A. Separate repo** | Clean isolation, independent versioning. | Doubles the ops surface (CI, release-please, secrets, worktrees). Strawberry's monorepo discipline is load-bearing — splitting fights the grain. |
| **B. Subdir of strawberry, another Cloud Function** | Reuses `apps/functions/` deploy path. | Functions is sized for small event handlers; a dashboard with a UI, a DB, and artifact serving is a poor fit. Mixes concerns — Bee's Functions project is about the agent loop. |
| **C. Separate Cloud Run service, in-repo** ← **chosen** | Single repo for unified tooling (release-please already planned per-app), right-sized runtime for a long-running HTTP service with a bundled UI, independent deploy surface per the monorepo-isolation contract in the deployment-pipeline ADR §1a. | New deploy surface to add to `scripts/deploy/`. Cost: a small amount of scripting. |

**Decision: Option C.** The service lives under a new top-level `dashboards/` directory — sibling to `apps/`, not under it. Release-please gets a new package (`test-dashboard`) with tag `test-dashboard-v*`.

### 2a. Repo layout — one service, two frontends

The monitoring dashboard (Section 10) ships as a second frontend on the **same Cloud Run service**. That's an intentional architectural decision, not a deployment-time coincidence. To keep it honest, the source layout separates the shared server from the frontends:

```
dashboards/
  server/              # the Cloud Run service — Express/Fastify API, auth, ingestion
    src/
    package.json
  test-dashboard/      # React frontend #1 — test results
    src/
    index.html
    package.json
  dashboard/           # React frontend #2 — monitoring (future; scaffolded empty in Phase 1)
    src/
    index.html
    package.json
  shared/              # shared UI primitives (auth hook, layout, theme)
    package.json
```

**Composition model.**

- `dashboards/server/` owns the HTTP surface, auth middleware, Firestore + GCS access, and ingestion endpoints. It is the only component that is deployed.
- Each frontend is a Vite app that builds to static assets. At container build time, both frontends are built and placed under `dashboards/server/public/{test,monitoring}/`.
- The server mounts them under disjoint route namespaces:
  - `/` and `/runs/*`, `/commits/*`, `/types/*` → `test-dashboard` frontend
  - `/monitoring/*` → `dashboard` frontend (404s in Phase 1 until that frontend exists)
  - `/api/v1/*` → the API, shared by both
- `dashboards/shared/` is a workspace package that both frontends consume for auth, layout, theme. It is **not** required in Phase 1 — it materializes only when the monitoring frontend is actually built. Phase 1 may inline its eventual contents inside `test-dashboard/` and extract later.

**Why one server, two frontends, not two full apps.**

- One auth path. Firebase ID token verification lives once, not twice.
- One datastore client. Firestore + GCS credentials are the server's only, never the browser's.
- One deploy surface. Release-please, smoke tests, audit log, IAM grants — single set.
- Frontend code stays split so the two surfaces can evolve independently (different routes, different data shapes, no accidental coupling in React state or components).

**Why not a single React app with two route trees.** Tempting for simplicity, but it forces the test-results page to import monitoring code at bundle time (or adopt a code-splitting convention that's heavier than just having two Vite apps). Two entries is the cleaner seam.

**Why Cloud Run over Firebase Hosting + Functions.** The dashboard has a persistent DB connection, serves artifacts with signed URLs, and will grow a small API surface. Cloud Run's container model fits; Hosting+Functions forces an artificial split between static and dynamic that we don't need.

**Why not reuse `myapps-b31ea`'s existing Firebase Hosting.** Hosting is for the public-facing web apps. The test dashboard is internal tooling; keeping it on a distinct Cloud Run service keeps public traffic and internal traffic on separate blast radii.

---

## 3. Data model

Five entities. Keep the surface small.

```
Run           # one invocation of one test type in one environment
Suite         # grouping within a run (file-level for unit/e2e, feature-level for QA)
Case          # one test function / one scenario
Artifact      # blob reference (screenshot, video, trace)
Environment   # label: local | ci | staging | prod
```

**Run** (top-level event):

```json
{
  "id": "run_01HXY...",              // ULID
  "type": "unit|xfail|regression|e2e|qa|smoke",
  "environment": "local|ci|staging|prod",
  "project": "myapps-b31ea",         // Firebase project ID (nullable for local)
  "git_sha": "abc1234",
  "git_ref": "main",                 // branch or tag
  "version": "bee-v1.3.0",           // nullable
  "actor": "duong@local|github-actions",
  "started_at": "2026-04-17T10:00:00Z",
  "finished_at": "2026-04-17T10:00:47Z",
  "status": "pass|fail|error|skipped",
  "counts": { "total": 142, "pass": 140, "fail": 2, "skipped": 0, "xfail": 0 },
  "trigger": {                       // provenance, not control
    "source": "pre-commit|gh-actions|post-deploy|manual",
    "workflow": "test.yml",          // nullable
    "pr_number": 42                  // nullable
  },
  "metadata": { }                    // escape hatch per type
}
```

**Case** (one test result, belongs to a run via `run_id`):

```json
{
  "id": "case_01HXY...",
  "run_id": "run_01HXY...",
  "suite": "apps/functions/src/bee/handler.test.ts",
  "name": "rejects unauthenticated writes",
  "status": "pass|fail|error|skipped|xfail|xpass",
  "duration_ms": 234,
  "failure_message": "AssertionError: ...",   // nullable
  "failure_stack": "...",                      // nullable, truncated to 8KB
  "artifacts": ["artifact_01HXY..."]           // references
}
```

(Suite is an implicit grouping derived from `case.suite`, not a first-class table. Cheaper, still queryable.)

**Artifact**:

```json
{
  "id": "artifact_01HXY...",
  "run_id": "run_01HXY...",
  "case_id": "case_01HXY...",           // nullable (run-level artifacts)
  "kind": "screenshot|video|trace|design-diff|log",
  "storage_path": "gs://bucket/runs/<run_id>/<filename>",
  "mime": "image/png|video/webm|application/zip|...",
  "size_bytes": 123456,
  "created_at": "2026-04-17T10:00:47Z"
}
```

**Indexes that matter** (Postgres / Firestore composite equivalents):

- `runs (type, started_at desc)` — latest runs per type for the landing page.
- `runs (git_sha)` — "what tests ran for this commit" — load-bearing for the PR view.
- `runs (environment, started_at desc)` — smoke timeline per env.
- `cases (run_id)` — drill-down.
- `cases (name, status)` — "is this test flaky?" query (future feature; index now is cheap).

**Datastore choice: Firestore.** Rationale:

- Already in the stack (`myapps-b31ea` uses Firebase Storage + Auth); zero new infra.
- Fits the document shape above without fighting the schema.
- Sufficient for personal-scale write volume (hundreds of runs/day worst case).
- The future monitoring dashboard reads Firestore and the deploy audit log from one place.

Postgres was considered and rejected: fine fit, but adds a managed-DB surface (Cloud SQL) that's otherwise absent. Not worth the ops tax for this scale.

**Retention.** Keep runs forever at the metadata level (small). Artifacts expire at 90 days by default via a GCS lifecycle rule (Section 5). Runs whose artifacts expired remain queryable; artifact links return 410 Gone via a signed-URL error path. Flagged as work, not a blocker.

---

## 4. Ingestion — contract per test type

**One HTTP endpoint, one shape, six callers.** No per-type endpoint proliferation.

```
POST /api/runs
  Authorization: Bearer <service-token>
  Content-Type: application/json
  body: { run: Run, cases: Case[], artifact_uploads?: ArtifactUpload[] }
  response: { run_id, artifact_upload_urls: { [local_ref]: signed_url } }
```

Flow:

1. Caller POSTs the run + cases. Artifacts are declared by `local_ref` (e.g. `"screenshot_0"`) + kind + size; they are not uploaded inline.
2. Service creates the run + cases transactionally; returns per-ref V4 signed GCS upload URLs.
3. Caller PUTs each artifact to its signed URL (direct to GCS, bypassing the service).
4. Caller POSTs `/api/runs/<id>/finalize` to flip the run's `status` to its terminal value once all artifacts are uploaded (or `error` if uploads failed).

**Why declare-then-upload.** Keeps the service path small and avoids streaming large videos through Cloud Run. Playwright trace ZIPs can be 50MB+; direct-to-GCS uploads are the correct pattern.

**Per-test-type wiring:**

| Test type | Trigger point | Reporter shape |
|---|---|---|
| **xfail-first** | Agent / Kayn marks the red test via a wrapper before the fix is written | Single-case run; `counts.xfail = 1`, `status = pass` (xfail is the expected state). Recorded so the TDD ladder is visible. |
| **Regression** | Tagged test annotation (`@regression(bug_id)`) in the test suite; reporter writes the annotation into `case.metadata.bug_id` | Normal run; monitoring later groups by `bug_id`. |
| **Unit** | Pre-commit hook (local only) | Vitest/Jest JSON reporter → `tools/report-run.sh` → `POST /api/runs`. Fire-and-forget — hook doesn't block on the POST, only on test failure. Best-effort delivery; if the service is down, unit results are lost, not the commit. |
| **Playwright E2E** | GH Actions PR workflow | Playwright JSON reporter → `scripts/report-run.sh` called from the workflow's `post-test` step. Runs even on test failure (`if: always()`). |
| **QA Playwright** | Pre-PR, agent-triggered via a `scripts/qa-record.sh` (Kayn to design) | QA reporter emits recording + screenshots as artifacts; each screenshot has a paired `design-diff` artifact showing pixel diff against the Figma export. One `case` per user flow. |
| **Smoke** | Post-deploy, called from `scripts/deploy/smoke.sh` (deployment pipeline ADR §7a) | Smoke script writes a synthetic run with cases = assertion list; ingests after the deploy-audit record is written. On auto-revert, the revert deploy's smoke gets its own run. |

**Reporter abstraction.** A single shared script `scripts/report-run.sh <reporter-json-path> <type>` normalizes each framework's JSON into the ingestion shape. One shared normalizer avoids six one-offs.

**Auth for ingestion.** Ingestion uses a long-lived service token (separate from the dashboard UI's user auth). Stored as:

- GH Actions secret `TEST_DASHBOARD_INGEST_TOKEN` (for CI ingestion).
- Encrypted per the deployment-pipeline ADR §2 secrets layout for local pre-commit and QA ingestion: `secrets/env/test-dashboard-ingest.env.age`.

Rotation: rewrite the ciphertext, redeploy. Same flow as every other secret. No rotation tooling required at this scale.

---

## 5. Artifact storage

**Decision: GCS bucket, one per environment.** Buckets: `strawberry-test-artifacts-prod`, `strawberry-test-artifacts-staging`. Local runs write to the staging bucket (cheapest shared path; local ingestion is low-volume).

**Why GCS over Firebase Storage.**

- Firebase Storage is a thin wrapper on GCS; we get the same API. The tradeoff is tooling: Firebase Storage's rules language is oriented around per-user client access, which this service doesn't need. Signed URLs from GCS via the service account are the right model for a service-mediated flow.
- Keeps the Firebase Storage buckets (`myapps-b31ea.appspot.com`) focused on product data.

**Layout:**

```
gs://strawberry-test-artifacts-<env>/
  runs/<run_id>/
    <case_id>/
      screenshot-0.png
      video.webm
      trace.zip
      design-diff.png
    run-level/
      summary.json
```

**Lifecycle:**

- Default: delete objects after 90 days.
- Override path: runs tagged `pin: true` via `PATCH /api/runs/<id>` skip deletion. Used rarely (e.g. a landmark regression test that's canonical). Implementation: lifecycle rule excludes objects under a `pinned/` prefix; pinning moves objects.

**Access:**

- Reads through the dashboard API only. The UI never gets bucket-wide credentials; it receives short-lived (15 min) signed URLs per artifact on demand.
- Uploads via upload-time signed URLs (Section 4).

**Cost.** 90-day retention at ~50MB/run × 10 runs/day worst case ≈ 45 GB steady state. GCS Standard at ~$0.02/GB/mo ≈ $1/mo. Noise.

---

## 6. API contract

**REST, not event-driven.** Rationale: one producer style (HTTP clients), one consumer (the UI and later the monitoring dashboard). Events would add a broker with no multiplexing benefit at this scale.

**Endpoints (v1):**

```
# Ingestion
POST   /api/runs                        create run + cases, return upload URLs
POST   /api/runs/:id/finalize           mark run terminal; caller signals all artifacts uploaded
PATCH  /api/runs/:id                    pin/unpin, edit metadata

# Read
GET    /api/runs?type=&env=&sha=&limit= paginated list with filters
GET    /api/runs/:id                    run detail + cases
GET    /api/runs/:id/artifacts/:aid     302 redirect to signed URL
GET    /api/commits/:sha/runs           all runs for a git sha (PR view)
GET    /api/health                      liveness (no auth)
GET    /api/version                     {version, sha, builtAt}
```

**Versioning.** Path-prefixed `/api/v1/...`. Breaking changes cut `/api/v2/...`; v1 stays live until no caller references it. For a single-operator system this is cheap insurance against reporter-script drift.

**Auth model:** Section 7.

**Error shape (consistent across all endpoints):**

```json
{ "error": { "code": "RUN_NOT_FOUND", "message": "..." } }
```

---

## 7. Auth model — Duong-only

**Two principals:**

| Principal | Identity | Used for |
|---|---|---|
| **Human (Duong)** | Firebase Auth, Google provider, UID allowlist of exactly one | UI access, PATCH/pin operations |
| **Service** | Bearer token in `Authorization` header, value stored encrypted | Ingestion POSTs from CI and local reporter scripts |

**Frontend auth:**

- Firebase Auth on `myapps-b31ea` (already configured for Bee). Reuse.
- The Cloud Run service validates ID tokens via Firebase Admin SDK.
- A UID allowlist lives in the service's env (`ALLOWED_UIDS=0DJzc86i5MP74jAwwT4YjvbcAub2`). Anyone else — 403. Simple, boring, correct.

**Service auth:**

- Single symmetric token, 32 bytes, rotated by re-encrypting the env + redeploying.
- Validated by a constant-time compare on the ingestion endpoints.
- **Not** a JWT — no value in signing when there's one issuer and one verifier and the token is already a shared secret.

**Cloud Run ingress:**

- Public (allow unauthenticated invocations at the Cloud Run layer). Auth is enforced in-app, same as Bee.
- Rationale: CI runners don't carry GCP identities we want to federate; the app-level token is simpler.

**CORS:**

- Allow the dashboard's own origin for browser requests.
- Ingestion endpoints are CORS-denied — they're server-to-server only. A browser cannot POST runs.

---

## 8. Frontend stack — keep it light

**Decision: Vite + React + TypeScript, bundled and served by the same Cloud Run container.**

- Vite for build; React for familiarity and component ecosystem; TS because the rest of the repo is.
- Styling: Tailwind. The repo already uses it elsewhere (per `apps/landing`).
- State: TanStack Query for server state; no global client store. Personal-scale app, no need.
- Routing: TanStack Router or React Router — pick during implementation; either is fine.
- Charts (for the future monitoring view): Recharts. Don't pull it in Phase 1 if the page doesn't need it.

**Why not Next.js / SSR.** The dashboard is behind auth and reads live data; SSR adds a Node server that re-fetches what the client would fetch anyway. No SEO story. Skip.

**Why not separate frontend and backend services.** For personal-scale: one container, one deploy, one URL. Splitting them doubles the deploy surface without benefit.

**Page inventory (Phase 1):**

- `/` — recent runs across all types, filterable.
- `/runs/:id` — run detail, case tree, artifact gallery (lazy-loaded signed URLs).
- `/commits/:sha` — all runs for a git sha; the "PR view."
- `/types/:type` — recent runs of one type (e.g. smoke timeline).
- `/login` — Google sign-in.

---

## 9. Deployment surface — reuses the deployment-pipeline ADR

The test dashboard is a new surface under the deployment pipeline defined in `plans/proposed/2026-04-17-deployment-pipeline.md`.

**Additions required in that pipeline:**

- New script: `scripts/deploy/dashboards.sh` — builds both frontends, assembles the container from `dashboards/server/`, pushes to Artifact Registry, deploys to Cloud Run for the given Firebase project.
- New release-please package: `test-dashboard` at `dashboards/` (root-level watch path with scoped subdirectories). First `feat:` commit touches `dashboards/test-dashboard/**` or `dashboards/server/**` → `test-dashboard-v*` tag. When the monitoring frontend lands, it either rides the same `test-dashboard` package (simpler) or splits into a sibling `monitoring` package (defer; flag if it ever matters).
- New encrypted env: `secrets/env/dashboards.<project>.env.age` containing `INGEST_TOKEN`, `FIREBASE_PROJECT_ID`, `GCS_BUCKET`, `ALLOWED_UIDS`.
- Smoke test extension: `scripts/deploy/smoke.sh` gets a new assertion list entry for the dashboard's `/api/health` and `/api/version`.

**Audit log integration:** dashboard deploys emit `logs/deploy-audit.jsonl` records with `surface: "test-dashboard"`. Same schema, zero pipeline changes beyond adding the surface.

**IAM on the Cloud Run service account:**

- `roles/datastore.user` — Firestore read+write.
- `roles/storage.objectAdmin` on the test-artifacts buckets only (scoped via IAM condition, not project-wide).
- `roles/firebaseauth.admin` — verify ID tokens via Admin SDK.

---

## 10. Relationship to future monitoring dashboard

**Decision: same Cloud Run service, second frontend at `dashboards/dashboard/`.** One service, two frontends, sharing auth, host, datastore, and ingestion. Section 2a spells out the source layout; this section defines the seam.

Rationale:

- Both are personal-use, Duong-only, read-heavy dashboards with tiny write volume.
- Deploy audit log is already file-based and app-readable; the monitoring frontend reads `logs/deploy-audit.jsonl` (or its future bucket-streamed successor) and Firebase/Cloud Logging via API.
- Splitting forces a second auth setup, a second deploy surface, and a second login for a reader who is one person.

**Stable interface the monitoring frontend will consume:**

1. Firestore collections `runs/`, `cases/`, `artifacts/` — additive schema growth only. Same backend, new read queries.
2. A future read adapter (`GET /api/v1/deploys?project=&limit=`) that fronts the deploy audit log. Defined here as a reserved path; **not implemented in Phase 1.**
3. Firebase function logs via Cloud Logging API — no contract needed, direct read from the server.

**Route namespace contract:**

- `/monitoring/*` → served by `dashboards/dashboard/` frontend (Phase 3). In Phase 1 the server reserves the prefix and returns 404; it must not be claimed by the test-dashboard frontend's catch-all router.
- `/` and all other dashboard-ish paths → `dashboards/test-dashboard/` frontend.
- `/api/v1/*` → shared API surface for both frontends.

**Non-goals for the monitoring frontend (Phase 1):**

- Not building it.
- Not designing it in detail.
- Only reserving the source directory (`dashboards/dashboard/`), the route prefix (`/monitoring/*`), and the shared API contract.

---

## 11. Implementation phasing

Phase-level only. Kayn's breakdown decides tasks.

**Phase 1 — Ingestion + storage + minimal UI.**

- `dashboards/server/` scaffolded (Express or Fastify for the API, one container) + `dashboards/test-dashboard/` (Vite + React frontend). `dashboards/dashboard/` reserved empty.
- Firestore collections created; security rules locked down (service-account-only write; UI reads via the service, never direct).
- GCS buckets created with lifecycle rules.
- `POST /api/runs`, finalize, list, detail endpoints.
- Unit + smoke reporter wiring (unit via pre-commit script, smoke via the deploy pipeline's smoke script).
- UI: list + detail + commit view.
- Firebase Auth + UID allowlist.

Exit criterion: a unit test run on Duong's laptop shows up at the dashboard's `/` within 5 seconds; a smoke test after a Bee deploy shows up under `/types/smoke`.

**Phase 2 — Playwright E2E + QA ingestion + artifact UX.**

- Playwright reporter wiring in the PR workflow.
- QA script that records + screenshots + diffs against a design artifact.
- Artifact gallery: lazy-load images, inline video player, trace download link.
- Signed-URL expiry handling in the UI (re-fetch on 410).

Exit criterion: a PR that runs Playwright shows videos and traces in the dashboard; a pre-PR QA run surfaces screenshots with visible design diffs.

**Phase 3 — Monitoring view.**

- Reserved. Separate plan when it happens.

---

## 12. Explicit non-goals

- No test execution — the dashboard only receives results.
- No notifications / paging in Phase 1.
- No multi-user support, team/org model, or roles beyond allowlist.
- No flaky-test detection algorithm (data is captured; detection waits).
- No coverage visualization.
- No custom test framework — reuse Vitest/Jest/Playwright with their stock JSON reporters.
- No cross-run comparison (diff two runs side by side).
- No historical roll-up analytics beyond what Firestore queries cheaply support.
- No replacement of `logs/deploy-audit.jsonl`. The deploy pipeline owns that file.

---

## 13. Decisions

Duong decided 2026-04-17: all recommendations in the original open-questions section adopted as-is. Retention is 90 days, service is Cloud Run with Firestore, UID allowlist is Duong only, ingestion token is a raw 32-byte secret, unit ingestion is fire-and-forget (2s timeout), Playwright ingestion soft-fails, QA config at `dashboards/server/config/qa-flows.yaml`, correlation on `git_sha` alone, single prod dashboard, first version `0.1.0`, path-prefixed `/api/v1`, parallelized artifact uploads. Monitoring shares this service (see §2a, §10).

---

## Cross-references

- `plans/proposed/2026-04-17-deployment-pipeline.md` — defines the deploy surface model, audit log, smoke test gate. This ADR adds `test-dashboard` as a new surface and `smoke` as an ingested test type.
- `CLAUDE.md` Rule 2, Rule 6 — secrets discipline applies to `TEST_DASHBOARD_INGEST_TOKEN` and the Firebase Admin key.
- `CLAUDE.md` Rule 10 — reporter scripts under `scripts/` are POSIX-portable.
- `architecture/system-overview.md`, `architecture/infrastructure.md` — to be updated by the breakdown with the new service.
- Future plan: **monitoring dashboard** — reuses this service's auth, host, and the `/monitoring/*` route namespace reserved in Section 10.

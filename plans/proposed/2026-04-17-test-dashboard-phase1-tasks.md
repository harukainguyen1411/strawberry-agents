---
status: proposed
owner: kayn
date: 2026-04-17
title: Test Dashboard — Phase 1 Task Breakdown (ingestion + storage + minimal UI + unit + smoke)
references:
  - plans/approved/2026-04-17-test-dashboard-architecture.md
  - plans/approved/2026-04-17-test-dashboard-qa-plan.md
  - plans/approved/2026-04-17-tdd-workflow-rules.md
  - plans/proposed/2026-04-17-deployment-pipeline.md
---

# Test Dashboard — Phase 1 Task Breakdown

Executable task list derived from Azir's ADR (Phase 1 exit criterion: a unit test on Duong's laptop appears at `/` within 5s; a smoke test after a Bee deploy appears under `/types/smoke`). Cross-woven with Caitlyn's QA plan layers 1 (xfail), 2 (regression), 3 (unit), and 6 (smoke). Layers 4 (E2E) and 5 (QA pre-PR) are deferred to Phase 2.

## Conventions

- **xfail-first discipline** (Pyke rule 12, QA layer 1). Every implementation task below lists a preceding `xfail-*` sub-task owned by Vi. Vi commits the xfail test first; the implementation commit flips it. Hand-off between Vi and the implementer is per-task, documented below.
- **Owners.** Jayce = new code/greenfield scaffolds. Viktor = refactors / cross-cutting edits. Vi = tests (and xfail seeding). Seraphine = React frontend. Ekko = TDD hooks / CI wiring (from Pyke §5 — blocking for several tasks below).
- **Commits.** All `chore:` prefix. No rebase. No raw `git checkout` — use `scripts/safe-checkout.sh` worktrees.
- **Files.** All paths absolute from repo root.

## Dependency on Ekko (Pyke §5)

Ekko's hook work (`scripts/hooks/pre-commit-unit-tests.sh`, `scripts/hooks/pre-push-tdd.sh`, `scripts/install-hooks.sh` extension, `.github/workflows/tdd-gate.yml`) is a **prerequisite** for xfail enforcement. Tasks marked **[blocked-by-ekko]** cannot push green until Ekko lands. They can still proceed locally — builders commit xfail-first by convention; the hooks become authoritative once Ekko ships.

Tasks marked **[not-blocked]** do not touch TDD-enabled packages yet (scaffold-only) or can be completed with framework-native test runners without hook enforcement.

---

## Area A — Scaffolding

### A1. Create `dashboards/` monorepo skeleton
- **Owner:** Jayce
- **Depends:** none
- **ADR section:** §2, §2a
- **QA layer:** n/a (scaffold)
- **Files created:**
  - `dashboards/server/package.json`, `dashboards/server/tsconfig.json`, `dashboards/server/src/index.ts` (empty Express/Fastify bootstrap, `/api/health` returning 200)
  - `dashboards/test-dashboard/package.json`, `dashboards/test-dashboard/vite.config.ts`, `dashboards/test-dashboard/index.html`, `dashboards/test-dashboard/src/main.tsx` (empty React mount)
  - `dashboards/dashboard/.gitkeep` (reserved empty per ADR §2a)
  - `dashboards/shared/.gitkeep` (reserved)
  - Root workspace config update (pnpm/npm workspaces) to include `dashboards/*`
  - `dashboards/server/package.json#tdd.enabled = true`, `dashboards/test-dashboard/package.json#tdd.enabled = true` (Pyke §2 marker)
- **Acceptance criteria:**
  - `pnpm -C dashboards/server build` produces a Node bundle.
  - `pnpm -C dashboards/test-dashboard build` produces static assets.
  - `curl localhost:$PORT/api/health` returns 200 when `dashboards/server` runs locally.
  - `dashboards/dashboard/` and `dashboards/shared/` exist but are empty.
- **xfail-first:** Vi adds `dashboards/server/src/__tests__/health.xfail.test.ts` asserting `/api/health` returns 200 with `{status:"ok"}` — initially marked `it.failing`. Jayce's implementation flips it.
- **[not-blocked]** — test framework not yet installed; can land as a plain assertion once Vitest is wired (task C1). In the interim, Vi lands an `it.todo` + note; flip happens after C1.

### A2. Release-please wiring for `test-dashboard` package
- **Owner:** Viktor
- **Depends:** A1
- **ADR section:** §2, §9
- **Files touched:**
  - `release-please-config.json` (add `dashboards/` package, tag format `test-dashboard-v*`)
  - `.release-please-manifest.json` (seed `0.1.0` per ADR §13)
- **Acceptance criteria:** A dry-run of release-please detects `dashboards/**` as a watched path; first `feat:` commit (when one lands) would produce a `test-dashboard-v0.2.0` PR. Plan commits under `plans/**` do NOT trigger release-please.
- **xfail-first:** n/a (config, verified via dry-run script).
- **[not-blocked]**

---

## Area B — Data layer (Firestore + GCS)

### B1. Firestore collection shapes + security rules
- **Owner:** Jayce
- **Depends:** A1
- **ADR section:** §3
- **Files created:**
  - `dashboards/server/src/data/schema.ts` — TS types for `Run`, `Case`, `Artifact` per ADR §3
  - `dashboards/server/src/data/firestore.ts` — typed Firestore client wrapper
  - `firestore.rules` (or dashboards-scoped rules file) — deny all client reads/writes; service account only
  - `firestore.indexes.json` — composite indexes per ADR §3:
    - `runs (type, started_at desc)`
    - `runs (git_sha)`
    - `runs (environment, started_at desc)`
    - `cases (run_id)`
    - `cases (name, status)`
- **Acceptance criteria:**
  - `firebase emulators:start --only firestore` runs with rules; a direct client write is rejected; the service account client succeeds.
  - Index file lints via `firebase firestore:indexes --project myapps-b31ea` dry check.
- **xfail-first:** Vi writes `firestore-rules.xfail.test.ts` (Firestore rules unit test) asserting anonymous reads/writes are denied. Jayce flips it when rules land.
- **[not-blocked]**

### B2. GCS buckets + lifecycle rules
- **Owner:** Viktor
- **Depends:** none (infra-side, can run in parallel)
- **ADR section:** §5
- **Files created:**
  - `scripts/deploy/dashboards-bootstrap.sh` — idempotent bootstrap creating `strawberry-test-artifacts-prod`, `strawberry-test-artifacts-staging`, applying the 90-day lifecycle rule with a `pinned/` prefix exclusion
  - `dashboards/server/config/gcs-lifecycle.json` — the lifecycle policy JSON, referenced by the bootstrap
- **Acceptance criteria:**
  - Running the bootstrap twice is a no-op on the second run.
  - `gsutil lifecycle get gs://strawberry-test-artifacts-staging` returns the policy with the `pinned/` exclusion.
  - IAM on the Cloud Run service account scoped to these buckets only (not project-wide) — ADR §9.
- **xfail-first:** n/a (infra script; verified by integration test in Area H).
- **[not-blocked]**

### B3. Signed URL helpers (upload + download)
- **Owner:** Jayce
- **Depends:** B2
- **ADR section:** §4, §5
- **Files created:** `dashboards/server/src/storage/signed-urls.ts` — `createUploadUrl(runId, caseId, kind, mime, size)` (V4, 15min) and `createDownloadUrl(artifactId)` (V4, 15min)
- **Acceptance criteria:** Given a service-account key, unit test generates a URL whose parsed expiry is ~15min out and whose path matches `runs/<run_id>/<case_id>/<filename>`.
- **xfail-first:** Vi seeds `signed-urls.xfail.test.ts` asserting expiry ≤ 15min and correct path layout. Jayce flips.
- **[blocked-by-ekko]** for hook enforcement; code itself is **not-blocked**.

---

## Area C — Unit test infrastructure

### C1. Vitest setup for server and frontend
- **Owner:** Vi
- **Depends:** A1
- **ADR section:** §4 (unit reporter) · QA layer 3
- **Files created:**
  - `dashboards/server/vitest.config.ts`, `dashboards/test-dashboard/vitest.config.ts`
  - `dashboards/server/package.json#scripts.test:unit = "vitest run --reporter=json --outputFile=.test-results/unit.json"` (and a human-readable default `vitest run` for pre-commit)
  - Same for `dashboards/test-dashboard/`
  - `dashboards/server/src/__tests__/env-guard.test.ts` — asserts `fetch`/`http` imports throw in unit-test mode (QA layer 3 requirement)
- **Acceptance criteria:**
  - `pnpm -C dashboards/server test:unit` exits 0 on an empty suite.
  - JSON reporter output shape matches what `scripts/report-run.sh` will consume (task D1).
  - Full suite under 60s per QA layer 3 budget (trivially met while empty).
- **xfail-first:** self-referential — task meta-xfail is a placeholder test `it.failing('unit framework wired')` that flips to `pass` once the config lands.
- **[not-blocked]**

### C2. Pre-commit hook wiring for unit tests
- **Owner:** Ekko (coordinate — Pyke rule 3 / §5 step 1)
- **Depends:** C1
- **ADR section:** §4 (unit: pre-commit, fire-and-forget ingestion)
- **Files touched:**
  - `scripts/hooks/pre-commit-unit-tests.sh` (Ekko authors per Pyke plan)
  - `scripts/install-hooks.sh` (extended to install the new hook alongside existing secrets/chore guards)
- **Acceptance criteria:** Per Pyke rule 3 — staged change under `dashboards/server/src/**` causes `pnpm -C dashboards/server test:unit` to run on commit; non-zero exit blocks the commit; unchanged packages no-op.
- **xfail-first:** Ekko's own test per Pyke plan.
- **Blocker note:** All downstream unit-ingestion tasks (D2) wait on this.

---

## Area D — Ingestion

### D1. Shared reporter normalizer `scripts/report-run.sh`
- **Owner:** Jayce
- **Depends:** C1
- **ADR section:** §4 ("reporter abstraction")
- **Files created:** `scripts/report-run.sh <reporter-json-path> <type>` — POSIX-portable bash (CLAUDE.md rule 10). Reads the framework JSON, normalizes to the `POST /api/runs` body, reads `INGEST_TOKEN` from env, POSTs, captures signed URLs, PUTs artifacts in parallel, calls `/finalize`.
- **Acceptance criteria:**
  - `bash scripts/report-run.sh fixtures/vitest-sample.json unit` hits a local dashboard and creates a run.
  - Script times out at 2s on the initial POST when `<type>` is `unit` (ADR §13 fire-and-forget).
  - Script soft-fails (exit 0 with stderr warning) when `<type>` is `e2e` (ADR §4 Playwright wiring — soft-fail per §13).
  - Runs on both macOS bash 3.2 and Git Bash on Windows.
- **xfail-first:** Vi adds `scripts/__tests__/report-run.xfail.bats` (bats-core) asserting the three behaviors above. Jayce flips.
- **[blocked-by-ekko]** only for the CI invocation path; the script itself is **not-blocked**.

### D2. `POST /api/runs` — create run + cases, return upload URLs
- **Owner:** Jayce
- **Depends:** B1, B3
- **ADR section:** §4, §6
- **Files touched:**
  - `dashboards/server/src/api/v1/runs.create.ts`
  - `dashboards/server/src/api/v1/index.ts` (router mount under `/api/v1/runs`)
- **Acceptance criteria:**
  - Transactional Firestore write of the run and all cases (single batch).
  - Returns `{ run_id, artifact_upload_urls: { [local_ref]: signed_url } }`.
  - Returns 401 without the ingest token; 401 with a wrong token (constant-time compare per ADR §7).
  - Rejects unknown `type` values (400, error shape per ADR §6).
- **xfail-first:** Vi adds `runs.create.xfail.test.ts` covering happy path + auth + validation. Jayce flips.
- **[blocked-by-ekko]** for pre-push TDD gate; code itself **not-blocked**.

### D3. `POST /api/runs/:id/finalize` — flip run to terminal status
- **Owner:** Jayce
- **Depends:** D2
- **ADR section:** §4
- **Files touched:** `dashboards/server/src/api/v1/runs.finalize.ts`
- **Acceptance criteria:**
  - Transitions `status` from initial to terminal (`pass|fail|error|skipped`) based on aggregated case statuses.
  - Idempotent — second call with the same terminal status is a no-op 200.
  - 404 with error shape if run id is unknown.
- **xfail-first:** Vi authors the xfail.
- **[blocked-by-ekko]** downstream; code **not-blocked**.

### D4. `PATCH /api/runs/:id` — pin/unpin + metadata edits
- **Owner:** Jayce
- **Depends:** D2
- **ADR section:** §5 (pin override), §6
- **Files touched:** `dashboards/server/src/api/v1/runs.patch.ts`
- **Acceptance criteria:**
  - `{ pin: true }` moves all run artifacts under `gs://.../pinned/<run_id>/...` so the lifecycle rule excludes them.
  - Metadata merge semantics.
  - Requires Firebase user auth (Duong UID), not ingest token — this is a UI operation.
- **xfail-first:** Vi authors.
- **[blocked-by-ekko]** downstream.

---

## Area E — Read API

### E1. Read endpoints (`GET /api/runs`, `/api/runs/:id`, `/api/commits/:sha/runs`, `/api/types/:type`)
- **Owner:** Jayce
- **Depends:** B1
- **ADR section:** §6
- **Files touched:**
  - `dashboards/server/src/api/v1/runs.read.ts`
  - `dashboards/server/src/api/v1/commits.read.ts`
- **Acceptance criteria:**
  - `GET /api/runs?type=unit&env=local&limit=50` returns paginated runs, uses the `(type, started_at desc)` index.
  - `GET /api/runs/:id` returns `{ run, cases }`.
  - `GET /api/commits/:sha/runs` returns all runs for a git sha (PR view).
  - Requires Firebase ID token with UID in allowlist (ADR §7). 403 otherwise.
- **xfail-first:** Vi authors per-endpoint xfail tests.
- **[blocked-by-ekko]** downstream.

### E2. Artifact redirect endpoint (`GET /api/runs/:id/artifacts/:aid`)
- **Owner:** Jayce
- **Depends:** B3, E1
- **ADR section:** §5, §6
- **Files touched:** `dashboards/server/src/api/v1/artifacts.redirect.ts`
- **Acceptance criteria:** 302 to a fresh 15-min signed download URL. 410 Gone if the artifact is past lifecycle expiry (GCS returns 404 → service returns 410 per ADR §3 retention).
- **xfail-first:** Vi authors.

### E3. Health + version (`/api/health`, `/api/version`)
- **Owner:** Jayce
- **Depends:** A1
- **ADR section:** §6, §9 (smoke gate)
- **Files touched:** `dashboards/server/src/api/v1/health.ts`
- **Acceptance criteria:**
  - `/api/health` — 200, no auth.
  - `/api/version` — returns `{ version, sha, builtAt }` injected at container build time via env.
- **xfail-first:** already covered by A1 xfail; expand to include `/api/version`.
- **[not-blocked]**

---

## Area F — Auth

### F1. Ingest token middleware
- **Owner:** Viktor
- **Depends:** A1
- **ADR section:** §7
- **Files touched:**
  - `dashboards/server/src/auth/ingest-token.ts` — constant-time bearer-compare against `INGEST_TOKEN` env
  - Mount as middleware on POST /api/v1/runs, /finalize
- **Acceptance criteria:** Unit tests verify constant-time path (timing-safe equal), missing header = 401, wrong token = 401, right token = next().
- **xfail-first:** Vi authors.
- **[not-blocked]**

### F2. Firebase ID token middleware + UID allowlist
- **Owner:** Viktor
- **Depends:** A1
- **ADR section:** §7
- **Files touched:**
  - `dashboards/server/src/auth/firebase.ts` — Admin SDK verification, reads `ALLOWED_UIDS` env (CSV)
  - Mount on GET /api/v1/runs, :id, commits, types, PATCH :id
- **Acceptance criteria:** Valid token from an allowlisted UID → next(). Token for a non-allowlisted UID → 403. Expired/invalid token → 401.
- **xfail-first:** Vi authors.
- **[not-blocked]**

### F3. CORS configuration
- **Owner:** Viktor
- **Depends:** F1, F2
- **ADR section:** §7
- **Files touched:** `dashboards/server/src/middleware/cors.ts`
- **Acceptance criteria:**
  - UI origin allowed for GET/PATCH routes.
  - Ingestion routes deny CORS preflight (server-to-server only) — Origin header absent or rejected.
- **xfail-first:** Vi authors.
- **[not-blocked]**

### F4. Secrets wiring — encrypted env bundle
- **Owner:** Viktor
- **Depends:** A1
- **ADR section:** §4, §9
- **Files created:**
  - `secrets/env/dashboards.myapps-b31ea.env.age` (encrypted, contains `INGEST_TOKEN`, `FIREBASE_PROJECT_ID`, `GCS_BUCKET`, `ALLOWED_UIDS`)
  - `secrets/env/test-dashboard-ingest.env.age` (encrypted, contains the same `INGEST_TOKEN` for local reporter use)
  - `tools/decrypt.sh` invocation documented in `dashboards/server/README.md` — never `age -d` directly (CLAUDE.md rule 6)
- **Acceptance criteria:** `bash -c 'eval "$(tools/decrypt.sh secrets/env/dashboards.myapps-b31ea.env.age)"; env | grep INGEST_TOKEN'` shows the token without leaking to parent shell or history. Pre-commit hook does not flag the ciphertext.
- **xfail-first:** n/a (ops) — verified by Vi via a hook-compliance bats test.
- **[not-blocked]**

---

## Area G — Frontend (test-dashboard)

All Seraphine tasks. Each xfail-first with Vi authoring React Testing Library skeletons.

### G1. Routing skeleton + layout
- **Owner:** Seraphine
- **Depends:** A1, E1 (for live data, mockable initially)
- **ADR section:** §8
- **Files created:**
  - `dashboards/test-dashboard/src/App.tsx` — router setup (TanStack Router or React Router)
  - `dashboards/test-dashboard/src/routes/{index,run,commit,type,login}.tsx`
  - Tailwind config initial pass (`tailwind.config.ts`, `postcss.config.js`, base CSS)
- **Acceptance criteria:**
  - Routes render distinct placeholders.
  - `/monitoring/*` is NOT claimed by a catch-all (ADR §10 namespace reservation). Unknown paths under `/monitoring/*` → explicit 404 component, not the test-dashboard shell.
- **xfail-first:** Vi authors `App.xfail.test.tsx` asserting routes render expected headings and `/monitoring/foo` does not render the test-dashboard shell.

### G2. Login page + Firebase Auth integration
- **Owner:** Seraphine
- **Depends:** G1, F2
- **ADR section:** §7, §8
- **Files created:**
  - `dashboards/test-dashboard/src/auth/firebase-client.ts` — Firebase web SDK init (reads `myapps-b31ea` config from Vite env)
  - `dashboards/test-dashboard/src/auth/useAuth.ts` — hook exposing `user`, `idToken`, `signIn`, `signOut`
  - `dashboards/test-dashboard/src/routes/login.tsx` — Google sign-in button
- **Acceptance criteria:** Non-signed-in user hitting `/` is redirected to `/login`. Successful Google sign-in with Duong's UID lands on `/`. Non-allowlisted UID lands on a 403 page.
- **xfail-first:** Vi authors RTL tests for each of the three paths using a mocked auth provider.

### G3. TanStack Query client + API fetcher with ID token
- **Owner:** Seraphine
- **Depends:** G2
- **ADR section:** §8
- **Files created:**
  - `dashboards/test-dashboard/src/api/client.ts` — wraps fetch, attaches `Authorization: Bearer <idToken>`, handles 401 → signOut
  - `dashboards/test-dashboard/src/api/queries.ts` — `useRunsList`, `useRun`, `useCommitRuns`, `useTypeRuns`
- **Acceptance criteria:** Query hooks compile against E1 response shapes; 401 triggers a sign-out flow; request retry respects TanStack Query defaults.
- **xfail-first:** Vi authors.

### G4. Runs list page (`/`)
- **Owner:** Seraphine
- **Depends:** G3
- **ADR section:** §8
- **Files created:** `dashboards/test-dashboard/src/routes/index.tsx`, `components/RunRow.tsx`, `components/Filters.tsx`
- **Acceptance criteria:** Renders recent runs across all types; filter chips for `type` and `environment`; pass/fail/error status visible; clicking a row navigates to `/runs/:id`. Matches ADR Phase 1 exit criterion: a new unit run visible within 5 seconds (query refetch or polling — picked by implementer).
- **xfail-first:** Vi authors.

### G5. Run detail page (`/runs/:id`)
- **Owner:** Seraphine
- **Depends:** G3, E1, E2
- **ADR section:** §8
- **Files created:** `dashboards/test-dashboard/src/routes/run.tsx`, `components/CaseTree.tsx`, `components/ArtifactPlaceholder.tsx`
- **Acceptance criteria:**
  - Case tree grouped by `case.suite`.
  - Artifact list shows kind + size + a lazy "open" link that hits E2 on demand (not on page load — ADR §5 access model).
  - Failing cases show `failure_message` (no stack in Phase 1 — deferred visual).
- **xfail-first:** Vi authors.

### G6. Commit view (`/commits/:sha`) and type view (`/types/:type`)
- **Owner:** Seraphine
- **Depends:** G3
- **ADR section:** §8
- **Files created:** `dashboards/test-dashboard/src/routes/commit.tsx`, `routes/type.tsx`
- **Acceptance criteria:** Both pages render filtered run lists reusing `RunRow`. `/types/smoke` is the view the Phase 1 exit criterion's smoke ingestion lands on.
- **xfail-first:** Vi authors.

---

## Area H — Ingestion wiring (unit + smoke)

### H1. Unit test reporter wiring (pre-commit fire-and-forget)
- **Owner:** Viktor
- **Depends:** C2 (Ekko's pre-commit hook), D1, D2
- **ADR section:** §4 (unit row)
- **Files touched:**
  - Extend `scripts/hooks/pre-commit-unit-tests.sh` to invoke `scripts/report-run.sh .test-results/unit.json unit &` after the test run (backgrounded, 2s timeout on the initial POST)
  - `dashboards/server/README.md` documents that the hook runs AFTER the tests so failed tests block the commit while still reporting what ran.
- **Acceptance criteria:**
  - Successful test run on a staged commit produces a Firestore `runs` document with `trigger.source = "pre-commit"` and `environment = "local"` within 5s.
  - Dashboard unreachable → commit still succeeds; stderr warning logged; no hook blocking.
- **xfail-first:** Vi authors a bats integration test with a mock HTTP listener.
- **[blocked-by-ekko]**

### H2. Smoke test reporter wiring (post-deploy)
- **Owner:** Viktor
- **Depends:** D1, D2, E3
- **ADR section:** §4 (smoke row), §9
- **Files touched:**
  - `scripts/deploy/smoke.sh` — extend (or create per deployment-pipeline ADR §7a) to call `scripts/report-run.sh` with `<type>=smoke` after assertions run
  - Include assertions against `/api/health` and `/api/version` (ADR §9 smoke extension)
- **Acceptance criteria:**
  - After a `scripts/deploy/dashboards.sh` run against staging, a run with `type=smoke`, `environment=staging`, and matching `git_sha` appears in `/types/smoke` within 10s.
  - Smoke failure still reports the run (with `status=fail`) before the rollback step runs (ordering matters for forensics).
- **xfail-first:** Vi authors a shell-level integration test against the emulator.
- **[blocked-by-ekko]** for TDD gate; script **not-blocked**.

---

## Area I — Deploy wiring

### I1. `scripts/deploy/dashboards.sh`
- **Owner:** Viktor
- **Depends:** A1, A2, F4
- **ADR section:** §9
- **Files created:** `scripts/deploy/dashboards.sh` — POSIX bash; builds both frontends (`dashboards/test-dashboard` for real, `dashboards/dashboard` as a stub), copies bundles to `dashboards/server/public/{test,monitoring}/`, builds the server container, pushes to Artifact Registry, deploys to Cloud Run
- **Acceptance criteria:**
  - Idempotent — two successive runs produce the same deployed revision hash (no spurious redeploys).
  - Respects `--project=<myapps-b31ea|...>` flag.
  - Emits a `logs/deploy-audit.jsonl` line with `surface: "test-dashboard"` (ADR §9 audit integration).
  - Runs on macOS and Git Bash (CLAUDE.md rule 10).
- **xfail-first:** Vi authors a bats test that asserts idempotency with a mock `gcloud` on `$PATH`.
- **[not-blocked]**

### I2. Cloud Run service account IAM
- **Owner:** Viktor
- **Depends:** B2
- **ADR section:** §9
- **Files touched:** `scripts/deploy/dashboards-iam.sh` — grants `datastore.user`, scoped `storage.objectAdmin` on test-artifact buckets only, `firebaseauth.admin`
- **Acceptance criteria:** `gcloud projects get-iam-policy` after the script shows the exact three role bindings; no project-wide `storage.objectAdmin`.
- **xfail-first:** n/a (infra).
- **[not-blocked]**

### I3. Container build config (Dockerfile, static asset mounting)
- **Owner:** Jayce
- **Depends:** G1 (frontend build output), E1–E3 (server routes)
- **ADR section:** §2a, §8
- **Files created:** `dashboards/server/Dockerfile` — multi-stage: build both frontends, copy to `/app/public/{test,monitoring}/`, bundle server, CMD node dist/index.js
- **Acceptance criteria:**
  - Resulting image serves `/` from `public/test/index.html`, `/monitoring/*` from `public/monitoring/*` (returns 404 body from the dashboard frontend stub in Phase 1), `/api/*` from the server.
  - Image size under 250MB.
- **xfail-first:** Vi authors a container-level smoke test using docker run + curl.
- **[not-blocked]**

### I4. Release-please smoke extension
- **Owner:** Viktor
- **Depends:** H2, I1
- **ADR section:** §9
- **Files touched:** `scripts/deploy/smoke.sh` entries for the dashboard (`/api/health`, `/api/version`, one list-runs round-trip using a test-only ingest token).
- **Acceptance criteria:** `scripts/deploy/smoke.sh --surface test-dashboard --env staging` exits 0 against a healthy deploy, non-zero on any failed assertion.
- **xfail-first:** covered by H2 xfail.
- **[blocked-by-ekko]** downstream, not code-blocked.

---

## Area J — Regression test lane (QA layer 2 prep)

### J1. `tests/regression/` scaffold + PR template
- **Owner:** Vi
- **Depends:** none
- **ADR section:** n/a · QA layer 2 · Pyke rule 13
- **Files created:**
  - `tests/regression/.gitkeep`
  - `.github/pull_request_template.md` — add Testing section with "Regression test linked: <path>" checkbox and xfail SHA fields per QA layer 1 + 2
- **Acceptance criteria:** The PR template renders; `tests/regression/` exists and is documented in `architecture/testing.md` (to be created by Ekko per Pyke §5 step 1).
- **xfail-first:** self-referential — Vi's own regression test reproducing a deliberately seeded no-op bug, proving the lane works.
- **[not-blocked]**

---

## Parallelism map

These can run in parallel after scaffolding (A1):

- Track 1 (data layer): B1 → B3 → (D2, D3, D4)
- Track 2 (infra): B2 → I2; I1 → I3 → I4
- Track 3 (auth): F1, F2, F3, F4 all independent after A1
- Track 4 (frontend): G1 → G2 → G3 → (G4, G5, G6 parallel)
- Track 5 (tests/scripts): C1 → D1 → (H1 after C2, H2 after I1)
- Track 6 (QA lanes): J1 independent

Critical path: A1 → C1 → Ekko's C2 → H1 (Phase 1 exit criterion's "unit run visible" hinges on this). Parallel critical path: A1 → I1 → H2 (smoke visible).

## Explicit blockers summary

**Blocked by Ekko** (cannot fully close without hooks + `tdd-gate.yml`): C2, D1's CI path, D2, D3, D4, E1, E2, H1, H2, I4.

Work around: implementers proceed locally; Vi's xfails carry the discipline by convention; Ekko's hooks become authoritative on arrival. Do not land a `main` PR with a TDD-enabled package until Ekko's hooks are in place — the pre-push will fail once installed and we don't want a waiver-heavy history from the start.

**Not blocked:** A1, A2, B1, B2, B3, C1, F1, F2, F3, F4, G1–G6 (under xfail discipline), I1, I2, I3, J1.

## Out of scope (Phase 2 and beyond)

- Playwright E2E reporter wiring (QA layer 4) — deferred.
- QA pre-PR bundler (QA layer 5) — deferred; the `dashboards/server/config/qa-flows.yaml` path is reserved only.
- Artifact gallery UX (video player, trace viewer) — Phase 2.
- `GET /api/v1/deploys` read adapter — Phase 3.
- `dashboards/dashboard/` monitoring frontend — Phase 3.
- Flakiness quarantine lane, coverage tracking — QA plan layers tracked but not executed in Phase 1.

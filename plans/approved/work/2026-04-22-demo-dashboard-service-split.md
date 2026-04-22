---
status: approved
orianna_gate_version: 2
complexity: complex
concern: work
owner: sona
created: 2026-04-22
tags:
  - demo-studio
  - dashboard
  - cloud-run
  - infrastructure
  - split
  - work
tests_required: true
orianna_signature_approved: "sha256:08680989be8d4ec670b0a0563746e5d050500d9883d009b192355664960425b8:2026-04-22T08:40:07Z"
orianna_signature_in_progress: "sha256:08680989be8d4ec670b0a0563746e5d050500d9883d009b192355664960425b8:2026-04-22T09:08:30Z"
---

# ADR: Split `/dashboard` out of demo-studio-v3 into a new Cloud Run service

<!-- orianna: ok — all file-path tokens in this plan (main.py, deploy.sh, Dockerfile, requirements.txt, secrets-mapping.txt, dashboard.html, session.py, session_store.py, firebase_auth.py, auth.py, tools/demo-dashboard/*, tools/demo-studio-v3/*) reference files inside the missmp/company-os work workspace under company-os/tools/demo-studio-v3/ or the new company-os/tools/demo-dashboard/, not strawberry-agents files -->
<!-- orianna: ok — HTTP path tokens (/dashboard, /dashboard/refresh, /api/service-health/{name}/health, /api/test-results, /api/test-run-history, /api/managed-sessions, /test-dashboard, /healthz, /health, /auth/config, /auth/login, /auth/logout, /auth/me) are routes on Cloud Run services, not filesystem paths -->
<!-- orianna: ok — env-var names (BASE_URL, CONFIG_MGMT_URL, FACTORY_URL, VERIFICATION_URL, PREVIEW_URL, DEMO_STUDIO_URL, FIREBASE_PROJECT_ID, ALLOWED_EMAIL_DOMAIN, SESSION_SECRET, INTERNAL_SECRET, COOKIE_SECURE) are env vars, not filesystem paths -->
<!-- orianna: ok — Cloud Run tokens (demo-studio-v3, demo-studio-mcp, demo-dashboard, demo-runner-sa, europe-west1, mmpt-233505, europe-west1-docker.pkg.dev) are GCP resource names, not filesystem paths -->
<!-- orianna: ok — external refs (google-cloud-firestore, firebase-admin, uvicorn, FastAPI) are library names, not files -->

## 1. Context

`demo-studio-v3` (S1) currently hosts two distinct surfaces:

1. **Per-session studio** — `/`, `/session/{sid}`, `/session/{sid}/*` (chat, stream,
   build, logs, …). Operator-facing, owner-scoped auth (post-Loop 2c).
2. **Dashboard + admin** — `/dashboard`, `/api/service-health/*`,
   `/api/test-results`, `/api/test-run-history`, `/api/managed-sessions`,
   `/test-dashboard`. Team-wide read surface.

Both live in one `main.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> (3249 lines, `mmp/workspace/tools/demo-studio-v3/main.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->). Coupling them has three costs:

- **Scaling mismatch.** Dashboard is low-RPS always-on; studio spikes with chat/SSE. Single service forces worst-case sizing.
- **Auth surface conflict.** Dashboard is team-wide read; studio routes are owner-scoped (per parent Firebase ADR §3.4). Two dependency ladders in one process.
- **Deploy cadence.** A session-regression rollback shouldn't take the dashboard with it.

Duong's proposal: reuse the (retiring) `demo-studio-mcp` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> Cloud Run slot by renaming it. Renaming is not supported — Cloud Run service names are immutable. Instead we create a new `demo-dashboard` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> service in `europe-west1 / mmpt-233505` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> and plan to delete `demo-studio-mcp` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> once the MCP retirement (`plans/proposed/work/2026-04-21-demo-studio-mcp-retirement.md` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->) lands.

## 2. Decision

Create a new Cloud Run service `demo-dashboard` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> in `europe-west1 / mmpt-233505` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->, container-image deploy (parity with S1–S5 tooling). Migrate the dashboard + admin routes out of S1. Defer Firebase auth wiring to a follow-on wave after Loop 2b (frontend sign-in) lands, so dashboard inherits the same identity the studio does — no auth wired twice.

### 2.1 Routes that move to `demo-dashboard`

| Route | Source (S1 main.py line) | Moves |
|---|---|---|
| `GET /dashboard` | 823 | ✓ |
| `POST /dashboard/refresh` | 855 | ✓ |
| `GET /api/service-health/{name}/health` | 774 | ✓ (Loop 1 proxy) |
| `GET /api/test-results` | 949 | ✓ |
| `GET /api/test-run-history` | 996 | ✓ |
| `GET /test-dashboard` | 1013 | ✓ |
| `GET /api/managed-sessions` | 3128 | ✓ |
| `POST /api/managed-sessions/{managed_session_id}/terminate` | 3243 | ✓ |

S1 keeps everything else. Nothing else depends on these handlers.

### 2.2 Routes that stay in S1

`/`, `/healthz`, `/health`, `/debug`, `/logs`, `/auth/*`, `/session/*`, `/mcp`, `/static/*`, lifespan code, chat/stream/build/verification callbacks. Unchanged.

### 2.3 Cross-service dependencies after split

- **Firestore.** Both services read sessions from `demo-studio-sessions` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> collection. Dashboard is read-only; studio is read-write. IAM: `demo-dashboard` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> runtime SA gets `roles/datastore.user` <!-- orianna: ok -- IAM role string, not a filesystem path --> (or a narrower `demo-studio-sessions`-only custom role if we want to be strict later).
- **S2–S5 health.** Dashboard is the only caller of the Loop 1 proxy. Moves cleanly.
- **Test-results data.** `/api/test-results` + `/api/test-run-history` read `test-results.json` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> and `test-run-history.json` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> as local files today. Two options:
  1. (short-term) bundle stale copies into the dashboard image,
  2. (correct) persist to Firestore or GCS so both services agree.
  This plan picks option 2 as a W2 task — the current local-file scheme is already broken for multi-instance S1.

### 2.4 Auth wiring — deferred to W4

Through W1–W3, dashboard routes stay behind the existing `require_session` dep OR are temporarily unauthenticated on a private Cloud Run (ingress=internal). Once Loop 2b (frontend sign-in) + 2c (route migration) land, dashboard gets `require_user` (team-wide `@missmp.tech` read per OQ 3 of parent ADR). No auth logic is written twice — all Firebase code lives in `firebase_auth.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->, imported by both services as a shared file (phase 1 via copy, phase 2 via a shared package once we have two consumers).

### 2.5 Service split diagram

    Before:
      [browser] ── /session/* ──► demo-studio-v3 ── Firestore
                ── /dashboard ─┘               └── S2-S5 proxy
                ── /api/* ─────┘

    After:
      [browser] ── /session/*   ──► demo-studio-v3  ── Firestore (rw)
                ── /dashboard    ──► demo-dashboard  ── Firestore (ro)
                ── /api/*                            └── S2-S5 upstream (via same proxy)

## 3. Architecture impact

- **New** `tools/demo-dashboard/` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> — FastAPI app, Dockerfile, deploy.sh, requirements.txt, secrets-mapping.txt, tests/.
- **Shared code (phase 1, via copy)** — `firebase_auth.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->, `auth.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> helpers, logger. Factor into a shared package in a follow-up once both services stabilize.
- **Removed from S1** — all routes in §2.1; `dashboard.html` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> (template) and any JS assets exclusive to dashboard.
- **deploy.sh pattern** — copy `mmp/workspace/tools/demo-studio-v3/deploy.sh` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> (28 lines) as template; adapt service name, env vars, secret mappings. Cloud Build + Artifact Registry pipeline reused.
- **No changes to Firestore schema.** Dashboard is pure read of existing fields.

## 4. Scope

- **In:** new service scaffolding, migrated routes, new deploy pipeline, Playwright verify, S1 cleanup of migrated routes.
- **Out:**
  - Firebase auth wiring (W4 picks it up; gated on Loop 2b+2c landing).
  - Custom domain mapping (`dashboard.mmp.tech` <!-- orianna: ok -- prospective external domain, not a local path --> or similar) — follow-up when IAM has the domain.
  - `demo-studio-mcp` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> deletion (separate MCP retirement ADR).
  - Firestore custom role narrower than `roles/datastore.user` <!-- orianna: ok -- IAM role string, not a filesystem path --> — later hardening.
  - Batching / GraphQL for the managed-sessions API — no change this split.

## Test plan

### Unit tests (new, in `tools/demo-dashboard/tests/` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->)

- `test_service_health_proxy.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> — mirror of the existing S1 test file (9 cases). Copy verbatim after the route moves; import target becomes dashboard's `main`.
- `test_dashboard_render.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> — GET /dashboard returns 200 + injects `window.__serviceUrls` with relative proxy paths (same assertion the S1 test makes today).
- `test_api_test_results.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> — GET /api/test-results returns parsed JSON; Firestore (or GCS) read path mocked.
- `test_api_managed_sessions.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> — GET /api/managed-sessions returns list; terminate endpoint gates on cookie (or internal-secret in phase 1).

All xfail-first (Rule 12) — committed as xfail on `feat/demo-dashboard-split` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->, flipped green once the new service's `main.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> lands.

### Integration

- Local `uvicorn main:app --port 8090` for dashboard; S1 stays on 8080. Curl the migrated endpoints against 8090; verify identical JSON/HTML body shape to S1.
- S1 test regression — after routes removed from S1, S1's test suite stays green; no orphaned tests covering migrated routes.

### Playwright E2E

- Dashboard card grid renders 5/5 UP against the live `demo-dashboard` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> local service, same assertions as the Loop 1 QA report.
- `/api/test-results` + `/api/test-run-history` return JSON to the dashboard.js client without CORS errors.

### Deploy smoke (W5)

- `curl https://<dashboard-url>/healthz` → 200.
- Dashboard loaded in browser against staging Cloud Run renders card grid.

## 5. Waves

| Wave | Scope | Deps |
|---|---|---|
| **W1** Scaffold | New folder `tools/demo-dashboard/` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> — Dockerfile, deploy.sh, requirements.txt, main.py skeleton (just `GET /healthz`), empty tests dir. Local `uvicorn` runs on port 8090. | clean |
| **W2** Route migration | Move the 8 routes (§2.1) + `dashboard.html` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> + shared helpers (logger, Firestore read client, `_wants_html`, service-health proxy helpers). xfail-first tests for each. Move `test-results.json` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> / `test-run-history.json` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> source of truth to Firestore (or accept temporary local-file duplication with a follow-up task). | W1 |
| **W3** S1 cleanup | Remove the 8 routes from S1 `main.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. Update S1 tests to drop now-irrelevant cases. Both services stand alone. | W2 |
| **W4** Firebase auth wire-up | After Loop 2b + 2c land: dashboard migrates from legacy cookie to `require_user`. `firebase_auth.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> copied into dashboard folder (or factored to shared package). | Loop 2b, 2c complete |
| **W5** Deploy | First push to Cloud Run `europe-west1 / mmpt-233505` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> via `deploy.sh` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. Artifact Registry image. Ingress: internal-and-cloud-load-balancing initially; flip to all after auth lands in W4. | W3 |
| **W6** Cutover + retire MCP | Remove dashboard links that point to S1 (`{BASE_URL}/dashboard`) in any wiring; update to `{DEMO_DASHBOARD_URL}/dashboard`. Delete `demo-studio-mcp` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> per the MCP retirement ADR. | W5 + MCP retirement |

## 6. Risks

- **Code duplication.** `firebase_auth.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->, logger, Firestore read client are copied into the dashboard folder in W2. Mitigation: factor into a shared Python package (`tools/_shared/` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> or similar) in a follow-up ADR once both services are stable. Accepted tech debt for the split PR.
- **test-results.json data source.** Current local-file scheme is already broken for multi-instance S1 — we flush this to Firestore in W2 regardless. Risk: schema churn between old and new readers during cutover. Mitigation: freeze test-results writes on S1 side for the cutover window (hours, not days).
- **Deploy cost.** New Cloud Run service = min-instances=0 default (same as S1), $0 idle. Negligible.
- **IAM drift.** Dashboard SA needs `roles/datastore.user` <!-- orianna: ok -- IAM role string, not a filesystem path -->. Mitigation: explicit `gcloud projects add-iam-policy-binding` in deploy.sh comments; Ekko runs it once pre-W5.
- **Split regression on dashboard.** Playwright E2E against the new service before W5 prod cutover. Any mismatch surfaces before real traffic.

## 7. Open questions

1. **Should `demo-dashboard` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> use the same `demo-runner-sa` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> runtime SA as S1, or a scoped `demo-dashboard-sa`?** Default to same SA for W5; tighten to scoped SA in a follow-up once IAM separation is needed.
2. **Custom domain (`dashboard.mmp.tech` <!-- orianna: ok -- prospective external domain, not a local path --> or subfolder on the main domain)?** Deferred — not in this plan's scope. `*.run.app` URL is fine for internal tooling.
3. **Keep `/test-dashboard` as a separate HTML route, or fold into `/dashboard` tabs?** Keep separate for this split — minimize code churn. Revisit after merge.
4. **Freeze the S1 `test-results.json` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> writer during cutover, or dual-write through W3?** Freeze — simplest and the window is short.

## Tasks

<!-- orianna: ok — all file paths in T.W*.* tasks reference files inside company-os/tools/demo-dashboard/ and company-os/tools/demo-studio-v3/ within the work workspace; not strawberry-agents local files -->

### Coordination

- [ ] **T.COORD.1** — Duong reviews §2 routes-that-move table and §7 open questions; answers OQ 1 and OQ 4 before W2 starts. estimate_minutes: 15
- [ ] **T.COORD.2** — Ekko runs one-time IAM grant on the new `demo-dashboard` runtime SA (`roles/datastore.user` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> on project `mmpt-233505`) before W5. estimate_minutes: 10
- [ ] **T.COORD.3** — Senna + Lucian review the W3 cleanup PR (removal from S1). estimate_minutes: 30
- [ ] **T.COORD.4** — Akali runs the W5 Playwright smoke against staging and prod `demo-dashboard`. estimate_minutes: 20

### Wave 1 — Scaffold

- [ ] **T.W1.1** — Create folder `tools/demo-dashboard/` with `Dockerfile` copied from `mmp/workspace/tools/demo-studio-v3/Dockerfile`, unchanged except for filename. estimate_minutes: 5. Files: `tools/demo-dashboard/Dockerfile` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: `docker build` succeeds on the skeleton.
- [ ] **T.W1.2** — Create `tools/demo-dashboard/requirements.txt` with only the deps the dashboard actually needs — fastapi, uvicorn, google-cloud-firestore, httpx, itsdangerous, jinja2, pillow. Drop anthropic, mcp, pytest-timeout. estimate_minutes: 5. Files: `tools/demo-dashboard/requirements.txt` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: `pip install -r requirements.txt` clean in fresh venv.
- [ ] **T.W1.3** — Create `tools/demo-dashboard/main.py` skeleton with just `app = FastAPI()`, `GET /healthz` → `{"status":"ok"}`, and startup/shutdown hooks. estimate_minutes: 10. Files: `tools/demo-dashboard/main.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: `uvicorn main:app --port 8090` serves `/healthz` 200 locally.
- [ ] **T.W1.4** — Create `tools/demo-dashboard/deploy.sh` copied from S1's deploy.sh with service name → `demo-dashboard`, region `europe-west1`. estimate_minutes: 10. Files: `tools/demo-dashboard/deploy.sh` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: dry-run `bash deploy.sh --dry-run` (or `--help`) renders expected gcloud command.
- [ ] **T.W1.5** — Create `tools/demo-dashboard/secrets-mapping.txt` with only the secrets the dashboard uses (no ANTHROPIC_API_KEY, no FIREBASE_SERVICE_ACCOUNT_JSON unless we stick with JSON fallback). estimate_minutes: 5. Files: `tools/demo-dashboard/secrets-mapping.txt` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: file exists with stable format.
- [ ] **T.W1.6** — Create `tools/demo-dashboard/tests/conftest.py` + empty `tests/` folder; reuse the sys.path shim from S1's conftest. estimate_minutes: 5. Files: `tools/demo-dashboard/tests/conftest.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: `pytest tools/demo-dashboard -q` discovers 0 tests, 0 errors.
- [ ] **T.W1.7** — Scaffold commit on branch `feat/demo-dashboard-split` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->; push. estimate_minutes: 5. Files: (git only). DoD: branch on origin.

### Wave 2 — Route migration

- [ ] **T.W2.1** — Write xfail `tools/demo-dashboard/tests/test_service_health_proxy.py` as a copy of S1's same-named file, targeting dashboard's `main`. estimate_minutes: 10. Files: `tools/demo-dashboard/tests/test_service_health_proxy.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: 9 xfails.
- [ ] **T.W2.2** — Copy `GET /api/service-health/{name}/health` + helpers from S1 to dashboard `main.py`; flip xfails green. estimate_minutes: 15. Files: `tools/demo-dashboard/main.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: 9 pass.
- [ ] **T.W2.3** — Write xfail `tools/demo-dashboard/tests/test_dashboard_render.py` (GET /dashboard 200 + `window.__serviceUrls` injection with relative proxy paths). estimate_minutes: 10. Files: `tools/demo-dashboard/tests/test_dashboard_render.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: 2 xfails.
- [ ] **T.W2.4** — Copy `GET /dashboard` + `POST /dashboard/refresh` handlers + `dashboard.html` template from S1 to dashboard. estimate_minutes: 30. Files: `tools/demo-dashboard/main.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->, `tools/demo-dashboard/templates/dashboard.html` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: xfails flip green; local 8090/dashboard renders card grid.
- [ ] **T.W2.5** — Write xfail `tools/demo-dashboard/tests/test_api_test_results.py` (GET /api/test-results + /api/test-run-history, Firestore read mocked). estimate_minutes: 15. Files: `tools/demo-dashboard/tests/test_api_test_results.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: 4 xfails.
- [ ] **T.W2.6** — Migrate test-results storage from local JSON files to Firestore (collection `demo-studio-test-results` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->). S1 writer updated in T.W3.3 to match. estimate_minutes: 45. Files: `tools/demo-dashboard/main.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->, `tools/demo-dashboard/test_results_store.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> (new). DoD: xfails flip green; local reads return recent runs.
- [ ] **T.W2.7** — Write xfail `tools/demo-dashboard/tests/test_api_managed_sessions.py` (list + terminate; auth gate is internal-secret in phase 1, `require_user` in W4). estimate_minutes: 15. Files: `tools/demo-dashboard/tests/test_api_managed_sessions.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: 3 xfails.
- [ ] **T.W2.8** — Migrate `GET /api/managed-sessions` + `POST /api/managed-sessions/{mid}/terminate` from S1 to dashboard. estimate_minutes: 30. Files: `tools/demo-dashboard/main.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: xfails flip green.
- [ ] **T.W2.9** — Migrate `GET /test-dashboard` HTML handler from S1 to dashboard (plain template render, no data wiring beyond what already exists). estimate_minutes: 15. Files: `tools/demo-dashboard/main.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: local 8090/test-dashboard renders same HTML S1 did.
- [ ] **T.W2.10** — Copy `firebase_auth.py` (as-is) + the `auth.py` cookie helpers (`encode_user_cookie`, `decode_user_cookie`, `verify_session_cookie`, `verify_internal_secret`) into dashboard folder. No auth dep wiring yet — these are available for W4. estimate_minutes: 15. Files: `tools/demo-dashboard/firebase_auth.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->, `tools/demo-dashboard/auth.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: modules importable; unit smoke passes.
- [ ] **T.W2.11** — Local integration: `tools/demo-dashboard/` on port 8090 renders full dashboard against live local Firestore emulator (or real dev Firestore). estimate_minutes: 15. Files: (runtime only). DoD: Playwright screenshot taken; saved under `assessments/qa-reports/` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->.

### Wave 3 — S1 cleanup

- [ ] **T.W3.1** — Remove the 8 migrated routes from `mmp/workspace/tools/demo-studio-v3/main.py` (§2.1 table). estimate_minutes: 20. Files: `mmp/workspace/tools/demo-studio-v3/main.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: S1 main.py no longer declares them; `grep -c "@app.get.*dashboard"` on S1 returns 0.
- [ ] **T.W3.2** — Drop corresponding tests from S1 test suite (or re-home them under `demo-dashboard`). estimate_minutes: 15. Files: `mmp/workspace/tools/demo-studio-v3/tests/*` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: `pytest tools/demo-studio-v3` still green; no orphan test references.
- [ ] **T.W3.3** — Update S1's test-results writer to emit to the new Firestore collection from T.W2.6 (remove local JSON writes). estimate_minutes: 20. Files: `mmp/workspace/tools/demo-studio-v3/main.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->, `mmp/workspace/tools/demo-studio-v3/test_results_store.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> (or wherever it lives). DoD: S1 writes; dashboard reads; round-trip green.
- [ ] **T.W3.4** — Delete `mmp/workspace/tools/demo-studio-v3/templates/dashboard.html` + any dashboard-only static assets. estimate_minutes: 5. Files: `mmp/workspace/tools/demo-studio-v3/templates/dashboard.html` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: no orphan templates.

### Wave 4 — Firebase auth wire-up (gated on Loop 2b + 2c)

- [ ] **T.W4.1** — Copy latest `firebase_auth.py` + `auth.py` user-cookie helpers from S1 into dashboard (refresh post-Loop 2c). estimate_minutes: 10. Files: `tools/demo-dashboard/firebase_auth.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->, `tools/demo-dashboard/auth.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: modules identical to S1 versions at HEAD.
- [ ] **T.W4.2** — Add `require_user` dep to dashboard; gate `/dashboard`, `/api/test-results`, `/api/test-run-history`, `/api/managed-sessions` on it. estimate_minutes: 20. Files: `tools/demo-dashboard/main.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: unauth → 401; authed `@missmp.tech` → 200.
- [ ] **T.W4.3** — Write regression test matrix for dashboard auth: (route, method) × (no cookie, legacy sid cookie, user cookie, internal secret). kind: test. estimate_minutes: 20. Files: `tools/demo-dashboard/tests/test_dashboard_auth_matrix.py` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->. DoD: 12+ row matrix green.

### Wave 5 — Deploy

- [ ] **T.W5.1** — Ekko runs deploy.sh for `demo-dashboard` to staging Cloud Run. estimate_minutes: 20. Files: (deploy only). DoD: revision live; `curl https://<staging-url>/healthz` 200; dashboard UI loads.
- [ ] **T.W5.2** — Grant `roles/datastore.user` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> on `mmpt-233505` to the `demo-dashboard` runtime SA. estimate_minutes: 10. Files: (IAM only). DoD: SA has role per `gcloud projects get-iam-policy`.
- [ ] **T.W5.3** — Post-deploy smoke: all 5 service-health cards UP, test-results + managed-sessions render. estimate_minutes: 15. Files: (runtime only). DoD: Playwright video attached to PR.
- [ ] **T.W5.4** — Production deploy once staging soaks 24h green. estimate_minutes: 20. Files: (deploy only). DoD: prod `demo-dashboard` live; dashboard traffic shifted (W6 wiring update).

### Wave 6 — Cutover + retire MCP

- [ ] **T.W6.1** — Update any hardcoded dashboard URLs (internal wiki, Slack bookmarks, IAM docs) from S1's `/dashboard` to the new service URL. estimate_minutes: 15. Files: (docs only). DoD: no remaining S1 dashboard link in onboarding docs.
- [ ] **T.W6.2** — Per the MCP retirement ADR, delete `demo-studio-mcp` Cloud Run service once that ADR's exit criteria are met. Not gated on this plan; tracked for visibility. estimate_minutes: 10. Files: (GCP console / gcloud only). DoD: `demo-studio-mcp` service absent; `demo-dashboard` takes its observability-dashboard slot.

## Loop context

This plan is independent of the Loop 2 Firebase chain (2a / 2b / 2c / 2d) except for the W4 auth-wire-up, which explicitly waits on 2b + 2c. Concrete W1–W3 work can proceed in parallel with any Loop 2 loop — it touches `tools/demo-dashboard/` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path --> only (new folder) and the migrated routes in S1 (clean deletions). No overlap with Firebase auth changes landing on `feat/demo-studio-v3` <!-- orianna: ok -- cross-repo/service token, not a local strawberry-agents path -->.

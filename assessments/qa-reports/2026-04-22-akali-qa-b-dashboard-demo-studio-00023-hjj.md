---
agent: akali
concern: work
track: QA-B
surface: dashboard / service-health / session-list / navigation
revision: demo-studio-00023-hjj
target_url: https://demo-studio-266692422014.europe-west1.run.app
date: 2026-04-22
plan: plans/in-progress/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md
pr: 32
verdict: FAIL
---

# Akali QA-B — Dashboard / Service Health / Session-List / Navigation
## Revision: demo-studio-00023-hjj (Option B vanilla-API ship)

---

## Per-Screen Pass/Fail Table

| Screen | Route | Result | Notes |
|--------|-------|--------|-------|
| Root landing page | `/` | PASS | Renders correctly. Session-ID input + "Open" button present. Text "Sessions are created via Slack" (no self-serve new-session flow). |
| Dashboard — Prod mode, Sessions tab | `/dashboard` | FAIL | Lists old services: "Demo Studio MCP" (DOWN), "Wallet Studio MCP" (DOWN), "Demo Studio Backend" (UP). S1–S5 services not represented. |
| Dashboard — Managed Agents tab | `/dashboard` → Managed Agents tab | FAIL | Banner: "Failed to load managed sessions: HTTP 404". `/managed-sessions` route removed but dashboard still calls it. |
| Session page | `/session/<id>` (via auth redirect) | PARTIAL | Chat and phase-nav render. Preview pane shows "Preview unavailable (S5_BASE not configured)" — `window.__s5Base` is null on prod. |
| Session preview route (direct) | `/session/<id>/preview` | FAIL | 404 Not Found. Route removed server-side (Bug 5 from Duong's notes confirmed on prod). |
| Sessions API | `/sessions` | PASS | Returns 200 + JSON array (72–77 sessions). Correct fields: sessionId, brand, line, market, status, phase, cost_usd, authUrl. |
| Managed-sessions API | `/managed-sessions` | FAIL | 404. Route deleted in Wave 6 but dashboard JS still polls it. |
| `/health` | `/health` | PASS | 200 `{"status":"ok"}` |
| `/healthz` | `/healthz` | FAIL | 404 |
| `/readyz` | `/readyz` | FAIL | 404 |
| `/v1/health` | `/v1/health` | FAIL | 404 |
| Cross-service: config-mgmt | `https://demo-config-mgmt-4nvufhmjiq-ew.a.run.app/health` | PASS | 200 `{"status":"ok"}` |
| Cross-service: factory | `https://demo-factory-4nvufhmjiq-ew.a.run.app/health` | FAIL | 404 (no `/health` route; service is alive — `/v1/build` exists per OpenAPI) |
| Cross-service: verification | `https://demo-verification-4nvufhmjiq-ew.a.run.app/health` | FAIL | 404 (no `/health` route; service alive — `/verify` exists) |
| Cross-service: preview (S5) | `https://demo-preview-4nvufhmjiq-ew.a.run.app/health` | FAIL | 404 (no `/health` route; service alive — `/v1/preview/{session_id}` exists) |
| Nav: Dashboard → session | `/dashboard` → click "Open" on a session | PASS | Auth redirect works, session page loads. |
| Nav: Session → Dashboard | Session page → "Dashboard" link | PASS | Link present at `/dashboard?session=<id>`, functions correctly. |
| Nav: Session → "+ New Session" | Session page → "+ New Session" button | PARTIAL | Modal opens with Brand/Line/Market fields. Posts to `POST /session/new`. Known Viktor in-flight issue (managedSessionId path); not gated by QA-B scope. |

---

## Bug List

### BUG-B1 — Sev1 — Dashboard SERVICE HEALTH panel lists retired managed-agent services instead of S1–S5
**Reproduction:** Navigate to `/dashboard`, click "Prod" mode button. SERVICE HEALTH panel shows three cards: "Demo Studio MCP" (DOWN, `{"error":"Failed to fetch"}`), "Wallet Studio MCP" (DOWN, `{"error":"Failed to fetch"}`), "Demo Studio Backend" (UP). The two DOWN services correspond to `localhost:3100` and `localhost:3001` (the managed-agent MCP servers), which do not exist on prod. None of S2 (config-mgmt), S3 (factory), S4 (verification), S5 (preview) appear in the health panel.
**Impact:** Operators see two permanent red boxes on every prod dashboard load. S1–S5 health is invisible.
**Expected:** S2/S3/S4/S5 Cloud Run URLs should be polled; MCP Studio / Wallet MCP entries should be removed or renamed.
**Screenshot:** `qa-b-dashboard-prod-mode.png`

### BUG-B2 — Sev1 — Dashboard "Managed Agents" tab errors with HTTP 404 on every page load
**Reproduction:** Navigate to `/dashboard` → click "Managed Agents" tab. Banner reads "Failed to load managed sessions: HTTP 404". Top-right shows "fetch failed". The tab body is empty.
**Root cause:** Wave 6 deleted the `/managed-sessions` server route, but `dashboard.js` (or equivalent client JS) still issues `GET /managed-sessions` on tab activation.
**Impact:** Entire "Managed Agents" tab is broken on prod. Cannot be dismissed; re-fires on every "Refresh all".
**Screenshot:** `qa-b-dashboard-managed-agents-tab.png`

### BUG-B3 — Sev1 — `/session/<id>/preview` returns 404 (S1 preview route removed, JS not updated)
**Reproduction:** Navigate to `/session/0fdb1de0d002408485d3ccbad0d572c0/preview` directly. Returns `{"detail":"Not Found"}` (404). Also reproduced via iframe on session page — preview pane renders "Preview unavailable (S5_BASE not configured)" because `window.__s5Base` is `undefined`/null on prod (PREVIEW_URL env var is set to `https://demo-preview-4nvufhmjiq-ew.a.run.app` but `__s5Base` is not injected into the session page template).
**Root cause (composite):** (a) The S1 `/session/<id>/preview` server route was removed (confirmed by Duong's Bug 5 note). (b) `static/studio.js` still sets `previewFrame.src = '/session/' + sessionId + '/preview'`. (c) `window.__s5Base` is never set in the session HTML (the `templates/session.html` placeholder exists but is not the actual render path per Senna M5 — and neither is `PREVIEW_URL` injected into the inline render in `main.py`).
**Impact:** Preview iframe is permanently broken on every session. Core user value proposition of the Configure→Preview workflow is blocked.
**Screenshot:** `qa-b-session-page.png` (shows "Preview unavailable (S5_BASE not configured)"), `qa-b-preview-404.png`

### BUG-B4 — Sev2 — Factory, verification, and preview (S3/S4/S5) services have no `/health` endpoint; dashboard health-check framework cannot poll them even after BUG-B1 is fixed
**Reproduction:** `GET https://demo-factory-4nvufhmjiq-ew.a.run.app/health` → 404. Same for demo-verification and demo-preview. All three services are alive (FastAPI OpenAPI at `/docs` and `/openapi.json` responds). Their routes are: factory `/v1/build`, verification `/verify`, preview `/v1/preview/{session_id}`. None expose `/health`.
**Impact:** Once BUG-B1 is fixed and the dashboard polls S2–S5 URLs, S3/S4/S5 will still show DOWN unless their health routes are added.
**Config-mgmt (S2):** PASS — exposes `/health` → 200 `{"status":"ok"}`.

### BUG-B5 — Sev2 — `window.__s5Base` not injected into session page; S5 fullview "Open full screen" button is inoperative
**Reproduction:** Load any session page. `window.__s5Base` is null/undefined (confirmed from page snapshot — preview pane shows "Preview unavailable (S5_BASE not configured)"). The "Open full screen" button in the preview pane will attempt to open `__s5Base + '/v1/preview/' + sessionId + '/fullview'` but with a null base URL this produces a broken or localhost URL.
**Root cause:** `PREVIEW_URL` env var is correctly set (`https://demo-preview-4nvufhmjiq-ew.a.run.app`) but it is not surfaced to the client. The inline session HTML renderer in `main.py` does not inject `window.__s5Base = <PREVIEW_URL>`.
**Impact:** S5 preview integration is completely non-functional for users who navigate to the session page.

### BUG-B6 — Sev3 — Root landing page has no navigation to `/dashboard`; no "New Session" self-serve entry point
**Reproduction:** Navigate to `/`. Page shows only session-ID input box with placeholder "Enter session ID (ses_...)". There is no link to `/dashboard`, no "+ New Session" button, and no explanation that session creation requires Slack (Duong explicitly noted in manual feedback that there is no alternative way to create sessions from the UI).
**Impact:** New users without a session ID have no onboarding path. Dashboard is invisible from root. "Sessions are created via Slack" text is the only hint but is not actionable.
**Note:** This is primarily a UX/product gap rather than a regression; the session-ID entry form does function (pasting a valid ID + clicking Open redirects correctly).

### BUG-B7 — Sev3 — `/healthz` and `/readyz` return 404; only `/health` is functional
**Reproduction:** `GET /healthz` → 404. `GET /readyz` → 404. `GET /health` → 200 `{"status":"ok"}`.
**Impact:** Cloud Run readiness and liveness probes configured against `/healthz` or `/readyz` would fail. Current Cloud Run revision uses default startup probe (no custom healthz configuration visible in revision spec), so this is not presently breaking — but any future probe configuration or third-party uptime monitor expecting standard paths would misfail.

---

## Health Endpoint Summary

| Endpoint | HTTP Status | Body |
|----------|-------------|------|
| `GET /health` (demo-studio) | 200 | `{"status":"ok"}` |
| `GET /healthz` (demo-studio) | 404 | `{"detail":"Not Found"}` |
| `GET /readyz` (demo-studio) | 404 | `{"detail":"Not Found"}` |
| `GET /v1/health` (demo-studio) | 404 | `{"detail":"Not Found"}` |
| `GET /sessions` | 200 | JSON array, 72–77 sessions |
| `GET /managed-sessions` | 404 | `{"detail":"Not Found"}` |
| `GET /session/new` | 401 | (auth required) |
| `GET /session/<id>/preview` | 404 | `{"detail":"Not Found"}` |
| `GET` demo-config-mgmt `/health` | 200 | `{"status":"ok"}` |
| `GET` demo-factory `/health` | 404 | No health route; `/v1/build` POST exists |
| `GET` demo-verification `/health` | 404 | No health route; `/verify` POST exists |
| `GET` demo-preview `/health` | 404 | No health route; `/v1/preview/{id}` GET exists |

---

## Cross-Service URL Surfacing in UI

- `CONFIG_MGMT_URL`, `FACTORY_URL`, `VERIFICATION_URL`, `PREVIEW_URL` are set as env vars on revision 00023-hjj (confirmed via `gcloud run revisions describe`).
- None of these URLs are surfaced in the dashboard SERVICE HEALTH panel — the panel only polls localhost MCP endpoints and the backend base URL.
- `PREVIEW_URL` is not injected as `window.__s5Base` into the session page template.
- The dashboard "Backend" config field correctly shows `https://demo-studio-4nvufhmjiq-ew.a.run.app` in Prod mode.

---

## Screenshots

| File | Content |
|------|---------|
| `qa-b-root-landing-clean.png` | Root `/` landing page |
| `qa-b-dashboard-prod-mode.png` | Dashboard Prod mode — Sessions tab — SERVICE HEALTH panel with old MCP services |
| `qa-b-dashboard-managed-agents-tab.png` | Dashboard — Managed Agents tab — HTTP 404 error banner |
| `qa-b-session-page.png` | Session page — chat active, preview pane "S5_BASE not configured" |
| `qa-b-preview-404.png` | `/session/<id>/preview` direct navigation — 404 |

Screenshots are stored in the Playwright MCP working directory (paths relative to the MCP session output root).

---

## Overall Verdict: FAIL

Three Sev1 issues independently block the dashboard and preview user flows:

1. **BUG-B1** — Dashboard SERVICE HEALTH panel shows wrong services (old MCP stack, not S1–S5).
2. **BUG-B2** — Managed Agents tab errors 404 on every load (deleted route still polled by JS).
3. **BUG-B3** — Preview iframe permanently 404s; `window.__s5Base` not injected; S1 preview route deleted without JS update.

Viktor hotfix on `POST /session/new → managedSessionId` path is tracked separately and is NOT included in the above count per brief.

---

— Akali (QA-B track), 2026-04-22

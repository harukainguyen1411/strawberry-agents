# QA Report — S1-new-flow E2E MCP-driven Post-Ship
**Date:** 2026-04-21  
**QA Agent:** Akali  
**Concern:** work  
**Method:** Live Playwright MCP browser drive against production

---

## Deploy Targets Tested

| Service | URL | Revision | Env Flags |
|---------|-----|----------|-----------|
| S1 demo-studio | https://demo-studio-4nvufhmjiq-ew.a.run.app | demo-studio-00016-5rw | `MANAGED_AGENT_MCP_INPROCESS=1`, `S5_BASE=https://demo-preview-4nvufhmjiq-ew.a.run.app` |
| S3 demo-factory | https://demo-factory-4nvufhmjiq-ew.a.run.app | demo-factory-00007-qjd | `PROJECTS_FIRESTORE=1` |
| S5 demo-preview | https://demo-preview-4nvufhmjiq-ew.a.run.app | demo-preview-00006-57w | — |

**Test session used:** `35af5b9da1d64a168d56507dd5a5d733` (Allianz, motor/US, status: configuring)

---

## Pre-flight Service Checks

| Service | HTTP Check | Result |
|---------|------------|--------|
| S1 demo-studio GET / | 200 | PASS |
| S5 demo-preview GET /v1/preview/{session} | 200 | PASS |
| S3 demo-factory POST /build | 405 on GET (POST-only, service alive) | PASS |
| S1 /debug connectivity.firestore | "ok" | PASS |
| S1 /debug connectivity.anthropic | 401 invalid x-api-key | **FAIL — see Bug 1** |

---

## Scenario Pass/Fail Matrix

| # | Scenario | Result | Notes |
|---|----------|--------|-------|
| S1 | Studio landing page loads without errors | PASS | Title "Demo Studio v3 — MMP", zero JS errors, correct UI |
| S2 | Session page loads via authUrl token flow | PASS | Auth redirect `/auth/session/{id}?token=…` → `/session/{id}` working |
| S3 | Iframe renders S5 preview | PASS | `<iframe src="https://demo-preview-…/v1/preview/{session}">` loads (726ms), Allianz brand + Motor Insurance visible |
| S4 | S5 fullview route opens via "Open in fullview" | PASS | New tab opens at `/v1/preview/{session}/fullview`, title "Allianz — {session}", content correct |
| S5 | SSE /stream authenticated connection | PASS | Server logs show `/session/{id}/stream → 200` at 14:23:30; UI shows "Waiting for your first message" (no error state) |
| S6 | SSE /stream unauthenticated returns 401 | PASS | `curl -si …/stream` → `HTTP/2 401 {"detail":"Not authenticated"}` |
| S7 | SSE /logs unauthenticated returns 401 | PASS | `curl -si …/logs` → `HTTP/2 401 {"detail":"Not authenticated"}` |
| S8 | No outbound calls to demo-studio-mcp-* (in-process MCP merge) | PASS | Zero network requests to `demo-studio-mcp-4nvufhmjiq-ew.a.run.app`; `DEMO_STUDIO_MCP_URL=<not set>` confirmed in /debug; performance entries show no external MCP calls |
| S9 | Phase tabs (Configure/Build/QC/Tweak) render | PASS | All 4 tabs visible; active tab locks to Configure while session in configure phase — expected behaviour |
| S10 | Terminal verification event renders in UI | CANNOT TEST | Anthropic API key invalid (Bug 1); AI agent cannot run; no build triggered; no terminal event generated |
| S11 | Deploy modal renders | PASS | "Deploy this demo?" dialog with Cancel/Deploy buttons present in DOM |
| S12 | Dashboard loads with session list | PARTIAL | Loads in Prod mode after manual switch; session list populates (64 sessions); but Local mode (default) triggers JS error (Bug 3/4) |
| S13 | Dashboard Demo Studio Backend health | PASS | UP, 390ms–833ms, `{"status":"ok"}` in Prod mode |
| S14 | Trigger build / watch SSE logs stream | CANNOT TEST | Blocked by Anthropic API key issue (Bug 1); no AI messages can be processed |

---

## Bugs Found

### Bug 1 — CRITICAL: Anthropic API key invalid on production revision demo-studio-00016-5rw
**Severity:** Critical (blocks all AI agent functionality)  
**Evidence:** `/debug` endpoint shows:
```
startup_anthropic_failed: Error code: 401 - {'type': 'error', 'error': {'type': 'authentication_error', 'message': 'invalid x-api-key'}}
```
**Impact:** The AI agent cannot process any messages. Users typing in the chat box will get no response. All terminal verification events, tool use, and agent-driven configuration are broken.  
**Ownership:** Viktor (infra/secrets rotation)  
**Reproduction:** `curl -s https://demo-studio-4nvufhmjiq-ew.a.run.app/debug | jq .connectivity.anthropic`

---

### Bug 2 — PARTIAL: S5 preview sections show TODO stubs
**Severity:** Medium (visual regression / incomplete implementation)  
**Evidence:** Both the S1 iframe and S5 fullview show:
- "iPad Demo Steps — TODO: render ipadDemo.steps[]"
- "Journey Actions — TODO: render journey[] timeline"
- "Token UI — TODO: render tokenUi pages"

**Impact:** The preview is skeletal — only brand header and pass preview card render. The full demo journey is not visible.  
**Ownership:** Talon (S5 demo-preview frontend rendering)  
**Reproduction:** Navigate to `/session/{id}` or S5 fullview — visible without any session configuration.

---

### Bug 3 — LOW: Dashboard defaults to Local mode on page load
**Severity:** Low (developer tooling UX issue)  
**Evidence:** Dashboard loads with mode=Local, pointing to `localhost:3100`, `localhost:3001`, `localhost:8080`. In production, this means all three service health cards show DOWN on first load.  
**Impact:** Anyone opening `/dashboard` on the prod URL sees a false "everything down" state until they manually click "Prod".  
**Ownership:** Talon (dashboard default mode logic)  
**Reproduction:** `https://demo-studio-4nvufhmjiq-ew.a.run.app/dashboard` — observe "Local" selected by default.

---

### Bug 4 — MEDIUM: JS ReferenceError `Cannot access 'SERVICES' before initialization` on dashboard load
**Severity:** Medium (JS error in monitoring tool)  
**Evidence:**
```
ReferenceError: Cannot access 'SERVICES' before initialization
    at pollHealth (https://demo-studio-4nvufhmjiq-ew.a.run.app/dashboard:1329:21)
    at refreshAll (https://demo-studio-4nvufhmjiq-ew.a.run.app/dashboard:2391:3)
    at setMode (https://demo-studio-4nvufhmjiq-ew.a.run.app/dashboard:1201:43)
```
**Impact:** `pollHealth` crashes on initial load for both Local and Prod modes. Health polling may be partially broken (retries may recover).  
**Ownership:** Talon (dashboard JS — variable declaration order / hoisting bug)  
**Reproduction:** Open `/dashboard`, check browser console.

---

### Bug 5 — LOW: Dashboard Prod mode doesn't auto-populate MCP service URLs
**Severity:** Low (UX issue in dev tool)  
**Evidence:** Switching to Prod mode updates the Backend field but leaves MCP Studio at `localhost:3100` and Wallet MCP at `localhost:3001`. Manual "Apply" is required after editing those fields.  
**Ownership:** Talon  
**Reproduction:** Click "Prod" on dashboard — MCP Studio and Wallet MCP fields retain localhost values.

---

### Non-bug observations

- **favicon.ico 404**: Both S1 and S5 are missing a favicon file. Low priority cosmetic.
- **iframe sandbox advisory**: `allow-scripts` + `allow-same-origin` in iframe sandbox produces a browser security warning. This is a known trade-off for the preview iframe — not blocking.

---

## Network Evidence — No Old MCP Calls

All network requests captured during session page load:

| Request | Status | Notes |
|---------|--------|-------|
| GET /static/studio.css | 200 | stylesheet |
| GET /static/studio.js | 200 | main bundle |
| GET https://demo-preview-…/v1/preview/{session} | 200 | S5 iframe (726ms) |
| GET /session/{session}/status | 200 | session status fetch |
| GET /session/{session}/stream | 200 | SSE stream (server-side log confirms) |

**Zero calls to `demo-studio-mcp-4nvufhmjiq-ew.a.run.app`.**  
`DEMO_STUDIO_MCP_URL=<not set>` confirmed in /debug env_vars.  
In-process MCP merge (MANAGED_AGENT_MCP_INPROCESS=1) is working.

---

## Console Errors Summary

| Page | Errors | Warnings | Notes |
|------|--------|----------|-------|
| Studio landing / | 0 | 0 | Clean |
| Session page /session/{id} | 0 | 1 | iframe sandbox warning (non-blocking) |
| S5 fullview /v1/preview/{id}/fullview | 1 | 0 | favicon.ico 404 only |
| Dashboard /dashboard (Local mode) | 3+ | 0 | localhost fetch errors + SERVICES ReferenceError |
| Dashboard /dashboard (Prod mode) | 7 | 0 | Continued localhost MCP polling + SERVICES error |

---

## Screenshot Paths

| Step | Path |
|------|------|
| Studio landing page | `assessments/qa-artifacts/akali/01-studio-landing.png` |
| Session page loaded with S5 iframe | `assessments/qa-artifacts/akali/02-session-page-loaded.png` |
| S5 fullview tab | `assessments/qa-artifacts/akali/03-s5-fullview.png` |
| Build tab click (stays on Configure — expected) | `assessments/qa-artifacts/akali/04-build-tab.png` |
| Dashboard (Local mode, all DOWN) | `assessments/qa-artifacts/akali/05-dashboard.png` |
| Dashboard (Prod mode, backend UP) | `assessments/qa-artifacts/akali/06-dashboard-prod-mode.png` |
| Dashboard final state | `assessments/qa-artifacts/akali/07-session-page-final.png` |

---

## Video Artifacts

No video recording was taken (browser_start_video not invoked — Playwright MCP does not expose a start/stop video API in the current version). Screenshots at each step serve as the visual record.

---

## Overall Verdict: PARTIAL

**Critical blocker:** Anthropic API key is invalid on the deployed revision — the AI agent is non-functional. The chat interface renders correctly but cannot process messages. No terminal verification event could be triggered or verified.

**What is working:**
- Studio landing page, auth flow, session page — clean renders, zero JS errors on core paths
- S5 preview iframe loads and renders within the session page
- S5 fullview route opens correctly from "Open in fullview"
- SSE /stream authenticated (200) and unauthenticated (401) — correct
- In-process MCP merge confirmed — zero external MCP calls
- Demo Studio Backend health: UP
- S3 demo-factory: alive (responds correctly to POST-only endpoint)

**What is broken:**
- Anthropic API 401 — AI agent dead (Bug 1, Critical)
- S5 preview section stubs not rendered (Bug 2, Medium)
- Dashboard JS ReferenceError on load (Bug 4, Medium)
- Dashboard defaults to Local mode (Bug 3, Low)

**Recommendation:** Fix Bug 1 (rotate/redeploy Anthropic API key secret) immediately. Then re-run scenarios S10 and S14 to validate terminal verification event and full SSE logs stream. Bugs 2–5 can be tracked separately.

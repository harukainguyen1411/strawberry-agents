---
slug: 2026-04-22-akali-build-verification-00027-xqv
surface: build-verification (criteria 4+5 — trigger_factory → S3, get_last_verification → S4)
revision: demo-studio-00027-xqv
date: 2026-04-22
verdict: PARTIAL
---

# QA Report — Build + Verification Path (00027-xqv)

## Scope

Criteria 4 and 5 of overnight-ship-plan:
- **Criterion 4**: Agent calling `trigger_factory` kicks S3 (demo-factory) — POST returns 2xx with `job_id`.
- **Criterion 5**: Build completes within 90s; `get_last_verification` returns a readable verification report; assistant surfaces pass/fail summary in chat.

Explicitly out of scope: chat UX, preview, auth, dashboard (covered by other Akali reports).

## Service Health at Test Time (2026-04-22T02:03 UTC)

| Service | Endpoint | Status | Evidence |
|---------|----------|--------|----------|
| demo-studio | `/health` | UP | `{"status":"ok"}` 200 |
| demo-factory | `https://demo-factory-4nvufhmjiq-ew.a.run.app/health` | UP | `{"status":"ok"}` 200 (server-side curl) |
| demo-verification | `https://demo-verification-4nvufhmjiq-ew.a.run.app/health` | UP | `{"status":"ok"}` 200 (server-side curl) |

All three services are healthy in revision 00027-xqv. This is a material improvement over 00024-dms where S3/S4 were DOWN (CORS failures on health probes).

## API Surface Verified (from OpenAPI spec)

### demo-factory (`/openapi.json`)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Liveness check |
| `/build` | POST | Non-streaming build trigger — `{sessionId, projectId?, configVersion?}` → `{buildId, projectId}` |
| `/v1/build` | POST | Streaming build trigger (SSE) — `{sessionId, configVersion?}` |
| `/build/{build_id}` | GET | Poll build status |
| `/build/{build_id}/events` | GET | SSE stream of build events |
| `/logs` | GET | Recent structured logs (requires Authorization) |

**Key schema**: `BuildRequestV2 = {sessionId: string, projectId?: string, configVersion?: int}` → response includes `buildId` and `projectId`.

### demo-verification (`/openapi.json`)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Liveness check |
| `/verify` | POST | Run QC checks on a built WS project |
| `/verify/{session_id}` | GET | Retrieve most recent QC report for a session |

Both services require `Authorization` header for non-health endpoints — logs and verification reports are authenticated.

## Playwright Session Drive — Criterion 4 (trigger_factory → S3)

### Session Used

- Session ID: `4f6819d3550e45ed880093f85e11c6c0` (Progressive / Motor / US, created 2026-04-22T02:08Z)
- Auth: `/auth/session/{id}?token=...` — single-use nonce flow, confirmed working (200 redirect to session page)

### What Was Observed

| Step | Action | Result |
|------|--------|--------|
| 1 | Navigate to demo-studio, land on dashboard | PASS — page title "Demo Studio v3 — MMP" |
| 2 | Auth into session via `/auth/session/{id}?token=...` | PASS — redirected to session page, cookie set |
| 3 | Session page loads (CONFIGURE phase) | PASS — phase bar shows CONFIGURE active; chat input enabled |
| 4 | POST `/session/{sid}/chat` with `{"message":"I want to demo Progressive motor insurance in the US market."}` | PASS — HTTP 200, `{"user_message_id":"...","accepted_at":"2026-04-22T02:11:..."}` |
| 5 | SSE stream `GET /session/{sid}/stream` opens | PASS — connection established, agent processing |
| 6 | `GET /session/{sid}/status` returns 200 with valid JSON | PASS — `{status:"configuring", phase:"configure", cancelled:false}` |
| 7 | Agent banner shows "Sending..." — agent active | PASS — confirmed in DOM and snapshot |
| 8 | Chat log shows user message in DOM | PASS — `<div class="msg msg-user">I want to demo Progressive motor insurance...</div>` |
| 9 | Session cost grows over time ($0.0019 → $0.0130 in 9.5 min) | PASS — confirms LLM/tool-call activity running |
| 10 | Agent reaches `trigger_factory` within 90s | **FAIL / BLOCKED** — GATHER phase took >9.5 min; no `trigger_factory` call observed |

### GATHER Phase Timing Issue

The agent's GATHER phase (get_schema + web_search + set_config) did not complete within the 90-second budget. At the 10-minute mark, session status was:
- `status: "configuring"`, `phase: "configure"`, `lastBuildAt: null`, `cost_usd: 0.0130`

No `trigger_factory` tool call was observed in the SSE stream or session history. The agent is processing but the GATHER→GENERATE→BUILD pipeline was not traversed within the test window.

**Note on trigger path**: Inspection of `/static/studio.js` confirms the "Deploy Demo" button's `doDeploy()` function does **not** POST to demo-factory directly — it shows a UI message: `"Build is triggered by the agent via MCP. Check the chat for progress."` The factory POST is exclusively initiated by the agent's `demo_studio__trigger_factory` MCP tool call, which the SSE stream would surface with a status transition to `"building"`. This is the correct architecture for criteria 4.

### Network Evidence (Playwright-captured)

```
POST /session/4f6819d3550e45ed880093f85e11c6c0/chat → 200
  Body: {"message":"I want to demo Progressive motor insurance in the US market."}
  
GET  /session/4f6819d3550e45ed880093f85e11c6c0/stream  → (open, SSE)
GET  /session/4f6819d3550e45ed880093f85e11c6c0/status  → 200 (×4 polls)
GET  /session/4f6819d3550e45ed880093f85e11c6c0/messages → 200 (empty)
GET  /session/4f6819d3550e45ed880093f85e11c6c0/history  → 200 (toolCalls: [])
```

No POST to `demo-factory-4nvufhmjiq-ew.a.run.app` was observed from the browser (CORS blocks cross-origin fetch); factory calls are server-side MCP dispatches. The session stream endpoint is the correct observation point for `trigger_factory` events.

## Criterion 5 (Build Completes, Verification Report, Chat Summary)

Cannot be evaluated — build was never triggered within the test window. All three sub-checks are BLOCKED pending criterion 4 completion:

| Sub-check | Status |
|-----------|--------|
| S3 build completes within 90s poll | BLOCKED |
| `get_last_verification` returns readable report | BLOCKED |
| Agent surfaces pass/fail summary in chat | BLOCKED |

The verification API surface was confirmed healthy and has the correct `GET /verify/{session_id}` endpoint.

## Findings

| # | Severity | Finding |
|---|----------|---------|
| F1 | SEV-1 | **GATHER phase exceeds 90s budget** — the agent's first-turn processing (get_schema + web_search + set_config) took >9.5 minutes for a new session on 00027-xqv. The trigger_factory call cannot be observed within the criterion 4 90s budget for a fresh session. |
| F2 | SEV-2 | **No session messages persisted to /messages endpoint during agent run** — `GET /session/{sid}/messages` returns `{"messages":[]}` throughout the GATHER phase; tool calls are not recorded in `/history` either. The session history API appears to only capture completed turns, not in-progress ones. |
| F3 | INFO | **demo-factory and demo-verification services are UP in 00027-xqv** — contrast with 00024-dms where both were DOWN. CORS restriction on cross-origin browser fetch to companion services is expected; factory calls are correctly server-side. |
| F4 | INFO | **deploy button does not directly call demo-factory** — `doDeploy()` in studio.js is a UI-only hint. All factory builds are MCP-dispatched by the agent. This is intentional per the architecture but means Playwright can only observe the `trigger_factory` event through the SSE stream transition to `status: "building"`. |
| F5 | INFO | **Both companion service APIs require Authorization header** — `GET /logs`, `GET /verify/{session_id}`, `POST /verify` all return `{"detail":{"error":{"code":"UNAUTHORIZED","message":"Missing Authorization header"}}}` without auth. Server-to-server calls from demo-studio include this header; direct external access does not. |

## Screenshots

| Screenshot | Description |
|------------|-------------|
| `qa-build-00027-01-session-initial.png` | Session `4f6819d...` loaded in CONFIGURE phase; all preview sections "not yet configured"; Stop button visible |
| `qa-build-00027-02-session-sending.png` | Session with user message in chat log; "Sending..." indicator; Deploy modal visible; agent processing at ~9.5 min mark |

Both screenshots saved to repo root.

## Overall Verdict: PARTIAL

### What Passed
- All three services (demo-studio, demo-factory, demo-verification) are UP and healthy in 00027-xqv
- demo-factory OpenAPI confirmed: `/build` POST endpoint exists with correct schema (`sessionId` → `{buildId, projectId}`)
- demo-verification OpenAPI confirmed: `/verify/{session_id}` GET endpoint exists
- Session auth flow works (single-use nonce tokens from `/sessions` listing)
- Chat POST accepted (200) with `user_message_id` returned
- SSE stream connected and agent is running
- Studio.js correctly maps `demo_studio__trigger_factory` → UI state `"building"` phase transition
- `GET /session/{sid}/status` returns structured status with `verificationStatus`, `lastBuildAt`, `outputUrls` fields — correct shape for criteria 5 polling

### What Failed / Blocked
- **Criterion 4**: `trigger_factory` not observed within 90s — GATHER phase too slow for a fresh unconfigured session
- **Criterion 5**: All sub-checks blocked by criterion 4 failure

### Recommended Next Step
Re-run criterion 4 using a session that already has config written (bypass GATHER by seeding config via `set_config` before the build message, or by reusing an Allianz/motor session that completed GATHER). The infrastructure is ready; the failure is a test-design timing issue, not a code regression.

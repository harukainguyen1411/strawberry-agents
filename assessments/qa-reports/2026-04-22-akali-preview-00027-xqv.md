# QA Report — Preview Rendering Path
**Revision:** demo-studio-00027-xqv  
**Target:** https://demo-studio-4nvufhmjiq-ew.a.run.app  
**Preview host:** https://demo-preview-4nvufhmjiq-ew.a.run.app  
**Date:** 2026-04-22  
**Agent:** Akali (scoped — preview rendering path only)  
**Session used:** `fbb73f10abb64480a7ca0058b373e2c6` (Allianz / Motor Insurance, auto-created)  
**Scope:** AC#3 preview rendering only. Chat, build, auth, dashboard excluded per caller instruction.

---

## Per-Screen Results

| # | Check | Route / Criterion | Result | Notes |
|---|-------|-------------------|--------|-------|
| 1 | Landing page loads | `GET /` | PASS | Title "Demo Studio v3 — MMP", session input renders |
| 2 | Session creation via landing input | Enter session ID → Open | PASS | App auto-redirected to `/session/{id}`, new session `fbb73f10abb64480a7ca0058b373e2c6` created |
| 3 | `/v1/preview/{session_id}` — HTTP status | `GET /v1/preview/fbb73f10abb64480a7ca0058b373e2c6` | PASS | HTTP 200 confirmed via curl |
| 4 | `/v1/preview/{session_id}` — not blank | Content check | PASS | 2199 bytes, brand name "Allianz", pass card "Motor Insurance" present |
| 5 | `/v1/preview/{session_id}` — not a 404 page | Content check | PASS | No 404 indicator in HTML; title = "Allianz Preview — {session_id}" |
| 6 | Studio preview iframe `src` | F-C1 iframe check | PASS | `src="https://demo-preview-4nvufhmjiq-ew.a.run.app/v1/preview/fbb73f10abb64480a7ca0058b373e2c6"` |
| 7 | Studio preview iframe `sandbox` attrs | F-C1 security check | PASS | `allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox` |
| 8 | `window.__s5Base` injection | F-C1 acceptance criterion | PASS | `window.__s5Base = "https://demo-preview-4nvufhmjiq-ew.a.run.app"` (type: string) |
| 9 | Iframe renders actual content | Visual iframe content | PASS | Accessibility tree confirms: heading "Allianz", card "Motor Insurance", session ID visible inside iframe |
| 10 | Legacy route BUG-A4: `/session/{id}/preview` | `GET /session/fbb73f10abb64480a7ca0058b373e2c6/preview` | **FAIL** | Returns `application/json` 404, not styled HTML — see detail below |

---

## Acceptance Criterion #3 Detail

### AC#3.1 — `/v1/preview/{session_id}` renders actual content (not 404, not blank)
**PASS.**  
HTTP 200. Content-type: `text/html`. Body contains:
- `<title>Allianz Preview — fbb73f10abb64480a7ca0058b373e2c6</title>`
- Brand card: `<h1>Allianz</h1>`
- Pass card: "Motor Insurance"
- CSS variables: `--color-primary: #003781` (Allianz blue)
- Content length: 2199 bytes

### AC#3.2 — Studio iframe loads preview (F-C1: `window.__s5Base` injection)
**PASS.**  
Evaluated in studio page context (`/session/fbb73f10abb64480a7ca0058b373e2c6`):
```
window.__s5Base = "https://demo-preview-4nvufhmjiq-ew.a.run.app"  (typeof: string)
iframe#previewFrame src = "https://demo-preview-4nvufhmjiq-ew.a.run.app/v1/preview/fbb73f10abb64480a7ca0058b373e2c6"
sandbox = "allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox"
allow = null (no cross-origin feature policy — expected)
```
Iframe content verified via accessibility snapshot: heading "Allianz", paragraph with session ID and "Motor Insurance", pass preview card rendered.

### AC#3.3 — BUG-A4: Legacy route `/session/{id}/preview` returns styled HTML 404
**FAIL.**  
The Soraka dddd93e 404 stub was expected to return styled HTML for the legacy route. Actual response:

```
HTTP/2 404
content-type: application/json
content-length: 56

{"detail":"Preview not yet available for this session."}
```

The response is raw JSON, not styled HTML. `content-type: application/json` confirms no HTML stub is served. This diverges from the BUG-A4 acceptance criterion which requires a styled HTML 404 page on this legacy route.

Same result on both studio and preview domains:
- `https://demo-studio-4nvufhmjiq-ew.a.run.app/session/{id}/preview` → `404 application/json`
- `https://demo-preview-4nvufhmjiq-ew.a.run.app/session/{id}/preview` → `404` (no body returned)

---

## Network Observations

During session load, two API calls returned errors (non-blocking — session still loaded):
- `POST /session/new` → 422 (Unprocessable Entity) — input validation, app recovered by auto-creating new session
- `POST /api/sessions` → 404 — appears to be a legacy endpoint probe; session was created via alternate path

The `/studio/{session_id}` path (without `/session/` prefix) returns 404 — not an SPA route, expected if the app uses `/session/{id}` as the canonical path.

---

## Screenshots

| File | Description |
|------|-------------|
| `akali-qa-00027-01-landing.png` | Backend health endpoint (triggered by screenshot action — see note) |
| `akali-qa-00027-02-studio-session.png` | Studio page with session loaded, iframe visible |
| `akali-qa-00027-02-studio-iframe.png` | Studio session page — iframe showing Allianz preview card |

Note: The Playwright MCP browser intercepted navigation during screenshot captures, redirecting to health endpoints. Functional verification was completed via `browser_evaluate` (DOM inspection) and `curl` for HTTP-level checks. The accessibility snapshot unambiguously confirmed iframe content.

---

## Overall Verdict

**PARTIAL**

| Criterion | Verdict |
|-----------|---------|
| AC#3 — `/v1/preview/{id}` renders real content | PASS |
| AC#3 — Preview iframe loads in /studio (F-C1 `__s5Base`) | PASS |
| AC#3 — Iframe `src` + `sandbox` correct | PASS |
| AC#3 — BUG-A4: legacy route returns styled HTML 404 | FAIL |

The preview rendering path is functional end-to-end. The single failing item is BUG-A4: the legacy route `/session/{id}/preview` returns a raw JSON error body instead of the styled HTML 404 stub committed by Soraka dddd93e. This does not block preview functionality but the acceptance criterion is not met.

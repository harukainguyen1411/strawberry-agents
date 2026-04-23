---
agent: akali
track: QA-C
concern: work
target: https://demo-studio-266692422014.europe-west1.run.app
revision: demo-studio-00023-hjj
date: 2026-04-22
scope: ui-polish, static-assets, console-errors, route-discovery
verdict: PARTIAL
---

# Akali QA-C — UI Polish, Static Assets, Console Errors, Route Discovery
## demo-studio-00023-hjj (Option B vanilla API ship)

---

## Route Discovery Table

| Route | HTTP Status | Notes |
|-------|-------------|-------|
| `/` (root landing) | 200 | Clean render, no console errors |
| `/dashboard` | 200 | Renders but 4 console errors (localhost health endpoints) |
| `/session/new` | 401 | Bare JSON `{"detail":"Session mismatch"}` — no redirect, no UI |
| `/session/<id>` | 200 | Full session page renders |
| `/session/<id>/preview` | 404 | JSON `{"detail":"Not Found"}` — Bug 5 NOT restored |
| `/v1/preview/<id>` | 404 | JSON `{"detail":"Not Found"}` — S5 route not on S1 |
| `/static/studio.css` | 200 | Clean load |
| `/static/studio.js` | 200 | Clean load |

---

## Console Error Dumps

### `/dashboard`
```
[ERROR] Failed to load resource: net::ERR_CONNECTION_REFUSED @ http://localhost:3100/health?_t=...
[ERROR] Failed to load resource: net::ERR_CONNECTION_REFUSED @ http://localhost:3001/health?_t=...
[ERROR] Failed to load resource: net::ERR_CONNECTION_REFUSED @ http://localhost:3100/health?_t=...
[ERROR] Failed to load resource: net::ERR_CONNECTION_REFUSED @ http://localhost:3001/health?_t=...
```
(4 errors — two polls per auto-refresh cycle, two localhost endpoints)

### `/session/new`
```
[ERROR] Failed to load resource: the server responded with a status of 401 ()
```

### `/session/<id>/preview`
```
[ERROR] Failed to load resource: the server responded with a status of 404 ()
```

### `/v1/preview/<id>`
```
[ERROR] Failed to load resource: the server responded with a status of 404 ()
```

### `/session/<id>` (authenticated view of existing session)
```
[WARNING] An iframe which has both allow-scripts and allow-same-origin for its sandbox attribute can escape its sandboxing. @ .../static/studio.js:74
```
(0 errors, 1 security warning)

### `/` root
```
(no errors, no warnings)
```

---

## Network Errors

| Request | Status |
|---------|--------|
| `http://localhost:3100/health` (repeated) | FAILED — ERR_CONNECTION_REFUSED |
| `http://localhost:3001/health` (repeated) | FAILED — ERR_CONNECTION_REFUSED |
| `https://demo-studio-4nvufhmjiq-ew.a.run.app/session/<id>/stream` | 401 (expected — no auth cookie in headless browser) |

All other requests (CSS, JS, session data) return 200.

---

## Visual Findings

### Session page (`/session/<id>`)
- Layout intact: header, phase timeline, chat panel, preview panel all render.
- Preview pane shows "Preview unavailable (S5_BASE not configured)" placeholder — graceful fallback, but the pane is dead whitespace for all sessions until `__s5Base` is injected server-side.
- "Refresh" and "Open full screen" buttons visible in preview toolbar even when preview is unavailable — both are non-functional in this state; "Open full screen" is wired to `window.open(s5Base + '/v1/preview/...')` which resolves to `undefined/v1/preview/...` and silently opens a broken URL.
- Phase timeline items (Configure / Build / QC / Tweak / Complete) are plain `div` elements with no ARIA role or keyboard focus — not a regression, but noted.
- No spinner that never resolves observed on session page.
- No z-index or overflow issues observed.
- No dark mode; not applicable.

### Dashboard
- Service health panel shows three cards: "Demo Studio MCP" (DOWN, red), "Wallet Studio MCP" (DOWN, red), "Demo Studio Backend" (UP, green).
- The two DOWN cards map to `http://localhost:3100` and `http://localhost:3001` — these are the local dev defaults hardcoded in the dashboard's URL inputs. The prod dashboard is polling localhost instead of the real S2–S5 services. The service health UI is entirely stale/non-functional on prod.
- "Managed Agents" tab still present alongside "Sessions" — dead post-Option B; navigating to it will show stale managed-agent data.
- Cost footer shows "Managed Agent ($0.08/hr)" — label is stale post-Option B retirement.
- Dashboard Mode toggle shows "Local / Prod" with "Prod" active and the correct revision URL (`https://demo-studio-4nvufhmjiq-ew.a.run.app`), but backend health reports are still using localhost URLs for MCP Studio and Wallet MCP field defaults.

### Root landing (`/`)
- Clean, minimal, renders perfectly.
- Only entry point is a "Paste session ID or link" input — no UI way to create a new session from this page (confirmed Duong feedback: need Firebase auth + Create Session flow).

---

## Accessibility Smoke

| Check | Result |
|-------|--------|
| Chat composer `aria-label` | PASS — `aria-label="Chat message"` present |
| Send button keyboard access | PASS — button element, visible text "Send" |
| Chat/Preview tabs `role="tab"` | PASS — both tabs have `role="tab"` and `aria-selected` |
| Phase timeline items ARIA role | FAIL (LOW) — `div.phase-item` elements have no role; not keyboard-focusable |
| iframe sandbox escape risk | WARN — `allow-scripts + allow-same-origin` combination generates browser security warning (studio.js:74); a confined script could escape the sandbox |
| Missing alt text on images | N/A — no `<img>` elements on any page |
| Form labels (`/session/new`) | N/A — route returns raw 401 JSON; no form rendered |

---

## Severity-Tagged Findings

- **[HIGH] Bug 5 NOT restored — `/session/<id>/preview` still 404.** The S1 route was removed per BD.B.7/B.8 but the studio.js was never updated to use `__s5Base`. The studio.js code at line 219–239 *does* correctly reference `window.__s5Base` for the preview iframe src — however `__s5Base` is not being injected server-side into the session page HTML (observed: `window.__s5Base` is `undefined`/falsy on prod). The iframe silently shows an empty placeholder. The `/v1/preview/<id>` route also returns 404 on S1 (expected — it belongs to S5 which is not deployed or not URL-configured on this revision).

- **[HIGH] Dashboard service health cards hard-coded to localhost — broken on prod.** `http://localhost:3100` (MCP Studio) and `http://localhost:3001` (Wallet MCP) are the field defaults in prod mode. Every health poll fires ERR_CONNECTION_REFUSED and fills the console. The S2–S5 services are not listed. The dashboard's service health surface provides no real signal on prod.

- **[MEDIUM] `/session/new` returns raw JSON 401 with no UI.** A user or operator hitting this URL directly gets `{"detail":"Session mismatch"}` in the browser — no redirect to root, no helpful message. Should either redirect to `/` with an error flash or return a proper HTML 401 error page.

- **[MEDIUM] Dashboard "Managed Agents" tab and "Managed Agent ($0.08/hr)" cost label are stale post-Option B.** The tab navigates to managed-agent session detail views that are no longer meaningful; the cost label incorrectly frames cost tracking around a retired pricing model.

- **[LOW] iframe sandbox: `allow-scripts + allow-same-origin` combination generates browser security warning.** studio.js:74 builds the iframe with both attributes, which allows a contained page to remove its own sandbox attribute. The sandbox attribute string should drop `allow-same-origin` for the preview iframe, or the security trade-off should be explicitly documented.

- **[LOW] Phase timeline items (Configure / Build / QC / Tweak / Complete) have no ARIA role or keyboard access.** Plain `div` elements — not navigable by keyboard. If keyboard support is in scope, these should be `role="listitem"` inside a `role="list"` or `role="progressbar"`.

- **[LOW] "Open full screen" button is visible and clickable when `__s5Base` is not configured.** Clicking it opens `undefined/v1/preview/<id>/fullview` in a new tab, which fails silently. Button should be hidden or disabled when S5_BASE is absent.

---

## Screenshots

| Page | File |
|------|------|
| Dashboard (full page) | `akali-qa-c-dashboard-full.png` |
| `/session/new` — 401 JSON response | `akali-qa-c-session-new.png` |
| `/session/<id>` — session page | `akali-qa-c-session-id.png` |
| `/session/<id>/preview` — 404 JSON | `akali-qa-c-session-preview-route.png` |
| `/v1/preview/<id>` — 404 JSON | `akali-qa-c-v1-preview-id.png` |
| Root landing page | `akali-qa-c-root.png` |

Screenshots saved to working directory (playwright run directory).

---

## Known-in-flight (not gated)

- Viktor hotfix for managed-agent routing + C2 persistence — excluded from this assessment per task brief.

---

## Overall Verdict: PARTIAL

Static assets load cleanly (all 200). Session page UI renders and is functionally accessible for the chat compositor. Critical gaps: preview is completely non-functional end-to-end on prod (Bug 5 `__s5Base` not injected + both preview routes 404); dashboard service health is broken on prod (localhost URLs, stale managed-agent surface). No catastrophic layout regressions. No 5xx on any tested route.

— Akali

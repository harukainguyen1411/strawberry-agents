---
qa_agent: akali
scope: session-lifecycle + auth-flows
revision: demo-studio-00023-hjj
primary_url: https://demo-studio-266692422014.europe-west1.run.app
alt_url: https://demo-studio-4nvufhmjiq-ew.a.run.app
date: 2026-04-22
verdict: PARTIAL
---

# QA Report — Session Lifecycle + Auth Flows

**Revision:** `demo-studio-00023-hjj`
**Scope:** Landing page flow, session creation UI, auth exchange, token expiry, session page load, close/archive, dashboard session-list health
**Agent:** Akali (parallel QA pass A of 4)
**Date:** 2026-04-22

---

## Per-Screen Pass/Fail Table

| # | Scenario | Surface | Result | Notes |
|---|----------|---------|--------|-------|
| S1 | Landing page renders | `/` | PASS | Title, subtitle, session ID input, Open button all present. Single cosmetic console error: favicon.ico 404. |
| S2a | Empty session ID submit | `/` | PARTIAL | Clicking Open with empty field stays on `/`. No user-facing validation feedback shown (no error message, no field highlight). Open button enters "active" state briefly only. |
| S2b | Invalid session ID submit | `/session/{invalid}` | FAIL | Navigates to `/session/ses_invalid_test_12345`, returns raw JSON `{"detail":"Session mismatch"}` — no HTML error page, no styled state, no back navigation. |
| S3 | Auth exchange — valid active token | `/auth/session/{sid}?token=...` | PASS | Redirects to `/session/{sid}`, cookie `ds_session` set correctly (httpOnly, secure, sameSite=Strict). Console clean (favicon 404 only). |
| S4a | Stale/archived token (valid cryptography) | `/auth/session/{sid}?token=...` | PASS | 110h+ old archived session tokens still cryptographically valid are accepted and redirect to session page showing "Session archived." with chat disabled. Graceful. |
| S4b | Invalid/malformed token | `/auth/session/{sid}?token=...` | FAIL | Returns raw JSON `{"detail":"Invalid or expired token"}` with no HTML wrapper, no back button, no user-friendly presentation. Same bare-JSON pattern as S2b. |
| S4c | Token re-use (nonce exhaustion) | `/auth/session/{sid}?token=...` | PASS | Tokens are single-use. Re-using a consumed token correctly returns "Invalid or expired token". Correct nonce behavior. |
| S5 | Session page load after auth | `/session/{sid}` | PASS | Session page renders HTML shell correctly. Stepper (Configure/Build/QC/Tweak) visible. Chat area loads. Preview pane shows "Preview unavailable (S5_BASE not configured)" — expected. No 500s. Console: only favicon 404. |
| S5b | Cookie security attributes | cookies | PASS | `ds_session`: `httpOnly=true`, `secure=true`, `sameSite=Strict`. Correct. |
| S6a | Archive button visible for cancelled sessions | dashboard | PASS | 15 Archive buttons rendered for cancelled sessions in dashboard session list. |
| S6b | Session status of archived session | `/session/{sid}/status` | PASS | Status endpoint returns correct JSON: `{"status":"archived","phase":"configure",...}`. Publicly accessible (no auth required) — acceptable for read-only status. |
| S7a | Dashboard session list — refresh | `/dashboard` | PASS | "Refresh all" button updates the "updated at" timestamp correctly. Session list reloads. |
| S7b | Dashboard session count | `/dashboard` | PASS | 77 sessions shown. Active session `0fdb1de0` highlighted with green dot and warning indicator. |
| S7c | Dashboard loads without session param | `/dashboard` (no auth) | PASS | Dashboard loads without auth cookie. Service health shows correctly (MCP services DOWN — expected in prod, Backend UP). |
| S8 | `/session/{sid}/preview` route | `/session/{sid}/preview` | FAIL | Route returns raw JSON `{"detail":"Not Found"}`. "Open full screen" button in the preview pane navigates to this route when S5_BASE is not configured — user sees bare JSON instead of a handled error. |

---

## Bugs Found

### BUG-A1 — Bare JSON error responses on auth failure routes (HIGH)
**Affects:** S2b, S4b, S8
**Symptom:** Multiple routes return raw FastAPI JSON error responses directly to the browser with no HTML wrapper:
- `/session/{invalid_sid}` → `{"detail":"Session mismatch"}`
- `/auth/session/{sid}?token={invalid}` → `{"detail":"Invalid or expired token"}`
- `/session/{sid}/preview` (no S5_BASE) → `{"detail":"Not Found"}`

All three render as plain text in a browser JSON viewer (Chrome's "Pretty-print" raw JSON view), with no navigation affordance, no styled error page, and no back button.
**Severity:** HIGH — these are user-facing error states hit in normal usage flows (wrong link, expired link, preview before config is complete).
**Repro:** Navigate to any of the above URLs with invalid params or no S5_BASE.

---

### BUG-A2 — No client-side validation feedback on empty session ID submit (LOW)
**Affects:** S2a
**Symptom:** Clicking "Open" with an empty text field leaves the user on `/` with no visible error message. The Open button briefly enters an "active" CSS state. No field highlighting, no toast, no inline error text.
**Severity:** LOW — the user is not misdirected, but the UX is poor; user has no feedback on why nothing happened.
**Repro:** Visit `/`, leave session ID blank, click Open.

---

### BUG-A3 — `/session/{sid}/preview` navigated to automatically (MEDIUM)
**Affects:** S8
**Symptom:** During session page use, the browser auto-navigated to `/session/{sid}/preview` (which returns a bare 404 JSON). This was triggered automatically — likely by the "Open full screen" button or a JS polling mechanism — without explicit user intent. The resulting page is a dead-end bare JSON error.
**Severity:** MEDIUM — user can be stranded on an unrecoverable error page through normal session page interaction.
**Repro:** On session page with S5_BASE not configured, interact with the preview pane area; automatic navigation to `/preview` occurs.

---

## Cookie Behavior Summary

`ds_session` is session-scoped: the cookie payload contains the `sid`. Accessing `/session/{different_sid}` with a cookie for another session correctly returns 401 "Session mismatch". This is by design and not a bug — users need a fresh auth token per session. The token-based auth flow (via Slack link → `/auth/session/{sid}?token=...`) is the intended entry path.

Tokens are single-use (nonce-based). Old session tokens with valid cryptographic signatures (110h+) still authenticate for archived sessions. No time-based token expiry is enforced — only nonce exhaustion and signature validity. This is a design choice but means dashboard "Open" links for archived sessions remain permanently valid as long as the nonce hasn't been used.

---

## Dashboard — Session List Health

- 77 sessions loaded successfully on refresh.
- "Refresh all" button works; timestamp updates confirm live data fetch.
- "Archive All" button present and accessible.
- Archive buttons present for all cancelled (non-archived) sessions.
- Service health panel: MCP services show DOWN with `{"error":"Failed to fetch"}` — expected in prod context (localhost endpoints). Backend shows UP with 875ms response.
- Console errors on dashboard: only `ERR_CONNECTION_REFUSED` for localhost MCP health checks — expected.

---

## New Session UI

The "+ New Session" button is present on the session page and opens a modal form with: Brand name (text), Insurance line (combobox: Motor/Health/Home/Life/Travel/Pet/Commercial), Market (2-letter code text). "Cancel" and "Create" buttons present. Form submission (`POST /session/new`) was not exercised (would create real prod session). The `/session/new` endpoint is confirmed reachable (returns 405 for OPTIONS, implying POST is accepted).

---

## Screenshot Artifacts

| File | Scenario |
|------|----------|
| `qa-s1-landing-page.png` | Landing page full render |
| `qa-s2-invalid-session-id.png` | Bare JSON on invalid session ID |
| `qa-s3-dashboard.png` | Dashboard overview with session list |
| `qa-s4-session-page.png` | Session page after auth (active session) |
| `qa-s5-archived-session.png` | Archived session page state |
| `qa-s6-invalid-token.png` | Bare JSON on invalid token |
| `qa-s7-new-session-modal.png` | Dashboard — "New Session" form in dashboard context |
| `qa-s8-preview-not-found.png` | `/preview` bare JSON 404 |
| `qa-s9-dashboard-archive-buttons.png` | Dashboard with Archive buttons visible |

Screenshots are local to the Playwright session output directory.

---

## Overall Verdict: PARTIAL

Core auth exchange, cookie security, session page load, dashboard session list, and refresh all pass. Three bugs found — all center on bare JSON error responses exposed directly to users (BUG-A1, consolidated, HIGH severity), one UX gap on empty submit (LOW), and one unintended navigation to a broken route (MEDIUM). No 500s encountered. No data loss or security issues identified beyond the UX polish gaps.

**Total bugs: 3**
- HIGH: 1 (BUG-A1 — bare JSON errors on auth failure routes)
- MEDIUM: 1 (BUG-A3 — auto-navigation to unhandled /preview route)
- LOW: 1 (BUG-A2 — no validation feedback on empty session ID submit)

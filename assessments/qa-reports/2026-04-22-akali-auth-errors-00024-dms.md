---
qa_agent: akali
scope: auth-flows + error-page-ux
revision: demo-studio-00024-dms
primary_url: https://demo-studio-266692422014.europe-west1.run.app
date: 2026-04-22
verdict: PARTIAL
---

# QA Report — Auth Flows + Error-Page UX

**Revision:** `demo-studio-00024-dms`
**Scope:** Token-exchange, nonce reuse, invalid session, preview route, empty-submit validation, landing UX
**Agent:** Akali (scoped — auth + error pages)
**Date:** 2026-04-22

---

## Per-Screen Pass/Fail Table

| TC | Scenario | Route | Result | Notes |
|----|----------|-------|--------|-------|
| A1 | Token-exchange — valid token flow | `/auth/session/{sid}?token=...` | PARTIAL | No live token available; tested with invalid token against real sid. Auth endpoint now renders styled HTML error (401 "Invalid or expired token", "Back to home") in browser. Server still returns `content-type: application/json` — client-side route intercepts and renders error page. Cookie set behavior untestable without a real Slack-issued token. |
| A2 | Single-use nonce reuse | `/auth/session/{sid}?token=reused` | PASS | Invalid/exhausted token against real session id shows styled 401 "Invalid or expired token" + "Back to home". BUG-A1 from `00023-hjj` FIXED for this route. |
| A3 | Invalid/nonexistent session | `/session/sid_nonexistent_xyz` | PASS | Styled 401 page: "Session mismatch", "Back to home" link navigates to `/`. BUG-A1 from `00023-hjj` FIXED for this route. |
| A4 | Deleted preview route | `/session/{sid}/preview` | FAIL | Still returns raw JSON `{"detail":"Not Found"}` in browser with no HTML wrapper, no navigation. BUG-A1 NOT fixed for this sub-route. |
| A5 | Empty session-id submit | `/` (Open button) | PASS | Inline `alert` role element "Please enter a session ID." appears. `aria-invalid=true`, `aria-describedby=sessionInputError` set on input. BUG-A2 from `00023-hjj` FIXED. |
| A6 | Landing page basic UX | `/` | PASS | Title "Demo Studio", subtitle, session input, Open button all present. Clean layout. One favicon 404 console error (pre-existing). |

---

## Bugs Found

### BUG-A4 (MEDIUM) — `/session/{sid}/preview` still renders raw JSON

**Symptom:** Navigating to `/session/{sid}/preview` in browser returns raw `{"detail":"Not Found"}` with no HTML wrapper, no styled error page, no navigation affordance. Server returns `content-type: application/json`. The client-side error interceptor that now handles `/session/{sid}` and `/auth/session/{sid}` does not cover the `/preview` sub-route.

**Prior state:** BUG-A1 in `00023-hjj` covered this as one of three raw-JSON failure modes. The other two are now fixed.

**Severity:** MEDIUM — user can reach this route via "Open full screen" button on preview pane when S5_BASE is not configured (per BUG-A3 in prior report). Dead-end with no recovery path.

**Repro:** Navigate directly to `/session/any-sid/preview`.

---

## Regression Notes (vs `00023-hjj`)

| Issue | Prior State | `00024-dms` State |
|-------|-------------|-------------------|
| BUG-A1 — bare JSON on invalid session | FAIL | FIXED (A3) |
| BUG-A1 — bare JSON on bad/expired token | FAIL | FIXED (A2) |
| BUG-A1 — bare JSON on /preview route | FAIL | STILL FAILING (A4) |
| BUG-A2 — no empty-submit feedback | FAIL | FIXED (A5) |

---

## Screenshot Artifacts

| File | Scenario |
|------|----------|
| `qa-auth-landing.png` | Landing page full render |
| `qa-auth-invalid-session.png` | Styled 401 "Session mismatch" error page |
| `qa-auth-nonce-reuse-error.png` | (browser redirect occurred; functional verification via snapshot) |

---

## Overall Verdict: PARTIAL

BUG-A1 is 2/3 fixed: styled error pages now render for invalid session IDs and bad/expired tokens. The `/preview` sub-route remains unhandled (raw JSON). BUG-A2 (empty submit) is fully fixed with inline error and correct ARIA attributes. Token-exchange happy-path (cookie security attributes) could not be verified without a live Slack-issued token — no regression evidence, carries forward from `00023-hjj` PASS.

**Remaining open bug: 1 (MEDIUM)**

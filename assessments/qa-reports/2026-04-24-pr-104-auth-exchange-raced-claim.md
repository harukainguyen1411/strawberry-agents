---
slug: 2026-04-24-pr-104-auth-exchange-raced-claim
surface: auth_exchange session-ownership claim (user-flow)
pr: 104
branch: fix/demo-studio-v3-auth-exchange-raced-claim
base: feat/demo-studio-v3
date: 2026-04-24
agent: akali
verdict: PASS
environment: local — uvicorn 127.0.0.1:8080, branch tip 121e191
---

# QA Report — PR #104 auth_exchange raced-claim

**PR:** https://github.com/missmp/company-os/pull/104  
**Branch:** `fix/demo-studio-v3-auth-exchange-raced-claim` @ 121e191  
**Date:** 2026-04-24  
**Agent:** Akali (Sonnet)  
**Environment:** Local server — `uvicorn main:app --host 127.0.0.1 --port 8080` running PR branch code. Firestore: `mmpt-233505 / demo-studio-staging`. All 5 services UP at test time.

---

## Change Under Test

PR #104 (two commits):

- `dce4343` — xfail tests for `auth_exchange` raced-claim TOCTOU  
- `121e191` — raced-claim branch returns 403 with `{"reason": "raced_claim", "sid": sid}`

Handler diff: `tools/demo-studio-v3/main.py` +24 lines. When `set_session_owner` returns `False` (transactional race lost), the handler re-reads the session to distinguish:
- Foreign win → `HTTPException(403, {"reason": "raced_claim", "sid": sid})`
- Self win (idempotent) → fall through to 303 redirect

---

## Per-Screen Pass/Fail Table

| TC | Scenario | Method | Route | Result | Evidence |
|----|----------|--------|-------|--------|----------|
| S1 | Happy path — unauthenticated visitor follows nonce URL, gets 303 redirect to session page | Browser navigation (Playwright) | `GET /auth/session/{sid}?token=...` (no `ds_session` cookie) | PASS | Browser landed at `/session/66223cd91b0a4bc98453510b14135956` — session page fully loaded, title "Demo Studio — Allianz" |
| S2a | Idempotent re-exchange — same caller hits auth_exchange on their session | Browser navigation (Playwright) | `GET /auth/session/{sid}?token=...` (no `ds_session` cookie, legacy path) | PASS | First exchange → `/session/5a3a5416...`. Reauth generated fresh token; second exchange also → `/session/5a3a5416...`. No 403. |
| S2b | Token-reuse protection (prior token rejected) | curl | `GET /auth/session/{old_sid}?token=consumed_token` | PASS | HTTP 401 "Invalid or expired token" — one-time token correctly exhausted |
| S3 | Raced-claim concurrent exchange — loser gets 403 with `raced_claim` body | Unit test (pytest) | `GET /auth/session/{sid}?token=...` (mocked race) | PASS | `test_auth_exchange_raced_claim_returns_403_with_reason` PASSED — 403 with `detail["reason"]=="raced_claim"` and `detail["sid"]==sid`, no Location redirect header |
| S3b | Idempotent re-exchange (self-won race) — same caller still gets 303 | Unit test (pytest) | `GET /auth/session/{sid}?token=...` (mocked self-race) | PASS | `test_auth_exchange_idempotent_reexchange_succeeds` PASSED — 303 redirect, not 403 |
| S4 | Session already owned by different Firebase user → early 403 | curl + valid Firebase cookie | `GET /auth/session/{sid}?token=...` (with `ds_session` cookie for uid≠owner) | PASS | HTTP 403 `{"detail": "Session already claimed by another user"}` — pre-race ownership guard fires correctly |

**Overall verdict: PASS**

---

## Figma Design Reference

None applicable. PR #104 introduces no new UI surfaces, no new HTML templates, no CSS changes. The only externally visible change is the HTTP response code/body for a specific error condition on a server-side route. No Figma diff warranted.

---

## Screenshots

All screenshots captured via `mcp__plugin_playwright_playwright__browser_*` on `127.0.0.1:8080`.

| File | Description |
|------|-------------|
| `pr104-01-dashboard-before.png` | Dashboard at test start — all 5 services UP, 7 sessions visible |
| `pr104-02-s1-happy-path-after-redirect.png` | S1: browser landed on `/session/66223cd9...` after auth_exchange 303 |
| `pr104-03-s2-idempotent-first-exchange.png` | S2: first exchange on session `5a3a5416...` → session page loaded |
| `pr104-04-s2-idempotent-reexchange.png` | S2: second (idempotent) exchange on same session → session page, no 403 |
| `pr104-05-s2-idempotent-confirmed.png` | S2: final state confirmation |

Screenshot paths: `assessments/qa-reports/pr104-*.png`

---

## Unit Test Run

```
tests/test_auth_exchange_raced_claim.py::test_auth_exchange_raced_claim_returns_403_with_reason PASSED
tests/test_auth_exchange_raced_claim.py::test_auth_exchange_idempotent_reexchange_succeeds PASSED
2 passed in 0.37s
```

Run in worktree: `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-auth-raced-claim/tools/demo-studio-v3`

---

## Scenario 3 — Race Condition Browser Staging

The concurrent-race scenario (two browser contexts hitting auth_exchange simultaneously on the same unclaimed session within the transactional window) was not reproducible via browser. Reasons:

1. All current Firestore sessions were created with `ownerUid=""` (Slack bot path, `POST /session`) or a real UID (Firebase UI path). Neither has `ownerUid=null` as required to enter the `set_session_owner` branch.
2. Legacy sessions (`ownerUid` field absent) exist but produce a 500 when a Firebase-cookie holder calls `set_session_owner` — pre-existing Firestore schema incompatibility, unrelated to PR #104.
3. Staging a sub-millisecond transactional race between two Playwright browser contexts is not a reliable browser-level test.

`QA-Waiver: race-condition-not-reproducible-in-headed-browser — covered by unit xfails dce4343 (2 tests, both PASS at 121e191)`

The 403 response shape `{"detail": {"reason": "raced_claim", "sid": sid}}` and the redirect/non-redirect invariant are fully exercised by the unit tests committed on the same branch.

---

## Pre-existing Issues Observed (not introduced by PR #104)

1. **Legacy sessions 500 on Firebase ownership claim** — Sessions created without an `ownerUid` field in Firestore return HTTP 500 `{"error": "'ownerUid' is not contained in the data"}` when a Firebase-cookie holder calls `auth_exchange`. This is a pre-existing Firestore schema/field incompatibility and is not in scope for PR #104.

---

## Regression Confirmation

The happy-path redirect (Scenario 1) was verified against session `66223cd9...` on the PR branch. The session page loads correctly, all dashboard services remain UP, and no regressions were observed in the normal auth_exchange flow.

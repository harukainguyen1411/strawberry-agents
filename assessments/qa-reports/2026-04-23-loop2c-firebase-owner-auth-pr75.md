---
slug: 2026-04-23-loop2c-firebase-owner-auth-pr75
surface: firebase-owner-aware-auth-deps (Loop 2c)
pr: 75
branch: feat/firebase-auth-2c-impl
commit: 047e025
base: feat/demo-studio-v3 (xfail harness at feat-firebase-2c-xfails)
date: 2026-04-23
verdict: PASS-WITH-NOTES
figma: no Figma ref (Loop 2c is server-side only; no new UI surface)
---

# QA Report — PR #75 Firebase Owner-Aware Auth Deps (Loop 2c)

## Scope

PR #75 migrates all `/session/{sid}/*` routes from the deprecated `require_session` dep to a new
Firebase-aware owner-auth dep chain. User-flow changes per Rule 16 definition:
new auth behavior on existing routes, session ownership claim, 403 cross-user enforcement,
`/stream` under `require_session_or_owner`, legacy cookie rejection on `/session/new`.

## Staging Environment

Branch `feat/firebase-auth-2c-impl` has no deployed staging environment. No CI runs exist for the branch.
QA was performed against a locally-started server using the worktree at
`/Users/duongntd99/Documents/Work/mmp/workspace/feat-firebase-2c-impl/tools/demo-studio-v3`
with production `.env` (excluding secrets committed to git; `.env` removed after run).

Server started: `http://127.0.0.1:8766`

## Figma Reference

No Figma ref — Loop 2c introduces no new UI surface. All changes are HTTP status-code behaviors on
existing routes. Comparison baseline: PR #69 (Loop 2b) which established the auth chrome.

## Per-Screen / Per-Flow Pass/Fail Table

| Flow | Figma Frame | Expected | Actual | Screenshot | Result |
|------|-------------|----------|--------|------------|--------|
| Dashboard landing | N/A | Renders, Local mode default | Rendered — S1 DOWN (expected: backend URL default is :8080) | pr75-01-dashboard-landing.png | PASS |
| Main page (signed-out) | N/A | Session form, no auth error | Session form shown, Firebase degraded (no emulator) | pr75-02-main-signed-out.png | PASS |
| `GET /session/{sid}` — no cookie | N/A | 401 "Session mismatch" error page | 401 rendered correctly | pr75-03-session-no-auth-401.png | PASS |
| Nonce-exchange → session owner | N/A | `/auth/session/{id}?token=...` redirects to session page | Redirected, session UI loaded | pr75-04-session-owner-authenticated.png | PASS |
| `POST /session/new` — no cookie | N/A | 401 | 401 | — | PASS |
| `POST /session/new` — Firebase cookie (Alice) | N/A | 201 + studioUrl | 201 `{"sessionId":…,"studioUrl":"/auth/session/…"}` | — | PASS |
| `POST /session/new` — legacy old-format string cookie | N/A | 401 (per dual-stack) | 500 (pre-existing bug — see Notes) | — | NOTE |
| `GET /session/{sid}` — Alice (owner) | N/A | 200 | 200 | — | PASS |
| `GET /session/{sid}` — Bob (non-owner) | N/A | 403 | 403 | — | PASS |
| `GET /session/{sid}/status` — owner | N/A | 200 | 200 | — | PASS |
| `GET /session/{sid}/status` — non-owner | N/A | 403 | 403 | — | PASS |
| `POST /session/{sid}/chat` — owner | N/A | 200 | 200 | — | PASS |
| `POST /session/{sid}/chat` — non-owner | N/A | 403 | 403 | — | PASS |
| `POST /session/{sid}/chat` — internal secret bypass | N/A | non-403 | 200 | — | PASS |
| `GET /session/{sid}/logs` — owner | N/A | 200 | 200 | — | PASS |
| `GET /session/{sid}/logs` — non-owner | N/A | 403 | 403 | — | PASS |
| `GET /session/{sid}/events` — non-owner | N/A | 403 | 403 | — | PASS |
| `GET /session/{sid}/messages` — non-owner | N/A | 403 | 403 | — | PASS |
| `GET /session/{sid}/history` — non-owner | N/A | 403 | 403 | — | PASS |
| `GET /session/{sid}/stream` — owner | N/A | 200 | 200 | — | PASS |
| `GET /session/{sid}/stream` — non-owner | N/A | 403 | 403 | — | PASS |
| `GET /session/{sid}/stream` — internal secret | N/A | non-403 | 200 | — | PASS |
| `POST /session/{sid}/close` — owner | N/A | 200 | 200 | — | PASS |
| `POST /session/{sid}/close` — non-owner | N/A | 403 | 403 | — | PASS |
| `/auth/me` — no cookie | N/A | 401 | 401 | — | PASS |

## Pytest Suite

**Core Loop 2c tests — 82/82 PASS:**

| File | Count | Result |
|------|-------|--------|
| `test_require_session_owner.py` | — | PASS |
| `test_require_user.py` | — | PASS |
| `test_require_session_or_owner.py` | 3 | PASS |
| `test_route_auth_matrix_2c.py` | 63 | PASS |
| `test_session_ownership.py` | 4 | PASS |

**Full suite (non-integration, excl. test_akali_qa_bugs_234.py):**
941 passed, 71 failed, 17 skipped, 146 xfailed.
All 71 failures confirmed pre-existing on base branch `feat-firebase-2c-xfails`. Zero new regressions.

## Video Artifacts

No CI E2E workflow runs exist for this branch. No video recorded (no `browser_start_video` support
available in current Playwright MCP version). Screenshots below serve as artifact record.

## Screenshots

- `assessments/qa-reports/pr75-01-dashboard-landing.png` — Dashboard in local mode
- `assessments/qa-reports/pr75-02-main-signed-out.png` — Main page, unauthenticated
- `assessments/qa-reports/pr75-03-session-no-auth-401.png` — 401 "Session mismatch" error page on direct session URL
- `assessments/qa-reports/pr75-04-session-owner-authenticated.png` — Session page after nonce-exchange auth flow

## Notes

### NOTE-1: Legacy old-format string cookie causes 500 (pre-existing, not introduced by PR)

`verify_session_cookie` in `auth.py:83` calls `data.get("sid")` after deserializing the cookie.
Old-format cookies serialized with `_serializer.dumps(session_id)` (plain string, not a dict)
deserialize to a Python `str`, causing `AttributeError: 'str' object has no attribute 'get'`.
The `except BadSignature` in `verify_session_cookie` does not catch `AttributeError`, so the
exception propagates through `require_user` to FastAPI as a 500.

**Confirmed pre-existing:** same error reproducible on `feat-firebase-2c-xfails` (base branch).
**Impact:** Users with cookies minted before `create_session_cookie` was updated to store a dict
payload will get a 500 instead of a 401. In practice this only affects sessions created before the
dict format was introduced and only when `AUTH_LEGACY_COOKIE_ALLOWED=True`.

Fix (one line in `auth.py`): wrap `data.get("sid")` in a type guard:
```python
if not isinstance(data, dict):
    return None
return data.get("sid")
```

This fix is not required to merge PR #75 (pre-existing, not introduced), but is recommended.

### NOTE-2: No full Firebase sign-in popup flow tested

The Firebase `signInWithGoogle` popup flow requires a live Firebase project with valid API key
and either the Firebase Auth Emulator or a real domain. The local server returns
`{"projectId":"","apiKey":"","authDomain":""}` from `/auth/config` (empty values in .env for
the Firebase web SDK fields), so the popup flow cannot be exercised locally. This was also
noted in PR #69 (Loop 2b) QA report. The route-level auth enforcement (which is what Loop 2c
changes) has been fully verified via API-level and unit testing.

## Overall Verdict: PASS-WITH-NOTES

All 22 route auth behaviors pass. 82/82 Loop 2c unit tests pass. Full suite shows zero new
regressions vs base branch. One pre-existing 500 bug on old-format legacy cookies documented
(NOTE-1). Nonce-exchange UI flow verified end-to-end via Playwright. No Figma diff required
(no new UI surface).

QA-Report: assessments/qa-reports/2026-04-23-loop2c-firebase-owner-auth-pr75.md

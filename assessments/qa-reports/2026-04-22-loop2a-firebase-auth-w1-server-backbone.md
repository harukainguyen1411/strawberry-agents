# Loop 2a QA — Firebase Auth W1 server backbone

**Date:** 2026-04-22
**Branch / HEAD:** `feat/demo-studio-v3` @ `b2adf20` (impl)
**Predecessor xfail commit:** `6a96d04`
**Plan:** `plans/proposed/work/2026-04-22-firebase-auth-loop2a-server-backbone.md`
**Parent ADR:** `plans/approved/work/2026-04-22-firebase-auth-for-demo-studio.md`
**Surface:** local — demo-studio on `http://127.0.0.1:8083`

## Before (identify pass)

- `firebase-admin` not in `requirements.txt`.
- No `firebase_auth.py` module.
- No `/auth/login`, `/auth/logout`, `/auth/me`, `/auth/config` routes. Landing
  page has no Sign-in affordance. Cookie `ds_session` holds only a session ID
  bound by the one-time token flow.

## Change

- **Plan:** `plans/proposed/work/2026-04-22-firebase-auth-loop2a-server-backbone.md`
  committed to main as `c59e2d6`.
- **xfail tests:** 3 files, 15 tests — `tests/test_firebase_auth.py` (5),
  `tests/test_auth_cookie_encode.py` (2), `tests/test_auth_routes.py` (8).
  Committed on `feat/demo-studio-v3` as `6a96d04`, verified 15 xfailed / 0 xpassed.
- **Implementation:** `feat/demo-studio-v3` @ `b2adf20`:
  - `requirements.txt`: +`firebase-admin>=6.5.0`.
  - `firebase_auth.py` (new): `User` dataclass; `verify_firebase_token(id_token)`;
    `InvalidTokenError` / `DomainNotAllowedError`; lazy Admin-SDK init with ADC
    preference and `FIREBASE_SERVICE_ACCOUNT_JSON` fallback; `email_verified`
    gate; domain-lowercase allowlist (OQ 6).
  - `auth.py`: `encode_user_cookie`, `decode_user_cookie`, `USER_COOKIE_MAX_AGE`
    (7 days per OQ 2), `AUTH_LEGACY_COOKIE_ALLOWED = True`. Existing
    `create_session_cookie` / `verify_session_cookie` / `require_session`
    untouched — migration is Loop 2c.
  - `main.py`: four new routes injected before `/auth/session/{sid}`:
    - `GET /auth/config` → `{projectId, apiKey, authDomain}` (public, from env).
    - `POST /auth/login` body `{idToken}` → verify → 204 + `ds_session` cookie
      (`HttpOnly; SameSite=strict; Max-Age=7d`); 400 missing / 401 invalid /
      403 wrong-domain.
    - `POST /auth/logout` → 204 + cookie cleared (`Max-Age=0`).
    - `GET /auth/me` → 200 `{uid, email}` or 401.
- 15 xfail markers stripped; all 15 tests green.

## After (verify pass)

### Unit + integration tests

    $ cd tools/demo-studio-v3
    $ python -m pytest tests/test_firebase_auth.py \
        tests/test_auth_cookie_encode.py \
        tests/test_auth_routes.py -q
    ...............                                                          [100%]
    15 passed in 2.51s

### curl smokes

    $ curl -s http://127.0.0.1:8083/auth/config
    {"projectId":"mmpt-233505","apiKey":"local-web-key-test","authDomain":"mmpt-233505.firebaseapp.com"}
    HTTP 200

    $ curl -s -w "HTTP %{http_code}\n" http://127.0.0.1:8083/auth/me
    {"detail":"not authenticated"}HTTP 401

    $ curl -s -w "HTTP %{http_code}\n" -X POST \
        -H "Content-Type: application/json" -d '{}' \
        http://127.0.0.1:8083/auth/login
    {"detail":"missing idToken"}HTTP 400

    $ curl -s -D - -X POST http://127.0.0.1:8083/auth/logout
    HTTP/1.1 204 No Content
    set-cookie: ds_session=""; HttpOnly; Max-Age=0; Path=/; SameSite=strict

### Playwright verify

- Navigate `http://127.0.0.1:8083/auth/config` → renders JSON body with
  correct `projectId`/`apiKey`/`authDomain`. Screenshot at
  `assessments/qa-reports/2026-04-22-loop2a-auth-config-200.png`.
- `fetch('/auth/me', {credentials:'include'})` from same page → `status: 401`,
  body `{"detail":"not authenticated"}`.

### Cookie + behavior spot checks

| Endpoint | Input | Expected | Observed |
|---|---|---|---|
| `GET /auth/config` | — | 200 + config JSON | 200 ✅ |
| `GET /auth/me` | no cookie | 401 `"not authenticated"` | 401 ✅ |
| `POST /auth/login` | `{}` | 400 `"missing idToken"` | 400 ✅ |
| `POST /auth/logout` | — | 204 + ds_session cleared | 204, `Max-Age=0` ✅ |

## Tests

```
tests/test_firebase_auth.py::test_valid_token_returns_user PASSED
tests/test_firebase_auth.py::test_email_not_verified_raises PASSED
tests/test_firebase_auth.py::test_wrong_domain_raises PASSED
tests/test_firebase_auth.py::test_expired_token_raises PASSED
tests/test_firebase_auth.py::test_domain_case_insensitive PASSED
tests/test_auth_cookie_encode.py::test_encode_decode_round_trip PASSED
tests/test_auth_cookie_encode.py::test_tampered_cookie_returns_none PASSED
tests/test_auth_routes.py::test_login_happy_path_sets_cookie PASSED
tests/test_auth_routes.py::test_login_missing_token_returns_400 PASSED
tests/test_auth_routes.py::test_login_invalid_token_returns_401 PASSED
tests/test_auth_routes.py::test_login_wrong_domain_returns_403 PASSED
tests/test_auth_routes.py::test_logout_clears_cookie PASSED
tests/test_auth_routes.py::test_me_authed_returns_user PASSED
tests/test_auth_routes.py::test_me_unauth_returns_401 PASSED
tests/test_auth_routes.py::test_config_returns_public_values PASSED
15 passed in 2.51s
```

## Screenshot

`assessments/qa-reports/2026-04-22-loop2a-auth-config-200.png` — renders the
expected `{projectId, apiKey, authDomain}` JSON at `/auth/config`.

## Follow-ups not taken this loop

- **Loop 2b — Frontend sign-in.** `static/index.html` adds Firebase Web SDK,
  Sign-in with Google button, post-login UI; `static/auth.js` helper.
- **Loop 2c — Route migration.** `require_session` → `User`; new
  `require_session_owner`; dual-stack decode; all `/session/{sid}/*` routes
  migrate.
- **Loop 2d — Slack scaffolding removal.** Per Duong's "entirely" directive:
  drop `slack_user_id`/`slack_channel`/`slack_thread_ts` fields, `POST /session`
  Slack handoff, and (open question) `/auth/session/{sid}?token=...` if we go
  truly slack-free rather than dual-stack.
- **W0 IAM grant.** `roles/firebase.sdkAdminServiceAgent` on SA
  `266692422014-compute@developer.gserviceaccount.com` remains human-blocked —
  needed only once we deploy to Cloud Run and exercise Admin-SDK calls beyond
  `verify_id_token`. Unit tests mock the verifier.

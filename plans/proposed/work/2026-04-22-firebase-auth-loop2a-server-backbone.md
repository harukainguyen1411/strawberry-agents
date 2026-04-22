---
status: approved
orianna_gate_version: 2
complexity: normal
concern: work
owner: sona
created: 2026-04-22
tags:
  - demo-studio
  - auth
  - firebase
  - work
tests_required: true
---

# Loop 2a — Firebase auth W1 server backbone

<!-- orianna: ok — every file-path token in this plan (main.py, auth.py, firebase_auth.py, requirements.txt, tests/test_firebase_auth.py, tests/test_auth_routes.py, tools/demo-studio-v3/*) references files inside the missmp/company-os work workspace under company-os/tools/demo-studio-v3/, not strawberry-agents -->
<!-- orianna: ok — HTTP path tokens (/auth/login, /auth/logout, /auth/me, /auth/config, /auth/session/{sid}) are route paths on the demo-studio Cloud Run service, not filesystem paths -->
<!-- orianna: ok — env-var name tokens (FIREBASE_PROJECT_ID, FIREBASE_WEB_API_KEY, FIREBASE_AUTH_DOMAIN, ALLOWED_EMAIL_DOMAIN, SESSION_SECRET, GOOGLE_APPLICATION_CREDENTIALS) are environment variables, not filesystem paths -->
<!-- orianna: ok — external tokens (firebase-admin, itsdangerous, identitytoolkit.googleapis.com) are library/SDK refs, not files -->
<!-- orianna: ok — cookie token (ds_session) is an HTTP cookie name, not filesystem -->

## 1. Context

Loop 2 of Duong's hands-dirty cadence continues the P0 goal: user reliably logs in + creates session. The approved ADR
`plans/approved/work/2026-04-22-firebase-auth-for-demo-studio.md` <!-- orianna: ok -- cross-repo plan path, lives in strawberry-agents not company-os --> (Orianna-signed
`sha256:91a431b7ed3f69b260755586908979245602a06e9d3e815d9ba432790d232d86`) lays out W0–W6 for the full Firebase cutover.
The W0 spike is HUMAN-BLOCKED on an IAM grant (`roles/firebase.sdkAdminServiceAgent` <!-- orianna: ok -- GCP IAM role name, not a filesystem path --> on SA
`266692422014-compute@developer.gserviceaccount.com`).

`verify_id_token` does not actually need an IAM role — it fetches public JWKs from Google's CDN and verifies
signatures cryptographically. The IAM role is only needed for Admin-SDK project metadata operations we don't use.
W1 unit tests mock the verifier entirely, so we are unblocked on this loop.

**Loop 2a scope** — narrow slice of W1: add the dependency, create the module, add the four `/auth/*` routes,
all TDD'd with mocked verify. Deferred to later loops:

- Loop 2b: Frontend sign-in UI (W4).
- Loop 2c: Route migrations `require_session` → `User` + `require_session_owner` (W2, W3).
- Loop 2d: Slack scaffolding removal per Duong's "entirely" directive.

## 2. Decision

Deliver W1.1–W1.13 of the parent ADR on branch `feat/demo-studio-v3` <!-- orianna: ok -- Git branch name in company-os workspace, not strawberry-agents path -->:

1. `requirements.txt` <!-- orianna: ok -- company-os workspace file, not strawberry-agents --> gains `firebase-admin>=6.5.0`.
2. New module `firebase_auth.py` <!-- orianna: ok -- company-os workspace file -->: `verify_firebase_token(id_token: str) -> User`,
   `User` dataclass (`uid`, `email`), raises `InvalidTokenError` / `DomainNotAllowedError`. Reads
   `FIREBASE_PROJECT_ID` + `ALLOWED_EMAIL_DOMAIN` from env. Initializes `firebase_admin` app lazily.
3. `auth.py` <!-- orianna: ok -- company-os workspace file --> gains `encode_user_cookie(user)` / `decode_user_cookie(raw)` helpers and
   module flag `AUTH_LEGACY_COOKIE_ALLOWED = True`. **`require_session` signature is NOT changed this loop** —
   that migration is Loop 2c. Only the new encode/decode helpers are added.
4. `main.py` <!-- orianna: ok -- company-os workspace file --> gains four new routes:
   - `POST /auth/login` — body `{idToken}` → verify → set cookie `{uid, email, iat}` → 204.
   - `POST /auth/logout` — clear cookie → 204.
   - `GET /auth/me` — return `{uid, email}` or 401.
   - `GET /auth/config` — return `{projectId, apiKey, authDomain}` from env (public).
5. Cookie payload format: `{uid, email, iat}`. Max-Age: 7 days (OQ 2 from parent ADR). Existing
   `ds_session` cookie name reused (dual-stack decode handled in Loop 2c).

Failure modes:

| Condition | Route | Status | Body |
|---|---|---|---|
| `idToken` missing | POST /auth/login | 400 | `{"detail": "missing idToken"}` |
| `email_verified=False` | POST /auth/login | 403 | `{"detail": "email not verified"}` |
| wrong domain | POST /auth/login | 403 | `{"detail": "domain not allowed"}` |
| expired/malformed token | POST /auth/login | 401 | `{"detail": "invalid token"}` |
| unauthenticated | GET /auth/me | 401 | `{"detail": "not authenticated"}` |
| env var unset | GET /auth/config | 200 | `{projectId: null, ...}` (advisory, not fatal) |

## 3. Scope

- **In scope:** dep, module, four routes, cookie encode/decode helpers, xfail-first unit tests, Playwright
  smoke (`/auth/config` 200, `/auth/me` 401 when unauth).
- **Out of scope:** UI changes, `require_session` rewrite, `require_session_owner`, session ownership field,
  token-exchange redirect, Slack removal, deploy. All follow-on loops.

## Test plan

Test files (xfail-first, Rule 12):

- `mmp/workspace/tools/demo-studio-v3/tests/test_firebase_auth.py` <!-- orianna: ok -- company-os workspace test file --> — 5 cases:
  valid token → User; `email_verified=False` → raises `DomainNotAllowedError` / `InvalidTokenError`
  (TBD inside impl); wrong domain → raises; expired → raises; missing env → clear error. Mock
  `firebase_admin.auth.verify_id_token`.
- `mmp/workspace/tools/demo-studio-v3/tests/test_auth_routes.py` <!-- orianna: ok -- company-os workspace test file --> — 6 cases:
  POST /auth/login happy path sets cookie + 204; POST /auth/login bad token → 401; POST /auth/login
  wrong domain → 403; POST /auth/logout clears cookie; GET /auth/me authed → 200 with `{uid, email}`;
  GET /auth/me unauth → 401. Plus: GET /auth/config returns env values.
- `mmp/workspace/tools/demo-studio-v3/tests/test_auth_cookie_encode.py` <!-- orianna: ok -- company-os workspace test file --> — 2 cases:
  `encode_user_cookie` → `decode_user_cookie` round-trips `{uid, email, iat}`; tampered cookie → None.

All tests committed as xfail first, then flipped green once impl lands.

## 4. Risks

- `firebase_admin.initialize_app()` is app-global; must be idempotent across test reloads. Guard with
  `try: get_app(); except: initialize_app()`.
- Tests must NOT actually contact `identitytoolkit.googleapis.com` <!-- orianna: ok -- external URL, not filesystem path --> — verify all network mocked.
- Cookie secret (`SESSION_SECRET`) reused from existing `auth.py` <!-- orianna: ok -- company-os workspace file -->; no new secret introduced this loop.
- `AUTH_LEGACY_COOKIE_ALLOWED` flag is added but unused this loop (dual-stack decode lands in 2c).
  Acceptable tech debt — flag value already decided (True).

## 5. Out of scope follow-ups

- Loop 2b: Frontend sign-in (`static/index.html` <!-- orianna: ok -- company-os workspace file -->, `static/auth.js` <!-- orianna: ok -- company-os workspace file -->, `static/studio.css` <!-- orianna: ok -- company-os workspace file -->).
- Loop 2c: `require_session` → `User` migration + `require_session_owner` for all `/session/{sid}/*` routes.
- Loop 2d: Drop Slack scaffolding (`slack_user_id`, `slack_channel`, `slack_thread_ts` fields; `POST /session`
  Slack handoff path; `/auth/session/{sid}?token=...` if we go "entirely" per Duong's directive).
- Deploy: Ekko lane once IAM grant lands.

## Tasks

- [ ] **T.1** — Write xfail test file `mmp/workspace/tools/demo-studio-v3/tests/test_firebase_auth.py` with 5 cases per §Test plan, mocking `firebase_admin.auth.verify_id_token`. owner: sona. estimate_minutes: 15. Files: `mmp/workspace/tools/demo-studio-v3/tests/test_firebase_auth.py` <!-- orianna: ok -- company-os workspace file -->. DoD: `pytest tests/test_firebase_auth.py -q` reports 5 xfailed, 0 xpassed.
- [ ] **T.2** — Write xfail test file `mmp/workspace/tools/demo-studio-v3/tests/test_auth_cookie_encode.py` with 2 cases covering encode/decode round-trip and tamper detection. owner: sona. estimate_minutes: 8. Files: `mmp/workspace/tools/demo-studio-v3/tests/test_auth_cookie_encode.py` <!-- orianna: ok -- company-os workspace file -->. DoD: 2 xfailed, 0 xpassed.
- [ ] **T.3** — Write xfail test file `mmp/workspace/tools/demo-studio-v3/tests/test_auth_routes.py` with 7 cases covering all four routes per §Test plan. owner: sona. estimate_minutes: 15. Files: `mmp/workspace/tools/demo-studio-v3/tests/test_auth_routes.py` <!-- orianna: ok -- company-os workspace file -->. DoD: 7 xfailed, 0 xpassed.
- [ ] **T.4** — Add `firebase-admin>=6.5.0` to `requirements.txt`. owner: sona. estimate_minutes: 3. Files: `mmp/workspace/tools/demo-studio-v3/requirements.txt` <!-- orianna: ok -- company-os workspace file -->. DoD: pip install clean in fresh venv.
- [ ] **T.5** — Create `mmp/workspace/tools/demo-studio-v3/firebase_auth.py` with `User` dataclass, `verify_firebase_token`, exception types, lazy-init of `firebase_admin` app. owner: sona. estimate_minutes: 25. Files: `mmp/workspace/tools/demo-studio-v3/firebase_auth.py` <!-- orianna: ok -- company-os workspace file -->. DoD: T.1 xfails flip green.
- [ ] **T.6** — Add `encode_user_cookie` / `decode_user_cookie` helpers + `AUTH_LEGACY_COOKIE_ALLOWED` flag to `auth.py`. owner: sona. estimate_minutes: 10. Files: `mmp/workspace/tools/demo-studio-v3/auth.py` <!-- orianna: ok -- company-os workspace file -->. DoD: T.2 xfails flip green.
- [ ] **T.7** — Add the four `/auth/*` routes to `main.py` using the new firebase_auth module and cookie helpers. owner: sona. estimate_minutes: 20. Files: `mmp/workspace/tools/demo-studio-v3/main.py` <!-- orianna: ok -- company-os workspace file -->. DoD: T.3 xfails flip green.
- [ ] **T.8** — Playwright verify: navigate to `http://127.0.0.1:8080/auth/config` expect JSON with projectId; navigate to `/auth/me` unauth expect 401 JSON. owner: sona. estimate_minutes: 5. Files: (runtime-only). DoD: both smokes pass; screenshots captured under `assessments/qa-reports` <!-- orianna: ok -- strawberry-agents assessments dir, not company-os -->.

## Architecture impact

- `requirements.txt` <!-- orianna: ok -- company-os workspace file --> — one new dep.
- `firebase_auth.py` <!-- orianna: ok -- company-os workspace file --> — new module (~100 lines est.).
- `auth.py` <!-- orianna: ok -- company-os workspace file --> — additive: new helpers + flag, no existing function signatures changed.
- `main.py` <!-- orianna: ok -- company-os workspace file --> — 4 new routes appended; no route migrations.
- Test directory — 3 new test files (~14 tests total).

## Loop context

Second loop of Duong's hands-dirty cadence. Loop 1 (dashboard CORS) done. This loop is narrow — pure server
backbone, no UI. Frontend + route migration + Slack drop are later loops. Respects the approved parent ADR
for structure while sliced small enough to verify-and-compact within one session.

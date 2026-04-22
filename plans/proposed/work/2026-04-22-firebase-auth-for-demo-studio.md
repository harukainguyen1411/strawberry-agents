---
status: proposed
orianna_gate_version: 2
complexity: complex
concern: work
owner: swain
created: 2026-04-22
tags:
  - demo-studio
  - auth
  - firebase
  - security
  - work
tests_required: true
---

# ADR: Firebase Auth for Demo Studio v3 (@missmp.tech SSO)

<!-- orianna: ok — all bare module tokens in this plan (main.py, auth.py, session.py, session_store.py, conversation_store.py, deploy.sh, secrets-mapping.txt, requirements.txt, static/index.html, static/studio.css, static/studio.js, templates/session.html) reference files inside the missmp/company-os work workspace under company-os/tools/demo-studio-v3/, not strawberry-agents -->
<!-- orianna: ok — every HTTP route token (/, /healthz, /health, /debug, /logs, /dashboard, /auth/session/{sid}, /session/{sid}, /session/{sid}/chat, /session/{sid}/stream, /session/{sid}/build, /session/{sid}/logs, /session/{sid}/status, /session/{sid}/messages, /session/{sid}/events, /session/{sid}/history, /session/{sid}/cancel-build, /session/{sid}/reauth, /session/{sid}/complete, /session/{sid}/close, /session/new, /sessions, /api/test-results, /api/test-run-history, /api/managed-sessions, /auth/login, /auth/callback, /auth/logout, /auth/me, /mcp) is an HTTP path on the demo-studio Cloud Run service, not a filesystem path -->
<!-- orianna: ok — env-var names (FIREBASE_PROJECT_ID, FIREBASE_WEB_API_KEY, FIREBASE_AUTH_DOMAIN, FIREBASE_CLIENT_ID, GOOGLE_APPLICATION_CREDENTIALS, FIREBASE_SERVICE_ACCOUNT_JSON, ALLOWED_EMAIL_DOMAIN, SESSION_SECRET, INTERNAL_SECRET, COOKIE_SECURE, BASE_URL, DS_STUDIO_FIREBASE_ADMIN_SA) are environment variables or Secret Manager names, not filesystem paths -->
<!-- orianna: ok — Firestore collection tokens (demo-studio-sessions, demo-studio-users, demo-studio-used-tokens) are Firestore logical paths, not filesystem -->
<!-- orianna: ok — external hosts/SDKs (identitytoolkit.googleapis.com, accounts.google.com, firebase.googleapis.com, firebase-admin, firebase/auth, @firebase/app) are external refs, not files -->
<!-- orianna: ok — cookie names (ds_session, ds_id_token) are HTTP cookie tokens, not filesystem paths -->

## 1. Context

Demo Studio v3 authenticates via an operator-cookie flow in `auth.py`: Slack bot or UI POSTs `/session` / `/session/new` and gets `studioUrl = /auth/session/{sid}?token=...` (`main.py` lines 1570, 1626); browser hits `auth_exchange` (`main.py` line 1638) which consumes the one-time token (`auth.py` line 36) and sets the HttpOnly `ds_session` cookie (`auth.py` `COOKIE_MAX_AGE = 86400`); protected routes depend on `require_session` (line 101) or `require_session_or_internal` (line 120) and enforce `path_session_id == cookie.sid`. <!-- orianna: ok -->

There is **no user identity**. The cookie binds a browser to a session, not a human. Anyone with the one-time URL becomes that session's operator — no login page, no audit, no way for a teammate to pick up a session, no defense against leaked URLs.

Duong's stretch goal (`assessments/work/2026-04-22-overnight-ship-plan.md` §Stretch): **@missmp.tech users log in once, every session is scoped to a real identity**. Firebase Auth (Google provider) fits: GCP project `mmpt-233505` already runs Firebase (`deploy.sh` line 10), domain allowlisting against the verified `email` claim is trivial, and `firebase-admin` verifies ID tokens offline. <!-- orianna: ok -->

## 2. Decision

Replace **session-binding operator cookie** with **user-identity auth** via Firebase Authentication (Google provider, `@missmp.tech` allowlist). Every session gains an `ownerEmail` field; every protected route first authenticates, then authorizes against session ownership.

- Landing page gains **Sign in with Google** button using `firebase/auth` client SDK. <!-- orianna: ok -->
- Client posts Firebase ID token to `POST /auth/login`; S1 calls `firebase-admin.auth.verify_id_token`, checks `email_verified == True` and `email.lower().endswith("@missmp.tech")`, then issues a `ds_session` cookie (reusing `itsdangerous`) with payload `{uid, email, iat}`. <!-- orianna: ok -->
- `require_session` returns a `User`; new `require_session_owner` additionally checks `session.ownerEmail == user.email`. <!-- orianna: ok -->
- `/auth/session/{sid}?token=...` stays for Slack handoff but now requires an active Firebase cookie; redirects to `/auth/login?next=...` if absent. The one-time token is consumed only after Firebase verification passes. <!-- orianna: ok -->

## 3. Architecture

### 3.1 Before (operator cookie)

    Browser ──POST /auth/session/{sid}?token──► S1.auth_exchange
                                                    │
                                                    ├─ verify_and_consume_token
                                                    └─ set_cookie(ds_session={sid})
                                                    │
    Browser ──GET /session/{sid} (cookie)─────────► require_session
                                                    └─ decode{sid} == path.sid ? ok : 401

Identity: **none**. Cookie == session.

### 3.2 After (Firebase Auth + session ownership)

    Browser ──Sign in with Google──► Firebase client SDK (identitytoolkit.googleapis.com)
                  │
                  └─ ID token ──POST /auth/login──► S1.auth_login
                                                    │
                                                    ├─ firebase-admin verify_id_token()
                                                    ├─ email.endswith("@missmp.tech")? else 403
                                                    └─ set_cookie(ds_session={uid, email, iat})

    Browser ──GET /auth/session/{sid}?token──► S1.auth_exchange
                  │ (if no ds_session cookie → 302 /auth/login?next=...)
                  ├─ require_session (decode uid,email)
                  ├─ verify_and_consume_token
                  ├─ session_store.set_owner(sid, email) if ownerEmail unset
                  └─ 303 /session/{sid}

    Browser ──GET /session/{sid} (cookie)─────► require_session_owner
                                                  ├─ decode {uid, email}
                                                  ├─ session = get_session(sid)
                                                  └─ ownerEmail == email ? ok : 403

### 3.3 Libraries

- **Server**: `firebase-admin>=6.5.0` in `requirements.txt`. Used only for `verify_id_token` — offline JWT verification after one-time JWK fetch. No Firestore Admin (we already use `google-cloud-firestore`). <!-- orianna: ok -->
- **Client**: Firebase JS modular SDK `firebase/app` + `firebase/auth` via Google CDN ES module import — no npm / bundler. Surface: `initializeApp`, `getAuth`, `GoogleAuthProvider`, `signInWithPopup`, `onAuthStateChanged`, `getIdToken`, `signOut`. <!-- orianna: ok -->

### 3.4 Route classification

| Route | Auth |
|---|---|
| `GET /`, `/healthz`, `/health` | public | <!-- orianna: ok -->
| `GET /debug`, `/logs` | internal (existing `verify_internal_secret`) | <!-- orianna: ok -->
| `POST /auth/login`, `GET /auth/config` | public | <!-- orianna: ok -->
| `POST /auth/logout`, `GET /auth/me` | user | <!-- orianna: ok -->
| `GET /dashboard`, `/api/test-results`, `/api/test-run-history`, `/api/managed-sessions` | user (`require_user`) | <!-- orianna: ok -->
| `GET /auth/session/{sid}` | user; else redirect `/auth/login?next=...` | <!-- orianna: ok -->
| `POST /session`, `/session/new` | user | <!-- orianna: ok -->
| `GET/POST /session/{sid}/*` (chat, stream, build, logs, events, messages, history, status, cancel-build, reauth, complete, close) | owner (`require_session_owner`) | <!-- orianna: ok -->
| `POST /session/{sid}/chat` with `X-Internal-Secret` | internal bypass preserved (S3/S4 callbacks) | <!-- orianna: ok -->

## 4. Migration — dual-stack

Two weeks of dual-stack:

- **Phase A (this plan)**: `require_session` accepts either the new `{uid, email}` cookie or the legacy `{sid}` cookie. New sessions always issue the new format. A module-level flag `AUTH_LEGACY_COOKIE_ALLOWED = True` gates the legacy branch. <!-- orianna: ok -->
- **Phase B (follow-up ADR, ~14 days later)**: Flip to `False`, delete legacy branch. Any surviving legacy sessions force re-login — acceptable since observed session lifetime is < 24 h. <!-- orianna: ok -->

Pre-cutover sessions have no `ownerEmail`. Claim-on-first-touch: if unset and the user presents a valid Firebase cookie, set `ownerEmail = user.email` and continue. Safe because the one-time token still gates the URL. <!-- orianna: ok -->

The `X-Internal-Secret` bypass (`auth.py` line 120) is untouched — server-to-server poller callbacks never had user identity and still won't. <!-- orianna: ok -->

## 5. Token-exchange interaction

The one-time token stays — it is the Slack handoff (`main.py` line 1626). New `auth_exchange` behavior: if no Firebase cookie → 302 `/auth/login?next={encoded_url}`; after login, client redirects back; `auth_exchange` re-runs, validates email, consumes token, claims `ownerEmail` if unset, 303 to `/session/{sid}`. Logged-in Slack user: click link → land in studio. New Slack user: click link → Google popup → land in studio. <!-- orianna: ok -->

## 6. Frontend

`static/index.html` (41 lines today) adds a module-script Firebase import, a **Sign in with Google** button (hidden when `onAuthStateChanged` reports a user), post-sign-in POST of `idToken` to `/auth/login`, then reload to `/` or `next`. The session-ID input is gated behind login. Header gets a **Sign out** link that clears the server cookie and calls `firebase.signOut()`. `studio.css` adds ~30 lines of button/header styling; `studio.js` adds an `auth.js` helper (~80 lines) covering init, login, and a credentials-included fetch wrapper. No npm, no bundler — matches existing static-asset convention. <!-- orianna: ok -->

## 7. Secrets / env config

**Server** — `FIREBASE_PROJECT_ID=mmpt-233505` and `ALLOWED_EMAIL_DOMAIN=missmp.tech` as plain env in `deploy.sh`. `firebase-admin` init **prefers ADC** (grant `demo-runner-sa` — see `deploy.sh` comment line 6 — `roles/firebase.sdkAdminServiceAgent` via one `gcloud` call, no JSON key rotation); fallback is `DS_STUDIO_FIREBASE_ADMIN_SA` in Secret Manager bound via `secrets-mapping.txt` as `FIREBASE_SERVICE_ACCOUNT_JSON`. <!-- orianna: ok -->

**Client** — `FIREBASE_WEB_API_KEY` + `FIREBASE_AUTH_DOMAIN=mmpt-233505.firebaseapp.com` exposed via `GET /auth/config`. Public by design (security is our server-side domain allowlist + Firebase project rules); nothing secret in `static/*` — preserves the cross-system rule on committed-file secrets. <!-- orianna: ok -->

**Firebase Console one-time (Duong / Ekko)** — enable Google sign-in; add Cloud Run + custom domains to Authorized Domains; optionally restrict OAuth consent to the missmp Workspace org.

## 8. Waves

| Wave | Scope | Deps |
|---|---|---|
| W0 Spike | `firebase-admin.verify_id_token` + throwaway `/auth/ping`. Confirm ADC on `demo-runner-sa`. | clean | <!-- orianna: ok -->
| W1 Server backbone | `firebase-admin` in requirements; new `firebase_auth.py` (`verify_firebase_token`); `/auth/login`, `/auth/logout`, `/auth/me`, `/auth/config`. Cookie payload → `{uid, email, iat}`. Legacy decode behind `AUTH_LEGACY_COOKIE_ALLOWED`. Unit tests. | W0 | <!-- orianna: ok -->
| W2 Route deps | Rewrite `require_session` → `User`. New `require_session_owner`. Migrate all `/session/*` deps. `require_session_or_internal` unchanged. | W1 | <!-- orianna: ok -->
| W3 Ownership field | `ownerEmail` on session doc at create; claim-on-first-touch for legacy. | W1 | <!-- orianna: ok -->
| W4 Frontend login | `static/index.html` + `studio.js` + CSS — Firebase SDK, Sign-in button, post-login landing. | W1 | <!-- orianna: ok -->
| W5 Token-exchange compat | `/auth/session/{sid}` redirects unauthenticated → `/auth/login?next=...`. | W2, W4 | <!-- orianna: ok -->
| W6 Deploy + QA | `deploy.sh` env + secret binding; Ekko deploys; Akali Playwright — sign-in, domain rejection, ownership, Slack deep-link. | W1-W5 | <!-- orianna: ok -->
| W7 (future ADR) | Flip `AUTH_LEGACY_COOKIE_ALLOWED=False`, delete legacy branch. | W6 + 14 d |

Aphelios decomposes W1–W6 into tasks; each wave is one PR.

## Test plan
### 9. Test plan handoff (Xayah)

- **Unit W1** `test_firebase_auth.py`: valid token → user; `email_verified=False` → 403; wrong domain → 403; expired → 401; missing header → 401. Mock `verify_id_token`. <!-- orianna: ok -->
- **Unit W2** `test_require_session_owner.py`: own session → ok; other user's session → 403; legacy sid cookie + flag on → ok; legacy sid + flag off → 401. <!-- orianna: ok -->
- **Unit W3** `test_session_ownership.py`: `create_session` persists `ownerEmail`; claim-on-first-touch sets it when missing; second-user claim attempt → 403. <!-- orianna: ok -->
- **Integration W5**: Firebase-test-tenant token → `/auth/login` → `/auth/session/{sid}?token=...` → 303 → `/session/{sid}` 200. <!-- orianna: ok -->
- **E2E W6 (Akali)**: Playwright + Firebase Auth Emulator (`FIREBASE_AUTH_EMULATOR_HOST`) on staging — `@missmp.tech` login lands in studio; `@gmail.com` blocked; cross-user session access blocked. <!-- orianna: ok -->

## 10. Open questions (resolved 2026-04-22)

1. **Auth credential:** ADC on `demo-runner-sa` with `roles/firebase.sdkAdminServiceAgent`. No JSON key in Secret Manager. <!-- orianna: ok -->
2. **Session cookie lifetime:** 7 days (upgraded from 24 h; identity is now durable). <!-- orianna: ok -->
3. **`/dashboard` visibility:** Team-wide read-only for all authenticated `@missmp.tech` users; owner-only for mutating routes. <!-- orianna: ok -->
4. **`X-Internal-Secret` bypass on `POST /session`:** Kept. Slack handoff requires it; one-time token + claim-on-first-touch covers the handoff flow. <!-- orianna: ok -->
5. **Logout:** Both server cookie clear AND client-side `firebase.signOut()`. <!-- orianna: ok -->
6. **Email domain case:** Force `email.lower()` before domain match server-side (`email.lower().endswith("@missmp.tech")`). <!-- orianna: ok -->

## Tasks

<!-- orianna: ok — all file paths in T.W*.* tasks below reference files inside company-os/tools/demo-studio-v3/ within the work workspace; not strawberry-agents local files -->

### Coordination

- [x] **T.COORD.1** — Aphelios decomposes W1–W6 into implementation tasks. estimate_minutes: 45
- [ ] **T.COORD.2** — Xayah writes the test-plan stubs enumerated in §9. estimate_minutes: 30
- [ ] **T.COORD.3** — Ekko runs the one-time Firebase Console setup + SA role grant <!-- orianna: ok -->. estimate_minutes: 20
- [x] **T.COORD.4** — Duong answers §10 gating questions before promotion. estimate_minutes: 15
- [ ] **T.COORD.5** — Senna / Lucian reviews per-wave PRs. estimate_minutes: 60
- [ ] **T.COORD.6** — Akali runs the W6 E2E matrix against staging then prod. estimate_minutes: 45

### Wave 0 — Spike (verify `firebase-admin.verify_id_token` works with ADC)

**Status: HUMAN-BLOCKED on IAM grant.** Before W0 can run, Duong must execute once:

```
gcloud projects add-iam-policy-binding mmpt-233505 \
  --member="serviceAccount:266692422014-compute@developer.gserviceaccount.com" \
  --role="roles/firebase.sdkAdminServiceAgent"
```

SA `266692422014-compute@developer.gserviceaccount.com` is the ADC identity in Cloud Run. Ekko has completed the rest of GCP infra setup. W1 decomposition may begin in parallel (no runtime dep), but **no W0-W1 task may deploy until the grant lands**.

- [ ] **T.W0.1** — Add `firebase-admin>=6.5.0` to `requirements.txt` on a spike branch. owner: Viktor. estimate_minutes: 5. Files: `requirements.txt`. DoD: `pip install -r requirements.txt` in a fresh venv resolves without conflict; `pip show firebase-admin` reports ≥6.5.0. <!-- orianna: ok -->
- [ ] **T.W0.2** — Write throwaway `/auth/ping` route that calls `firebase_admin.auth.verify_id_token(header_token)` and returns the decoded claims or the exception class name. owner: Viktor. estimate_minutes: 15. Files: `main.py` (spike branch only — revert before W1 PR). DoD: route returns 200 + claims on a valid token; returns 401 + error class on invalid. <!-- orianna: ok -->
- [ ] **T.W0.3** — Deploy spike branch to Cloud Run dev; curl `/auth/ping` with a real `@missmp.tech` ID token minted via `gcloud auth print-identity-token` or Firebase emulator. owner: Ekko. estimate_minutes: 10. Files: (deploy only). DoD: 200 response with `email` claim; no `PermissionDenied` / `DefaultCredentialsError` in logs — confirms ADC role grant is effective. <!-- orianna: ok -->
- [ ] **T.W0.4** — Revert spike route + spike requirements pin. owner: Viktor. estimate_minutes: 5. Files: `main.py`, `requirements.txt`. DoD: branch clean except for spike learnings captured in the W1 PR description. <!-- orianna: ok -->

### Wave 1 — Server backbone (`firebase_auth.py` + `/auth/*` routes) <!-- orianna: ok -->

- [ ] **T.W1.1** — Add `firebase-admin>=6.5.0` to `requirements.txt` (for real). owner: Viktor. estimate_minutes: 5. Files: `requirements.txt`. DoD: dep pinned; `pip install` clean. <!-- orianna: ok -->
- [ ] **T.W1.2** — Write xfail `tests/test_firebase_auth.py` covering the five W1 cases in §9 (valid token → User; `email_verified=False` → 403; wrong domain → 403; expired → 401; missing header → 401). Mock `verify_id_token`. owner: Soraka. estimate_minutes: 15. Files: `tests/test_firebase_auth.py`. DoD: all five tests committed as xfail with docstrings citing this plan; `pytest -q` shows 5 xfail. <!-- orianna: ok -->
- [ ] **T.W1.3** — Create `firebase_auth.py` module with `verify_firebase_token(id_token: str) -> User` and `User` dataclass (`uid: str`, `email: str`). Raises `InvalidTokenError` / `DomainNotAllowedError`. Read `FIREBASE_PROJECT_ID` + `ALLOWED_EMAIL_DOMAIN` from env. owner: Viktor. estimate_minutes: 15. Files: `firebase_auth.py` (new). DoD: module importable; signature matches test expectations; `email.lower().endswith("@" + domain)` per OQ 6. <!-- orianna: ok -->
- [ ] **T.W1.4** — Flip `test_firebase_auth.py` xfails to strict (expect-pass). owner: Soraka. estimate_minutes: 5. Files: `tests/test_firebase_auth.py`. DoD: 5 tests pass locally; no xfail markers remain. <!-- orianna: ok -->
- [ ] **T.W1.5** — Update `auth.py`: cookie payload schema → `{uid, email, iat}`; `itsdangerous` serializer unchanged. Introduce module flag `AUTH_LEGACY_COOKIE_ALLOWED = True`. owner: Viktor. estimate_minutes: 15. Files: `auth.py`. DoD: new helper `encode_user_cookie(user)` / `decode_user_cookie(raw)`; legacy `{sid}` decode retained behind flag. <!-- orianna: ok -->
- [ ] **T.W1.6** — Add xfail test `tests/test_auth_cookie_dual_stack.py`: new cookie decodes → User; legacy `{sid}` cookie + flag on → sid; legacy cookie + flag off → raises. owner: Soraka. estimate_minutes: 15. Files: `tests/test_auth_cookie_dual_stack.py`. DoD: 3 xfails committed. <!-- orianna: ok -->
- [ ] **T.W1.7** — Implement dual-stack decode per T.W1.5 so T.W1.6 flips green. owner: Viktor. estimate_minutes: 10. Files: `auth.py`. DoD: xfails flipped; both cookie formats round-trip. <!-- orianna: ok -->
- [ ] **T.W1.8** — Add `POST /auth/login` route in `main.py`: reads `{idToken}` JSON body, calls `verify_firebase_token`, sets `ds_session` cookie with `{uid, email, iat}`, 7-day Max-Age (OQ 2), returns 204. owner: Viktor. estimate_minutes: 15. Files: `main.py`. DoD: route registered; unit test hits it with mocked verifier. <!-- orianna: ok -->
- [ ] **T.W1.9** — Add `POST /auth/logout` route: clears `ds_session` cookie, returns 204. owner: Viktor. estimate_minutes: 5. Files: `main.py`. DoD: cookie cleared with `expires=0` + same path/domain as set. <!-- orianna: ok -->
- [ ] **T.W1.10** — Add `GET /auth/me` route: returns `{uid, email}` from cookie or 401. owner: Viktor. estimate_minutes: 5. Files: `main.py`. DoD: 200 with claims when authed; 401 when not. <!-- orianna: ok -->
- [ ] **T.W1.11** — Add `GET /auth/config` route: returns `{projectId, apiKey, authDomain}` sourced from `FIREBASE_PROJECT_ID`, `FIREBASE_WEB_API_KEY`, `FIREBASE_AUTH_DOMAIN` env. owner: Viktor. estimate_minutes: 10. Files: `main.py`. DoD: route public; absent env → 500 at startup, not at request time. <!-- orianna: ok -->
- [ ] **T.W1.12** — Add xfail integration tests for all four new `/auth/*` routes in `tests/test_auth_routes.py`. owner: Soraka. estimate_minutes: 15. Files: `tests/test_auth_routes.py`. DoD: 4 xfails covering login/logout/me/config; flip green once T.W1.8–11 land. <!-- orianna: ok -->
- [ ] **T.W1.13** — Initialize `firebase_admin` app at module load in `firebase_auth.py` (prefer ADC; fallback to `FIREBASE_SERVICE_ACCOUNT_JSON` env). owner: Viktor. estimate_minutes: 15. Files: `firebase_auth.py`. DoD: `firebase_admin.initialize_app()` runs once; both branches exercised in unit tests via monkeypatch. <!-- orianna: ok -->

### Wave 2 — Route deps (`require_session` → `User`; new `require_session_owner`)

- [ ] **T.W2.1** — Write xfail test `tests/test_require_session.py` with cases: returns `User` with `{uid, email}` for new-format cookie; returns `User(uid=sid, email=None)` for legacy cookie + flag; raises 401 missing cookie. owner: Soraka. estimate_minutes: 10. Files: `tests/test_require_session.py`. DoD: 3 xfails committed. <!-- orianna: ok -->
- [ ] **T.W2.2** — Rewrite `require_session` in `auth.py` to decode dual-stack cookie and return `User`. owner: Jayce. estimate_minutes: 15. Files: `auth.py`. DoD: T.W2.1 xfails flip green; existing `require_session_or_internal` still returns its pre-existing shape. <!-- orianna: ok -->
- [ ] **T.W2.3** — Write xfail test `tests/test_require_session_owner.py` covering §9 W2 cases (own → ok; other → 403; legacy + flag on → ok; legacy + flag off → 401). owner: Soraka. estimate_minutes: 15. Files: `tests/test_require_session_owner.py`. DoD: 4 xfails committed. <!-- orianna: ok -->
- [ ] **T.W2.4** — Implement `require_session_owner(sid, user=Depends(require_session), session=Depends(load_session))` in `auth.py`: checks `session.ownerEmail == user.email`; legacy path allowed only if `AUTH_LEGACY_COOKIE_ALLOWED`. owner: Jayce. estimate_minutes: 15. Files: `auth.py`. DoD: T.W2.3 xfails flip green. <!-- orianna: ok -->
- [ ] **T.W2.5** — Migrate `/session/{sid}` GET route to `require_session_owner`. owner: Jayce. estimate_minutes: 5. Files: `main.py`. DoD: route signature swap; no behavioral test drift. <!-- orianna: ok -->
- [ ] **T.W2.6** — Migrate `/session/{sid}/chat` to owner dep; preserve `X-Internal-Secret` bypass (OQ 4 — untouched). owner: Jayce. estimate_minutes: 10. Files: `main.py`. DoD: `require_session_or_internal` wrap verified; internal secret still bypasses user check. <!-- orianna: ok -->
- [ ] **T.W2.7** — Migrate `/session/{sid}/stream` to owner dep. owner: Jayce. estimate_minutes: 5. Files: `main.py`. DoD: dep swap only. <!-- orianna: ok -->
- [ ] **T.W2.8** — Migrate `/session/{sid}/build` + `/session/{sid}/cancel-build` to owner dep. owner: Jayce. estimate_minutes: 10. Files: `main.py`. DoD: both routes require owner. <!-- orianna: ok -->
- [ ] **T.W2.9** — Migrate `/session/{sid}/logs` + `/session/{sid}/status` to owner dep. owner: Jayce. estimate_minutes: 10. Files: `main.py`. DoD: both routes require owner. <!-- orianna: ok -->
- [ ] **T.W2.10** — Migrate `/session/{sid}/messages` + `/session/{sid}/events` + `/session/{sid}/history` to owner dep. owner: Jayce. estimate_minutes: 10. Files: `main.py`. DoD: all three require owner. <!-- orianna: ok -->
- [ ] **T.W2.11** — Migrate `/session/{sid}/reauth` + `/session/{sid}/complete` + `/session/{sid}/close` to owner dep. owner: Jayce. estimate_minutes: 10. Files: `main.py`. DoD: all three require owner. <!-- orianna: ok -->
- [ ] **T.W2.12** — Migrate `/dashboard` + `/api/test-results` + `/api/test-run-history` + `/api/managed-sessions` to `require_user` (not owner — team-wide read per OQ 3). owner: Jayce. estimate_minutes: 15. Files: `main.py`. DoD: `require_user` dep exists (just `require_session` returning User); routes reject unauthenticated, allow any `@missmp.tech` authed user. <!-- orianna: ok -->
- [ ] **T.W2.13** — Migrate `POST /session` + `POST /session/new` to `require_user` (any authed @missmp.tech can create a session); preserve `X-Internal-Secret` bypass for Slack. owner: Jayce. estimate_minutes: 10. Files: `main.py`. DoD: internal secret bypass untouched; user dep added. <!-- orianna: ok -->
- [ ] **T.W2.14** — Write regression test matrix `tests/test_route_auth_matrix.py`: parametrize (route, method) × (no cookie, user cookie, owner cookie, other-user cookie, internal secret) → assert 401/403/200 as appropriate. owner: Soraka. estimate_minutes: 15. Files: `tests/test_route_auth_matrix.py`. DoD: 20+ row matrix green. <!-- orianna: ok -->

### Wave 3 — Ownership field + claim-on-first-touch

- [ ] **T.W3.1** — Write xfail `tests/test_session_ownership.py` for §9 W3 cases (persists `ownerEmail` on create; claim-on-first-touch sets when missing; second-user claim → 403). owner: Soraka. estimate_minutes: 15. Files: `tests/test_session_ownership.py`. DoD: 3 xfails committed. <!-- orianna: ok -->
- [ ] **T.W3.2** — Add `owner_email: str | None = None` param to `create_session` in `session.py`; persist as `ownerEmail` field in session doc. owner: Seraphine. estimate_minutes: 10. Files: `session.py`. DoD: field present in new docs; round-trip via session_store. <!-- orianna: ok -->
- [ ] **T.W3.3** — Update `session_store.py` schema/model to include optional `ownerEmail: str | None`. owner: Seraphine. estimate_minutes: 10. Files: `session_store.py`. DoD: old docs without field deserialize without error; Firestore schema tolerant. <!-- orianna: ok -->
- [ ] **T.W3.4** — Call-site: `POST /session/new` passes `owner_email=user.email` into `create_session`. owner: Seraphine. estimate_minutes: 5. Files: `main.py`. DoD: new sessions always carry ownerEmail; verified by T.W3.1. <!-- orianna: ok -->
- [ ] **T.W3.5** — Call-site: `POST /session` (Slack handoff w/ `X-Internal-Secret`) passes `owner_email=None` when no user context — claim-on-first-touch handles it. owner: Seraphine. estimate_minutes: 5. Files: `main.py`. DoD: internal-secret path creates session with null ownerEmail; first Firebase-authed visitor claims it (see T.W5.3). <!-- orianna: ok -->
- [ ] **T.W3.6** — Flip T.W3.1 xfails green. owner: Soraka. estimate_minutes: 5. Files: `tests/test_session_ownership.py`. DoD: 3 tests pass; xfail markers removed. <!-- orianna: ok -->

### Wave 4 — Frontend login UI

- [ ] **T.W4.1** — Add `static/auth.js` helper module (~80 lines): `initFirebase(config)` fetches `/auth/config` then calls `initializeApp` + `getAuth`; exports `signInWithGoogle()`, `signOut()`, `getCurrentUser()`, `fetchWithAuth(url, opts)` (credentials-include + 401 → redirect to login). owner: Rakan. estimate_minutes: 15. Files: `static/auth.js` (new). DoD: module loads as ES module from CDN-hosted Firebase SDK. <!-- orianna: ok -->
- [ ] **T.W4.2** — Modify `static/index.html` (41 → ~80 lines): add `<script type="module">` importing `auth.js`; add **Sign in with Google** button (id=`signin-btn`); gate session-ID form behind login state. owner: Rakan. estimate_minutes: 15. Files: `static/index.html`. DoD: unauthenticated view shows Sign-in button; authenticated view shows session form + email + Sign-out. <!-- orianna: ok -->
- [ ] **T.W4.3** — Wire `signin-btn` to `signInWithGoogle()` → `getIdToken()` → POST `/auth/login` → reload to `/` or `next`. owner: Rakan. estimate_minutes: 10. Files: `static/index.html` (inline script or `auth.js`). DoD: button click flow yields an authed cookie on success. <!-- orianna: ok -->
- [ ] **T.W4.4** — Add `onAuthStateChanged` listener that toggles Sign-in / Sign-out UI + email display. owner: Rakan. estimate_minutes: 10. Files: `static/auth.js`. DoD: page reacts to auth state without reload. <!-- orianna: ok -->
- [ ] **T.W4.5** — Add **Sign out** link: POST `/auth/logout` (clear cookie) → `firebase.signOut()` → redirect `/` (OQ 5). owner: Rakan. estimate_minutes: 10. Files: `static/auth.js`, `static/index.html`. DoD: both server cookie and client Firebase state cleared. <!-- orianna: ok -->
- [ ] **T.W4.6** — Add ~30 lines of button/header CSS in `static/studio.css`. owner: Rakan. estimate_minutes: 10. Files: `static/studio.css`. DoD: Sign-in button visually matches design language; no layout regressions in session view. <!-- orianna: ok -->
- [ ] **T.W4.7** — Update `static/studio.js` to use `fetchWithAuth` for all `/session/*` XHR calls (so a 401 redirects to login gracefully). owner: Rakan. estimate_minutes: 15. Files: `static/studio.js`. DoD: any `fetch(` call against `/session/` swaps to wrapper; existing event-stream / SSE code still works. <!-- orianna: ok -->
- [ ] **T.W4.8** — Update `README.md` §Local dev with Firebase emulator instructions (`FIREBASE_AUTH_EMULATOR_HOST=localhost:9099`) + ADC hint for `demo-runner-sa`. owner: Rakan. estimate_minutes: 10. Files: `README.md`. DoD: new contributor can follow the README to run the app locally with auth. <!-- orianna: ok -->

### Wave 5 — Token-exchange compatibility (Slack handoff)

- [ ] **T.W5.1** — Write xfail `tests/test_auth_exchange_redirect.py` with cases: unauthenticated `GET /auth/session/{sid}?token=...` → 302 `/auth/login?next=<encoded>`; authed + valid token → 303 `/session/{sid}`; authed + bad token → 403. owner: Soraka. estimate_minutes: 15. Files: `tests/test_auth_exchange_redirect.py`. DoD: 3 xfails committed. <!-- orianna: ok -->
- [ ] **T.W5.2** — Modify `auth_exchange` in `main.py` (line 1638): if no Firebase cookie → `return RedirectResponse(f"/auth/login?next={quote(str(request.url))}", 302)`. owner: Viktor. estimate_minutes: 10. Files: `main.py`. DoD: redirect fires for unauth; still consumes token for authed path. <!-- orianna: ok -->
- [ ] **T.W5.3** — In `auth_exchange`: after Firebase verify + token consume, if `session.ownerEmail is None` call `session_store.set_owner(sid, user.email)` (claim on first contact). owner: Viktor. estimate_minutes: 10. Files: `main.py`, `session_store.py` (add `set_owner` if missing). DoD: legacy session without owner gains owner on first authed visit; second visitor gets 403. <!-- orianna: ok -->
- [ ] **T.W5.4** — Ensure `next=` handling on login page: `static/index.html` reads `?next=` query param, passes it through on login success redirect. owner: Rakan. estimate_minutes: 10. Files: `static/index.html`. DoD: Slack-deep-link → login → lands on `/auth/session/{sid}?token=...` → studio. <!-- orianna: ok -->
- [ ] **T.W5.5** — Flip T.W5.1 xfails green. owner: Soraka. estimate_minutes: 5. Files: `tests/test_auth_exchange_redirect.py`. DoD: 3 tests pass. <!-- orianna: ok -->
- [ ] **T.W5.6** — Integration test `tests/test_slack_handoff_integration.py`: mint Firebase-emulator token → POST `/auth/login` → GET `/auth/session/{sid}?token=...` → follow 303 → assert 200 on `/session/{sid}`. owner: Soraka. estimate_minutes: 15. Files: `tests/test_slack_handoff_integration.py`. DoD: one green integration test end-to-end. <!-- orianna: ok -->

### Wave 6 — Deploy + QA

- [ ] **T.W6.1** — Add `ALLOWED_EMAIL_DOMAIN=missmp.tech` and `FIREBASE_PROJECT_ID=mmpt-233505` + `FIREBASE_AUTH_DOMAIN=mmpt-233505.firebaseapp.com` as plain env vars in `deploy.sh`. owner: Ekko. estimate_minutes: 5. Files: `deploy.sh`. DoD: env vars appear in next Cloud Run revision config. <!-- orianna: ok -->
- [ ] **T.W6.2** — Add `FIREBASE_WEB_API_KEY` to `secrets-mapping.txt` bound to Secret Manager entry (ADC for server; web key is public-but-managed). owner: Ekko. estimate_minutes: 10. Files: `secrets-mapping.txt`. DoD: deploy resolves secret; `/auth/config` returns correct value. <!-- orianna: ok -->
- [ ] **T.W6.3** — Add `DS_STUDIO_FIREBASE_ADMIN_SA` → `FIREBASE_SERVICE_ACCOUNT_JSON` fallback binding in `secrets-mapping.txt` (only used if ADC fails). owner: Ekko. estimate_minutes: 10. Files: `secrets-mapping.txt`. DoD: fallback secret exists but is unset by default; documented as emergency-only. <!-- orianna: ok -->
- [ ] **T.W6.4** — Confirm Firebase Console setup (Google sign-in enabled; Cloud Run + custom domains on Authorized Domains; OAuth consent restricted to missmp Workspace org). owner: Ekko. estimate_minutes: 15. Files: (console only). DoD: checklist screenshotted into PR body. <!-- orianna: ok -->
- [ ] **T.W6.5** — Deploy to staging Cloud Run; verify `/auth/config` returns correct values; verify `/auth/ping`-equivalent smoke passes. owner: Ekko. estimate_minutes: 10. Files: (deploy only). DoD: staging revision active; smoke green; logs free of Firebase init errors. <!-- orianna: ok -->
- [ ] **T.W6.6** — Akali writes Playwright E2E: happy path `@missmp.tech` Google sign-in → lands in studio. owner: Akali. estimate_minutes: 15. Files: `tests/e2e/test_firebase_auth_happy_path.spec.ts` (or established E2E location). DoD: test green against staging with Firebase Auth Emulator. <!-- orianna: ok -->
- [ ] **T.W6.7** — Akali writes Playwright E2E: `@gmail.com` user blocked with 403. owner: Akali. estimate_minutes: 10. Files: `tests/e2e/test_firebase_auth_domain_reject.spec.ts`. DoD: test green. <!-- orianna: ok -->
- [ ] **T.W6.8** — Akali writes Playwright E2E: user-A creates session, user-B tries `/session/{sidA}` → 403. owner: Akali. estimate_minutes: 15. Files: `tests/e2e/test_firebase_auth_cross_user.spec.ts`. DoD: test green. <!-- orianna: ok -->
- [ ] **T.W6.9** — Akali writes Playwright E2E: Slack deep-link → unauth → login → land on session. owner: Akali. estimate_minutes: 15. Files: `tests/e2e/test_firebase_auth_slack_deeplink.spec.ts`. DoD: test green. <!-- orianna: ok -->
- [ ] **T.W6.10** — Duong approves staging; Ekko deploys to prod; post-deploy smoke (`/auth/config` + `/auth/me` unauthenticated 401). owner: Ekko. estimate_minutes: 10. Files: (deploy only). DoD: prod revision live; smoke green; rollback script on standby per rule #17. <!-- orianna: ok -->

## Out of scope

- Revocation + session management UI for admins (future ADR).
- Multi-factor auth (Firebase supports it; no demand yet).
- Deleting the one-time-token machinery (stays because Slack needs it).
- Rate limiting on `/auth/login` (Cloud Run + Firebase already enforce per-project quotas).
- Switching `/mcp` bearer auth — MCP service is being retired (`plans/proposed/work/2026-04-21-demo-studio-mcp-retirement.md`).

## Architecture impact

- `auth.py` — `require_session` / `require_session_or_internal` return `User` dataclass instead of `str`; every caller updated in W2. New module `firebase_auth.py` wraps `verify_id_token`. <!-- orianna: ok -->
- `session.py` — `create_session` gains `owner_email` param; session doc gains `ownerEmail` field. <!-- orianna: ok -->
- `main.py` — 4 new routes (`/auth/login`, `/auth/logout`, `/auth/me`, `/auth/config`); 20+ existing routes swap `require_session` → `require_session_owner`. <!-- orianna: ok -->
- `deploy.sh` + `secrets-mapping.txt` — new env `ALLOWED_EMAIL_DOMAIN`; new secret binding only if ADC fallback. <!-- orianna: ok -->
- `requirements.txt` — `firebase-admin>=6.5.0`. <!-- orianna: ok -->
- `static/index.html`, `static/studio.js`, `static/studio.css` — login UI + SDK wiring. <!-- orianna: ok -->

Local dev: requires `demo-runner-sa` ADC or emulator (`FIREBASE_AUTH_EMULATOR_HOST=localhost:9099`); documented in `README.md` in W4. <!-- orianna: ok -->

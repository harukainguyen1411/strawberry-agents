---
status: approved
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
orianna_signature_approved: "sha256:f4cbd61c819b22a930fddbee8c0f0ab77221b79e2891718c0e156efaefb089dc:2026-04-22T01:36:51Z"
orianna_signature_in_progress: "sha256:f4cbd61c819b22a930fddbee8c0f0ab77221b79e2891718c0e156efaefb089dc:2026-04-22T01:38:26Z"
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
- Client posts Firebase ID token to `POST /auth/login`; S1 calls `firebase-admin.auth.verify_id_token`, checks `email_verified == True` and `email.lower().endswith("@missmp.tech")`, then issues a `ds_session` cookie (reusing `itsdangerous`) with payload `{uid, email, iat}`.
- `require_session` returns a `User`; new `require_session_owner` additionally checks `session.ownerEmail == user.email`.
- `/auth/session/{sid}?token=...` stays for Slack handoff but now requires an active Firebase cookie; redirects to `/auth/login?next=...` if absent. The one-time token is consumed only after Firebase verification passes.

## 3. Architecture

### 3.1 Before (operator cookie)

```
Browser ──POST /auth/session/{sid}?token──► S1.auth_exchange
                                                │
                                                ├─ verify_and_consume_token
                                                └─ set_cookie(ds_session={sid})
                                                │
Browser ──GET /session/{sid} (cookie)─────────► require_session
                                                └─ decode{sid} == path.sid ? ok : 401
```

Identity: **none**. Cookie == session.

### 3.2 After (Firebase Auth + session ownership)

```
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
```

### 3.3 Libraries

- **Server**: `firebase-admin>=6.5.0` in `requirements.txt`. Used only for `verify_id_token` — offline JWT verification after one-time JWK fetch. No Firestore Admin (we already use `google-cloud-firestore`). <!-- orianna: ok -->
- **Client**: Firebase JS modular SDK `firebase/app` + `firebase/auth` via Google CDN ES module import — no npm / bundler. Surface: `initializeApp`, `getAuth`, `GoogleAuthProvider`, `signInWithPopup`, `onAuthStateChanged`, `getIdToken`, `signOut`. <!-- orianna: ok -->

### 3.4 Route classification

| Route | Auth |
|---|---|
| `GET /`, `/healthz`, `/health` | public |
| `GET /debug`, `/logs` | internal (existing `verify_internal_secret`) |
| `POST /auth/login`, `GET /auth/config` | public |
| `POST /auth/logout`, `GET /auth/me` | user |
| `GET /dashboard`, `/api/test-results`, `/api/test-run-history`, `/api/managed-sessions` | user (`require_user`) |
| `GET /auth/session/{sid}` | user; else redirect `/auth/login?next=...` |
| `POST /session`, `/session/new` | user |
| `GET/POST /session/{sid}/*` (chat, stream, build, logs, events, messages, history, status, cancel-build, reauth, complete, close) | owner (`require_session_owner`) |
| `POST /session/{sid}/chat` with `X-Internal-Secret` | internal bypass preserved (S3/S4 callbacks) |

## 4. Migration — dual-stack

Two weeks of dual-stack:

- **Phase A (this plan)**: `require_session` accepts either the new `{uid, email}` cookie or the legacy `{sid}` cookie. New sessions always issue the new format. A module-level flag `AUTH_LEGACY_COOKIE_ALLOWED = True` gates the legacy branch.
- **Phase B (follow-up ADR, ~14 days later)**: Flip to `False`, delete legacy branch. Any surviving legacy sessions force re-login — acceptable since observed session lifetime is < 24 h.

Pre-cutover sessions have no `ownerEmail`. Claim-on-first-touch: if unset and the user presents a valid Firebase cookie, set `ownerEmail = user.email` and continue. Safe because the one-time token still gates the URL.

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
| W2 Route deps | Rewrite `require_session` → `User`. New `require_session_owner`. Migrate all `/session/*` deps. `require_session_or_internal` unchanged. | W1 |
| W3 Ownership field | `ownerEmail` on session doc at create; claim-on-first-touch for legacy. | W1 |
| W4 Frontend login | `static/index.html` + `studio.js` + CSS — Firebase SDK, Sign-in button, post-login landing. | W1 | <!-- orianna: ok -->
| W5 Token-exchange compat | `/auth/session/{sid}` redirects unauthenticated → `/auth/login?next=...`. | W2, W4 |
| W6 Deploy + QA | `deploy.sh` env + secret binding; Ekko deploys; Akali Playwright — sign-in, domain rejection, ownership, Slack deep-link. | W1-W5 | <!-- orianna: ok -->
| W7 (future ADR) | Flip `AUTH_LEGACY_COOKIE_ALLOWED=False`, delete legacy branch. | W6 + 14 d |

Aphelios decomposes W1–W6 into tasks; each wave is one PR.

## Test plan
### 9. Test plan handoff (Xayah)

- **Unit W1** `test_firebase_auth.py`: valid token → user; `email_verified=False` → 403; wrong domain → 403; expired → 401; missing header → 401. Mock `verify_id_token`. <!-- orianna: ok -->
- **Unit W2** `test_require_session_owner.py`: own session → ok; other user's session → 403; legacy sid cookie + flag on → ok; legacy sid + flag off → 401. <!-- orianna: ok -->
- **Unit W3** `test_session_ownership.py`: `create_session` persists `ownerEmail`; claim-on-first-touch sets it when missing; second-user claim attempt → 403. <!-- orianna: ok -->
- **Integration W5**: Firebase-test-tenant token → `/auth/login` → `/auth/session/{sid}?token=...` → 303 → `/session/{sid}` 200.
- **E2E W6 (Akali)**: Playwright + Firebase Auth Emulator (`FIREBASE_AUTH_EMULATOR_HOST`) on staging — `@missmp.tech` login lands in studio; `@gmail.com` blocked; cross-user session access blocked.

## 10. Open questions (resolved 2026-04-22)

1. **Auth credential:** ADC on `demo-runner-sa` with `roles/firebase.sdkAdminServiceAgent`. No JSON key in Secret Manager. <!-- orianna: ok -->
2. **Session cookie lifetime:** 7 days (upgraded from 24 h; identity is now durable). <!-- orianna: ok -->
3. **`/dashboard` visibility:** Team-wide read-only for all authenticated `@missmp.tech` users; owner-only for mutating routes. <!-- orianna: ok -->
4. **`X-Internal-Secret` bypass on `POST /session`:** Kept. Slack handoff requires it; one-time token + claim-on-first-touch covers the handoff flow. <!-- orianna: ok -->
5. **Logout:** Both server cookie clear AND client-side `firebase.signOut()`. <!-- orianna: ok -->
6. **Email domain case:** Force `email.lower()` before domain match server-side (`email.lower().endswith("@missmp.tech")`). <!-- orianna: ok -->

## Tasks

- [ ] T.COORD.1 — Aphelios decomposes W1–W6 into implementation tasks | estimate_minutes: 45
- [ ] T.COORD.2 — Xayah writes the test-plan stubs enumerated in §9 | estimate_minutes: 30
- [ ] T.COORD.3 — Ekko runs the one-time Firebase Console setup + SA role grant <!-- orianna: ok --> | estimate_minutes: 20
- [ ] T.COORD.4 — Duong answers §10 gating questions before promotion | estimate_minutes: 15
- [ ] T.COORD.5 — Senna / Lucian reviews per-wave PRs | estimate_minutes: 60
- [ ] T.COORD.6 — Akali runs the W6 E2E matrix against staging then prod | estimate_minutes: 45

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

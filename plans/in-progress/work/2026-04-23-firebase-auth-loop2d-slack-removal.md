---
status: approved
complexity: complex
concern: work
owner: swain
created: 2026-04-23
orianna_gate_version: 2
tags:
  - demo-studio
  - auth
  - firebase
  - slack
  - ui
  - work
tests_required: true
---

# Loop 2d — Slack scaffolding removal + UI session creation

<!-- orianna: ok -- all bare module tokens in this plan (main.py, auth.py, firebase_auth.py, session.py, session_store.py, tool_dispatch.py, managed_session_client.py, dashboard_service.py, conversation_store.py, deploy.sh, requirements.txt, static/index.html, static/auth.js, static/studio.css, static/studio.js, templates/session.html, api/content-gen.yaml, scripts/smoke-test.sh) reference files inside the missmp/company-os work workspace under company-os/tools/demo-studio-v3/, not strawberry-agents -->
<!-- orianna: ok -- every HTTP route token (/, /healthz, /auth/login, /auth/logout, /auth/me, /auth/config, /auth/session/{sid}, /session, /session/new, /session/{sid}, /session/{sid}/chat, /session/{sid}/stream, /session/{sid}/build, /session/{sid}/logs, /session/{sid}/status, /session/{sid}/messages, /session/{sid}/events, /session/{sid}/history, /session/{sid}/reauth, /session/{sid}/complete, /session/{sid}/close, /session/{sid}/cancel-build, /sessions, /api/managed-sessions, /api/test-results, /dashboard) is an HTTP path on the demo-studio Cloud Run service, not a filesystem path -->
<!-- orianna: ok -- Firestore collection tokens (demo-studio-sessions) and field tokens (slackUserId, slackChannel, slackThreadTs, ownerUid, ownerEmail, userEmail, managedSessionId, dbStatus) are Firestore logical paths/field names, not filesystem -->
<!-- orianna: ok -- cookie name (ds_session) and env-var tokens (AUTH_LEGACY_COOKIE_ALLOWED, INTERNAL_SECRET, FIREBASE_PROJECT_ID, ALLOWED_EMAIL_DOMAIN, DEMO_STUDIO_URL) are HTTP cookie / env names, not filesystem -->
<!-- orianna: ok -- external refs (slack-triage service, firebase-admin, firebase/auth, itsdangerous) are cross-service/SDK tokens, not files -->
<!-- orianna: ok -- branch name (feat/demo-studio-v3) is a git branch on missmp/company-os, not a filesystem path -->

## 1. Context

Loops 2a (server backbone), 2b (frontend sign-in) and 2c (route migration + owner checks) of the parent ADR `plans/in-progress/work/2026-04-22-firebase-auth-for-demo-studio.md` <!-- orianna: ok -- local plan path, exists on disk --> have all merged on `feat/demo-studio-v3`. Today `require_session_owner` enforces `session.ownerUid == user.uid` end-to-end (`company-os/tools/demo-studio-v3/auth.py:235-271` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents -->); `POST /session/new` stamps `ownerUid`/`ownerEmail` at creation from the Firebase cookie (`company-os/tools/demo-studio-v3/main.py:1678-1747` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents -->); and `auth_exchange` performs claim-on-first-touch for pre-cutover sessions (`company-os/tools/demo-studio-v3/main.py:1915-1989` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents -->).

Duong signed in locally and exercised the flow successfully, but the landing page still renders the pre-Firebase copy:

> "Enter session ID (ses_...)" / "Sessions are created via Slack. Paste your session link or ID above."

This is the last visible gap. Under the Firebase model an authenticated @missmp.tech user can already create a session via `POST /session/new` — but the only discoverable path to that endpoint is Slack. `static/index.html:30-35` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents --> exposes a paste-session-ID box and directs the user back to Slack.

Under the hood the Slack scaffolding is still load-bearing:

- `session.py::create_session` <!-- orianna: ok --> still requires three positional `slack_*` args (lines 30-32) and writes them on every Firestore doc (lines 61-63).
- `session_store.py` <!-- orianna: ok --> `SessionRecord` / `AgentInitMetadata` dataclasses carry `slack_user_id`, `slack_channel`, `slack_thread_ts` fields (lines 121-123, 141-143) and the `write_session_record` path persists them (lines 276-311).
- `main.py::create_new_session_ui` <!-- orianna: ok --> hardcodes `slack_user_id="ui", slack_channel="ui", slack_thread_ts="ui"` placeholders (lines 1720-1722) to satisfy the positional contract.
- `main.py::create_new_session` (`POST /session`, internal-secret gated) <!-- orianna: ok --> still accepts a full `SessionCreateRequest` with all three slack fields (lines 1755-1802).
- `main.py::managed_sessions_list` enrichment block <!-- orianna: ok --> echoes `slackChannel`/`slackThreadTs` into the `/api/managed-sessions` response (lines 3299-3300).
- `slack-triage/main.py` <!-- orianna: ok --> posts to `POST /session` with the full slack payload (lines 271-302).
- `api/content-gen.yaml` <!-- orianna: ok --> documents `slackUserId`/`slackChannel`/`slackThreadTs` in the `POST /session` request body schema (lines 224-240).

Loop 2d closes out the parent ADR's W7 ("Flip `AUTH_LEGACY_COOKIE_ALLOWED=False`, delete legacy branch") **and** performs the adjacent cleanups that Loops 2a–2c left for a single atomic removal: the slack fields on the session document, the `/session` Slack handoff entrypoint, the one-time-token `/auth/session/{sid}?token=...` URL, the legacy cookie codepaths, and the landing-page copy pointing users back to Slack.

## 2. Decision

Remove all Slack-era scaffolding from Demo Studio v3 in a **single coordinated loop** of 7 waves, gated by the landing of the new UI entrypoint:

1. **Kill the Slack handoff path entirely.** The `slack-triage` service is deprecated, not rewired. `POST /session` (internal-secret gated) is deleted; `GET /auth/session/{sid}?token=...` is deleted; `generate_session_token` / `verify_and_consume_token` and `create_session_cookie` / `verify_session_cookie` are deleted. Rationale: dual-stack already ran for a full week by the time 2d lands; the Slack surface has no identity and cannot be made owner-aware without duplicating the whole Firebase flow.
2. **Drop the slack fields from the write path.** `session.py::create_session` loses the three positional slack args. `session_store.py` loses `slack_user_id`/`slack_channel`/`slack_thread_ts` on both `SessionRecord` and `AgentInitMetadata`. Existing Firestore docs are handled by **drop-at-read** — the fields are no longer echoed in API responses, but we do not run a backfill script. Rationale below (§4).
3. **Flip `AUTH_LEGACY_COOKIE_ALLOWED` to `False` and delete the legacy cookie branch.** Session lifetime is < 24h (parent ADR §4); any holder of a legacy `{sid}` cookie re-signs in and is issued a Firebase cookie. `_is_legacy_user`, `verify_session_cookie`, and the `legacy:` uid-prefix machinery all go.
4. **Add UI "New session" entrypoint.** The landing page gets a **New session** button that calls `POST /session/new` with an empty body (`brand=""`, `market=""` — they're already optional-by-usage; we will make them optional-by-schema in this loop), receives `{sessionId, studioUrl}`, and redirects to `studioUrl`. The Slack-era `studioUrl = /auth/session/{sid}?token=...` redirect target is replaced by `studioUrl = /session/{sid}` — direct, cookie-gated.
5. **Rewrite the landing page copy.** The "Sessions are created via Slack" paragraph and the paste-session-ID box both go. The session-ID input is removed entirely (see OQ-4; my pick: drop clean). What remains is a single **New session** button for signed-in users and the sign-in chrome.
6. **Preserve the dashboard view of historical sessions.** The "Past sessions" surface (currently reached via the `/sessions` list and the `/dashboard` aggregator) does not change — users can still navigate to `/session/{sid}` by clicking an owned row there. Loop 2d only removes the landing-page entrypoint's paste-ID affordance; it does not remove the routes.

Net outcome: after 2d lands, there is exactly one way to reach a Demo Studio session — sign in at `/`, click **New session**, land on the session. No Slack URL, no one-time token, no identity-less session doc.

## 3. Architecture

### 3.1 Before (today, post-Loop-2c)

```
Slack bot ──POST /session (X-Internal-Secret)──► create_new_session
                                                      │
                                                      ├─ create_session(slack_user_id=U, slack_channel=C, slack_thread_ts=T)
                                                      └─ generate_session_token → studioUrl = /auth/session/{sid}?token=...

Browser ──GET /auth/session/{sid}?token──► auth_exchange
                                              │
                                              ├─ verify_and_consume_token
                                              ├─ (if Firebase cookie) claim-on-first-touch → set ownerUid
                                              └─ (if no Firebase cookie) mint legacy {sid} cookie  ← FALLBACK STILL LIVE

Browser ──Sign in with Google──► /auth/login → {uid,email,iat} cookie

Browser ──GET / (landing)──► index.html
                                │
                                ├─ "Sign in with Google" / "Sign out" chrome (Loop 2b)
                                └─ "Enter session ID" paste box + "Sessions are created via Slack" copy  ← DEAD END

Browser ──POST /session/new (Firebase cookie)──► create_new_session_ui
                                                      │
                                                      ├─ create_session(slack_user_id="ui", slack_channel="ui", slack_thread_ts="ui")  ← placeholder noise
                                                      ├─ ownerUid/ownerEmail stamped from user
                                                      └─ studioUrl = /auth/session/{sid}?token=...  ← still round-trips through token exchange
```

Three code paths converge on a single session doc; two of them write identity-less state; one of them (the landing page) is not actually usable as an entrypoint.

### 3.2 After (post-Loop-2d)

```
Browser ──Sign in with Google──► /auth/login → {uid,email,iat} cookie

Browser ──GET / (landing)──► index.html
                                │
                                ├─ Unauthenticated: "Sign in with Google" button
                                └─ Authenticated: "New session" button only

Browser ──POST /session/new (Firebase cookie)──► create_new_session_ui
                                                      │
                                                      ├─ create_session(ownerUid=user.uid, ownerEmail=user.email)  ← clean kwargs
                                                      └─ return {sessionId, studioUrl: "/session/{sid}"}  ← direct

Browser ──GET /session/{sid} (Firebase cookie)──► require_session_owner
                                                      ├─ decode {uid, email}
                                                      ├─ session.ownerUid == user.uid ? ok : 403
                                                      └─ (no legacy cookie path, no token exchange)

[DELETED]  POST /session (internal-secret Slack entrypoint)
[DELETED]  GET /auth/session/{sid}?token=...
[DELETED]  auth.py::verify_session_cookie, create_session_cookie
[DELETED]  auth.py::_is_legacy_user, legacy: uid-prefix machinery
[DELETED]  session.py slack_user_id / slack_channel / slack_thread_ts parameters
[DELETED]  session_store SessionRecord / AgentInitMetadata slack fields
[DELETED]  api/content-gen.yaml slackUserId / slackChannel / slackThreadTs properties
[DELETED]  SessionCreateRequest pydantic model
[DELETED]  scripts/smoke-test.sh POST /session invocations
```

### 3.3 One code path, one doc shape

Post-2d the session doc shape is strictly:

```
{
  sessionId, status, phase, configId,
  ownerUid, ownerEmail,
  managedSessionId?, projectId?, factoryRunId?, outputUrls?, eventHistory?,
  archivedAt?, workerJobId?,
  verificationStatus?, verificationReport?, lastBuildAt?,
  createdAt, updatedAt,
}
```

No `slackUserId`, `slackChannel`, `slackThreadTs`. New docs are born this way; old docs continue to carry the fields but nothing reads them.

### 3.4 `NewSessionRequest` becomes all-optional

Today `NewSessionRequest` requires `brand: str` and `market: str` (`company-os/tools/demo-studio-v3/main.py:662-667` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents -->). The new **New session** button sends an empty body. We relax both to `str | None = None` and pass them through to the title derivation (`title = " ".join(filter(None, [brand, market])) or f"Demo {new_session_id[:8]}"` — existing line, already handles empties). `closeSessionId: str | None = None` unchanged.

## 4. Migration strategy — drop at read (no backfill)

Three options considered for the existing Firestore documents that carry `slackUserId`/`slackChannel`/`slackThreadTs`:

- **a. Drop at read.** Stop reading the fields on every call site; leave existing docs untouched. Firestore is schemaless so this is a no-op migration — docs written before Loop 2d keep the fields forever, docs written after don't have them, and nothing cares either way.
- **b. Delete-on-write.** Every subsequent `merge=True` write clears the old fields. Couples each update path to the migration; forces us to add `.update({"slackUserId": firestore.DELETE_FIELD, ...})` to every write. Fragile.
- **c. One-shot backfill script.** A `scripts/migrate_drop_slack_fields.py` <!-- orianna: ok -- prospective script, not yet on disk --> that iterates `demo-studio-sessions` and clears the three fields on every doc. Operational hazard (cross-workspace Firestore write from a dev machine) without any reader-side benefit.

**Pick: a (drop at read).** Session lifetime is < 24h; the vast majority of active sessions already lack these fields within 48 hours of 2d landing. Orphaned archive docs keeping the fields indefinitely is operationally invisible — no API reads them, no dashboard reads them, Firestore storage cost is negligible. The `managed_sessions_list` enrichment block is the only read site (`main.py:3299-3300` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents -->) and we remove those two lines in W4.

This is a strict-shrink migration — the post-2d readers are a subset of pre-2d readers. No test data mutation is required; tests that seed docs with slack fields (e.g. `tests/test_main_session_create_no_config.py` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents -->) continue to pass because Firestore is tolerant of extra keys.

## 5. Slack bot future — kill entirely

The parent task brief asks whether the Slack bot authenticates via a Firebase service-account + a new endpoint, or is deprecated entirely. Both paths were considered:

- **a. Reauthenticate Slack bot via service account.** Grant `slack-triage-sa` <!-- orianna: ok -- prospective IAM identity, not yet created --> a Firebase custom-token-mint role; bot mints a user-scoped ID token per Slack user; bot calls a new internal endpoint that accepts the ID token and provisions a session with the Slack user's email as owner. This preserves the Slack-to-Studio handoff but introduces a fragile email-to-slack-user mapping and a second session-creation endpoint that parallels `POST /session/new`.
- **b. Kill Slack bot entirely from the Demo Studio surface.** `slack-triage/main.py::create_demo_studio_session` <!-- orianna: ok -- cross-repo file, lives in company-os slack-triage service not strawberry-agents --> and all Slack message templates that post a `/auth/session/{sid}?token=...` URL are deleted or replaced with a bare link to `https://demo-studio.missmp.tech/` (the landing page; user clicks, signs in, clicks **New session**). The Slack bot retains no session-creation authority.

**Pick: b (kill entirely).** The Loop 2d task brief directive is "entirely". The Slack-spec-gathering flow (`_update_specs_from_action`, `_thread_specs` in `slack-triage/main.py` <!-- orianna: ok -- cross-repo file, lives in company-os slack-triage service not strawberry-agents -->) can be preserved if desired — it's independent of the Demo Studio session surface — but the `create_demo_studio_session` function and every caller goes. This is scoped out of Loop 2d's plan (the slack-triage edits ship in a slack-triage PR) but is a **hard dependency** for the `POST /session` deletion to be safe: the slack-triage service stops calling `POST /session` **before** demo-studio-v3 deletes the route.

## 6. Legacy `/auth/session/{sid}?token=...` — drop clean

The parent ADR's W7 scope already flagged deleting `AUTH_LEGACY_COOKIE_ALLOWED` and the legacy cookie branch. 2d extends this to deleting the token-exchange URL itself, which is the only producer of legacy cookies.

- **a. Keep for Slack bot reauth.** If we were going with §5 option a, we'd keep the token-exchange endpoint. Moot under §5.b.
- **b. Drop clean.** No legacy cookies in circulation after 2d lands. No `?token=...` URLs are generated (`studioUrl = /auth/session/{sid}?token=...` is rewritten to `studioUrl = /session/{sid}` on the only remaining producer `create_new_session_ui`). The `auth_exchange` route is deleted. `generate_session_token` / `verify_and_consume_token` / the `used_tokens` Firestore collection's write path are deleted.

**Pick: b (drop clean).** Chosen.

## 7. New session endpoint shape — reuse `POST /session/new`

The route `POST /session/new` already exists (`company-os/tools/demo-studio-v3/main.py:1678-1747` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents -->), is gated by `Depends(require_user)`, stamps `ownerUid`/`ownerEmail`, and returns `{sessionId, studioUrl}`. Loop 2d reuses it with three adjustments:

1. `NewSessionRequest.brand` and `.market` become `str | None = None` so an empty body passes validation.
2. The returned `studioUrl` is rewritten from `f"/auth/session/{new_session_id}?token={token}"` to `f"/session/{new_session_id}"`. No token is generated.
3. The hardcoded `slack_user_id="ui", slack_channel="ui", slack_thread_ts="ui"` placeholders (lines 1720-1722) are deleted once `create_session` drops those parameters in W1.

The `POST /session` route is **deleted** entirely. It is the Slack-only entrypoint and has no analogue once the slack-triage service stops calling it. `SessionCreateRequest` is deleted. `api/content-gen.yaml` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents --> loses the `POST /session` documentation; only `POST /session/new` remains. `scripts/smoke-test.sh` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents --> stops hitting `POST /session`; smoke test is rewritten to exercise `POST /session/new` with a Firebase-authed fixture or skipped (see OQ-5).

## 8. Landing page UI — New session button + remove paste box

`static/index.html` today (lines 30-35) contains:

```
<div class="session-input-row">
  <input type="text" id="sessionInput" placeholder="Enter session ID (ses_...)" ...>
  <button onclick="goToSession()">Open</button>
</div>
<p id="sessionInputError" ...>Please enter a session ID.</p>
<p class="hint">Sessions are created via Slack. Paste your session link or ID above.</p>
```

Post-2d this block is replaced with:

```
<div id="new-session-row" class="hidden">
  <button id="new-session-btn" class="primary-btn">New session</button>
</div>
<div id="new-session-error" class="auth-error hidden" role="alert"></div>
```

The `#new-session-row` is hidden by default and revealed by the existing `onAuthReady(callback)` path in `static/auth.js` <!-- orianna: ok --> — specifically the branch that already reveals `#auth-signed-in` (line 101-112 in current `index.html`).

The `goToSession()` inline script (lines 37-55 of current `index.html`) is deleted along with its event listener. The session-ID paste box is gone — see §OQ-4 for the "keep as secondary affordance" alternative.

`static/auth.js` gains one exported helper `createNewSession()` that:

1. POSTs to `/session/new` with `{}` body and credentials-include.
2. On 201, reads `{sessionId, studioUrl}` from the JSON response and `window.location.href = studioUrl`.
3. On 401, calls `signInWithGoogle()` once, retries on success; re-throws on failure.
4. On any other status, throws `new Error("Could not create session (${status})")` so the inline `#new-session-error` surface can render it.

`static/studio.css` <!-- orianna: ok --> gains ~15 lines of `.primary-btn` styling (the auth chrome already has `.auth-btn` / `.auth-btn-signin`; we want a visually-distinct primary action).

## 9. Routes removed, renamed, or newly-required

| Route | Change | Auth |
|---|---|---|
| `GET /` | unchanged | public |
| `POST /session/new` | `NewSessionRequest` fields optional; `studioUrl` returns `/session/{sid}` directly; no token mint | user |
| `POST /session` | **deleted** | — |
| `GET /auth/session/{sid}` | **deleted** | — |
| `POST /auth/login` | unchanged | public |
| `POST /auth/logout` | unchanged | user |
| `GET /auth/me` | unchanged | user |
| `GET /auth/config` | unchanged | public |
| `GET /session/{sid}` | unchanged | owner |
| `GET/POST /session/{sid}/*` (chat, stream, build, logs, etc.) | unchanged | owner |
| `POST /session/{sid}/chat` with `X-Internal-Secret` | unchanged | internal |
| `GET /dashboard`, `/api/managed-sessions`, `/api/test-results`, `/sessions` | enrichment block drops `slackChannel` / `slackThreadTs` keys in W4 | user |

The `X-Internal-Secret` bypass on `POST /session/{sid}/chat` (for S3/S4 callbacks) is untouched — those callbacks never had user identity and still don't. The S3/S4 services do not call `POST /session`; removing it does not affect them (verified via OQ-6).

## 10. Waves

| Wave | Scope | Deps |
|---|---|---|
| W0 | Pre-flight: confirm slack-triage's `create_demo_studio_session` is removed from prod before W3 lands. Coordination-only wave; no code changes in demo-studio-v3. | clean |
| W1 | `session.py` + `session_store.py` drop slack parameters/fields. Internal callers updated. Xfail tests for the new-shape write. | W0 |
| W2 | `main.py::create_new_session_ui` updated — empty-body support, `studioUrl = /session/{sid}`, no token mint. `NewSessionRequest` fields optional. | W1 |
| W3 | Delete `POST /session`, `SessionCreateRequest`, `auth_exchange`, `generate_session_token` / `verify_and_consume_token`, `create_session_cookie` / `verify_session_cookie`, `_is_legacy_user`, legacy-uid synthesis in `require_user`. Flip `AUTH_LEGACY_COOKIE_ALLOWED` to `False` (then delete the flag). | W1, W2, slack-triage removal in prod |
| W4 | `managed_sessions_list` enrichment block drops `slackChannel`/`slackThreadTs` keys. `api/content-gen.yaml` spec updated (`POST /session` section removed; `NewSessionRequest` documented). `scripts/smoke-test.sh` rewritten or skipped. | W3 |
| W5 | Landing page UI — `static/index.html` replace paste-box with **New session** button; `static/auth.js` add `createNewSession()` helper; `static/studio.css` primary button styling. Integration test for the button → `/session/{sid}` round-trip. | W2 |
| W6 | Deploy + QA — Ekko deploys; Akali Playwright E2E covering (a) signed-out → sign-in → click New session → land on session, (b) signed-in → click New session → land on session, (c) 403 on cross-user session access still holds, (d) direct `GET /auth/session/{sid}?token=...` returns 404 (route gone). | W3, W4, W5 |

Aphelios decomposes W1–W6 into implementation tasks after Duong approves §OQ. Each wave is one PR.

## Test plan

- **Unit W1** `tests/test_session_create_no_slack_fields.py` <!-- orianna: ok -- prospective test, not yet on disk -->: `create_session(owner_uid="U", owner_email="u@missmp.tech")` succeeds with keyword-only args; the Firestore doc contains no `slackUserId`/`slackChannel`/`slackThreadTs` keys; existing docs with those keys still round-trip via `get_session` (schemaless tolerance).
- **Unit W1** `tests/test_session_store_no_slack_fields.py` <!-- orianna: ok -- prospective test, not yet on disk -->: `SessionRecord` and `AgentInitMetadata` no longer expose the three slack attributes; `write_session_record` reads tolerate legacy docs.
- **Unit W2** `tests/test_session_new_ui_empty_body.py` <!-- orianna: ok -- prospective test, not yet on disk -->: `POST /session/new` with body `{}` returns 201 and `studioUrl == "/session/{sid}"`; `ownerUid` / `ownerEmail` stamped from cookie.
- **Unit W3** `tests/test_legacy_auth_removed.py` <!-- orianna: ok -- prospective test, not yet on disk -->: `GET /auth/session/{sid}?token=...` → 404; `POST /session` → 404; legacy-format cookie presented → 401 (not synthesised into `legacy:` user); `AUTH_LEGACY_COOKIE_ALLOWED` symbol absent from `auth.py` module namespace.
- **Unit W4** `tests/test_managed_sessions_no_slack_fields.py` <!-- orianna: ok -- prospective test, not yet on disk -->: `/api/managed-sessions` response enrichment blocks contain no `slackChannel`/`slackThreadTs` keys even when seeded Firestore doc has them.
- **Integration W5** `tests/test_new_session_button.py` <!-- orianna: ok -- prospective test, not yet on disk -->: mint Firebase-emulator token → POST `/auth/login` → POST `/session/new` `{}` → assert 201 → follow `studioUrl` → 200 on `/session/{sid}`. No `/auth/session/{sid}?token=...` hop.
- **Regression W3** `tests/test_route_auth_matrix.py` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents --> updated: remove rows for `POST /session` and `GET /auth/session/{sid}`; add row that both return 404.
- **E2E W6** Playwright specs (Akali):
  - `tests/e2e/test_new_session_signed_in.spec.ts` <!-- orianna: ok -- prospective E2E test, not yet on disk --> — authed @missmp.tech user clicks New session, lands on `/session/{sid}`.
  - `tests/e2e/test_new_session_signed_out.spec.ts` <!-- orianna: ok -- prospective E2E test, not yet on disk --> — unauthed user sees only the Sign in button; after sign-in, New session button appears; click lands on session.
  - `tests/e2e/test_slack_handoff_dead.spec.ts` <!-- orianna: ok -- prospective E2E test, not yet on disk --> — GET `/auth/session/ses_nonexistent?token=dead` returns 404; no redirect to login.

## 11. Open questions (for Duong before promotion)

**Duong's answers (2026-04-23):** `1a 2c 3c 4a 5a 6a 7a` — all Swain picks accepted. OQs resolved; ADR ready for promotion.


1. **Slack-triage removal coordination.** W3 has a hard dep on `slack-triage/create_demo_studio_session` being removed from prod first. <br>
   a: Author a sibling slack-triage PR in 2d that deletes the Demo Studio handoff cleanly — cleanest but couples two repos' release cadence. <br>
   b: Ship 2d's W3 behind a Cloud Run revision-level kill switch (`DEMO_STUDIO_ACCEPT_SLACK_POST=0`); flip switch after slack-triage ships. <br>
   c: Hot-cut — accept a ~1h window where slack-triage errors on POST /session before demo-studio-v3 redeploys. <br>
   Pick: a — the slack-triage PR is ~15 minutes of work and the coupling is the actual constraint, hiding it behind a kill switch just defers the problem.

2. **Existing Firestore docs — drop-at-read vs backfill.** §4. <br>
   a: One-shot backfill script `scripts/migrate_drop_slack_fields.py` run once post-W3. <br>
   b: Delete-on-write in every `merge=True` site. <br>
   c: Drop at read — no data migration. <br>
   Pick: c — §4 rationale; session lifetime is < 24h, orphaned fields on archive docs are invisible.

3. **Keep `/auth/session/{sid}?token=...` for Slack bot reauth?** §6. <br>
   a: Keep route, rewire to Firebase-cookie-aware flow — cleanest from a "don't break URLs" standpoint. <br>
   b: Keep route, return 410 Gone with a "sign in at /" message for 30 days, then delete. <br>
   c: Delete now — any stale Slack URLs return 404. <br>
   Pick: c — under §5.b no producer of these URLs exists after W3; 410 is cheap to add but adds a second round of cleanup work.

4. **Keep paste-session-ID box as secondary affordance?** §8. <br>
   a: Drop the paste box entirely — landing page shows only Sign in / New session buttons. <br>
   b: Keep the paste box behind a "Resume a session" disclosure (details/summary), routing to `/session/{sid}` which then 403s non-owners. <br>
   c: Keep the paste box inline as today, just swap the copy. <br>
   Pick: a — the "Past sessions" entrypoints on `/dashboard` and `/sessions` already serve resume-my-session; a paste-ID box on the landing page is a vestigial Slack-URL muscle-memory.

5. **`scripts/smoke-test.sh` — rewrite or skip?** §7. <br>
   a: Rewrite the smoke test to acquire a Firebase-emulator ID token and hit `POST /session/new` — cleanest, exercises the real flow. <br>
   b: Skip the smoke test on the two invocations that need session creation; keep the non-auth-dependent assertions. <br>
   c: Delete the smoke test entirely. <br>
   Pick: a — the smoke test is load-bearing on deploy (Ekko uses it); rewriting to the emulator flow is ~30 minutes and gives us a permanent Firebase-auth smoke signal.

6. **`POST /session` callers from S3/S4?** Context scan showed only slack-triage calls `POST /session`. Asking for explicit confirmation before W3 deletes it. Ekko + Azir to audit. <br>
   a: Deep audit + grep across all four sibling services (demo-factory, demo-config-mgmt, demo-preview, demo-dashboard). <br>
   b: Rely on the context-scan evidence (slack-triage is the only caller). <br>
   c: Ship W3 behind a kill switch and watch for 5xx on `POST /session` for 48h before deletion. <br>
   Pick: a — a 20-minute grep audit across four services is cheap insurance against a silent callsite.

7. **`NewSessionRequest.brand`/`.market` relax to optional — retain default title?** §3.4 / §7. <br>
   a: `str | None = None`; title derivation stays as-is (`" ".join(filter(None, ...))` already handles empties). <br>
   b: Remove `brand`/`market` from the model entirely; title is always `f"Demo {sid[:8]}"`. <br>
   c: Keep `brand`/`market` required and populate them client-side from a modal before calling `POST /session/new`. <br>
   Pick: a — preserves the existing managed-agent-sets-brand-later flow without coupling the landing-page UI to a brand-entry form.

## Out of scope

- Re-adding any Slack-posting mechanism on session events (future ADR if re-requested).
- Multi-user session sharing (future ADR; `ownerEmail` check is strict).
- Rate limiting on `POST /session/new` (Cloud Run default quotas apply).
- Migrating S3/S4 internal-secret callbacks to Firebase identity (they are server-to-server; identity-free is correct).
- The `/sessions` list view auth (already `require_user`, team-wide read per parent ADR OQ-3).
- `demo-studio-mcp` retirement (`plans/proposed/work/2026-04-21-demo-studio-mcp-retirement.md` <!-- orianna: ok -- local plan path, exists on disk -->).

## Architecture impact

- `session.py` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents --> — `create_session` signature drops `slack_user_id`/`slack_channel`/`slack_thread_ts` positional args; `ownerUid`/`ownerEmail` become the primary identity fields. Firestore doc shape shrinks by three optional keys.
- `session_store.py` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents --> — `SessionRecord` and `AgentInitMetadata` dataclasses lose three fields each. Read path tolerant of legacy docs (schemaless Firestore).
- `auth.py` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents --> — deleted: `AUTH_LEGACY_COOKIE_ALLOWED`, `create_session_cookie`, `verify_session_cookie`, `generate_session_token`, `verify_and_consume_token`, `_is_legacy_user`, legacy-uid synthesis in `require_user`. Simpler module: only Firebase-cookie encode/decode + `require_user` + `require_session_owner` + `require_session_or_internal` remain.
- `main.py` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents --> — deleted: `POST /session`, `GET /auth/session/{sid}`, `SessionCreateRequest` model. `create_new_session_ui` returns `studioUrl = /session/{sid}` directly. `managed_sessions_list` enrichment block stops echoing slack fields.
- `static/index.html` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents --> — paste-session-ID box + "Sessions are created via Slack" copy deleted; New session button added (hidden until signed-in).
- `static/auth.js` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents --> — new exported `createNewSession()` helper.
- `static/studio.css` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents --> — +15 lines of `.primary-btn` styling.
- `api/content-gen.yaml` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents --> — `POST /session` path deleted from spec; `POST /session/new` documented with empty-body semantics.
- `scripts/smoke-test.sh` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents --> — rewritten to exercise `POST /session/new` via Firebase emulator (per OQ-5.a).
- `slack-triage/main.py` <!-- orianna: ok -- cross-repo file, lives in company-os slack-triage service not strawberry-agents --> — `create_demo_studio_session` function deleted; callers stop posting to demo-studio (ships in sibling slack-triage PR per OQ-1.a).

Local dev impact: none. Firebase-emulator path unchanged. Smoke test contributors need the Firebase emulator running locally (already documented in README §Local dev per Loop 2b).

## Tasks

<!-- orianna: ok -- all file paths in T.W*.* tasks below reference files inside company-os/tools/demo-studio-v3/ within the work workspace; not strawberry-agents local files -->

<!-- Aphelios refinement 2026-04-23: tier/executor routing added per task; explicit blockedBy chains added; DoD/Files backfilled on coordination tasks; W0.1→W3 dep now explicit on every W3 task; T.W3.8 added (verify no used-tokens reader); T.W5.6 added (dead-import sweep on auth.js / index.html); T.W0.2 added (Ekko+Azir S3/S4 grep output pinned into plan before W3 starts). Owner field is a builder-tier hint (normal-track = Sonnet builder on single file; complex-track = Opus+Sonnet pair where a planner call precedes the executor call). Evelynn/Sona route by tier at dispatch time. -->

### Executor tier legend

- **normal-track** = single Sonnet builder. Single file, deterministic edit, clear DoD.
- **complex-track** = Opus planner writes a sub-ADR or inline spec, Sonnet builder executes. Required for multi-symbol-delete tasks and shape-change tasks.
- **qa-track** = Akali Playwright MCP. xfail-first discipline satisfied because implementation already landed in W2/W5.
- **deploy-track** = Ekko deploy + smoke. Rule 17 rollback-on-prod-failure applies.

### Coordination

- [ ] **T.COORD.1** — Aphelios decomposes W1–W6 into implementation tasks with executor-tier routing. estimate_minutes: 45. Files: plans/approved/work/2026-04-23-firebase-auth-loop2d-slack-removal.md. DoD: every T.W*.* task carries estimate, Files, DoD, blockedBy, and tier; no task > 60 min. track: this task.
- [ ] **T.COORD.2** — Xayah writes the test-plan stubs enumerated in Test plan (§ above). estimate_minutes: 30. Files: tests/test_session_create_no_slack_fields.py, tests/test_session_store_no_slack_fields.py, tests/test_session_new_ui_empty_body.py, tests/test_legacy_auth_removed.py, tests/test_managed_sessions_no_slack_fields.py, tests/test_new_session_button.py. DoD: one xfail per assertion from §Test plan lives in the correct test file; each test imports the current code and is in `xfail(strict=True)`. track: complex-track (Xayah is Opus test planner; emits stubs that the W* xfail tasks consume). blockedBy: T.COORD.4.
- [ ] **T.COORD.3** — Ekko + Azir audit S3/S4 for `POST /session` callers (OQ-6.a). estimate_minutes: 20. Files: (grep output pinned into T.W0.2 below). DoD: written finding appended to this plan as T.W0.2 result; zero callers confirmed OR new migration sub-task filed before W3 starts. track: normal-track (two-agent grep sweep; no code). blockedBy: T.COORD.4.
- [ ] **T.COORD.4** — Duong answers §11 gating questions before promotion. estimate_minutes: 15. Files: plans/approved/work/2026-04-23-firebase-auth-loop2d-slack-removal.md §11. DoD: all 7 OQs resolved inline; plan promoted by Orianna to approved/. track: human. Status: DONE 2026-04-23.
- [ ] **T.COORD.5** — Sibling slack-triage PR: delete `create_demo_studio_session` and every caller (OQ-1.a). Must merge and deploy before W3. estimate_minutes: 30. Files: slack-triage/main.py, slack-triage/tests/*. DoD: PR merged; prod revision deployed; slack-triage no longer contains the string `DEMO_STUDIO_URL`. track: complex-track (cross-repo; Swain plans the slack-triage edit, Seraphine executes). blockedBy: T.COORD.4.
- [ ] **T.COORD.6** — Senna / Lucian reviews per-wave PRs. estimate_minutes: 45 (total, ~7 min per wave PR). Files: n/a. DoD: one approving non-author review on each of the 6 wave PRs before merge (Strawberry Rule 18). track: human reviewer.
- [ ] **T.COORD.7** — Akali runs the W6 Playwright E2E matrix against staging then prod. estimate_minutes: 45. Files: tests/e2e/test_new_session_signed_in.spec.ts, tests/e2e/test_new_session_signed_out.spec.ts, tests/e2e/test_slack_handoff_dead.spec.ts, assessments/qa-reports/2026-04-??-loop2d.md. DoD: all 3 specs green on staging; QA report filed; `QA-Report:` line added to the W6 PR body (Strawberry Rule 16). track: qa-track. blockedBy: T.W5.5, T.W6.1.

### Wave 0 — Pre-flight slack-triage coordination

- [ ] **T.W0.1** — Ship the slack-triage cleanup PR (T.COORD.5) to prod. Confirm `DEMO_STUDIO_URL/session` is no longer called from slack-triage logs (24h observation window). estimate_minutes: 15 (wall time is 24h; active agent time is 15m for log-query + sign-off). Files: slack-triage/main.py (deploy artifact), Cloud Logging query output pinned to PR comment. DoD: slack-triage logs show zero `POST /session` calls for a rolling 24h window; screenshot of log query attached to this plan as comment under T.W0.1; W3 unblocked. track: deploy-track + verification. blockedBy: T.COORD.5.
- [ ] **T.W0.2** — Pin the S3/S4 grep-audit output (T.COORD.3) into this plan. estimate_minutes: 5. Files: plans/approved/work/2026-04-23-firebase-auth-loop2d-slack-removal.md (append result block under §10 or this task). DoD: grep output for `/session` (not `/session/new`, not `/session/{sid}/*`) across demo-factory, demo-config-mgmt, demo-preview, demo-dashboard committed to plan; zero hits OR explicit follow-up tasks filed. track: normal-track. blockedBy: T.COORD.3.

### Wave 1 — Drop slack fields from write path

- [ ] **T.W1.1** — Xfail `tests/test_session_create_no_slack_fields.py` + `tests/test_session_store_no_slack_fields.py` covering Test-plan W1 cases (Rule 12 — xfail committed before W1.2/W1.3 implementation lands on branch). estimate_minutes: 15. Files: tests/test_session_create_no_slack_fields.py, tests/test_session_store_no_slack_fields.py. DoD: 5 xfails total (kwargs-only signature on create_session; no slack keys on new doc; legacy docs still readable via get_session; dataclass fields absent; write_session_record does not persist them). track: normal-track (test author). blockedBy: T.COORD.2.
- [ ] **T.W1.2** — `session.py` — change `create_session` signature from `(slack_user_id, slack_channel, slack_thread_ts, *, owner_uid, owner_email)` to `(*, owner_uid, owner_email)`. Remove slack fields from the written doc dict. estimate_minutes: 15. Files: session.py. DoD: T.W1.1 xfails 1–2 flip green; no caller in repo still passes positional slack args (grep proves zero). track: complex-track (signature change; Opus planner confirms no external callers in this repo before Sonnet executes). blockedBy: T.W1.1.
- [ ] **T.W1.3** — `session_store.py` — remove `slack_user_id`/`slack_channel`/`slack_thread_ts` from `SessionRecord` and `AgentInitMetadata` dataclasses. Update `write_session_record` to not persist them. Reader (`_doc_to_session_record`) stays tolerant of legacy docs carrying the fields (ignores them, does not fail). estimate_minutes: 20. Files: session_store.py. DoD: T.W1.1 xfails 3–5 flip green; `mypy` / type-check clean; reader test seeded with a legacy doc (slack fields present) still succeeds. track: complex-track (dataclass-field deletion across read+write paths). blockedBy: T.W1.1.
- [ ] **T.W1.4** — Update `tests/test_session.py`, `tests/test_session_store_crud.py`, `tests/test_session_store_types.py`, `tests/test_session_store_no_config_write.py`, `tests/test_session_create_schema.py` to drop slack-arg usage. Leave legacy-doc-tolerance fixtures in `tests/test_routes.py`, `tests/test_main_session_create_no_config.py`, `tests/test_s1_new_flow_phase_*.py` intact (they exercise reader tolerance — see plan "Test plan notes for Xayah"). estimate_minutes: 15. Files: tests/test_session.py, tests/test_session_store_crud.py, tests/test_session_store_types.py, tests/test_session_store_no_config_write.py, tests/test_session_create_schema.py. DoD: the 5 listed tests pass with new kwargs-only signature; the 3 legacy-tolerance test files are unchanged. track: normal-track. blockedBy: T.W1.2, T.W1.3.

### Wave 2 — UI entrypoint returns direct session URL

- [ ] **T.W2.1** — Xfail `tests/test_session_new_ui_empty_body.py` for the Test-plan W2 case (Rule 12). estimate_minutes: 10. Files: tests/test_session_new_ui_empty_body.py. DoD: 2 xfails (POST `/session/new` body `{}` → 201; studioUrl equals `/session/{sid}` with no `?token=` query). track: normal-track. blockedBy: T.COORD.2, T.W1.4.
- [ ] **T.W2.2** — `main.py` — relax `NewSessionRequest.brand` / `.market` to `str | None = None`. estimate_minutes: 5. Files: main.py. DoD: empty POST body validates via pydantic; existing callers that send populated fields still work. track: normal-track. blockedBy: T.W2.1.
- [ ] **T.W2.3** — `main.py::create_new_session_ui` — remove `slack_user_id="ui", slack_channel="ui", slack_thread_ts="ui"` placeholder kwargs; rewrite `studio_url = f"/auth/session/{new_session_id}?token={token}"` to `studio_url = f"/session/{new_session_id}"`; remove the `token = generate_session_token(...)` call. estimate_minutes: 10. Files: main.py. DoD: T.W2.1 xfails flip green; response JSON schema unchanged (same keys, new value for studioUrl). track: normal-track. blockedBy: T.W2.2, T.W1.2.

### Wave 3 — Delete legacy endpoints, cookies, and flag

W3 hard-blocked on **T.W0.1** (slack-triage stopped calling `POST /session` for 24h) AND **T.W0.2** (S3/S4 audit shows zero callers). Do not begin W3 until both are checked.

- [ ] **T.W3.1** — Xfail `tests/test_legacy_auth_removed.py` for the Test-plan W3 cases (Rule 12). estimate_minutes: 15. Files: tests/test_legacy_auth_removed.py. DoD: 4 xfails (GET `/auth/session/{sid}?token=...` → 404; POST `/session` → 404; legacy-format `ds_session` cookie presented → 401 not `legacy:` synthesis; `AUTH_LEGACY_COOKIE_ALLOWED` symbol absent from `auth.py` module namespace). track: normal-track. blockedBy: T.COORD.2, T.W0.1, T.W0.2.
- [ ] **T.W3.2** — `main.py` — delete `POST /session` handler + `SessionCreateRequest` pydantic model. estimate_minutes: 10. Files: main.py. DoD: route returns 404; model symbol absent; grep for `SessionCreateRequest` in repo returns zero hits. track: normal-track. blockedBy: T.W3.1.
- [ ] **T.W3.3** — `main.py` — delete `GET /auth/session/{sid}` handler (`auth_exchange`). estimate_minutes: 10. Files: main.py. DoD: route returns 404; no other code path references `auth_exchange`. track: normal-track. blockedBy: T.W3.1.
- [ ] **T.W3.4** — `auth.py` — delete `create_session_cookie`, `verify_session_cookie`, `generate_session_token`, `verify_and_consume_token`, `_is_legacy_user`, `AUTH_LEGACY_COOKIE_ALLOWED` flag. Remove the legacy-cookie branch from `require_user` so only Firebase-cookie decode remains. estimate_minutes: 20. Files: auth.py. DoD: module public surface is {`require_user`, `require_session_owner`, `require_session_or_internal`, Firebase-cookie encode/decode helpers}; grep for `legacy:` prefix returns zero hits in auth.py and main.py; T.W3.1 flag-symbol xfail flips green. track: complex-track (6-symbol deletion + control-flow simplification in require_user; Opus planner maps the call graph before Sonnet executes). blockedBy: T.W3.1, T.W3.2, T.W3.3.
- [ ] **T.W3.5** — Delete `demo-studio-used-tokens` collection writes that lived inside `verify_and_consume_token`. estimate_minutes: 5. Files: auth.py. DoD: no call site in repo writes to `demo-studio-used-tokens`. track: normal-track (absorbed into T.W3.4 diff). blockedBy: T.W3.4.
- [ ] **T.W3.6** — Flip T.W3.1 xfails green; update `tests/test_route_auth_matrix.py` regression matrix to match. estimate_minutes: 15. Files: tests/test_legacy_auth_removed.py, tests/test_route_auth_matrix.py. DoD: all deleted-route rows assert 404; cookie-only rows assert 401 for legacy-format cookies; pytest module green. track: normal-track. blockedBy: T.W3.2, T.W3.3, T.W3.4, T.W3.5.
- [ ] **T.W3.7** — Remove dead-code callers and imports exposed by the W3 deletions (e.g. `COOKIE_MAX_AGE`, `itsdangerous` imports, unused helpers in `auth.py` / `main.py`). estimate_minutes: 10. Files: auth.py, main.py, requirements.txt. DoD: `ruff` / `flake8` clean; `pytest` green; `requirements.txt` drops `itsdangerous` only if no other consumer remains (grep confirms). track: normal-track. blockedBy: T.W3.6.
- [ ] **T.W3.8** — Verify no reader of `demo-studio-used-tokens` collection remains. estimate_minutes: 5. Files: (grep only; no edit expected). DoD: grep for `demo-studio-used-tokens` / `used_tokens` / `verify_and_consume_token` across demo-studio-v3 returns zero hits post-W3.5; if any remain, surface as T.W3.8.1 follow-up. track: normal-track. blockedBy: T.W3.5.

### Wave 4 — Read-site cleanup

- [ ] **T.W4.1** — Xfail `tests/test_managed_sessions_no_slack_fields.py` for the Test-plan W4 case (Rule 12). estimate_minutes: 10. Files: tests/test_managed_sessions_no_slack_fields.py. DoD: 1 xfail covering `/api/managed-sessions` enrichment block: seeded Firestore doc carries slackChannel/slackThreadTs; response dict contains neither key. track: normal-track. blockedBy: T.COORD.2, T.W3.6.
- [ ] **T.W4.2** — `main.py::managed_sessions_list` — delete `"slackChannel": fs_doc.get("slackChannel")` and `"slackThreadTs": fs_doc.get("slackThreadTs")` from the enrichment dict (lines 3299-3300). estimate_minutes: 5. Files: main.py. DoD: T.W4.1 xfail flips green; no other key removed. track: normal-track. blockedBy: T.W4.1.
- [ ] **T.W4.3** — `api/content-gen.yaml` — delete the `POST /session` path entry; add a `POST /session/new` entry documenting the empty-body / ownerUid-stamped contract. estimate_minutes: 20. Files: api/content-gen.yaml. DoD: OpenAPI spec validates via `openapi-spec-validator`; no `slackUserId`/`slackChannel`/`slackThreadTs` token remains in the file; `NewSessionRequest` schema shows brand/market as optional. track: complex-track (spec author; Opus planner confirms schema shape before Sonnet applies the edit). blockedBy: T.W3.2, T.W2.2.
- [ ] **T.W4.4** — `scripts/smoke-test.sh` — rewrite both `POST /session` invocations (lines 85 and 89) to hit `POST /session/new` after acquiring a Firebase-emulator ID token via `curl` (per OQ-5.a). estimate_minutes: 30. Files: scripts/smoke-test.sh. DoD: smoke test green against staging; no `slackUserId`/`slackChannel` tokens remain in the script; emulator-token acquisition documented inline as a comment. track: complex-track (Ekko as ops-aware implementer; Firebase emulator integration is non-trivial). blockedBy: T.W3.2, T.W2.3.

### Wave 5 — Landing page UI

- [ ] **T.W5.1** — Xfail `tests/test_new_session_button.py` for the Test-plan W5 integration case (Rule 12). estimate_minutes: 15. Files: tests/test_new_session_button.py. DoD: 1 xfail (mint Firebase-emulator ID token → POST `/auth/login` → POST `/session/new` `{}` → assert 201 → GET `studioUrl` → 200 on `/session/{sid}`; assert no `/auth/session/*` hop). track: normal-track. blockedBy: T.COORD.2, T.W2.3.
- [ ] **T.W5.2** — `static/auth.js` — add `createNewSession()` export per §8. estimate_minutes: 15. Files: static/auth.js. DoD: module exports `createNewSession`; POSTs to `/session/new` with `{}` body and `credentials: 'include'`; on 201 reads `{sessionId, studioUrl}` and sets `window.location.href = studioUrl`; on 401 calls `signInWithGoogle()` once and retries; on other status throws `Error("Could not create session (${status})")`. track: normal-track. blockedBy: T.W5.1.
- [ ] **T.W5.3** — `static/index.html` — delete paste-session-ID row (lines 30-35), `goToSession()` inline script (lines 37-55), and its event listener; delete "Sessions are created via Slack" copy. Add `#new-session-row` (hidden by default) with `#new-session-btn.primary-btn`; wire click handler to `createNewSession()`; wire `onAuthReady` callback to reveal `#new-session-row` on sign-in (mirror existing `#auth-signed-in` reveal at lines 101-112). Add `#new-session-error.auth-error.hidden[role=alert]` surface. estimate_minutes: 20. Files: static/index.html. DoD: landing page shows only Sign in for unauthed; shows Sign out + New session for authed; no `<input id="sessionInput">` element in DOM; `#new-session-error` renders helper's thrown error text. track: complex-track (DOM surgery with event-listener rewiring; Rakan pair with planner to ensure onAuthReady contract preserved). blockedBy: T.W5.2.
- [ ] **T.W5.4** — `static/studio.css` — add `.primary-btn` rule (~15 lines) matching existing `.auth-btn` visual language (padding, hover, focus, disabled). estimate_minutes: 10. Files: static/studio.css. DoD: button renders with consistent padding / hover / focus states; dark-mode variant present if the existing auth-chrome has one. track: normal-track. blockedBy: T.W5.3.
- [ ] **T.W5.5** — Flip T.W5.1 xfail green. estimate_minutes: 5. Files: tests/test_new_session_button.py. DoD: integration test passes end-to-end against the local dev server. track: normal-track. blockedBy: T.W5.2, T.W5.3, T.W5.4.
- [ ] **T.W5.6** — Dead-import sweep on `static/auth.js` and `static/index.html` — remove references to deleted helpers (`goToSession`, any `/auth/session/` URL constructors, `generate_session_token` shims). estimate_minutes: 5. Files: static/auth.js, static/index.html. DoD: browser devtools console shows no ReferenceError on landing page; grep for `/auth/session/` in static/ returns zero hits. track: normal-track. blockedBy: T.W5.3.

### Wave 6 — Deploy + QA

W6 is QA + deploy; xfail-first (Rule 12) does not apply to deploy tasks. E2E specs are themselves the tests; implementation already lives in W2/W5.

- [ ] **T.W6.1** — Deploy to staging; smoke test (T.W4.4) green; manual Akali pass on staging landing page. estimate_minutes: 15. Files: (deploy only; no code diff). DoD: staging revision active; `GET /auth/session/ses_probe?token=probe` returns 404; `GET /` renders New session button for authed @missmp.tech users; smoke-test.sh exits 0. track: deploy-track. blockedBy: T.W5.5, T.W4.4.
- [ ] **T.W6.2** — Akali Playwright E2E spec `test_new_session_signed_in.spec.ts` per Test-plan W6.a. estimate_minutes: 15. Files: tests/e2e/test_new_session_signed_in.spec.ts. DoD: test green against staging; video + screenshots archived under assessments/qa-reports/. track: qa-track. blockedBy: T.W6.1.
- [ ] **T.W6.3** — Akali Playwright E2E spec `test_new_session_signed_out.spec.ts` per Test-plan W6.b. estimate_minutes: 15. Files: tests/e2e/test_new_session_signed_out.spec.ts. DoD: test green; video archived. track: qa-track. blockedBy: T.W6.1.
- [ ] **T.W6.4** — Akali Playwright E2E spec `test_slack_handoff_dead.spec.ts` per Test-plan W6.c. estimate_minutes: 10. Files: tests/e2e/test_slack_handoff_dead.spec.ts. DoD: test green; 404 confirmed on staging; video archived. track: qa-track. blockedBy: T.W6.1.
- [ ] **T.W6.5** — Duong approves staging; Ekko deploys to prod; post-deploy smoke (`/auth/config` 200 + `/session/new` unauth 401 + `/auth/session/*` 404). estimate_minutes: 10. Files: (deploy only). DoD: prod revision live; smoke green; rollback script on standby per Strawberry Rule 17; auto-revert wired to prod-smoke-fail. track: deploy-track. blockedBy: T.W6.2, T.W6.3, T.W6.4, T.COORD.7.

## Aphelios breakdown notes (2026-04-23)

**Task count:** 7 coordination + 2 W0 + 4 W1 + 3 W2 + 8 W3 + 4 W4 + 6 W5 + 5 W6 = **39 tasks** across 7 waves + coordination stream.

**Additions vs Swain's baked-in list (T.COORD.1–7 + T.W0.1 + T.W1.1–W6.5 = 30 tasks):**

1. **T.W0.2** (new) — Pin the S3/S4 grep-audit output from T.COORD.3 into the plan before W3 starts. Closes the loop on OQ-6.a.
2. **T.W3.8** (new) — Explicit verify-no-reader-remains sweep on `demo-studio-used-tokens`. T.W3.5 covers writer deletion only; a dead reader would silently persist.
3. **T.W5.6** (new) — Dead-import sweep on `static/auth.js` and `static/index.html`. Frontend JS is not linted by the pre-commit hook path (hook runs unit tests for changed packages; static assets don't register as a package), so this is manual.
4. Every W3 task now carries `blockedBy: T.W0.1, T.W0.2` (transitively via T.W3.1). The Swain draft had only the W3 wave-table dep; individual tasks were silent.
5. Coordination tasks (T.COORD.1–7) gained explicit `Files:`, `DoD:`, `track:`, and where applicable `blockedBy:`. Swain's draft was title-only on those lines.
6. `track:` annotation added to every task to support Evelynn/Sona dispatch routing. **Complex-track** tasks (8 of them: T.COORD.2, T.COORD.5, T.W1.2, T.W1.3, T.W3.4, T.W4.3, T.W4.4, T.W5.3) need an Opus planner call before the Sonnet executor call. The rest are normal-track single-Sonnet-builder tasks, qa-track (Akali), or deploy-track (Ekko).

**Verified Swain's bake-in is sound on:**

- xfail-first ordering (Rule 12): W1.1→W1.2/3, W2.1→W2.2/3, W3.1→W3.2–5, W4.1→W4.2, W5.1→W5.2–4. All xfail tasks precede their implementation tasks on the same branch; pre-push TDD-gate will pass. W6 exempt (deploy + QA).
- No task > 60 min. Largest is T.W1.3 / T.W3.4 / T.W4.4 / T.W5.3 at 20–30 min.
- Every task touches a single logical scope (one file or one tight cluster). T.W5.3 is the biggest blast-radius (DOM surgery) and is marked complex-track accordingly.
- Regression discipline (Rule 13): W3 route-deletion tasks have T.W3.6 updating the `test_route_auth_matrix.py` matrix — this is the regression assertion.
- QA gate (Rule 16): T.COORD.7 + T.W6.2–4 produce the Playwright MCP report linked from the W5/W6 PR bodies.

**Gaps surfaced / flagged:**

- **G1:** Swain's T.COORD.2 (Xayah test stubs) has no explicit ordering vs T.W*.1 xfail tasks. Resolved here by setting T.COORD.2 as blockedBy for every T.W*.1. If Xayah and the xfail authors are the same agent (Soraka), collapse — otherwise Xayah's stubs must land first.
- **G2:** `POST /session/new` currently does not have a rate-limit (per §"Out of scope"). Flagging because making it the sole session-creation path raises its blast radius; Azir may want a follow-up ADR to add basic rate-limiting. Not in scope here.
- **G3:** Firebase-emulator ID token acquisition in `scripts/smoke-test.sh` (T.W4.4) relies on the emulator's REST endpoint being reachable from the CI runner. If staging CI does not spin up the emulator, the smoke test as designed won't run in CI — it will only run locally and against staging manually. Worth confirming before T.W4.4 starts; otherwise OQ-5.a may need a fallback to OQ-5.b (skip).
- **G4:** T.W3.4 deletes `AUTH_LEGACY_COOKIE_ALLOWED` flag reads but there is no task to scrub the Cloud Run revision YAML / env-var config that sets it. Ops-side cleanup should ride inside T.W6.5 deploy notes; flagging here so Ekko sees it.
- **G5:** No task explicitly asserts the landing-page copy change is reflected in any Figma-mirror design doc (Rule 16 QA flow diffs against Figma). If no Figma source exists for the landing page, Akali's QA report will be a waiver — that's OK but worth calling out.

**Scope creep vs ADR body:** **none.** The three added tasks (T.W0.2, T.W3.8, T.W5.6) are verification/sweep tasks that close stated ADR invariants; no new behavior, no new surface area.

## Test plan notes for Xayah

The unit-test files listed above are all net-new; the existing `tests/test_routes.py` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents -->, `tests/test_main_session_create_no_config.py` <!-- orianna: ok -- cross-repo file, lives in company-os workspace not strawberry-agents -->, `tests/test_s1_new_flow_phase_*.py` <!-- orianna: ok -- cross-repo files, live in company-os workspace not strawberry-agents --> need their `slackUserId` / `slackChannel` / `slackThreadTs` seed dicts kept as-is (they exercise legacy-doc tolerance) — do NOT strip those keys from test fixtures, because one of the invariants we're testing is that legacy docs keep roundtripping. The only tests that need slack-arg removal are the `create_session()`-calling unit tests enumerated in T.W1.4.

---

## Orianna approval

**Decision:** APPROVE
**Date:** 2026-04-23
**Fact-check:** blocks: 0, warns: 0, infos: 2
**Notes:** All 7 OQs resolved by Duong (§11). All cross-repo file references properly annotated. Both local plan paths verified on disk. No speculative claims presented as current-state without anchor. Swain picks accepted; Aphelios owns downstream decomposition.

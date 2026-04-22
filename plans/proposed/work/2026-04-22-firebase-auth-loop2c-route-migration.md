---
status: proposed
orianna_gate_version: 2
complexity: normal
concern: work
owner: azir
created: 2026-04-22
tags:
  - demo-studio
  - auth
  - firebase
  - routes
  - work
tests_required: true
orianna_signature_approved: "sha256:16e8dd9305126301a01d925794a7953afa84a01e6f991c50ddd4086a14b18cbd:2026-04-22T13:10:12Z"
---

# Loop 2c — Firebase auth route migration (`require_session` → `require_session_owner`)

<!-- orianna: ok — every file-path token in this plan (main.py, auth.py, firebase_auth.py, session.py, session_store.py, requirements.txt, tests/test_*.py, tools/demo-studio-v3/*) references files inside the missmp/company-os work workspace under company-os/tools/demo-studio-v3/, not strawberry-agents -->
<!-- orianna: ok — HTTP path tokens (/session/{sid}, /session/{sid}/chat, /session/{sid}/stream, /session/{sid}/build, /session/{sid}/cancel-build, /session/{sid}/logs, /session/{sid}/status, /session/{sid}/events, /session/{sid}/messages, /session/{sid}/history, /session/{sid}/preview, /session/{sid}/reauth, /session/{sid}/complete, /session/{sid}/close, /auth/session/{sid}, /session/new, /sessions) are route paths on the demo-studio Cloud Run service, not filesystem paths -->
<!-- orianna: ok — Firestore collection token (demo-studio-sessions) is a Firestore logical path, not filesystem -->
<!-- orianna: ok — cookie token (ds_session) is an HTTP cookie name, not filesystem -->
<!-- orianna: ok — field tokens (ownerUid, ownerEmail, owner_uid, slackUserId, slackChannel, slackThreadTs) are Firestore document field names, not filesystem -->
<!-- orianna: ok — env-var tokens (AUTH_LEGACY_COOKIE_ALLOWED, SESSION_SECRET, INTERNAL_SECRET, FIREBASE_PROJECT_ID, ALLOWED_EMAIL_DOMAIN) are module flags or environment variables, not filesystem -->
<!-- orianna: ok — external refs (firebase-admin, itsdangerous, FastAPI Depends) are SDK/library tokens, not files -->

## 1. Context

Loop 2a of the Firebase auth rollout (`plans/approved/work/2026-04-22-firebase-auth-loop2a-server-backbone.md` <!-- orianna: ok -- sibling plan in approved/work, not a strawberry-agents implementation path -->, commits `c59e2d6`→`b2adf20` on branch `feat/demo-studio-v3` <!-- orianna: ok -- git branch name in company-os repo, not a local path -->) landed the server backbone:

- `firebase_auth.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ --> with `verify_firebase_token(id_token) -> User` (`User(uid, email)` dataclass), `InvalidTokenError`, `DomainNotAllowedError`.
- `auth.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ --> gained `encode_user_cookie(user_dict)` / `decode_user_cookie(raw) -> dict | None` helpers producing/consuming the new `{uid, email, iat}` cookie payload under the existing `ds_session` cookie name, plus module flag `AUTH_LEGACY_COOKIE_ALLOWED = True`.
- `main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ --> gained `POST /auth/login`, `POST /auth/logout`, `GET /auth/me`, `GET /auth/config`.
- The legacy surface (`create_session_cookie`, `verify_session_cookie`, `require_session`, `require_session_or_internal`) was **left untouched** — it still decodes only the `{sid}` payload and still binds cookie→session-id.

Loop 2b (frontend sign-in UI — W4 of the parent ADR `plans/approved/work/2026-04-22-firebase-auth-for-demo-studio.md` <!-- orianna: ok -- sibling plan in approved/work, not a strawberry-agents implementation path -->, Orianna-signed `sha256:91a431b7ed3f69b260755586908979245602a06e9d3e815d9ba432790d232d86`) is queued in parallel. This plan assumes 2b has landed before 2c executes, so live browser sessions already mint new-cookie payloads via `POST /auth/login`.

**Loop 2c scope** — W2 + W3 of the parent ADR, narrowed to S1's session-owned surface:

1. Rewrite `require_session` to dual-stack decode and return a `User` (new cookie) or a synthetic `User(uid=sid, email="")` (legacy cookie, flag-gated).
2. Introduce `require_session_owner(request, sid, user=Depends(require_session))` that additionally loads the session doc and enforces ownership.
3. Add `ownerUid` (and `ownerEmail` for auditability) on the Firestore session doc; populate on new-cookie-created sessions; claim-on-first-touch for pre-existing (legacy-created) sessions.
4. Migrate every S1 `/session/{sid}/*` route to the new owner dependency, preserving the existing `X-Internal-Secret` bypass on `require_session_or_internal` callers.
5. Keep the full dual-stack decode alive for the loop — legacy cookie helpers and the Slack `/auth/session/{sid}?token=...` handoff remain callable (removal is Loop 2d).

Deferred to other loops:

- Loop 2b: Frontend sign-in UI.
- Loop 2d: Removal of legacy cookie helpers, Slack handoff scaffolding, `AUTH_LEGACY_COOKIE_ALLOWED` flag flip.
- Dashboard split (`plans/in-progress/work/2026-04-22-demo-dashboard-service-split.md` <!-- orianna: ok -- sibling plan in in-progress/work, not a strawberry-agents implementation path -->) — Loop 2c migrates S1's `/session/{sid}/*` surface only; dashboard-owned routes are covered there.

## 2. Decision

Introduce an owner-aware FastAPI dependency chain on branch `feat/demo-studio-v3` <!-- orianna: ok -- git branch name in company-os repo, not a local path --> in `mmp/workspace/tools/demo-studio-v3/` <!-- orianna: ok -- cross-repo directory, lives in company-os workspace not strawberry-agents -->:

### 2.1 `require_session` rewritten (additive to existing behavior)

`auth.py::require_session` changes from returning `str` (session_id) to returning a `User`-ish object. Because callers in `main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ --> currently receive the session_id via `sid = Depends(require_session)` and compare it against `path_session_id`, we cannot swap the return type in place without breaking every call site simultaneously. Two-step approach inside this loop:

**Step 1 — add a parallel dep.** Introduce `require_user(request, ds_session=Cookie(...)) -> User` that:

1. Reads the `ds_session` cookie.
2. Calls `decode_user_cookie(raw)`:
   - Success → return `User(uid=payload["uid"], email=payload["email"])`.
3. If new-cookie decode returns `None` AND `AUTH_LEGACY_COOKIE_ALLOWED`:
   - Call `verify_session_cookie(raw)` → if returns a session-id, return a synthetic `User(uid=f"legacy:{sid}", email="")`. The `legacy:` prefix namespaces legacy uids so they never collide with Firebase uids.
4. If both decode paths fail (or flag is off and only legacy shape present) → raise `HTTPException(401, "Not authenticated")`.

`require_user` does NOT check path params. It is pure authentication.

**Step 2 — rewrite `require_session_owner`.** The new dep replaces `require_session` on every `/session/{sid}/*` route:

    async def require_session_owner(
        request: Request,
        session_id: str,           # from path param
        user: User = Depends(require_user),
    ) -> SessionRecord:
        session = get_session(session_id)
        if session is None:
            raise HTTPException(404, "Session not found")
        if _is_legacy_user(user):
            # Legacy cookie path: enforce cookie-sid == path-sid (existing semantics).
            if user.uid != f"legacy:{session_id}":
                raise HTTPException(401, "Session mismatch")
            return session
        owner_uid = session.get("ownerUid")
        if owner_uid is None:
            # Pre-cutover session with no owner → reject here; auth_exchange is
            # the claim-on-first-touch call-site, not arbitrary /session/* routes.
            raise HTTPException(403, "Session has no owner; revisit Slack link")
        if owner_uid != user.uid:
            raise HTTPException(403, "Not session owner")
        return session

Notes:

- Returns the session dict (not the string sid) so downstream handlers can drop their own `get_session(sid)` call. Migration is mechanical — handlers that currently read `session = get_session(sid)` after the `Depends(require_session)` call can either (a) accept the new signature and drop the lookup, or (b) keep the pattern, reading `session.get("sessionId")` from the dep. We take path (b) for the migration PR to keep diffs minimal; path (a) is a follow-up cleanup out of scope.
- `require_session_or_internal` (the `X-Internal-Secret` bypass dep used by `/session/{sid}/chat`, `/session/{sid}/logs`) is **not** migrated in this loop. It keeps its current `str` return. The internal bypass path has no user identity by construction and Loop 2c does not introduce one. Server-to-server callers remain unaffected. See §Open Questions Q2 for rationale.
- Legacy fallthrough (`user.uid.startswith("legacy:")`) is an audited intentional branch — explicit `_is_legacy_user` helper, not a magic string check scattered through handlers.

### 2.2 Ownership persistence

`session_store.py::create_session` signature (currently `create_session(slack_user_id, slack_channel, slack_thread_ts, initial_context=None)`) gains two optional kwargs:

    def create_session(
        slack_user_id: str,
        slack_channel: str,
        slack_thread_ts: str,
        initial_context: dict[str, Any] | None = None,
        *,
        owner_uid: str | None = None,
        owner_email: str | None = None,
    ) -> dict[str, Any]:
        ...
        doc = {
            ...,
            "ownerUid": owner_uid,      # None-tolerant; legacy path leaves unset
            "ownerEmail": owner_email,  # None-tolerant; audit-only
            ...,
        }

- `POST /session/new` (`main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ --> line 1645) currently uses `require_session` (legacy sid binding). In this loop its dep becomes `require_user`; on session creation it passes `owner_uid=user.uid, owner_email=user.email` (empty string for legacy users — acceptable since any session `/session/new` creates is owner-stamped at creation time; legacy users at the handoff path are handled by claim-on-first-touch instead).
- `POST /session` (Slack handoff with `X-Internal-Secret`, `main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ --> around line 1700s) keeps the bypass and passes `owner_uid=None, owner_email=None`. The owner is claimed when a Firebase-authed user first opens `/auth/session/{sid}?token=...`.
- `GET /auth/session/{session_id}` (`main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ --> line 1869) — the Slack handoff consumption endpoint — adds a claim-on-first-touch step: after `verify_and_consume_token` succeeds, if the session has a valid Firebase cookie AND `ownerUid` is unset, call `session_store.set_session_owner(sid, user.uid, user.email)`. If the user already has a Firebase cookie but the session is already owned by a different uid, return 403. If the user is unauthenticated, the 2c behavior is to **fall back to the legacy cookie mint** (emit a `{sid}` cookie), preserving current Slack-link-in-browser behavior for users who have not yet signed in. See §Open Questions Q1 — Duong flagged this.

A new helper `session_store.set_session_owner(session_id: str, owner_uid: str, owner_email: str) -> bool` performs a transactional claim: reads current doc, writes `ownerUid`+`ownerEmail` only if currently unset; returns `True` on claim, `False` if already owned (by anyone, including self). Call sites distinguish `False` + same-uid (idempotent) from `False` + different-uid (403) by re-reading the doc.

### 2.3 Dependency flow (after this loop)

    ds_session cookie ──► require_user ──► User (new OR legacy synthetic)
                                             │
    /session/{sid}/*  ──► require_session_owner ──┐
                                                  ├─► get_session(sid) ──► session dict
                                                  ├─► legacy: user.uid == f"legacy:{sid}"?
                                                  └─► new:    session.ownerUid == user.uid?
                                                                │
                                                                └─► returns session dict (or 403/401/404)

    X-Internal-Secret ──► require_session_or_internal (unchanged; returns str sid)
                            │
    /session/{sid}/chat, /logs  (preserve existing bypass)

### 2.4 Routes to migrate

From `main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ --> grep on `/session/` (line refs are pre-migration):

| Route | Current dep | New dep | Notes |
|---|---|---|---|
| `POST /session/new` (1645) | `require_session` | `require_user` | Any authed user can create; stamp owner at creation. |
| `GET /session/{sid}` (1904) | `require_session` | `require_session_owner` | Owner-only render. |
| `GET /session/{sid}/preview` (1948) | *(currently unauthenticated — confirm in T.PREC.1)* | `require_session_owner` | If currently open, tighten here; if already owner-guarded, dep swap. |
| `POST /session/{sid}/chat` (1972) | `require_session_or_internal` | `require_session_or_owner` (new compound) | Internal bypass preserved; human path is owner-gated. |
| `GET /session/{sid}/status` (2088) | *(check)* | `require_session_owner` | |
| `POST /session/{sid}/build` (2129) | *(check)* | `require_session_owner` | |
| `GET /session/{sid}/logs` (2213) | `require_session_or_internal` | `require_session_or_owner` | Internal bypass preserved. |
| `GET /session/{sid}/events` (2404) | *(check)* | `require_session_owner` | |
| `GET /session/{sid}/messages` (2435) | *(check)* | `require_session_owner` | |
| `GET /session/{sid}/stream` (2472) | existing `_require_session_for_stream` wrapper → `require_session` | owner variant via same wrapper pattern | SSE wrapper preserved. |
| `GET /session/{sid}/history` (2713) | *(check)* | `require_session_owner` | |
| `POST /session/{sid}/cancel-build` (2859) | *(check)* | `require_session_owner` | |
| `POST /session/{sid}/reauth` (2911) | *(check)* | `require_session_owner` | |
| `POST /session/{sid}/complete` (2933) | *(check)* | `require_session_owner` | |
| `POST /session/{sid}/close` (2955) | *(check)* | `require_session_owner` | |
| `GET /auth/session/{sid}` (1869) | *(none — public with token)* | remains public; gains claim-on-first-touch | See §2.2. |

Precondition task T.PREC.1 audits the exact current dep on every `/session/*` route (grep is authoritative) and updates the table above; 2c does NOT migrate routes whose current dep is absent (e.g. an unauth route would need an explicit decision).

`require_session_or_owner` is a new compound dep needed by `/session/{sid}/chat` and `/session/{sid}/logs`:

    async def require_session_or_owner(
        request: Request,
        session_id: str,
        ds_session: str | None = Cookie(default=None, alias=COOKIE_NAME),
    ):
        # Internal-secret bypass first — identical to require_session_or_internal.
        if verify_internal_secret(request):
            return {"sessionId": request.path_params.get("session_id", "")}
        # Cookie path: full owner check.
        user = await require_user(request, ds_session)
        return await require_session_owner(request, session_id, user)

The internal bypass returns a dict shaped like a session record (just `sessionId`) so callers have a single return shape to code against. Routes that previously received a `str` sid via `require_session_or_internal` need minimal change — `_sid = sess["sessionId"]`.

## 3. Scope

**In scope:**

- `auth.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->: new `require_user`, new `require_session_owner`, new `require_session_or_owner`, `_is_legacy_user` helper. Existing `require_session`, `require_session_or_internal`, `create_session_cookie`, `verify_session_cookie` left behind as dead-code-once-migrated (removed in Loop 2d) but still callable — NO deletions this loop.
- `session_store.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->: `owner_uid` + `owner_email` kwargs on `create_session`; new `set_session_owner(sid, uid, email) -> bool` transactional helper.
- `main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->: dep swaps on the routes in §2.4; new claim-on-first-touch in `auth_exchange` (GET /auth/session/{sid}); `/session/new` owner-stamps on create.
- `tests/` <!-- orianna: ok -- cross-repo directory token, lives in company-os/tools/demo-studio-v3/tests/ not strawberry-agents -->: xfail-first unit tests for `require_user`, `require_session_owner`, `require_session_or_owner`, `set_session_owner`, and a route-auth matrix for the migrated surface.
- Dual-stack decode remains live; `AUTH_LEGACY_COOKIE_ALLOWED = True` unchanged.

**Out of scope:**

- Removal of legacy helpers (`create_session_cookie`, `verify_session_cookie`, `require_session`, `require_session_or_internal`) — Loop 2d.
- Slack handoff scaffolding removal (`/auth/session/{sid}?token=...`, Slack field pruning on session doc) — Loop 2d.
- Frontend sign-in UI — Loop 2b.
- Dashboard-owned routes — `plans/in-progress/work/2026-04-22-demo-dashboard-service-split.md` <!-- orianna: ok -- sibling plan in in-progress/work, not a strawberry-agents implementation path --> covers those.
- Flipping `AUTH_LEGACY_COOKIE_ALLOWED` to `False` — Loop 2d or later (post-2-week soak).
- Schema migration of existing Firestore docs to backfill `ownerUid` — claim-on-first-touch is the migration strategy; no backfill script.
- Deploy. Ekko lane once merged. Post-deploy smoke: staging first, then prod per Rule 17.

## Test plan

All tests xfail-first (Rule 12), flipped green once the impl lands. Unit tests go under `mmp/workspace/tools/demo-studio-v3/tests/` <!-- orianna: ok -- cross-repo directory, lives in company-os workspace not strawberry-agents -->; integration tests under `mmp/workspace/tools/demo-studio-v3/tests/integration/` <!-- orianna: ok -- cross-repo directory, lives in company-os workspace not strawberry-agents -->.

### 4.1 Unit — `tests/test_require_user.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/tests/ -->

4 cases covering the dual-stack decode behavior:

1. New-format cookie (`encode_user_cookie({"uid":"u1","email":"a@missmp.tech"})`) → returns `User(uid="u1", email="a@missmp.tech")`.
2. Legacy-format cookie (`create_session_cookie("sess-abc")`) + `AUTH_LEGACY_COOKIE_ALLOWED=True` → returns `User(uid="legacy:sess-abc", email="")`.
3. Legacy-format cookie + `AUTH_LEGACY_COOKIE_ALLOWED=False` (monkeypatch) → raises `HTTPException(401)`.
4. Missing cookie → raises `HTTPException(401)`.

### 4.2 Unit — `tests/test_require_session_owner.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/tests/ -->

6 cases:

1. New user + session.ownerUid == user.uid → returns session dict.
2. New user + session.ownerUid != user.uid → 403.
3. New user + session.ownerUid is None → 403 (no arbitrary claim on `/session/*` routes).
4. Legacy user + cookie-sid == path-sid → returns session dict (dual-stack live).
5. Legacy user + cookie-sid != path-sid → 401 (session mismatch).
6. Session not found in Firestore → 404.

### 4.3 Unit — `tests/test_require_session_or_owner.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/tests/ -->

3 cases:

1. Valid `X-Internal-Secret` header + NO cookie → returns `{"sessionId": path_sid}` (bypass).
2. No internal secret + valid owner cookie → delegates to `require_session_owner` → returns session dict.
3. No internal secret + wrong-user cookie → 403.

### 4.4 Unit — `tests/test_session_ownership.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/tests/ -->

4 cases against a fake Firestore client:

1. `create_session(..., owner_uid="u1", owner_email="a@missmp.tech")` → doc contains `ownerUid="u1"`, `ownerEmail="a@missmp.tech"`.
2. `create_session(...)` without owner kwargs → doc has `ownerUid=None`, `ownerEmail=None` (schema-tolerant).
3. `set_session_owner(sid, "u1", "a@missmp.tech")` on unowned session → returns `True`, doc updated.
4. `set_session_owner(sid, "u2", "b@missmp.tech")` on session already owned by `u1` → returns `False`, doc unchanged.

### 4.5 Integration — `tests/integration/test_auth_dual_stack_decode.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/tests/integration/ -->

FastAPI TestClient against the live app with mocked `verify_id_token`:

1. `POST /auth/login` mints new-cookie; `GET /session/{sid}` with owner uid → 200.
2. `POST /auth/login` with user-B; `GET /session/{sidA}` where sidA owned by user-A → 403.
3. Legacy cookie (minted via the still-present `create_session_cookie`) + `AUTH_LEGACY_COOKIE_ALLOWED=True` → `GET /session/{sid}` with matching sid → 200. Confirms dual-stack actually lives across the HTTP boundary.

### 4.6 Integration — `tests/integration/test_slack_handoff_claim.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/tests/integration/ -->

Covers the claim-on-first-touch at `/auth/session/{sid}?token=...`:

1. Unowned session + unauthenticated user → falls back to legacy cookie mint (303 → `/session/{sid}`).
2. Unowned session + Firebase-authed user → claims ownership, 303 → `/session/{sid}`, and a subsequent `GET /session/{sid}` is 200.
3. Owned-by-user-A session + Firebase-authed user-B → 403 (cannot claim a claimed session).

### 4.7 Route-auth matrix — `tests/test_route_auth_matrix_2c.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/tests/ -->

Parametrized over the §2.4 migrated routes × (no cookie, owner new-cookie, non-owner new-cookie, matching legacy cookie, mismatched legacy cookie, internal secret). Minimum 30 assertions. Proves the migration is uniform and the internal-secret bypass is preserved on exactly `/chat` and `/logs`.

## 5. Risks

| Risk | Mitigation |
|---|---|
| Swapping `require_session` return type from `str` to something else breaks live routes mid-migration. | We **do not** swap `require_session`'s return type. We introduce **new** deps (`require_user`, `require_session_owner`, `require_session_or_owner`) and re-wire routes to them. The old `require_session` stays callable and typed-as-before until Loop 2d. |
| Legacy synthetic User (`uid="legacy:{sid}", email=""`) leaks into audit logs or Firestore writes where a real email is expected. | `_is_legacy_user(user)` helper plus centralized guard in `require_session_owner`. `email=""` is never passed to `create_session`'s `owner_email` kwarg by a real handler — only `POST /session/new` writes owner fields, and it requires a non-legacy user (guard test T.1-bonus). |
| Claim-on-first-touch has a TOCTOU window between read of `ownerUid` and write. | `set_session_owner` uses a Firestore transaction (pattern identical to `transition_session_status` in `session_store.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->). Transaction body checks `ownerUid is None` and bails otherwise. |
| `require_session_or_owner` changes the return shape from `str` to dict for `/chat` and `/logs` internal-bypass callers. | We shape the bypass return as `{"sessionId": sid}` so handlers access `sess["sessionId"]` uniformly. Migration tasks update both call sites explicitly (T.M.6, T.M.9). |
| Existing tests that patch `auth.require_session` globally (e.g. for `/stream`) silently no-op after we point routes at `require_session_owner`. | T.TEST.1 audits `grep -n "require_session" tests/` and fixes patches before dep swaps; new helper `_require_session_for_stream` wrapper pattern carries into an owner variant to preserve the SSE test path. |
| `AUTH_LEGACY_COOKIE_ALLOWED=False` path isn't exercised in prod during 2c soak, so Loop 2d flip could surprise us. | Unit tests force-flip the flag (T.1 case 3). Staging smoke (out of scope but called out): Ekko can temp-flip for a 1-hour canary before Loop 2d. Non-blocking for 2c. |

## 6. Open questions

1. **Q1 (flagged by Duong in task prompt) — What happens at `/auth/session/{sid}?token=...` for an unauthenticated Slack visitor?**
   - Option A (this plan's default): preserve 2c-era behavior — if no Firebase cookie, fall back to minting a legacy `{sid}` cookie (existing `create_session_cookie`). Slack links continue to work for not-yet-signed-in users. Defer removal to Loop 2d.
   - Option B: redirect to `/auth/login?next=<encoded>` per parent ADR §5 (the eventual steady state). This requires a frontend login page that reads `?next=` — that's Loop 2b's territory, and it's plausibly already there when 2c executes. If so, we'd prefer Option B.
   - **Recommendation:** gate on whether Loop 2b delivered the `?next=` redirect flow. If yes, use Option B in 2c. If no, use Option A in 2c and do the swap as the first ticket in Loop 2d.
   - **Decision (Duong, 2026-04-22):** Use **Option A** for Loop 2c — preserve the legacy cookie mint fallback at `/auth/session/{sid}?token=...` for unauthenticated Slack visitors. Redirect to `/auth/login?next=...` (Option B) is deferred to Loop 2d once Loop 2b's `?next=` flow is confirmed shipped and stable.

2. **Q2 — Should `require_session_or_internal` migrate to an owner-aware variant in 2c, or stay as-is?**
   - Current call sites: `/session/{sid}/chat`, `/session/{sid}/logs`. The plan introduces `require_session_or_owner` to cover these, with internal bypass preserved. `require_session_or_internal` itself is left in place for any other callers (grep confirms only those two routes use it — if grep ends up clean, we delete it in Loop 2d alongside `require_session`).
   - **Recommendation:** keep `require_session_or_internal` as-is for 2c (additive-only discipline); switch the two call sites to `require_session_or_owner`.
   - **Decision owed to:** captured here; no blocker.

3. **Q3 — Does `/session/{sid}/preview` currently have any auth at all?**
   - The route appears at `main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ --> line 1948 but the grep did not show a `Depends`. Precondition task T.PREC.1 resolves this. If currently public, migration to `require_session_owner` is a security tightening and should be called out in the PR body (potential UX change for any Slack preview embed).
   - **Decision owed to:** resolved by T.PREC.1 read, no human input needed — but if it tightens behavior, flag to Duong in the PR.

4. **Q4 — Do we need a Firestore composite index change for `ownerUid`?**
   - Not for ownership checks (we read by document id) — only if a future `/sessions?owner={uid}` listing lands. Out of scope here; leave un-indexed for now. Noted so Loop 2b/dashboard doesn't assume a query path exists.

## Tasks

### Precondition — audit

- [ ] **T.PREC.1** — Grep `main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ --> for every `@app.(get|post|put|delete)` whose path contains `/session/{session_id}` and record current `Depends(...)` expression. Update §2.4 table in-place on the plan file if any row differs from observed. owner: azir-or-aphelios. estimate_minutes: 15. Files: `plans/proposed/work/2026-04-22-firebase-auth-loop2c-route-migration.md` (this file). DoD: §2.4 table reflects actual main.py state; any newly-discovered route missing from the table is appended with an explicit decision (migrate vs leave).

### Tests first (Rule 12 — xfail-then-impl)

- [ ] **T.T.1** — Write xfail `tests/test_require_user.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/tests/ --> with the 4 §4.1 cases. owner: soraka. estimate_minutes: 15. Files: `mmp/workspace/tools/demo-studio-v3/tests/test_require_user.py`. DoD: `pytest tests/test_require_user.py -q` reports 4 xfailed, 0 xpassed.
- [ ] **T.T.2** — Write xfail `tests/test_require_session_owner.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/tests/ --> with the 6 §4.2 cases using a fake `get_session`. owner: soraka. estimate_minutes: 20. Files: `mmp/workspace/tools/demo-studio-v3/tests/test_require_session_owner.py`. DoD: 6 xfailed, 0 xpassed.
- [ ] **T.T.3** — Write xfail `tests/test_require_session_or_owner.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/tests/ --> with the 3 §4.3 cases. owner: soraka. estimate_minutes: 10. Files: `mmp/workspace/tools/demo-studio-v3/tests/test_require_session_or_owner.py`. DoD: 3 xfailed, 0 xpassed.
- [ ] **T.T.4** — Write xfail `tests/test_session_ownership.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/tests/ --> with the 4 §4.4 cases, using `conftest.py` fake Firestore. owner: soraka. estimate_minutes: 15. Files: `mmp/workspace/tools/demo-studio-v3/tests/test_session_ownership.py`. DoD: 4 xfailed, 0 xpassed.
- [ ] **T.T.5** — Write xfail `tests/integration/test_auth_dual_stack_decode.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/tests/integration/ --> with the 3 §4.5 cases. owner: soraka. estimate_minutes: 20. Files: `mmp/workspace/tools/demo-studio-v3/tests/integration/test_auth_dual_stack_decode.py`. DoD: 3 xfailed, 0 xpassed.
- [ ] **T.T.6** — Write xfail `tests/integration/test_slack_handoff_claim.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/tests/integration/ --> with the 3 §4.6 cases (resolving Q1 first — test shapes differ between Option A and Option B). owner: soraka. estimate_minutes: 20. Files: `mmp/workspace/tools/demo-studio-v3/tests/integration/test_slack_handoff_claim.py`. DoD: 3 xfailed, 0 xpassed; PR body cites which Q1 option was chosen.
- [ ] **T.T.7** — Write xfail route-auth matrix `tests/test_route_auth_matrix_2c.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/tests/ --> covering §2.4 × (no cookie, owner, non-owner, legacy matching, legacy mismatched, internal secret). owner: soraka. estimate_minutes: 25. Files: `mmp/workspace/tools/demo-studio-v3/tests/test_route_auth_matrix_2c.py`. DoD: ≥30 xfailed rows, 0 xpassed.

### Implementation — deps and helpers

- [ ] **T.I.1** — Add `require_user` to `auth.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->. Reads cookie, tries `decode_user_cookie` first, then `verify_session_cookie` if `AUTH_LEGACY_COOKIE_ALLOWED`. Returns `User` (imported from `firebase_auth.py`). No path-param logic here. Adds `_is_legacy_user(user)` helper. owner: jayce. estimate_minutes: 20. Files: `mmp/workspace/tools/demo-studio-v3/auth.py`. DoD: T.T.1 xfails flip green; existing tests unaffected.
- [ ] **T.I.2** — Add `require_session_owner` to `auth.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->. Owner check as per §2.1 spec; returns the session dict; legacy branch gated on `_is_legacy_user`. owner: jayce. estimate_minutes: 20. Files: `mmp/workspace/tools/demo-studio-v3/auth.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->. DoD: T.T.2 xfails flip green.
- [ ] **T.I.3** — Add `require_session_or_owner` to `auth.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->. Internal-secret bypass returns `{"sessionId": path_sid}`; otherwise delegates to `require_session_owner`. owner: jayce. estimate_minutes: 10. Files: `mmp/workspace/tools/demo-studio-v3/auth.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->. DoD: T.T.3 xfails flip green.
- [ ] **T.I.4** — Add `owner_uid` + `owner_email` kwargs to `session_store.create_session`; persist as `ownerUid`/`ownerEmail` fields. owner: seraphine. estimate_minutes: 15. Files: `mmp/workspace/tools/demo-studio-v3/session_store.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->. DoD: T.T.4 cases 1-2 flip green; no regression in existing `test_conversation_store.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/tests/ --> / session-related tests.
- [ ] **T.I.5** — Add `session_store.set_session_owner(sid, uid, email) -> bool` transactional helper (pattern: `transition_session_status`). owner: seraphine. estimate_minutes: 15. Files: `mmp/workspace/tools/demo-studio-v3/session_store.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->. DoD: T.T.4 cases 3-4 flip green.
- [ ] **T.I.6** — Add `session.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ --> re-export of `get_session`/`set_session_owner` if `auth.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ --> needs them (avoids circular import w/ lazy `_get_db`). Verify import order. owner: seraphine. estimate_minutes: 10. Files: `mmp/workspace/tools/demo-studio-v3/session.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->. DoD: no import error on `python -c "import auth"`.

### Implementation — route migrations (§2.4)

For each task below: the dep swap is mechanical. Handlers that currently read `sid: str = Depends(require_session)` become either `sess: dict = Depends(require_session_owner)` with `sid = sess.get("sessionId")` at the top, OR keep the `sid` name and extract from the dep. Pick one style per PR; stay consistent.

- [ ] **T.M.1** — Migrate `POST /session/new` (`main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ --> line 1645) from `require_session` → `require_user`. Call `create_session(..., owner_uid=user.uid, owner_email=user.email)`. Reject legacy users at this call site (`if _is_legacy_user(user): raise HTTPException(400, "sign in to create a session")`). owner: jayce. estimate_minutes: 15. Files: `mmp/workspace/tools/demo-studio-v3/main.py`. DoD: T.T.7 matrix rows for `/session/new` green.
- [ ] **T.M.2** — Migrate `GET /session/{sid}` (1904). owner: jayce. estimate_minutes: 5. Files: `main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->. DoD: matrix rows green.
- [ ] **T.M.3** — Migrate `GET /session/{sid}/preview` (1948) — depends on T.PREC.1 outcome. owner: jayce. estimate_minutes: 10. Files: `main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->. DoD: matrix rows green; if tightening behavior, note in PR body.
- [ ] **T.M.4** — Migrate `POST /session/{sid}/chat` (1972) from `require_session_or_internal` → `require_session_or_owner`. Extract `sid = sess["sessionId"]`. Preserve `X-Internal-Secret` bypass. owner: jayce. estimate_minutes: 15. Files: `main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->. DoD: matrix rows green; internal-secret path asserted in matrix.
- [ ] **T.M.5** — Migrate `GET /session/{sid}/status` (2088). owner: jayce. estimate_minutes: 5. Files: `main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->. DoD: matrix rows green.
- [ ] **T.M.6** — Migrate `POST /session/{sid}/build` (2129). owner: jayce. estimate_minutes: 5. Files: `main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->. DoD: matrix rows green.
- [ ] **T.M.7** — Migrate `GET /session/{sid}/logs` (2213) from `require_session_or_internal` → `require_session_or_owner`. owner: jayce. estimate_minutes: 10. Files: `main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->. DoD: matrix rows green; SSE still streams.
- [ ] **T.M.8** — Migrate `GET /session/{sid}/events` (2404) + `/messages` (2435) + `/history` (2713). owner: jayce. estimate_minutes: 10. Files: `main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->. DoD: matrix rows green.
- [ ] **T.M.9** — Migrate `GET /session/{sid}/stream` (2472) via its `_require_session_for_stream` wrapper. Add a parallel `_require_session_owner_for_stream` wrapper to preserve the test-patchable hook shape (see Risk row 5). owner: jayce. estimate_minutes: 20. Files: `main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->. DoD: matrix rows green; existing SSE tests still pass.
- [ ] **T.M.10** — Migrate `GET /auth/session/{sid}` (1869) per the Q1 decision. Path A: keep legacy mint fallback, add claim-on-first-touch when Firebase cookie is present. Path B: redirect unauth to `/auth/login?next=...`, plus claim-on-first-touch. owner: jayce. estimate_minutes: 20. Files: `main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->. DoD: T.T.6 xfails flip green; Q1 decision recorded in PR body.
- [ ] **T.M.11** — Migrate `POST /session/{sid}/cancel-build` (2859) + `/reauth` (2911) + `/complete` (2933) + `/close` (2955). owner: jayce. estimate_minutes: 15. Files: `main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ -->. DoD: matrix rows green.

### Verification — flip xfails green + regression

- [ ] **T.V.1** — Flip all xfails from T.T.1–T.T.7 to strict-pass. owner: soraka. estimate_minutes: 10. Files: all test files listed in §4. DoD: `pytest tools/demo-studio-v3/tests -q` shows 0 xfailed, 0 xpassed, new tests all green.
- [ ] **T.V.2** — Run the existing demo-studio-v3 test suite; investigate and fix any regression that the dep swap introduced (mock scopes, test fixtures patching `require_session`, etc.). owner: soraka + jayce. estimate_minutes: 30. Files: `mmp/workspace/tools/demo-studio-v3/tests/**` <!-- orianna: ok -- cross-repo directory glob, lives in company-os workspace not strawberry-agents -->. DoD: full suite green on `feat/demo-studio-v3` <!-- orianna: ok -- git branch name in company-os repo, not a local path -->.
- [ ] **T.V.3** — Manual Playwright smoke on local: sign in as user-A → create session → open it (200); sign out + sign in as user-B → open user-A's session URL (403). owner: akali or sona. estimate_minutes: 15. Files: (runtime-only); screenshots to `assessments/qa-reports/` <!-- orianna: ok -- local strawberry-agents path, runtime QA output dir -->. DoD: screenshots attached to PR; both assertions hold.

### Review + merge

- [ ] **T.R.1** — Senna/Lucian review the PR per Rule 18 (author ≠ reviewer). owner: senna-or-lucian. estimate_minutes: 30. Files: GitHub PR. DoD: one approving review on non-author account; no red required checks.
- [ ] **T.R.2** — Merge PR via normal `gh pr merge` (NOT `--admin`). owner: reviewer. estimate_minutes: 5. Files: GitHub PR. DoD: PR merged; `feat/demo-studio-v3` <!-- orianna: ok -- git branch name in company-os repo, not a local path --> contains the 2c diff.

## Architecture impact

- `auth.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ --> — additive: `require_user`, `require_session_owner`, `require_session_or_owner`, `_is_legacy_user`. Existing `require_session` / `require_session_or_internal` untouched (removed in 2d).
- `session_store.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ --> — `create_session` gains two optional kwargs (backward compatible); new `set_session_owner` helper.
- `session.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ --> — possibly one re-export to keep import graph clean.
- `main.py` <!-- orianna: ok -- cross-repo/service token, file lives in company-os/tools/demo-studio-v3/ --> — dep swap on ~13 routes; `auth_exchange` gains claim-on-first-touch; `/session/new` stamps owner at create.
- Firestore schema — new optional `ownerUid` + `ownerEmail` fields on `demo-studio-sessions` <!-- orianna: ok -- cross-repo/service token, Firestore collection name in company-os/tools/demo-studio-v3/ --> docs. Backwards compatible (unset on pre-2c docs; claim-on-first-touch backfills on first owner visit via Slack link).
- Tests — 7 new test files (~50 new assertions including the matrix).
- No new dependencies, no new env vars, no new secrets, no deploy changes.

## Loop context

Third loop in the Firebase auth rollout. Normal-tier: additive deps, flag-gated dual-stack, no rewrite. Respects the approved parent ADR's W2+W3 waves while staying additive-with-flag — legacy code paths are untouched until Loop 2d. Safe to ship mid-rollout because the migration is a dep swap per route, each swap has matrix coverage, and the legacy cookie path is still a valid fallback for any browser session that hasn't yet moved to the Firebase cookie.

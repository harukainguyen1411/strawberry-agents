---
status: approved
complexity: quick
concern: work
owner: karma
created: 2026-04-22
tags:
  - demo-studio
  - auth
  - firebase
  - frontend
  - work
tests_required: true
---

# Loop 2b — Firebase auth frontend sign-in UI

<!-- orianna: ok -- all file-path tokens in this plan (static/index.html, static/auth.js, static/studio.css, static/studio.js, tests/e2e/*, tools/demo-studio-v3/*) reference files inside the missmp/company-os work workspace under company-os/tools/demo-studio-v3/, not strawberry-agents -->
<!-- orianna: ok -- HTTP path tokens (/auth/config, /auth/login, /auth/logout, /auth/me, /, /dashboard) are route paths on the demo-studio Cloud Run service, not filesystem paths -->
<!-- orianna: ok -- env-var tokens (FIREBASE_PROJECT_ID, FIREBASE_WEB_API_KEY, FIREBASE_AUTH_DOMAIN) are environment variables, not filesystem paths -->
<!-- orianna: ok -- external tokens (firebase/app, firebase/auth, gstatic.com, googleapis.com, signInWithPopup, GoogleAuthProvider, onAuthStateChanged, getIdToken) are Firebase JS SDK refs, not files -->
<!-- orianna: ok -- cookie token (ds_session) is an HTTP cookie name, not filesystem -->
<!-- orianna: ok -- git branch token (feat/demo-studio-v3) is a git branch ref, not a filesystem path -->

## 1. Context

Loop 2a of the Firebase auth rollout landed the server backbone: `/auth/config`, `/auth/login`, `/auth/logout`, `/auth/me` are live on the feat-demo-studio-v3 branch (commits `c59e2d6`→`b2adf20`, 15/15 unit tests green, QA report at `assessments/qa-reports/2026-04-22-loop2a-firebase-auth-w1-server-backbone.md`). The server will verify a Firebase ID token, set a `ds_session` cookie with `{uid, email, iat}`, and answer `/auth/me` with the claims. The browser has no way to drive that flow today — the landing page `mmp/workspace/tools/demo-studio-v3/static/index.html` <!-- orianna: ok -- file lives in work workspace company-os/tools/demo-studio-v3/ --> is the 41-line legacy landing page with no auth surface.

Loop 2b delivers wave W4 of the parent ADR (`plans/approved/work/2026-04-22-firebase-auth-for-demo-studio.md` §6, §Tasks W4). Narrow slice: add Firebase Web SDK, Google sign-in button, sign-out button, and email chrome to the landing page. Nothing else.

Explicitly deferred: route migration to `require_session_owner` (Loop 2c), Slack scaffolding removal (Loop 2d), `/auth/session/{sid}?token=` redirect handling (Loop 2c, paired with W5).

## 2. Decision

Deliver W4.1–W4.6 of the parent ADR on the feat-demo-studio-v3 branch, scoped to the landing page only:

1. **Firebase Web SDK via CDN ES modules** — import the firebase-app and firebase-auth modules from the gstatic.com Firebase CDN (e.g. `https://www.gstatic.com/firebasejs/11.0.2/firebase-app.js` + `firebase-auth.js`). <!-- orianna: ok -- external CDN URL, not a filesystem path --> No npm, no bundler. Justification: demo-studio-v3 ships no JS build pipeline today; the rest of static assets are hand-written ES modules. Adding rollup/vite for three SDK imports is ceremony. CDN module imports are the idiomatic Firebase Web v9+ path when there is no bundler, and they keep the static dir asset-only which matches the existing deploy contract (FastAPI StaticFiles). Pin to the current stable Firebase JS SDK version (11.0.2 as of 2026-04).

2. **New file `mmp/workspace/tools/demo-studio-v3/static/auth.js`** (~80 lines, ES module) — exports: <!-- orianna: ok -- prospective path, created by this plan -->
   - `initFirebase()` — GET `/auth/config`, `initializeApp(cfg)`, `getAuth()`. Returns the auth instance. Cached on module scope.
   - `signInWithGoogle()` — `signInWithPopup(auth, new GoogleAuthProvider())` → `user.getIdToken()` → POST `/auth/login` with `{idToken}` (credentials: 'include') → on 204 resolve, else throw with status + detail.
   - `signOutUser()` — POST `/auth/logout` (credentials: 'include') then `signOut(auth)`.
   - `getCurrentUser()` — GET `/auth/me` (credentials: 'include'); 200 → `{uid,email}`; 401 → `null`.
   - `onAuthReady(cb)` — wires `onAuthStateChanged` plus an initial `/auth/me` probe; invokes `cb(user|null)` each time state changes.

3. **Modify `mmp/workspace/tools/demo-studio-v3/static/index.html`** <!-- orianna: ok -- file lives in work workspace company-os/tools/demo-studio-v3/ --> — add a module script that:
   - Calls `initFirebase()` on DOMContentLoaded.
   - Renders two states in a single `<div id="auth-chrome">`:
     - **Signed out**: `<button id="signin-btn">Sign in with Google</button>`.
     - **Signed in**: `<span id="user-email"></span> <button id="signout-btn">Sign out</button>`.
   - `signin-btn` click → `signInWithGoogle()` → on success `window.location.reload()` (server cookie is now set; next paint shows signed-in chrome).
   - `signout-btn` click → `signOutUser()` → `window.location.reload()`.
   - `onAuthReady` toggles which chrome block is visible and fills `#user-email`.

4. **Minimal CSS in `mmp/workspace/tools/demo-studio-v3/static/studio.css`** <!-- orianna: ok -- file lives in work workspace company-os/tools/demo-studio-v3/ --> — ~30 lines covering button styling (Google brand blue acceptable, no logo image required this loop), header layout, and visibility toggles (`.hidden { display: none; }`).

5. **No changes to `mmp/workspace/tools/demo-studio-v3/static/studio.js`** <!-- orianna: ok -- file lives in work workspace company-os/tools/demo-studio-v3/ --> — the `fetchWithAuth` migration across existing `/session/*` XHR calls is Loop 2c territory (it couples with the `require_session_owner` cutover). Keeping this loop to the landing page.

6. **Config source of truth** — `/auth/config` at boot. No hardcoded API key in the landing HTML. If `/auth/config` returns a body with `projectId: null` (server env unset), `initFirebase()` throws a visible banner "Auth not configured" and leaves the page in a degraded-but-functional state (legacy session-id form still visible for the legacy cookie path, which is still live per Loop 2a's non-migration).

### Failure modes

| Condition | Behavior |
|---|---|
| `/auth/config` 5xx or missing keys | Banner "Auth not configured"; sign-in button disabled. |
| `signInWithPopup` popup-blocked / closed-by-user | Inline error under button: "Sign-in cancelled". No reload. |
| `signInWithPopup` succeeds, `/auth/login` returns 403 (wrong domain) | Inline error: "Only @missmp.tech accounts are allowed". Call `signOut(auth)` to clear the client-side Firebase state. |
| `/auth/login` returns 401 (bad token) | Inline error: "Sign-in failed, please retry". `signOut(auth)`. |
| `/auth/me` returns 401 at boot | Render signed-out chrome. Normal. |

## 3. Scope

**In scope:**
- New `mmp/workspace/tools/demo-studio-v3/static/auth.js`. <!-- orianna: ok -- prospective path, created by this plan -->
- Edits to `mmp/workspace/tools/demo-studio-v3/static/index.html` and `mmp/workspace/tools/demo-studio-v3/static/studio.css`. <!-- orianna: ok -- files live in work workspace company-os/tools/demo-studio-v3/ -->
- Playwright E2E xfail-first covering sign-in happy path, wrong-domain rejection, sign-out, and boot-state chrome.

**Out of scope:**
- `mmp/workspace/tools/demo-studio-v3/static/studio.js` migration to `fetchWithAuth` (Loop 2c). <!-- orianna: ok -- file lives in work workspace company-os/tools/demo-studio-v3/ -->
- `require_session_owner` cutover on `/session/{sid}/*` (Loop 2c).
- `/auth/session/{sid}?token=` redirect-to-login (Loop 2c, paired with W5).
- Slack scaffolding removal (Loop 2d).
- Deploy: Ekko lane after Loop 2c merges.

## Test plan

Rule 12: xfail tests committed first on the feat-demo-studio-v3 branch, then flipped green once impl lands. Playwright is the natural fit — this is pure browser behavior against the running server.

Test files (all new under `mmp/workspace/tools/demo-studio-v3/tests/e2e/`): <!-- orianna: ok -- prospective directory, created by this plan -->

- `mmp/workspace/tools/demo-studio-v3/tests/e2e/test_frontend_signin_chrome.spec.ts` <!-- orianna: ok -- prospective path, created by this plan --> — 3 cases:
  (a) boot with no cookie → `#signin-btn` visible, `#signout-btn` hidden, `#user-email` empty.
  (b) boot with valid `ds_session` cookie (seeded via direct server login in a setup hook using a Firebase emulator ID token) → `#signout-btn` visible, `#user-email` contains `@missmp.tech`, `#signin-btn` hidden.
  (c) `/auth/config` stub returning `{projectId: null}` → banner "Auth not configured" visible, `#signin-btn` disabled.

- `mmp/workspace/tools/demo-studio-v3/tests/e2e/test_frontend_signin_flow.spec.ts` <!-- orianna: ok -- prospective path, created by this plan --> — 2 cases:
  (a) happy-path sign-in with Firebase Auth Emulator `@missmp.tech` user → popup resolves → page reloads → signed-in chrome rendered; `/auth/me` returns 200 with that email.
  (b) sign-out from signed-in state → `ds_session` cookie cleared (assert via the browser document.cookie API or a `/auth/me` probe returning 401) → signed-out chrome rendered.

- `mmp/workspace/tools/demo-studio-v3/tests/e2e/test_frontend_signin_reject.spec.ts` <!-- orianna: ok -- prospective path, created by this plan --> — 1 case:
  (a) sign-in with emulator `@gmail.com` user → `/auth/login` returns 403 → inline error "Only @missmp.tech accounts are allowed" visible, chrome stays signed-out, no reload.

Invariants protected:
- Config is never hardcoded (test a: degraded state when `/auth/config` is broken).
- Server-domain allowlist is user-visible, not silent (reject test).
- Sign-out clears both server cookie and client Firebase state (sign-out test).
- `/auth/me` drives chrome — reload correctness (happy path + boot-with-cookie test).

Firebase Auth Emulator (`FIREBASE_AUTH_EMULATOR_HOST=localhost:9099`) is the honest mock for Playwright; avoids real Google OAuth in CI. README update in T.9 keeps the local-dev path documented.

## 4. Risks

- **Firebase SDK version drift** — pinning to version 11.0.2 in the CDN URL prevents silent upgrades. Add a comment in the landing HTML naming the pin and review cadence.
- **Popup blockers** — `signInWithPopup` requires a user-gesture stack. Binding directly to the button `click` is fine; avoid async work between click and popup call. If popup UX becomes an issue, `signInWithRedirect` is a one-line swap — not doing it now since redirect breaks Playwright flow hooks.
- **CORS on `/auth/login`** — same-origin this loop (landing page and API are same Cloud Run service). If dashboard split lands (`plans/in-progress/work/2026-04-22-demo-dashboard-service-split.md` <!-- orianna: ok -- cross-plan reference, plan has since moved to in-progress -->) this will need CORS credentials config — not this loop's problem.
- **Emulator dependency in CI** — Playwright suite requires the emulator running. Akali's existing E2E harness for demo-studio-v3 already spawns it for Loop 2a smokes per the QA report; confirm at test time, add a `beforeAll` guard if not.
- **Legacy session form still visible** — the page still exposes the pre-Firebase session-id input. Loop 2a did not gate it. Leaving it visible; Loop 2c will gate it behind login-state. Not a regression, just incomplete.

## Tasks

- [ ] **T.1** — Write xfail `mmp/workspace/tools/demo-studio-v3/tests/e2e/test_frontend_signin_chrome.spec.ts` covering the 3 boot-state cases in the Test plan. owner: karma. estimate_minutes: 20. Files: `mmp/workspace/tools/demo-studio-v3/tests/e2e/test_frontend_signin_chrome.spec.ts` (new). <!-- orianna: ok -- prospective path, created by this plan --> DoD: `playwright test test_frontend_signin_chrome` reports 3 expected failures, 0 unexpected passes.
- [ ] **T.2** — Write xfail `mmp/workspace/tools/demo-studio-v3/tests/e2e/test_frontend_signin_flow.spec.ts` covering happy-path sign-in and sign-out against the Firebase Auth Emulator. owner: karma. estimate_minutes: 25. Files: `mmp/workspace/tools/demo-studio-v3/tests/e2e/test_frontend_signin_flow.spec.ts` (new). <!-- orianna: ok -- prospective path, created by this plan --> DoD: 2 xfails committed; emulator setup hook documented in the spec header.
- [ ] **T.3** — Write xfail `mmp/workspace/tools/demo-studio-v3/tests/e2e/test_frontend_signin_reject.spec.ts` covering the @gmail.com domain-rejection path. owner: karma. estimate_minutes: 15. Files: `mmp/workspace/tools/demo-studio-v3/tests/e2e/test_frontend_signin_reject.spec.ts` (new). <!-- orianna: ok -- prospective path, created by this plan --> DoD: 1 xfail committed.
- [ ] **T.4** — Create `mmp/workspace/tools/demo-studio-v3/static/auth.js` ES module with `initFirebase`, `signInWithGoogle`, `signOutUser`, `getCurrentUser`, `onAuthReady` per Decision item 2. Import Firebase SDK from gstatic CDN pinned to 11.0.2. owner: karma. estimate_minutes: 25. Files: `mmp/workspace/tools/demo-studio-v3/static/auth.js` (new). <!-- orianna: ok -- prospective path, created by this plan --> DoD: module parses as ES module; each export callable; `fetch` calls use `credentials: 'include'`.
- [ ] **T.5** — Modify `mmp/workspace/tools/demo-studio-v3/static/index.html` to add the `<div id="auth-chrome">` signed-in / signed-out blocks, the sign-in / sign-out buttons, and a module `<script>` wiring them to auth.js. Preserve the existing legacy session-id form untouched. owner: karma. estimate_minutes: 20. Files: `mmp/workspace/tools/demo-studio-v3/static/index.html`. <!-- orianna: ok -- file lives in work workspace company-os/tools/demo-studio-v3/, not strawberry-agents --> DoD: T.1 chrome xfails flip green; page renders without console errors in signed-out state.
- [ ] **T.6** — Add ~30 lines of button/header/visibility CSS to `mmp/workspace/tools/demo-studio-v3/static/studio.css`. owner: karma. estimate_minutes: 10. Files: `mmp/workspace/tools/demo-studio-v3/static/studio.css`. <!-- orianna: ok -- file lives in work workspace company-os/tools/demo-studio-v3/, not strawberry-agents --> DoD: no layout regression on existing session view; `.hidden` class works; sign-in button reads as a real button (padding, cursor, hover).
- [ ] **T.7** — Wire inline error surface for `/auth/login` 401/403 and popup-closed cases into auth.js + a `<div id="auth-error">` slot in the landing HTML. owner: karma. estimate_minutes: 15. Files: `mmp/workspace/tools/demo-studio-v3/static/auth.js`, `mmp/workspace/tools/demo-studio-v3/static/index.html`. <!-- orianna: ok -- files live in work workspace company-os/tools/demo-studio-v3/, not strawberry-agents --> DoD: T.3 reject xfail flips green.
- [ ] **T.8** — Flip T.2 flow xfails green once T.4–T.7 land (no code change — just remove xfail markers and verify emulator run). owner: karma. estimate_minutes: 10. Files: `mmp/workspace/tools/demo-studio-v3/tests/e2e/test_frontend_signin_flow.spec.ts`. <!-- orianna: ok -- prospective path, created by this plan --> DoD: full Playwright suite green locally against emulator + running server.
- [ ] **T.9** — Append a "Firebase Auth local dev" section to `mmp/workspace/tools/demo-studio-v3/README.md` (`FIREBASE_AUTH_EMULATOR_HOST=localhost:9099`, Playwright how-to, SDK pin note). owner: karma. estimate_minutes: 10. Files: `mmp/workspace/tools/demo-studio-v3/README.md`. <!-- orianna: ok -- file lives in work workspace company-os/tools/demo-studio-v3/, not strawberry-agents --> DoD: README builds no broken links; new contributor can follow it to drive the sign-in UI locally.

## Architecture impact

- `mmp/workspace/tools/demo-studio-v3/static/auth.js` <!-- orianna: ok -- prospective path, created by this plan --> — new ES module, ~80 lines.
- `mmp/workspace/tools/demo-studio-v3/static/index.html` <!-- orianna: ok -- file lives in work workspace company-os/tools/demo-studio-v3/, not strawberry-agents --> — 41 → ~80 lines; auth chrome block + module script.
- `mmp/workspace/tools/demo-studio-v3/static/studio.css` <!-- orianna: ok -- file lives in work workspace company-os/tools/demo-studio-v3/, not strawberry-agents --> — ~30 lines added.
- `mmp/workspace/tools/demo-studio-v3/tests/e2e/` <!-- orianna: ok -- prospective path, created by this plan --> — 3 new Playwright spec files, 6 tests total.
- `mmp/workspace/tools/demo-studio-v3/README.md` <!-- orianna: ok -- file lives in work workspace company-os/tools/demo-studio-v3/, not strawberry-agents --> — new local-dev section.

No server code changes. No new Python deps. No deploy this loop — merging to the feat-demo-studio-v3 branch keeps it landed for Loop 2c, where the route cutover plus a single prod deploy covers the end-to-end cutover.

## Loop context

Third loop of the Firebase cutover cadence (2a server backbone done, 2b frontend, 2c route migration, 2d Slack retirement). Quick-lane sized on purpose — additive frontend only, no schema changes, no invariant shifts. Server contract (Loop 2a) and Playwright emulator harness (existing) are both already in place.

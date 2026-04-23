---
plan: plans/proposed/work/2026-04-22-firebase-auth-loop2a-server-backbone.md
checked_at: 2026-04-22T11:22:12Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 1
info_findings: 14
external_calls_used: 0
---

## Block findings

None.

## Warn findings

1. **Step B — Gating marker:** unresolved `TBD` in `## Test plan` (line 86: "raises `DomainNotAllowedError` / `InvalidTokenError` (TBD inside impl)") | **Severity:** warn — marker is outside an explicit gating section (`## Open questions` / `## Gating questions` / `## Unresolved`), so it does not block promotion.

## Info findings

1. **Step A — Frontmatter:** `owner: sona` present. Pass.
2. **Step C — Claim:** `plans/approved/work/2026-04-22-firebase-auth-for-demo-studio.md` (line 27) | **Severity:** info (author-suppressed via `<!-- orianna: ok -->`).
3. **Step C — Claim:** `roles/firebase.sdkAdminServiceAgent` (line 29) | **Severity:** info (author-suppressed).
4. **Step C — Claim:** `feat/demo-studio-v3` (line 45) | **Severity:** info (author-suppressed).
5. **Step C — Claim:** `requirements.txt`, `firebase-admin>=6.5.0` (line 47) | **Severity:** info (author-suppressed; covers Step E too).
6. **Step C — Claim:** `firebase_auth.py`, `verify_firebase_token(...)`, `User` (line 48) | **Severity:** info (author-suppressed).
7. **Step C — Claim:** `auth.py` and helpers (line 51) | **Severity:** info (author-suppressed).
8. **Step C — Claim:** `main.py` (line 54) | **Severity:** info (author-suppressed).
9. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/tests/test_firebase_auth.py` (line 84) | **Severity:** info (author-suppressed; also C2b non-internal-prefix — no filesystem check performed).
10. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/tests/test_auth_routes.py` (line 88) | **Severity:** info (author-suppressed; C2b).
11. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/tests/test_auth_cookie_encode.py` (line 92) | **Severity:** info (author-suppressed; C2b).
12. **Step C — Claim:** `identitytoolkit.googleapis.com` (line 101) | **Severity:** info (author-suppressed).
13. **Step C — Claim:** Task-block file references lines 116–123 (all `mmp/workspace/tools/demo-studio-v3/...` paths plus `assessments/qa-reports` on line 123) | **Severity:** info (every task line carries `<!-- orianna: ok -->` — all tokens on each line suppressed).
14. **Step C — Claim:** Architecture-impact file references lines 127–131 (`requirements.txt`, `firebase_auth.py`, `auth.py`, `main.py`) | **Severity:** info (all author-suppressed).
15. **Step D — Sibling-file grep:** no `2026-04-22-firebase-auth-loop2a-server-backbone-tasks.md` or `-tests.md` found under `plans/`. Single-file layout satisfied.

Non-claim / skip log (summary): HTTP route tokens (`POST /auth/login`, `POST /auth/logout`, `GET /auth/me`, `GET /auth/config`, `/auth/session/{sid}`), template/brace expressions (`{idToken}`, `{uid, email, iat}`, `{projectId, apiKey, authDomain}`), dotted/snake_case identifiers (`verify_id_token`, `firebase_admin.auth.verify_id_token`, `require_session`, `require_session_owner`, `ds_session`, `encode_user_cookie`, `decode_user_cookie`, `InvalidTokenError`, `DomainNotAllowedError`, `AUTH_LEGACY_COOKIE_ALLOWED`, `slack_user_id`, `slack_channel`, `slack_thread_ts`), env var names (`FIREBASE_PROJECT_ID`, `ALLOWED_EMAIL_DOMAIN`, `SESSION_SECRET`, `GOOGLE_APPLICATION_CREDENTIALS`), and the SA principal `266692422014-compute@developer.gserviceaccount.com`, and the `sha256:...` hash — all §2 non-claim categories, not extracted for severity.

## External claims

None. Step E was not triggered: the one candidate (`firebase-admin>=6.5.0` with version pin, line 47 and line 119) is covered by same-line author suppression (`<!-- orianna: ok -->`), which per Step E.2 carries over from Step C. Budget unused (0/15).

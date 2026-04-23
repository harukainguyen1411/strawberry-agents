---
plan: plans/proposed/work/2026-04-22-firebase-auth-loop2a-server-backbone.md
checked_at: 2026-04-22T13:14:48Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 1
info_findings: 15
external_calls_used: 0
---

## Block findings

None.

## Warn findings

1. **Step B — Gating marker:** unresolved `TBD` in `## Test plan` (line 87: "raises `DomainNotAllowedError` / `InvalidTokenError` (TBD inside impl)") | **Severity:** warn — marker is outside an explicit gating section (`## Open questions` / `## Gating questions` / `## Unresolved`), so it does not block promotion.

## Info findings

1. **Step A — Frontmatter:** `owner: sona` present. Pass.
2. **Step C — Claim:** `plans/approved/work/2026-04-22-firebase-auth-for-demo-studio.md` (line 28) | **Severity:** info (author-suppressed via `<!-- orianna: ok -->`).
3. **Step C — Claim:** `roles/firebase.sdkAdminServiceAgent` (line 30) | **Severity:** info (author-suppressed; GCP IAM role, not filesystem).
4. **Step C — Claim:** `feat/demo-studio-v3` (line 46) | **Severity:** info (author-suppressed; git branch name).
5. **Step C — Claim:** `requirements.txt`, `firebase-admin>=6.5.0` (line 48) | **Severity:** info (author-suppressed; covers Step E too).
6. **Step C — Claim:** `firebase_auth.py`, `verify_firebase_token(...)`, `User` (line 49) | **Severity:** info (author-suppressed).
7. **Step C — Claim:** `auth.py` and helpers (line 52) | **Severity:** info (author-suppressed).
8. **Step C — Claim:** `main.py` (line 55) | **Severity:** info (author-suppressed).
9. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/tests/test_firebase_auth.py` (line 85) | **Severity:** info (author-suppressed; also C2b non-internal-prefix — no filesystem check performed).
10. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/tests/test_auth_routes.py` (line 89) | **Severity:** info (author-suppressed; C2b).
11. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/tests/test_auth_cookie_encode.py` (line 93) | **Severity:** info (author-suppressed; C2b).
12. **Step C — Claim:** `identitytoolkit.googleapis.com` (line 102) | **Severity:** info (author-suppressed; external domain, not filesystem).
13. **Step C — Claim:** task-block file references lines 117–124 (all `mmp/workspace/tools/demo-studio-v3/...` paths plus `assessments/qa-reports` on line 124) | **Severity:** info (every task line carries `<!-- orianna: ok -->` — all tokens on each line suppressed).
14. **Step C — Claim:** architecture-impact file references lines 128–131 (`requirements.txt`, `firebase_auth.py`, `auth.py`, `main.py`) | **Severity:** info (all author-suppressed).
15. **Step C — Claim:** test-results references lines 136–137 (`harukainguyen1411/strawberry-app`, `feat/demo-studio-v3`, `assessments/qa-reports`) | **Severity:** info (all author-suppressed).
16. **Step D — Sibling-file grep:** no `2026-04-22-firebase-auth-loop2a-server-backbone-tasks.md` or `-tests.md` found under `plans/`. Single-file layout satisfied.

Non-claim / skip log (summary): HTTP route tokens (`POST /auth/login`, `POST /auth/logout`, `GET /auth/me`, `GET /auth/config`, `/auth/session/{sid}`), template/brace expressions (`{idToken}`, `{uid, email, iat}`, `{projectId, apiKey, authDomain}`), dotted/snake_case identifiers (`verify_id_token`, `firebase_admin.auth.verify_id_token`, `require_session`, `require_session_owner`, `ds_session`, `encode_user_cookie`, `decode_user_cookie`, `InvalidTokenError`, `DomainNotAllowedError`, `AUTH_LEGACY_COOKIE_ALLOWED`, `slack_user_id`, `slack_channel`, `slack_thread_ts`), env var names (`FIREBASE_PROJECT_ID`, `ALLOWED_EMAIL_DOMAIN`, `SESSION_SECRET`, `GOOGLE_APPLICATION_CREDENTIALS`, `FIREBASE_WEB_API_KEY`, `FIREBASE_AUTH_DOMAIN`), and the SA principal `266692422014-compute@developer.gserviceaccount.com`, and the `sha256:...` hash — all §2 non-claim categories, not extracted for severity.

## External claims

None. Step E was not triggered: the one candidate (`firebase-admin>=6.5.0` with version pin, line 48 and task T.4) is covered by same-line author suppression (`<!-- orianna: ok -->`), which per Step E.2 carries over from Step C. Budget unused (0/15).

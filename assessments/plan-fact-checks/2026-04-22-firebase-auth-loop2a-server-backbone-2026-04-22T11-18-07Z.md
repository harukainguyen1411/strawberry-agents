---
plan: plans/proposed/work/2026-04-22-firebase-auth-loop2a-server-backbone.md
checked_at: 2026-04-22T11:18:07Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 1
info_findings: 27
external_calls_used: 0
---

## Block findings

None.

## Warn findings

1. **Step B — Gating marker:** `TBD` in `## Test plan` at line 86 ("(TBD inside impl)") | **Severity:** warn (not inside a gating section like `## Open questions`, `## Gating questions`, or `## Unresolved`; flagged for author awareness only).

## Info findings

1. **Step C — Claim:** `plans/approved/work/2026-04-22-firebase-auth-for-demo-studio.md` (line 27) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed; file verified to exist. | **Severity:** info
2. **Step C — Claim:** `roles/firebase.sdkAdminServiceAgent` (line 29) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed (IAM role name, not a filesystem path). | **Severity:** info
3. **Step C — Claim:** `feat/demo-studio-v3` (line 45) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed (git branch ref, C2b). | **Severity:** info
4. **Step C — Claim:** `requirements.txt` (line 47) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed (lives under company-os/tools/demo-studio-v3/ in workspace monorepo). | **Severity:** info
5. **Step C — Claim:** `firebase-admin>=6.5.0` (line 47) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed (PyPI library + version). | **Severity:** info
6. **Step C — Claim:** `firebase_auth.py` (line 48) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed (new module under demo-studio-v3). | **Severity:** info
7. **Step C — Claim:** `auth.py` (line 51) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed (existing module under demo-studio-v3). | **Severity:** info
8. **Step C — Claim:** `main.py` (line 54) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed (existing module under demo-studio-v3). | **Severity:** info
9. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/tests/test_firebase_auth.py` (line 84) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed (test file path in workspace). | **Severity:** info
10. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/tests/test_auth_routes.py` (line 88) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed. | **Severity:** info
11. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/tests/test_auth_cookie_encode.py` (line 92) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed. | **Severity:** info
12. **Step C — Claim:** `identitytoolkit.googleapis.com` (line 101) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed (Google API host). | **Severity:** info
13. **Step C — Claim:** `auth.py` (line 102) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed. | **Severity:** info
14. **Step C — Claim:** `static/index.html` (line 108) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed (workspace demo-studio-v3 frontend asset). | **Severity:** info
15. **Step C — Claim:** `static/auth.js` (line 108) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed. | **Severity:** info
16. **Step C — Claim:** `static/studio.css` (line 108) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed. | **Severity:** info
17. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/tests/test_firebase_auth.py` (line 116, T.1) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed. | **Severity:** info
18. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/tests/test_auth_cookie_encode.py` (line 117, T.2) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed. | **Severity:** info
19. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/tests/test_auth_routes.py` (line 118, T.3) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed. | **Severity:** info
20. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/requirements.txt` (line 119, T.4) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed. | **Severity:** info
21. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/firebase_auth.py` (line 120, T.5) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed. | **Severity:** info
22. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/auth.py` (line 121, T.6) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed. | **Severity:** info
23. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/main.py` (line 122, T.7) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed. | **Severity:** info
24. **Step C — Claim:** `assessments/qa-reports` (line 123, T.8) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed; directory verified to exist in strawberry-agents working tree. | **Severity:** info
25. **Step C — Claim:** `requirements.txt` (line 127) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed. | **Severity:** info
26. **Step C — Claim:** `firebase_auth.py` (line 128) | **Anchor:** line-level `<!-- orianna: ok -->` | **Result:** author-suppressed. | **Severity:** info
27. **Step C — Non-claim skips:** Numerous HTTP route tokens (`POST /auth/login`, `GET /auth/me`, `GET /auth/config`, `POST /auth/logout`, `GET /build/{id}`-style), brace-expression tokens (`{uid, email, iat}`, `{idToken}`, `{projectId, apiKey, authDomain}`), and dotted/snake-case code symbols (`verify_id_token`, `firebase_admin.auth.verify_id_token`, `User`, `ds_session`, `FIREBASE_PROJECT_ID`, `ALLOWED_EMAIL_DOMAIN`, `SESSION_SECRET`, `AUTH_LEGACY_COOKIE_ALLOWED`, `require_session`, `require_session_owner`, `InvalidTokenError`, `DomainNotAllowedError`, `encode_user_cookie`, `decode_user_cookie`, `slack_user_id`, `slack_channel`, `slack_thread_ts`) classified as non-claims per contract §2 and skipped. | **Severity:** info

## External claims

None. (All library/URL references — `firebase-admin>=6.5.0`, `identitytoolkit.googleapis.com`, `http://127.0.0.1:8080/auth/config` — are on author-suppressed lines. No Step E tool calls were made.)

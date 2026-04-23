---
plan: plans/proposed/work/2026-04-22-firebase-auth-for-demo-studio.md
checked_at: 2026-04-22T02:15:40Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 12
warn_findings: 0
info_findings: 4
external_calls_used: 0
---

## Block findings

1. **Step C — Claim cluster (line 39, §2 Decision):** unsuppressed backtick tokens `POST /auth/login`, `firebase-admin.auth.verify_id_token`, `email_verified == True`, `email.lower().endswith("@missmp.tech")`, `ds_session`, `itsdangerous`, `{uid, email, iat}` | **Anchor:** path-shaped tokens (`/auth/...`) routed to `~/Documents/Work/mmp/workspace/` per concern: work; `test -e` fails. Identifier tokens (`ds_session`, `itsdangerous`, `firebase-admin.auth.verify_id_token`) are integration-shaped and not on `agents/orianna/allowlist.md`. | **Result:** block. Add same-line `<!-- orianna: ok -->` (these tokens describe in-flight design, not filesystem paths in this repo). | **Severity:** block

2. **Step C — Claim cluster (line 40, §2 Decision):** unsuppressed `require_session`, `User`, `require_session_owner`, `session.ownerEmail == user.email` | **Anchor:** integration-shaped code identifiers, not on allowlist. | **Result:** block per §4 strict default. Suppress with same-line marker. | **Severity:** block

3. **Step C — Claim cluster (line 41, §2 Decision):** unsuppressed path-shaped tokens `/auth/session/{sid}?token=...`, `/auth/login?next=...` | **Anchor:** routed to workspace root; `test -e ~/Documents/Work/mmp/workspace//auth/session/...` fails. | **Result:** block. These are HTTP route paths, not filesystem — needs same-line suppression. | **Severity:** block

4. **Step C — Fenced code block (lines 47–55, §3.1 Before diagram):** every token inside the fenced ASCII diagram is extracted per contract §6. Includes `/auth/session/{sid}?token`, `S1.auth_exchange`, `verify_and_consume_token`, `set_cookie(ds_session={sid})`, `/session/{sid}`, `require_session`, `decode{sid} == path.sid` | **Anchor:** fenced-code tokens not suppressible by inline marker; path-shaped resolve to workspace and miss; identifier tokens off allowlist. | **Result:** block. Either move the diagram to a non-fenced indented block, or wrap the fence with a preceding `<!-- orianna: ok -->` standalone line (note: standalone-marker suppression covers only the *immediately following line*, so per contract §8 fences are not currently coverable — the cleanest fix is to drop the diagram into prose form or accept the gate failure with a one-time bypass trailer). | **Severity:** block

5. **Step C — Fenced code block (lines 62–81, §3.2 After diagram):** same problem as finding 4 — extensive route + identifier tokens inside ``` ``` block (`identitytoolkit.googleapis.com`, `POST /auth/login`, `firebase-admin verify_id_token()`, `email.endswith("@missmp.tech")`, `set_cookie(ds_session={uid, email, iat})`, `/auth/session/{sid}?token`, `require_session`, `verify_and_consume_token`, `session_store.set_owner(sid, email)`, `/session/{sid}`, `require_session_owner`, `get_session(sid)`, `ownerEmail == email`). | **Anchor:** fenced tokens not currently suppressible per §8 line-scoped rule. | **Result:** block. See finding 4 remediation. | **Severity:** block

6. **Step C — §3.4 Route classification table (lines 92–100):** unsuppressed route tokens `GET /`, `/healthz`, `/health`, `GET /debug`, `/logs`, `verify_internal_secret`, `POST /auth/login`, `GET /auth/config`, `POST /auth/logout`, `GET /auth/me`, `GET /dashboard`, `/api/test-results`, `/api/test-run-history`, `/api/managed-sessions`, `require_user`, `GET /auth/session/{sid}`, `/auth/login?next=...`, `POST /session`, `/session/new`, `GET/POST /session/{sid}/*`, `require_session_owner`, `POST /session/{sid}/chat`, `X-Internal-Secret` | **Anchor:** path-shaped tokens routed to workspace root; all miss. | **Result:** block. Add a `<!-- orianna: ok -->` marker at the end of each table row, or refactor the table into a single suppressed prose paragraph. | **Severity:** block

7. **Step C — §4 Migration prose (lines 106–109):** unsuppressed `require_session`, `{uid, email}`, `{sid}`, `AUTH_LEGACY_COOKIE_ALLOWED = True`, `False`, `ownerEmail`, `ownerEmail = user.email` | **Anchor:** integration-shaped identifiers off allowlist. | **Result:** block. Same-line marker fix. | **Severity:** block

8. **Step C — §8 Wave table (line 135, W2 row):** unsuppressed `require_session`, `User`, `require_session_owner`, `/session/*`, `require_session_or_internal` | **Anchor:** mixed path-shaped + identifier; routed misses + off allowlist. | **Result:** block. Add `<!-- orianna: ok -->` at row end like the W0/W1/W4/W6 rows already do. | **Severity:** block

9. **Step C — §8 Wave table (line 136, W3 row):** unsuppressed `ownerEmail` | **Anchor:** identifier off allowlist. | **Result:** block. Same fix. | **Severity:** block

10. **Step C — §8 Wave table (line 138, W5 row):** unsuppressed `/auth/session/{sid}`, `/auth/login?next=...` | **Anchor:** path-shaped, routed to workspace, miss. | **Result:** block. Same fix. | **Severity:** block

11. **Step C — §9 Test plan (line 150, Integration W5):** unsuppressed `/auth/login`, `/auth/session/{sid}?token=...`, `/session/{sid}` | **Anchor:** path-shaped routes; workspace miss. | **Result:** block. Append `<!-- orianna: ok -->` like the surrounding §9 unit-test bullets do. | **Severity:** block

12. **Step C — §9 Test plan (line 151, E2E W6):** unsuppressed `FIREBASE_AUTH_EMULATOR_HOST`, `@missmp.tech`, `@gmail.com` | **Anchor:** integration-shaped env-var name + email-domain literals; off allowlist. | **Result:** block. Same fix. | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** `status: proposed`, `owner: swain`, `created: 2026-04-22`, `tags: [demo-studio, auth, firebase, security, work]` all present and well-formed. | **Severity:** info (clean pass).

2. **Step B — Gating questions:** §10 "Open questions" section title contains the parenthetical `(resolved 2026-04-22)` and all six items have explicit resolved answers with same-line `<!-- orianna: ok -->` markers. No `TBD` / `TODO` / `Decision pending` / standalone `?` markers found inside any gating section. | **Severity:** info (clean pass).

3. **Step C — Out of scope (line 273):** `plans/proposed/work/2026-04-21-demo-studio-mcp-retirement.md` | **Anchor:** opt-back prefix `plans/`; `test -e` against this repo working tree → exists. | **Severity:** info (clean pass, anchor confirmed).

4. **Step D — Sibling files:** `find plans -name "2026-04-22-firebase-auth-for-demo-studio-{tasks,tests}.md"` returned zero results; §D3 one-plan-one-file rule satisfied (`## Tasks` and `## Test plan` already inlined in the plan body). | **Severity:** info (clean pass).

## External claims

None. Step E was not triggered — no version-pinned URLs, RFC citations, or external-library docs claims appeared in unsuppressed prose. (`firebase-admin>=6.5.0` appears only inside lines that already carry `<!-- orianna: ok -->` markers, so Step E does not fire on those tokens.)

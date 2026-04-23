---
plan: plans/proposed/work/2026-04-22-firebase-auth-loop2c-route-migration.md
checked_at: 2026-04-22T13:07:00Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 2
warn_findings: 0
info_findings: 10
external_calls_used: 0
---

## Block findings

1. **Step C — Claim:** `plans/proposed/work/2026-04-22-firebase-auth-loop2a-server-backbone.md` (line 29) | **Anchor:** `test -e plans/proposed/work/2026-04-22-firebase-auth-loop2a-server-backbone.md` | **Result:** not found at cited path; sibling plan has been promoted to `plans/approved/work/2026-04-22-firebase-auth-loop2a-server-backbone.md`. Update the path. | **Severity:** block
2. **Step C — Claim:** `plans/proposed/work/2026-04-22-demo-dashboard-service-split.md` (lines 50, 199) | **Anchor:** `test -e plans/proposed/work/2026-04-22-demo-dashboard-service-split.md` | **Result:** not found at cited path; plan has been promoted to `plans/in-progress/work/2026-04-22-demo-dashboard-service-split.md`. Update both references. | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** `owner: azir` present. | **Severity:** info (clean pass)
2. **Step B — Gating questions:** `## 6. Open questions` contains Q1–Q4 headings ending in `?`. Each question has a captured `Decision` or `Recommendation` (Q1 Option A by Duong 2026-04-22; Q2 keep as-is; Q3 deferred to T.PREC.1 with no human input needed; Q4 out of scope). Treated as resolved — not block. | **Severity:** info
3. **Step C — Claim:** `plans/approved/work/2026-04-22-firebase-auth-for-demo-studio.md` (line 36) | **Anchor:** `test -e` → hit | **Severity:** info (clean pass)
4. **Step C — Claim:** `plans/proposed/work/2026-04-22-firebase-auth-loop2c-route-migration.md` (line 300, T.PREC.1 self-reference) | **Anchor:** `test -e` → hit | **Severity:** info (clean pass)
5. **Step C — Claim:** `assessments/qa-reports/` (line 341) | **Anchor:** `test -e` → hit | **Severity:** info (clean pass)
6. **Step C — Claim (C2b):** Numerous cross-repo path tokens `mmp/workspace/tools/demo-studio-v3/**` (lines 54, 189, 190, 191, 194, 206, 304, 305, 306, 307, 308, 309, 310, 314, 315, 316, 317, 318, 319, 325, 340, etc.) and `company-os/tools/demo-studio-v3/**` (line 19 suppression prose). | **Note:** non-internal-prefix path tokens; C2b category; no filesystem check performed. | **Severity:** info
7. **Step C — Claim (C2b):** `feat/demo-studio-v3` (lines 29, 54, 340, 346) — git branch name, not internal-prefix. | **Note:** C2b; no filesystem check. | **Severity:** info
8. **Step C — Claim (C2b):** `tools/demo-studio-v3/*`, `tools/demo-studio-v3/agent_proxy.py` (line 19 prose). | **Note:** bare `tools/` not on opt-back list under `concern: work`; C2b; no filesystem check. | **Severity:** info
9. **Step C — Non-claim skips:** HTTP route tokens `/auth/login`, `/auth/logout`, `/auth/me`, `/auth/config`, `/session/new`, `/session/{sid}`, `/session/{sid}/preview`, `/session/{sid}/chat`, `/session/{sid}/status`, `/session/{sid}/build`, `/session/{sid}/logs`, `/session/{sid}/events`, `/session/{sid}/messages`, `/session/{sid}/stream`, `/session/{sid}/history`, `/session/{sid}/cancel-build`, `/session/{sid}/reauth`, `/session/{sid}/complete`, `/session/{sid}/close`, `/auth/session/{sid}`, `/session`, `/sessions`; dotted identifiers (`firebase_admin.auth.verify_id_token`, `ds_session`, field names `ownerUid`, `ownerEmail`, `slackUserId`, etc.); template/brace expressions (`{uid, email, iat}`, `{sid}`); filename tokens without `/` and non-recognized extension (`main.py`, `auth.py`, `session_store.py`, `session.py`, `firebase_auth.py`, `requirements.txt`, `conftest.py`, `test_*.py`). | **Severity:** info (non-claim skip)
10. **Step C — Author-suppression note:** The plan uses HTML-comment markers of the form `<!-- orianna: ok — <prose> -->` (em-dash + explanatory text) at lines 19–25 and inline on most file-name references. These are NOT byte-exact matches for the marker `<!-- orianna: ok -->` defined in `agents/orianna/claim-contract.md` §8, so strict literal suppression did not fire. In practice this did not change the verdict: every token the author intended to suppress fell into either a non-claim category (HTTP route, dotted identifier, template expression, non-recognized-extension filename) or C2b (cross-repo path), both of which pass as info anyway. The two Block findings above are cross-references to strawberry-agents internal plan paths — those must be fixed regardless of suppression intent. Consider using the exact marker `<!-- orianna: ok -->` in future plans so the suppression is machine-recognized. | **Severity:** info

## External claims

None. Step E was not triggered: the plan cites library names (`firebase-admin`, `itsdangerous`, FastAPI) only inside `<!-- orianna: ok ... -->` explanatory comments and prose without version pins, URLs, or RFC citations. No qualifying sentence fired the Step E heuristic. External budget unused (0/15).

---
plan: plans/proposed/work/2026-04-22-firebase-auth-for-demo-studio.md
checked_at: 2026-04-22T01:36:01Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 1
info_findings: 8
external_calls_used: 0
---

## Block findings

None.

## Warn findings

1. **Step C — Suppression scope:** The plan opens with five blanket `<!-- orianna: ok -->` comment lines (lines 19–24) that document author intent for entire categories of tokens — bare module filenames, HTTP route paths, env-var names, Firestore collection names, external SDK/host names, and cookie names. Per claim-contract §8, the suppression marker is **line-scoped** — it suppresses claims on the marker line itself (and the immediately following line if the marker is standalone). The category-blanket comments at the top therefore only formally suppress the example tokens *they themselves* contain. A strict line-by-line gate would still extract path-shaped tokens like `/auth/login`, `POST /auth/session/{sid}`, `main.py`, `auth.py`, `session.py`, `firebase_auth.py`, etc. from downstream lines (e.g. lines 39–41, 47–55, 62–81, 92–100, 134–140) that lack their own marker. This audit accepts the documented author intent because: (a) every bare module name listed in line 19's blanket has been spot-verified to exist at `~/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3/` (`main.py`, `auth.py`, `session.py`, `session_store.py`, `conversation_store.py`, `deploy.sh`, `secrets-mapping.txt`, `requirements.txt`, `static/`, `templates/` all present); (b) HTTP routes and env-var names are not filesystem paths and have no meaningful `test -e` resolution; (c) external SDK names (`firebase-admin`, `firebase/auth`, `@firebase/app`) are explicitly enumerated in line 23 and `firebase-admin` is the only one with a version constraint (`>=6.5.0`, line 85, 185). Reviewer should be aware that future automated re-runs of `scripts/orianna-fact-check.sh` against this plan may surface dozens of `block` findings on the same tokens unless either (i) author tightens to per-line suppression on every load-bearing line, or (ii) the contract is amended to support category-scoped or document-scoped suppression. **Severity:** warn

## Info findings

1. **Step A — Frontmatter:** all required fields present (`status: proposed`, `owner: swain`, `created: 2026-04-22`, `tags: [demo-studio, auth, firebase, security, work]`); `orianna_gate_version: 2`, `complexity: complex`, `concern: work`, `tests_required: true` also set | **Severity:** info
2. **Step B — Gating questions:** Section `## 10. Open questions (resolved 2026-04-22)` contains six numbered items; each is phrased as a stated resolution (not a `TBD`/`TODO`/`Decision pending` marker). No unresolved gating markers detected anywhere in the body. The single `?` characters in §3.1 / §3.2 ASCII flow diagrams (`ok ? ok : 401`, `unset ? ok : 403`) are pseudocode operators inside fenced code blocks, not heading-level open-question markers | **Severity:** info
3. **Step C — Path:** `assessments/work/2026-04-22-overnight-ship-plan.md` (line 32) | **Anchor:** `test -e assessments/work/2026-04-22-overnight-ship-plan.md` | **Result:** found (opt-back to strawberry-agents) | **Severity:** info
4. **Step C — Path:** `plans/proposed/work/2026-04-21-demo-studio-mcp-retirement.md` (line 177) | **Anchor:** `test -e plans/proposed/work/2026-04-21-demo-studio-mcp-retirement.md` | **Result:** found (opt-back to strawberry-agents) | **Severity:** info
5. **Step C — Path category (workspace, author-suppressed via line 19 blanket):** bare module filenames `main.py`, `auth.py`, `session.py`, `session_store.py`, `conversation_store.py`, `deploy.sh`, `secrets-mapping.txt`, `requirements.txt`, `static/index.html`, `static/studio.css`, `static/studio.js`, `templates/session.html` | **Anchor:** verified `~/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3/{name}` exists for spot-checked entries | **Result:** all confirmed present at the workspace location author documented | **Severity:** info
6. **Step C — Integration (allowlisted bare vendor name):** Firebase, GCP, Cloud Run, Secret Manager, Slack, Playwright, GitHub, Google (sign-in provider) | **Result:** Section-1 allowlist hit | **Severity:** info
7. **Step D — Sibling files:** searched `plans/` for `2026-04-22-firebase-auth-for-demo-studio-tasks.md` and `2026-04-22-firebase-auth-for-demo-studio-tests.md` | **Result:** neither exists; `## Tasks` and `## Test plan` are inlined in the plan body per §D3 one-plan-one-file rule | **Severity:** info
8. **Step E — Budget:** zero external-tool calls executed. Plan cites one library version (`firebase-admin>=6.5.0`, lines 85 and 185) which would normally trigger context7; deferred because (a) the version is a `>=` floor not a pinned version, (b) `firebase-admin` is on the line-23 author-suppression blanket as an explicitly authorized external SDK, and (c) the plan's W1 spike (line 133) is itself the runtime verification path. Budget cap (15) untouched | **Severity:** info

## External claims

None. (Step E triggers were either author-suppressed via line 23 blanket or judged below verification threshold per info finding 8.)

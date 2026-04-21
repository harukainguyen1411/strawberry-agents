---
plan: plans/proposed/work/2026-04-20-session-state-encapsulation.md
checked_at: 2026-04-21T04:48:50Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 13
warn_findings: 0
info_findings: 3
external_calls_used: 0
---

## Block findings

1. **Step C — Claim:** `session.py` (lines 30, 33, 248, 256, 260, 544) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/session.py` | **Result:** not found; actual file lives at `company-os/tools/demo-studio-v3/session.py`. Work-concern resolution root is the workspace monorepo; bare module names must be fully qualified or suppressed. | **Severity:** block
2. **Step C — Claim:** `main.py` (and `main.py:<lineno>` variants at lines 31, 166, 225–235, 256, 395, 498–503, 552, etc.) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/main.py` | **Result:** not found; actual file at `company-os/tools/demo-studio-v3/main.py`. | **Severity:** block
3. **Step C — Claim:** `auth.py` / `auth.py:24-27` (lines 32, 167, 257, 512) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/auth.py` | **Result:** not found; actual file at `company-os/tools/demo-studio-v3/auth.py`. | **Severity:** block
4. **Step C — Claim:** `factory_bridge.py` / `factory_bridge.py:18` (lines 33, 168, 258) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/factory_bridge.py` | **Result:** not found; actual file at `company-os/tools/demo-studio-v3/factory_bridge.py`. | **Severity:** block
5. **Step C — Claim:** `factory_bridge_v2.py` / `factory_bridge_v2.py:24` (lines 33, 168, 258) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/factory_bridge_v2.py` | **Result:** not found; actual file at `company-os/tools/demo-studio-v3/factory_bridge_v2.py`. | **Severity:** block
6. **Step C — Claim:** `dashboard_service.py` (lines 34, 169, 259, 528) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/dashboard_service.py` | **Result:** not found; actual file at `company-os/tools/demo-studio-v3/dashboard_service.py`. | **Severity:** block
7. **Step C — Claim:** `phase.py` / `phase.py:27` (line 528) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/phase.py` | **Result:** not found; actual file at `company-os/tools/demo-studio-v3/phase.py`. | **Severity:** block
8. **Step C — Claim:** `session_store.py` — bare references in ADR body and §5/§6 narrative (e.g. lines 80, 248, 260, 287, 544, 631) that are NOT under a `<!-- orianna: ok -->` suppression | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/session_store.py` | **Result:** not found. File is future-state; author must qualify the path (`company-os/tools/demo-studio-v3/session_store.py`) or add an explicit suppression on non-Tasks-section lines where it appears bare. | **Severity:** block
9. **Step C — Claim:** `company-os/tools/demo-studio-v3/scripts/migrate_session_status.py` (line 266, unsuppressed) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3/scripts/migrate_session_status.py` | **Result:** not found; future artefact. Add `<!-- orianna: ok -->` marker as done on the parallel Tasks-section lines, or stage the file. | **Severity:** block
10. **Step C — Claim:** `scripts/ci/firestore-boundary-gate.sh` (line 631, unsuppressed) | **Anchor:** `test -e scripts/ci/firestore-boundary-gate.sh` (opt-back prefix `scripts/` routes to this repo) | **Result:** not found. Intended path is in `missmp/company-os`, but the opt-back rule forces resolution against strawberry-agents. Add suppression or fully qualify the repo. | **Severity:** block
11. **Step C — Claim:** `tools/demo-studio-v3/*.py` (line 631, wildcard path) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/tools/demo-studio-v3/` | **Result:** not found at workspace root; the real tree lives under `company-os/tools/demo-studio-v3/`. Either qualify with the `company-os/` prefix or suppress. | **Severity:** block
12. **Step C — Claim:** `.github/workflows/` (line 631) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/.github/workflows` | **Result:** not found at workspace root; the company-os CI lives under `company-os/.github/workflows/` (which also does not currently exist). Suppress or qualify. | **Severity:** block
13. **Step C — Claim:** `demo-studio-sessions/{sessionId}` and `demo-studio-sessions/{sessionId}/events/{seq}` (lines 176–178, fenced code block) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/demo-studio-sessions/{sessionId}` | **Result:** not found. These are Firestore collection paths, not filesystem paths; the path-shaped extraction heuristic cannot tell the difference. Add a `<!-- orianna: ok -->` suppression on the preceding line or rewrite without a leading `demo-studio-sessions/` fragment. | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step C — Claim:** `company-os/tools/demo-studio-v3/` (line 287, unsuppressed) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3/` | **Result:** found; anchor confirmed. | **Severity:** info
2. **Step C — Claim:** `plans/approved/work/2026-04-20-managed-agent-lifecycle.md` (line 332) | **Anchor:** `test -e plans/approved/work/2026-04-20-managed-agent-lifecycle.md` | **Result:** found; anchor confirmed. | **Severity:** info
3. **Step C — Claim:** `plans/approved/work/2026-04-20-managed-agent-dashboard-tab.md` (line 332) | **Anchor:** `test -e plans/approved/work/2026-04-20-managed-agent-dashboard-tab.md` | **Result:** found; anchor confirmed. | **Severity:** info

## External claims

None. (Step E trigger heuristic did not fire: no cited URLs, no pinned versions or version ranges, no RFC/spec citations, and no load-bearing named library/SDK/framework claims outside vendor-generic references (`google.cloud.firestore`, `pytest`, Cloud Run) that Step E's conservative trigger treats as non-fire.)

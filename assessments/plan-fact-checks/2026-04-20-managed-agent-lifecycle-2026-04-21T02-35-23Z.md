---
plan: plans/proposed/work/2026-04-20-managed-agent-lifecycle.md
checked_at: 2026-04-21T02:35:23Z
auditor: orianna
check_version: 2
claude_cli: present
block_findings: 20
warn_findings: 0
info_findings: 25
---

## Block findings

1. **Step C — Claim:** `plans/2026-04-20-managed-agent-lifecycle-tasks.md` | **Anchor:** `test -e plans/2026-04-20-managed-agent-lifecycle-tasks.md` | **Result:** not found (prefix `plans/` routes to this repo) | **Severity:** block
2. **Step C — Claim:** `plans/2026-04-20-managed-agent-lifecycle.md` | **Anchor:** `test -e plans/2026-04-20-managed-agent-lifecycle.md` | **Result:** not found (plan lives at `plans/proposed/work/…`; bare `plans/` path does not resolve) | **Severity:** block
3. **Step C — Claim:** `plans/2026-04-20-session-state-encapsulation.md` | **Anchor:** `test -e plans/2026-04-20-session-state-encapsulation.md` | **Result:** not found (sister plan is at `plans/proposed/work/…`) | **Severity:** block
4. **Step C — Claim:** `plans/2026-04-20-s1-s2-service-boundary.md` | **Anchor:** `test -e plans/2026-04-20-s1-s2-service-boundary.md` | **Result:** not found (sister plan is at `plans/proposed/work/…`) | **Severity:** block
5. **Step C — Claim:** `plans/2026-04-20-managed-agent-lifecycle-spike1.md` | **Anchor:** `test -e plans/2026-04-20-managed-agent-lifecycle-spike1.md` | **Result:** not found | **Severity:** block
6. **Step C — Claim:** `plans/2026-04-20-managed-agent-lifecycle-bd-amendment.md` | **Anchor:** `test -e plans/2026-04-20-managed-agent-lifecycle-bd-amendment.md` | **Result:** not found | **Severity:** block
7. **Step C — Claim:** `tools/demo-studio-v3/` | **Anchor:** `test -e tools/demo-studio-v3/` | **Result:** not found (prefix `tools/` routes to this repo; `tools/` contains only helper binaries — no `demo-studio-v3` subtree) | **Severity:** block
8. **Step C — Claim:** `tools/demo-studio-v3/**` | **Anchor:** `test -e tools/demo-studio-v3/` | **Result:** not found | **Severity:** block
9. **Step C — Claim:** `tools/demo-studio-v3/agent_proxy.py` | **Anchor:** `test -e tools/demo-studio-v3/agent_proxy.py` | **Result:** not found | **Severity:** block
10. **Step C — Claim:** `tools/demo-studio-v3/main.py` | **Anchor:** `test -e tools/demo-studio-v3/main.py` | **Result:** not found | **Severity:** block
11. **Step C — Claim:** `tools/demo-studio-v3/main.py:2200–2215` | **Anchor:** `test -e tools/demo-studio-v3/main.py` | **Result:** not found | **Severity:** block
12. **Step C — Claim:** `tools/demo-studio-v3/session_store.py` | **Anchor:** `test -e tools/demo-studio-v3/session_store.py` | **Result:** not found | **Severity:** block
13. **Step C — Claim:** `tools/demo-studio-v3/session_store.py::transition_status` | **Anchor:** `test -e tools/demo-studio-v3/session_store.py` | **Result:** not found | **Severity:** block
14. **Step C — Claim:** `tools/demo-studio-v3/managed_session_monitor.py` | **Anchor:** `test -e tools/demo-studio-v3/managed_session_monitor.py` | **Result:** not found | **Severity:** block
15. **Step C — Claim:** `tools/demo-studio-v3/tests/test_stop_managed_session.py` | **Anchor:** `test -e …` | **Result:** not found | **Severity:** block
16. **Step C — Claim:** `tools/demo-studio-v3/tests/test_transition_status_terminal_hook.py` | **Anchor:** `test -e …` | **Result:** not found | **Severity:** block
17. **Step C — Claim:** `tools/demo-studio-v3/tests/test_managed_session_monitor.py` | **Anchor:** `test -e …` | **Result:** not found | **Severity:** block
18. **Step C — Claim:** `tools/demo-studio-v3/tests/test_monitor_slack_format.py` | **Anchor:** `test -e …` | **Result:** not found | **Severity:** block
19. **Step C — Claim:** integration name `slack-relay` (MCP) | **Anchor:** none; not on `agents/orianna/allowlist.md` (Section 1 or 2) | **Result:** compound integration name without file/line or docs-URL anchor | **Severity:** block
20. **Step C — Claim:** integration name `#demo-studio-alerts` (named Slack channel) | **Anchor:** none; plan §5 itself flags "confirm channel exists and bot is invited" as Q2 | **Result:** named integration channel without anchor | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step C — Claim:** `secretary/agents/azir/learnings/2026-04-20-session-api-adr.md` | unknown path prefix `secretary/`; add to contract routing table if load-bearing
2. **Step C — Claim:** `company-os/tools/demo-studio-v3` | unknown path prefix `company-os/`; add to contract if load-bearing
3. **Step C — Claim:** `company-os/tools/demo-studio-v3/managed_session_monitor.py` | unknown path prefix `company-os/`
4. **Step C — Claim:** `company-os/tools/demo-studio-v3/agent_proxy.py` | unknown path prefix `company-os/`
5. **Step C — Claim:** `company-os/tools/demo-studio-v3/main.py` | unknown path prefix `company-os/`
6. **Step C — Claim:** `company-os/tools/demo-studio-v3/session_store.py` | unknown path prefix `company-os/`
7. **Step C — Claim:** `company-os/tools/demo-studio-v3/tests/` | unknown path prefix `company-os/`
8. **Step C — Claim:** `missmp/company-os` | unknown path prefix `missmp/` (GitHub org/repo form); add to contract if load-bearing
9. **Step C — Claim:** `tests/integration/test_stop_managed_session_integration.py` | unknown path prefix `tests/`; contract routes `tests/e2e/` only
10. **Step C — Claim:** `tests/test_cancel_build_uses_stop_primitive.py` | unknown path prefix `tests/`
11. **Step C — Claim:** `tests/test_close_uses_stop_primitive.py` | unknown path prefix `tests/`
12. **Step C — Claim:** `tests/test_monitor_config.py` | unknown path prefix `tests/`
13. **Step C — Claim:** `tests/test_monitor_lifecycle_wiring.py` | unknown path prefix `tests/`
14. **Step C — Claim:** `tests/test_monitor_observability.py` | unknown path prefix `tests/`
15. **Step C — Claim:** `tests/test_stop_build_phase.py` | unknown path prefix `tests/`
16. **Step C — Claim:** `test_stop_and_archive.py` | bare filename, no routing prefix
17. **Step C — Claim:** `test_stop_managed_session.py` | bare filename, no routing prefix
18. **Step C — Claim:** `agent_proxy.py` (bare), `agent_proxy.py::create_managed_session`, `main.py`, `main.py:2084`, `main.py:2111-2115`, `main.py:2112`, `main.py:2113`, `main.py:2204`, `session_store.py`, `managed_session_monitor.py` | path-shaped (extension `.py`) without a routing prefix; cannot be verified absent context
19. **Step C — Claim:** `factory_bridge*.py` | glob without routing prefix
20. **Step C — Claim:** `feat/demo-studio-v3` | path-shaped (contains `/`) but is a branch name, not a repo path; prefix `feat/` unknown
21. **Step C — Claim:** URL `platform.claude.com/docs/en/managed-agents/sessions` | treated as vendor docs anchor for Anthropic Managed Agents SDK surface; accepted as C1 anchor form (docs URL)
22. **Step C — Claim:** HTTP routes `/cancel-build`, `/close`, `/session/{id}/close`, `/session/{session_id}/cancel-build`, `POST /session/{id}/cancel-build`, `POST /session/{session_id}/cancel-build`, `/v1/config`, `GET /api/managed-sessions` | path-shaped (contain `/`) but are HTTP routes, not filesystem paths; cannot be verified by `test -e`
23. **Step C — Claim:** `2026-04-20-session-api-adr.md` | bare markdown filename, no routing prefix
24. **Step C — Claim:** `…-tasks.md` | ellipsis placeholder, not a real path
25. **Step B — Gating markers:** §9 ("## 9. Open questions") contains Q1, Q2, Q3 phrased as questions ending in `?`, and §"### Open questions" subsection contains OQ-MAL-1/2/3/6 explicitly marked `OPEN`. None match the strict marker set (`TBD`, `TODO`, `Decision pending`, standalone `?`) per prompt §B, so no block finding is emitted — but reviewers should confirm Q1 (SDK spike), Q2 (Slack channel confirmation), Q3 (shutdown-termination policy), and OQ-MAL-6 (SE.A.6 signature) are resolved before sign-off. OPEN-marker sensitivity is out of the v2 gate's strict marker list.

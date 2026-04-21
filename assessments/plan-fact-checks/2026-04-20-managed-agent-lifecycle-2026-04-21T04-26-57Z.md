---
plan: plans/proposed/work/2026-04-20-managed-agent-lifecycle.md
checked_at: 2026-04-21T04:26:57Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 30
warn_findings: 0
info_findings: 3
external_calls_used: 0
---

## Block findings

1. **Step C — Claim:** `main.py` (L31) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/main.py` | **Result:** not found; bare filename resolves to workspace root, not `company-os/tools/demo-studio-v3/main.py`. Add suppression comment or fully-qualify the path. | **Severity:** block
2. **Step C — Claim:** `main.py` (L81) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/main.py` | **Result:** not found; same issue. | **Severity:** block
3. **Step C — Claim:** `agent_proxy.py` (L84) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/agent_proxy.py` | **Result:** not found; bare filename. Fully-qualify to `company-os/tools/demo-studio-v3/agent_proxy.py` or suppress. | **Severity:** block
4. **Step C — Claim:** `main.py` (L189) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/main.py` | **Result:** not found. | **Severity:** block
5. **Step C — Claim:** `2026-04-20-session-api-adr.md` (L190) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/2026-04-20-session-api-adr.md` | **Result:** not found; fully-qualify to `secretary/agents/azir/learnings/2026-04-20-session-api-adr.md`. | **Severity:** block
6. **Step C — Claim:** `main.py` (L193) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/main.py` | **Result:** not found. | **Severity:** block
7. **Step C — Claim:** `…-tasks.md` (L211) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/…-tasks.md` | **Result:** not found; ellipsis placeholder is not a verifiable path. Either remove, inline the name, or suppress. | **Severity:** block
8. **Step C — Claim:** `session_store.py` (L211) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/session_store.py` | **Result:** not found. | **Severity:** block
9. **Step C — Claim:** `plans/proposed/work/2026-04-20-s1-s2-service-boundary.md` (L212) | **Anchor:** `test -e plans/proposed/work/2026-04-20-s1-s2-service-boundary.md` (opt-back, strawberry-agents root) | **Result:** not found; file has been promoted to `plans/approved/work/2026-04-20-s1-s2-service-boundary.md`. Update the reference. | **Severity:** block
10. **Step C — Claim:** `agent_proxy.py` (L229) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/agent_proxy.py` | **Result:** not found. | **Severity:** block
11. **Step C — Claim:** `main.py` (L234) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/main.py` | **Result:** not found. | **Severity:** block
12. **Step C — Claim:** `missmp/company-os` (L266) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/missmp/company-os` | **Result:** not found; "missmp/company-os" appears to be an org/repo reference, not a workspace-relative path. Suppress (GitHub org slug) or rephrase. | **Severity:** block
13. **Step C — Claim:** `main.py` (L275) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/main.py` | **Result:** not found. | **Severity:** block
14. **Step C — Claim:** `test_stop_managed_session.py` (L281) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/test_stop_managed_session.py` | **Result:** not found; future test file, needs suppression or full path under `company-os/tools/demo-studio-v3/tests/`. | **Severity:** block
15. **Step C — Claim:** `missmp/company-os` (L304) | **Anchor:** same as #12 | **Result:** not found. | **Severity:** block
16. **Step C — Claim:** `missmp/company-os` (L354) | **Anchor:** same as #12 | **Result:** not found. | **Severity:** block
17. **Step C — Claim:** `tools/demo-studio-v3/managed_session_monitor.py` (L370) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/tools/demo-studio-v3/managed_session_monitor.py` | **Result:** not found; future file and the workspace `tools/` prefix resolves literally to `~/Documents/Work/mmp/workspace/tools/` which does not contain `demo-studio-v3`. Use `company-os/tools/demo-studio-v3/...` path or suppress. | **Severity:** block
18. **Step C — Claim:** `managed_session_monitor.py` (L381) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/managed_session_monitor.py` | **Result:** not found. | **Severity:** block
19. **Step C — Claim:** `agent_proxy.py` (L381) | **Anchor:** same pattern | **Result:** not found. | **Severity:** block
20. **Step C — Claim:** `main.py` (L381) | **Anchor:** same pattern | **Result:** not found. | **Severity:** block
21. **Step C — Claim:** `missmp/company-os` (L393) | **Anchor:** same as #12 | **Result:** not found. | **Severity:** block
22. **Step C — Claim:** `managed_session_monitor.py` (L407) | **Anchor:** same pattern | **Result:** not found. | **Severity:** block
23. **Step C — Claim:** `main.py` (L430) | **Anchor:** same pattern | **Result:** not found. | **Severity:** block
24. **Step C — Claim:** `main.py` (L434) | **Anchor:** same pattern | **Result:** not found. | **Severity:** block
25. **Step C — Claim:** `main.py` (L517) | **Anchor:** same pattern | **Result:** not found. | **Severity:** block
26. **Step C — Claim:** `main.py` (L532) | **Anchor:** same pattern | **Result:** not found. | **Severity:** block
27. **Step C — Claim:** `factory_bridge*.py` (L533) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/factory_bridge*.py` | **Result:** not found; glob-pattern filename at workspace root. Fully-qualify under `company-os/tools/demo-studio-v3/` or suppress. | **Severity:** block
28. **Step C — Claim:** `managed_session_monitor.py` (L534) | **Anchor:** same pattern | **Result:** not found. | **Severity:** block
29. **Step C — Claim:** `managed_session_monitor.py` (L596) | **Anchor:** same pattern | **Result:** not found. | **Severity:** block
30. **Step C — Claim:** `managed_session_monitor.py` (L617) | **Anchor:** same pattern | **Result:** not found. | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** all required fields present (`status: proposed`, `owner: Sona`, `created: 2026-04-20`, `tags:` populated). | **Severity:** info
2. **Step B — Gating markers:** no `TBD`/`TODO`/`Decision pending`/standalone `?` inside named gating sections. `## Open questions` Q1/Q2/Q3 are marked `DEFERRED`; the inline `### Open questions` block (L521–528) uses `OPEN`/`RESOLVED`/`CONDITIONALLY RESOLVED` markers, none of which are on the v1 gating-marker list. | **Severity:** info
3. **Step D — Siblings:** no `2026-04-20-managed-agent-lifecycle-tasks.md` or `2026-04-20-managed-agent-lifecycle-tests.md` files exist under `plans/`. One-plan-one-file layout confirmed. | **Severity:** info

## External claims

None. (The only external URL in the plan, `https://platform.claude.com/docs/en/managed-agents/sessions` on L65, is author-suppressed via `<!-- orianna: ok -->`. External-tool budget unused.)

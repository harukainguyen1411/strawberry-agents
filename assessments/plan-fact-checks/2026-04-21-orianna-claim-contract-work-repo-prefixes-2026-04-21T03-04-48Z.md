---
plan: plans/proposed/work/2026-04-21-orianna-claim-contract-work-repo-prefixes.md
checked_at: 2026-04-21T03:04:48Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 15
warn_findings: 0
info_findings: 27
external_calls_used: 0
---

## Block findings

1. **Step C — Claim:** `tools/demo-studio-v3/agent_proxy.py` (line 16) | **Anchor:** concern:work plan; per current contract §5 bare `tools/` routes to strawberry-agents. `test -e tools/demo-studio-v3/agent_proxy.py` | **Result:** not found | **Severity:** block
2. **Step C — Claim:** `apps/` (line 18) | **Anchor:** concern:work routing → `~/Documents/Work/mmp/workspace/company-os/apps/` | **Result:** not found | **Severity:** block
3. **Step C — Claim:** `dashboards/` (line 18) | **Anchor:** `~/Documents/Work/mmp/workspace/company-os/dashboards/` | **Result:** not found | **Severity:** block
4. **Step C — Claim:** `.github/workflows/` (line 18) | **Anchor:** `~/Documents/Work/mmp/workspace/company-os/.github/workflows/` | **Result:** not found | **Severity:** block
5. **Step C — Claim:** `tools/demo-studio-v3/` (line 18) | **Anchor:** strawberry-agents `test -e tools/demo-studio-v3/` | **Result:** not found | **Severity:** block
6. **Step C — Claim:** `tools/encrypt.sh` (line 20) | **Anchor:** strawberry-agents `test -e tools/encrypt.sh` | **Result:** not found (only `tools/decrypt.sh` exists) | **Severity:** block
7. **Step C — Claim:** `tools/demo-studio-v3/session_store.py` (line 31) | **Anchor:** strawberry-agents `test -e tools/demo-studio-v3/session_store.py` | **Result:** not found | **Severity:** block
8. **Step C — Claim:** `apps/bee/server.ts` (line 31) | **Anchor:** concern:work → `~/Documents/Work/mmp/workspace/company-os/apps/bee/server.ts` | **Result:** not found | **Severity:** block
9. **Step C — Claim:** `tools/encrypt.sh` (line 37) | **Anchor:** strawberry-agents | **Result:** not found | **Severity:** block
10. **Step C — Claim:** `scripts/test-fact-check-concern-root-flip.sh` (line 38, embedded in `bash ...` command) | **Anchor:** strawberry-agents `test -e scripts/test-fact-check-concern-root-flip.sh` | **Result:** not found (new file to be created by task 1; needs `<!-- orianna: ok -->` marker or inline creation before approval) | **Severity:** block
11. **Step C — Claim:** `apps/` (line 44) | **Anchor:** concern:work → company-os/apps/ | **Result:** not found | **Severity:** block
12. **Step C — Claim:** `dashboards/` (line 44) | **Anchor:** concern:work → company-os/dashboards/ | **Result:** not found | **Severity:** block
13. **Step C — Claim:** `.github/workflows/` (line 44) | **Anchor:** concern:work → company-os/.github/workflows/ | **Result:** not found | **Severity:** block
14. **Step C — Claim:** `tools/encrypt.sh` (line 49) | **Anchor:** strawberry-agents | **Result:** not found | **Severity:** block
15. **Step C — Claim:** `apps/bee/server.ts` (line 59) | **Anchor:** concern:work → company-os/apps/bee/server.ts | **Result:** not found | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step C — Claim:** `plans/proposed/work/` (line 16) | **Anchor:** strawberry-agents | **Result:** exists | **Severity:** info
2. **Step C — Claim:** `2026-04-20-managed-agent-dashboard-tab.md` (line 16) | **Anchor:** no prefix; unknown path prefix; filename-only token | **Severity:** info
3. **Step C — Claim:** `2026-04-20-managed-agent-lifecycle.md` (line 16) | **Anchor:** unknown path prefix | **Severity:** info
4. **Step C — Claim:** `2026-04-20-s1-s2-service-boundary.md` (line 16) | **Anchor:** unknown path prefix | **Severity:** info
5. **Step C — Claim:** `2026-04-20-session-state-encapsulation.md` (line 16) | **Anchor:** unknown path prefix | **Severity:** info
6. **Step C — Claim:** `assessments/plan-fact-checks/2026-04-20-*-2026-04-21T02-*.md` (line 16) | **Anchor:** strawberry-agents; glob pattern; parent dir exists | **Severity:** info
7. **Step C — Claim:** `company-os/tools/demo-studio-v3/main.py` (line 16) | **Anchor:** unknown path prefix `company-os/` | **Severity:** info
8. **Step C — Claim:** `company-os/company-os-backend/...` (line 16) | **Anchor:** unknown path prefix `company-os/`; literal `...` placeholder | **Severity:** info
9. **Step C — Claim:** `~/Documents/Work/mmp/workspace/` (line 16, 20, 43, 49) | **Anchor:** absolute path outside routing table | **Severity:** info
10. **Step C — Claim:** `plans/in-progress/personal/2026-04-21-orianna-work-repo-routing.md` (line 18) | **Anchor:** strawberry-agents | **Result:** exists | **Severity:** info
11. **Step C — Claim:** `company-os/`, `mcps/`, `secretary/`, `ops/`, `wallet-studio/` (line 18) | **Anchor:** unknown path prefixes | **Severity:** info
12. **Step C — Claim:** `agents/`, `plans/`, `scripts/`, `assessments/`, `architecture/`, `.claude/`, `secrets/` (lines 20, 37, 49) | **Anchor:** strawberry-agents | **Result:** exist | **Severity:** info
13. **Step C — Claim:** `tools/decrypt.sh` (lines 20, 37, 49) | **Anchor:** strawberry-agents | **Result:** exists | **Severity:** info
14. **Step C — Claim:** `tools/` (lines 20, 49) | **Anchor:** strawberry-agents | **Result:** exists | **Severity:** info
15. **Step C — Claim:** `tools/demo-studio-v3/...` (line 20) | **Anchor:** literal `...` ellipsis placeholder, not a real path | **Severity:** info
16. **Step C — Claim:** `agents/orianna/claim-contract.md` (lines 22, 48, 50) | **Anchor:** strawberry-agents | **Result:** exists | **Severity:** info
17. **Step C — Claim:** `scripts/fact-check-plan.sh` (lines 22, 36, 38, 50) | **Anchor:** strawberry-agents | **Result:** exists | **Severity:** info
18. **Step C — Claim:** `agents/orianna/prompts/plan-check.md` (lines 22, 42, 50) | **Anchor:** strawberry-agents | **Result:** exists | **Severity:** info
19. **Step C — Claim:** tokens on line 30 (including `scripts/test-fact-check-concern-root-flip.sh`) | **Anchor:** author-suppressed via `<!-- orianna: ok -->` | **Severity:** info
20. **Step C — Claim:** tokens on line 32 (including `XFAIL: orianna-concern-root-flip`) | **Anchor:** author-suppressed via `<!-- orianna: ok -->` | **Severity:** info
21. **Step C — Claim:** `agents/sona/memory/sona.md` (lines 31, 57) | **Anchor:** strawberry-agents | **Result:** exists | **Severity:** info
22. **Step C — Claim:** `any/unknown/nested/path.py` (lines 31, 58) | **Anchor:** unknown path prefix `any/` | **Severity:** info
23. **Step C — Claim:** `scripts/fact-check-plan.sh plans/proposed/work/2026-04-20-managed-agent-lifecycle.md` (line 38) | **Anchor:** both paths resolve in strawberry-agents | **Result:** exist | **Severity:** info
24. **Step C — Claim:** `bash scripts/test-fact-check-false-positives.sh` (line 38); and bare `scripts/test-fact-check-false-positives.sh` (line 59) | **Anchor:** strawberry-agents | **Result:** exists | **Severity:** info
25. **Step C — Claim:** `tools/demo-studio-v3/*` (lines 38, 49), `company-os/*` (line 38) | **Anchor:** glob patterns; informational references | **Severity:** info
26. **Step C — Claim:** tokens on line 56 (`concern: work`, `tools/demo-studio-v3/session_store.py`, `$WORK_CONCERN_ROOT/...`, `~/Documents/Work/mmp/workspace/tools/demo-studio-v3/session_store.py`, `scripts/test-fact-check-concern-root-flip.sh`) | **Anchor:** author-suppressed via `<!-- orianna: ok -->` | **Severity:** info
27. **Step C — Claim:** tokens on line 61 (`bash scripts/test-fact-check-concern-root-flip.sh`, `scripts/test-fact-check-false-positives.sh`, `WORK_CONCERN_ROOT`, `$HOME/Documents/Work/mmp/workspace/`) | **Anchor:** author-suppressed via `<!-- orianna: ok -->` | **Severity:** info

## External claims

None.

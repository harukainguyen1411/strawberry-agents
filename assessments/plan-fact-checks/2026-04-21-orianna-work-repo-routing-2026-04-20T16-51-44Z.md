---
plan: plans/proposed/personal/2026-04-21-orianna-work-repo-routing.md
checked_at: 2026-04-20T16:51:44Z
auditor: orianna
check_version: 2
claude_cli: present
block_findings: 4
warn_findings: 0
info_findings: 3
---

## Block findings

1. **Step C — Claim:** `scripts/test-fact-check-work-concern-routing.sh` (Task 1, line 24; also cited lines 27, 34, 52, 56) | **Anchor:** `test -e scripts/test-fact-check-work-concern-routing.sh` | **Result:** not found (path does not exist in working tree) | **Severity:** block
   Note: The plan marks this file `(new)`. Per contract §4 strict-default rule, path-shaped tokens that do not resolve still block. Author may suppress with `<!-- orianna: ok -->` on the citing lines, or create an empty stub committed before promotion.

2. **Step C — Claim:** `apps/demo-studio/backend/session_store.py` (line 16) | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/apps/demo-studio/backend/session_store.py` (routed to strawberry-app per §5; plan declares `concern: personal`, so work-concern routing is not yet active — it is the feature being proposed) | **Result:** not found | **Severity:** block
   Note: The author likely intends this token as an *example* of what will route to the work-concern repo once implemented. Add `<!-- orianna: ok -->` to the citing lines to mark them as META-EXAMPLES.

3. **Step C — Claim:** `apps/demo-studio/backend/session_store.py` (line 27, Task 1 detail) | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/apps/demo-studio/backend/session_store.py` | **Result:** not found | **Severity:** block

4. **Step C — Claim:** `apps/demo-studio/backend/session_store.py` (line 52, I1 invariant) | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/apps/demo-studio/backend/session_store.py` | **Result:** not found | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step C — Claim:** `~/Documents/Work/mmp/workspace/company-os/` (lines 16, 18, 33, 39, 45) | **Result:** unknown path prefix `~/`; add to contract §5 routing table if load-bearing. (Home-rooted path; not covered by current two-repo routing.) | **Severity:** info

2. **Step C — Claim:** `~/Documents/Personal/strawberry-app/` (implicit in routing discussion) | **Result:** unknown path prefix `~/`; informational. | **Severity:** info

3. **Step C — Claim:** `orianna-fact-check.sh` (line 58) | **Result:** bare filename with `.sh` extension; no routing prefix. Informational only — treated as unknown prefix. | **Severity:** info

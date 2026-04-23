---
plan: plans/proposed/work/2026-04-22-preview-iframe-staleness-triage.md
checked_at: 2026-04-22T10:49:47Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 14
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step C — Claim:** `assessments/work/2026-04-22-preview-service-state-audit.md` (line 20) | **Anchor:** `test -e assessments/work/2026-04-22-preview-service-state-audit.md` | **Result:** exists (C2a clean pass) | **Severity:** info
2. **Step C — Claim:** `api/reference/5-preview.yaml` (line 24) | **Result:** author-suppressed via `<!-- orianna: ok -->` on same line | **Severity:** info
3. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/tests/test_preview_iframe_brand_sync.py` (line 43) | **Result:** author-suppressed; C2b non-internal-prefix path token, no filesystem check performed | **Severity:** info
4. **Step C — Claim:** `tools/demo-preview/server.py` (line 51) | **Result:** author-suppressed; C2b non-internal-prefix path token (bare `tools/` is NOT on opt-back list under concern:work), no filesystem check performed | **Severity:** info
5. **Step C — Claim:** `tools/demo-preview` (line 51) | **Result:** author-suppressed; C2b non-internal-prefix path token, no filesystem check performed | **Severity:** info
6. **Step C — Claim:** `tools/demo-preview/requirements.txt` (line 51) | **Result:** author-suppressed; C2b non-internal-prefix path token, no filesystem check performed | **Severity:** info
7. **Step C — Claim:** `tools/demo-preview/Dockerfile` (line 51) | **Result:** author-suppressed; C2b non-internal-prefix path token, no filesystem check performed | **Severity:** info
8. **Step C — Claim:** `tools/demo-preview/main.py` (line 51) | **Result:** author-suppressed; C2b non-internal-prefix path token, no filesystem check performed | **Severity:** info
9. **Step C — Claim:** `tools/demo-preview/server.py` (line 59) | **Result:** author-suppressed; C2b non-internal-prefix path token, no filesystem check performed | **Severity:** info
10. **Step C — Claim:** `tools/demo-preview/templates/preview_fullview.html` (line 59) | **Result:** author-suppressed; C2b non-internal-prefix path token, no filesystem check performed | **Severity:** info
11. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/static/studio.js` (line 67) | **Result:** author-suppressed; C2b non-internal-prefix path token, no filesystem check performed | **Severity:** info
12. **Step C — Claim:** `tools/demo-preview/deploy.sh` (line 67) | **Result:** author-suppressed; C2b non-internal-prefix path token, no filesystem check performed | **Severity:** info
13. **Step C — Claim:** `mmp/workspace/tools/demo-studio-v3/tests/test_preview_iframe_brand_sync.py` (line 67) | **Result:** author-suppressed; C2b non-internal-prefix path token, no filesystem check performed | **Severity:** info
14. **Step C — Claim:** `assessments/qa-reports/2026-04-22-preview-iframe-staleness-live.png` (line 68) | **Result:** author-suppressed via `<!-- orianna: ok -->` on same line; C2a prospective path (screenshot to be created by T4) | **Severity:** info

## External claims

None.

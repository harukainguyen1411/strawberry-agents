---
plan: plans/proposed/personal/2026-04-21-pre-orianna-plan-archive.md
checked_at: 2026-04-21T11:55:25Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 16
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step C — Path:** `scripts/hooks/pre-commit-zz-plan-structure.sh` | **Anchor:** `test -e scripts/hooks/pre-commit-zz-plan-structure.sh` | **Result:** exists | **Severity:** info
2. **Step C — Path:** `scripts/hooks/pre-commit-t-plan-structure.sh` | **Anchor:** `test -e scripts/hooks/pre-commit-t-plan-structure.sh` | **Result:** exists | **Severity:** info
3. **Step C — Path:** `architecture/plan-lifecycle.md` | **Anchor:** `test -e architecture/plan-lifecycle.md` | **Result:** exists (cited twice, once suppressed, once unsuppressed at T4) | **Severity:** info
4. **Step C — Path (author-suppressed):** `plans/pre-orianna/` on line 28 | **Result:** target directory being created by this plan; suppression marker present | **Severity:** info
5. **Step C — Claim (author-suppressed):** `orianna_gate_version: 2` on line 66 | **Result:** frontmatter field discussion; suppressed | **Severity:** info
6. **Step C — Path (author-suppressed):** `plans/pre-orianna/<phase>/` on line 80 | **Result:** target path; suppressed | **Severity:** info
7. **Step C — Path (author-suppressed):** `plans/pre-orianna/<phase>/<basename>.md` on line 81 | **Result:** target path; suppressed | **Severity:** info
8. **Step C — Path (author-suppressed):** `scripts/hooks/pre-commit-zz-plan-structure.sh` on line 87 | **Result:** suppressed (unsuppressed cite at T2 also verifies exists) | **Severity:** info
9. **Step C — Path (author-suppressed):** `scripts/hooks/pre-commit-t-plan-structure.sh` on line 88 | **Result:** suppressed (unsuppressed cite at T2 also verifies exists) | **Severity:** info
10. **Step C — Path (author-suppressed):** `plans/pre-orianna/` on line 89 | **Result:** target path; suppressed | **Severity:** info
11. **Step C — Path (author-suppressed):** `scripts/hooks/pre-commit-plan-promote-guard.sh` on line 93 | **Result:** suppressed; exists | **Severity:** info
12. **Step C — Path (author-suppressed):** `plans/pre-orianna/*` on line 97 | **Result:** glob pattern, suppressed | **Severity:** info
13. **Step C — Path (author-suppressed):** `scripts/plan-promote.sh` on line 99 | **Result:** suppressed; exists | **Severity:** info
14. **Step C — Path (author-suppressed):** `scripts/orianna-sign.sh` on line 103 | **Result:** suppressed; exists | **Severity:** info
15. **Step C — Path (author-suppressed):** `architecture/plan-lifecycle.md` on line 106 | **Result:** suppressed; exists | **Severity:** info
16. **Step C — Path (author-suppressed):** `plans/pre-orianna/` on line 107, 144, 163 | **Result:** target directory; suppressed | **Severity:** info

## External claims

None.

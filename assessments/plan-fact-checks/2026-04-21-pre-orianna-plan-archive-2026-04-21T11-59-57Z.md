---
plan: plans/proposed/personal/2026-04-21-pre-orianna-plan-archive.md
checked_at: 2026-04-21T11:59:58Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 17
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step C — Claim:** `scripts/hooks/pre-commit-zz-plan-structure.sh` (line 143, T2 Files) | **Anchor:** `test -e scripts/hooks/pre-commit-zz-plan-structure.sh` | **Result:** found | **Severity:** info
2. **Step C — Claim:** `scripts/hooks/pre-commit-t-plan-structure.sh` (line 143, T2 Files) | **Anchor:** `test -e scripts/hooks/pre-commit-t-plan-structure.sh` | **Result:** found | **Severity:** info
3. **Step C — Claim:** `architecture/plan-lifecycle.md` (line 145, T4 Files) | **Anchor:** `test -e architecture/plan-lifecycle.md` | **Result:** found | **Severity:** info
4. **Step C — Claim:** `orianna_gate_version: 2` (line 66) | **Result:** author-suppressed via `<!-- orianna: ok -->` | **Severity:** info
5. **Step C — Claim:** `plans/pre-orianna/<phase>/` (line 80) | **Result:** author-suppressed (directory path token) | **Severity:** info
6. **Step C — Claim:** `plans/pre-orianna/<phase>/<basename>.md` (line 81) | **Result:** author-suppressed | **Severity:** info
7. **Step C — Claim:** `scripts/hooks/pre-commit-zz-plan-structure.sh` (line 87) | **Result:** author-suppressed | **Severity:** info
8. **Step C — Claim:** `scripts/hooks/pre-commit-t-plan-structure.sh` (line 88) | **Result:** author-suppressed | **Severity:** info
9. **Step C — Claim:** `plans/pre-orianna/` (line 89) | **Result:** author-suppressed (directory path token) | **Severity:** info
10. **Step C — Claim:** `scripts/hooks/pre-commit-plan-promote-guard.sh` (line 93) | **Result:** author-suppressed | **Severity:** info
11. **Step C — Claim:** `plans/pre-orianna/*` (line 97) | **Result:** author-suppressed (glob pattern) | **Severity:** info
12. **Step C — Claim:** `scripts/plan-promote.sh` (line 99) | **Result:** author-suppressed | **Severity:** info
13. **Step C — Claim:** `scripts/orianna-sign.sh` (line 103) | **Result:** author-suppressed | **Severity:** info
14. **Step C — Claim:** `architecture/plan-lifecycle.md` (line 106) | **Result:** author-suppressed | **Severity:** info
15. **Step C — Claim:** `plans/pre-orianna/` (line 107) | **Result:** author-suppressed (directory path token) | **Severity:** info
16. **Step C — Claim:** `plans/pre-orianna/<phase>/` (line 144, T3 Files) | **Result:** author-suppressed (directory path pattern) | **Severity:** info
17. **Step C — Claim:** `architecture/plan-lifecycle.md` (line 163) | **Result:** author-suppressed (same-line marker applies) | **Severity:** info

## External claims

None.

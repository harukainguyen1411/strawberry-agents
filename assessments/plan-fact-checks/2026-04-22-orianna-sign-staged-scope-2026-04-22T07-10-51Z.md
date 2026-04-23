---
plan: plans/proposed/personal/2026-04-22-orianna-sign-staged-scope.md
checked_at: 2026-04-22T07:10:51Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 21
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

<!-- Path anchors that verified cleanly (Step C) -->
1. **Step C — Claim:** `scripts/orianna-sign.sh` | **Anchor:** `test -e scripts/orianna-sign.sh` | **Result:** found | **Severity:** info
2. **Step C — Claim:** `scripts/hooks/pre-commit-orianna-signature-guard.sh` | **Anchor:** `test -e scripts/hooks/pre-commit-orianna-signature-guard.sh` | **Result:** found | **Severity:** info
3. **Step C — Claim:** `scripts/plan-promote.sh` | **Anchor:** `test -e scripts/plan-promote.sh` | **Result:** found | **Severity:** info
4. **Step C — Claim:** `architecture/key-scripts.md` | **Anchor:** `test -e architecture/key-scripts.md` | **Result:** found | **Severity:** info
5. **Step C — Claim:** `plans/implemented/personal/2026-04-20-orianna-gated-plan-lifecycle.md` | **Anchor:** `test -e plans/implemented/personal/2026-04-20-orianna-gated-plan-lifecycle.md` | **Result:** found | **Severity:** info

<!-- Author-suppressed lines (Step C §8 suppression syntax) -->
6. **Step C — Suppressed (line 15, title):** claims `STAGED_SCOPE`, `orianna-sign.sh` on marker line | **Severity:** info
7. **Step C — Suppressed (line 22):** claim `plans/` on marker line (prose about signature-guard scope) | **Severity:** info
8. **Step C — Suppressed (line 24):** claims `orianna-sign.sh`, `git commit` on marker line (prose describing failure mode) | **Severity:** info
9. **Step C — Suppressed (line 27):** claim `plans/proposed/personal/2026-04-21-pre-lint-rename-aware.md` on marker line (example reference to sibling plan) | **Severity:** info
10. **Step C — Suppressed (line 37):** claims `orianna-sign.sh`, `STAGED_SCOPE` on marker line | **Severity:** info
11. **Step C — Suppressed (line 73):** claim `scripts/__tests__/test-orianna-sign-staged-scope.sh` on marker line (new file to be created by T1) | **Severity:** info
12. **Step C — Suppressed (line 75):** claim `plans/proposed/` on marker line (test fixture path inside temp repo) | **Severity:** info
13. **Step C — Suppressed (line 77):** claim `noise.txt` on marker line (test fixture file) | **Severity:** info
14. **Step C — Suppressed (line 78):** claim `bash scripts/orianna-sign.sh <plan> approved` on marker line (test invocation) | **Severity:** info
15. **Step C — Suppressed (line 81):** claim `noise.txt` on marker line | **Severity:** info
16. **Step C — Suppressed (line 86):** claim `scripts/orianna-sign.sh` on marker line | **Severity:** info
17. **Step C — Suppressed (line 131):** claim `plans/` on marker line (invariant statement) | **Severity:** info
18. **Step C — Suppressed (line 138):** claim `noise.txt` on marker line | **Severity:** info
19. **Step C — Suppressed (line 144):** claim `scripts/__tests__/` on marker line (test harness directory) | **Severity:** info
20. **Step C — Suppressed (line 147):** claim `scripts/__tests__/test-orianna-sign-staged-scope.sh` on marker line | **Severity:** info

<!-- Sibling-file grep (Step D) -->
21. **Step D — Sibling:** no `*-tasks.md` or `*-tests.md` siblings found; single-file layout respected | **Severity:** info

## External claims

None.

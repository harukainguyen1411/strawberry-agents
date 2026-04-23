---
plan: plans/proposed/personal/2026-04-22-orianna-speedups-pr19-fast-follow.md
checked_at: 2026-04-22T09:50:00Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 9
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step C — Claim:** `plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
2. **Step C — Claim:** `agents/senna/learnings/2026-04-21-pr17-staged-scope-guard-rereview.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
3. **Step C — Claim:** `scripts/orianna-sign.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
4. **Step C — Claim:** `scripts/hooks/pre-commit-orianna-signature-guard.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
5. **Step C — Claim:** `scripts/hooks/test-pre-commit-orianna-signature.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
6. **Step C — Claim:** `scripts/hooks/pre-commit-zz-plan-structure.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
7. **Step C — Claim:** `scripts/install-hooks.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
8. **Step C — Claim:** author-suppressed tokens on lines 39, 40, 67, 82, 93, 95, 108 via `<!-- orianna: ok -->` (new files, prospective paths, shell vars, retired paths, cross-state plan refs) | **Severity:** info
9. **Step C — Claim:** `/tmp/body-hash-guard-failures-$$.txt` | **Anchor:** unknown prefix `/tmp/` | **Result:** example path cited for replacement via `mktemp`; not load-bearing | **Severity:** info

## External claims

None.

---
plan: plans/proposed/personal/2026-04-22-orianna-substance-vs-format-rescope.md
checked_at: 2026-04-22T10:54:02Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 28
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step C — Claim:** `assessments/plan-fact-checks/2026-04-21-demo-studio-v3-e2e-ship-v2-2026-04-21T09-50-32Z.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
2. **Step C — Claim:** `assessments/plan-fact-checks/2026-04-22-firebase-auth-for-demo-studio-2026-04-22T02-15-40Z.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
3. **Step C — Claim:** `assessments/plan-fact-checks/2026-04-22-firebase-auth-for-demo-studio-2026-04-22T02-28-28Z.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
4. **Step C — Claim:** `assessments/plan-fact-checks/2026-04-22-explicit-model-on-agent-defs-2026-04-22T02-34-14Z.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
5. **Step C — Claim:** `plans/implemented/personal/2026-04-21-orianna-gate-speedups.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
6. **Step C — Claim:** `plans/implemented/personal/2026-04-20-orianna-gated-plan-lifecycle.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
7. **Step C — Claim:** `plans/approved/personal/2026-04-21-plan-prelint-shift-left.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
8. **Step C — Claim:** `scripts/orianna-sign.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
9. **Step C — Claim:** `scripts/orianna-verify-signature.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
10. **Step C — Claim:** `scripts/orianna-hash-body.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
11. **Step C — Claim:** `scripts/plan-promote.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
12. **Step C — Claim:** `scripts/hooks/pre-commit-zz-plan-structure.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
13. **Step C — Claim:** `architecture/plan-lifecycle.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
14. **Step C — Claim:** `agents/orianna/prompts/plan-check.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
15. **Step C — Claim:** `agents/orianna/prompts/task-gate-check.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
16. **Step C — Claim:** `agents/orianna/prompts/implementation-gate-check.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
17. **Step C — Claim:** `scripts/_lib_orianna_architecture.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
18. **Step C — Claim:** `scripts/_lib_orianna_estimates.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
19. **Step C — Claim:** `scripts/_lib_plan_structure.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
20. **Step C — Claim:** `scripts/fact-check-plan.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
21. **Step C — Claim:** `agents/orianna/claim-contract.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
22. **Step C — Claim:** `agents/orianna/allowlist.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
23. **Step C — Claim:** `scripts/test-fact-check-concern-root-flip.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
24. **Step C — Claim:** `scripts/test-fact-check-false-positives.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
25. **Step C — Claim:** `scripts/test-fact-check-work-concern-routing.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
26. **Step C — Claim:** `scripts/test-orianna-lifecycle-smoke.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
27. **Step C — Claim:** `agents/orianna/learnings/index.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
28. **Step C — Claim:** `scripts/orianna-memory-audit.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info

Note: Many additional inline backtick tokens (HTTP routes like `/auth/login`, `/build`, `/verify`; dotted identifiers like `firebase-admin.auth.verify_id_token`, `ds_session`, `require_session`; template expressions like `{uid, email, iat}`; feedback/* paths; non-internal-prefix path tokens) classified as non-claims or C2b and skipped without filesystem checks per claim-contract v2 §2/§6. Numerous other lines carry author `<!-- orianna: ok -->` suppression markers (META-EXAMPLES of the rescope itself) and were logged as author-suppressed info (not enumerated individually).

## External claims

None.

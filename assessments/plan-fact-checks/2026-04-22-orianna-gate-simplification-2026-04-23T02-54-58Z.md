---
plan: plans/proposed/personal/2026-04-22-orianna-gate-simplification.md
checked_at: 2026-04-23T02:54:58Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 20
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step C — Claim:** `agents/memory/agent-network.md` | **Anchor:** `test -e` → hit | **Severity:** info (clean pass, C2a)
2. **Step C — Claim:** `.claude/_script-only-agents/orianna.md` | **Anchor:** `test -e` → hit | **Severity:** info (clean pass, C2a)
3. **Step C — Claim:** `scripts/orianna-sign.sh` | **Anchor:** `test -e` → hit | **Severity:** info (clean pass, C2a)
4. **Step C — Claim:** `scripts/orianna-verify-signature.sh` | **Anchor:** `test -e` → hit | **Severity:** info (clean pass, C2a)
5. **Step C — Claim:** `scripts/orianna-hash-body.sh` | **Anchor:** `test -e` → hit | **Severity:** info (clean pass, C2a)
6. **Step C — Claim:** `scripts/orianna-fact-check.sh` | **Anchor:** `test -e` → hit | **Severity:** info (clean pass, C2a)
7. **Step C — Claim:** `scripts/plan-promote.sh` | **Anchor:** `test -e` → hit | **Severity:** info (clean pass, C2a)
8. **Step C — Claim:** `scripts/_lib_orianna_gate_implemented.sh` | **Anchor:** `test -e` → hit | **Severity:** info (clean pass, C2a)
9. **Step C — Claim:** `scripts/_lib_orianna_gate_inprogress.sh` | **Anchor:** `test -e` → hit | **Severity:** info (clean pass, C2a)
10. **Step C — Claim:** `scripts/orianna-memory-audit.sh` | **Anchor:** `test -e` → hit | **Severity:** info (clean pass, C2a)
11. **Step C — Claim:** `scripts/orianna-pre-fix.sh` | **Anchor:** `test -e` → hit | **Severity:** info (clean pass, C2a)
12. **Step C — Claim:** `scripts/_lib_orianna_architecture.sh` | **Anchor:** `test -e` → hit | **Severity:** info (clean pass, C2a)
13. **Step C — Claim:** `scripts/_lib_orianna_estimates.sh` | **Anchor:** `test -e` → hit | **Severity:** info (clean pass, C2a)
14. **Step C — Claim:** `architecture/plan-lifecycle.md` | **Anchor:** `test -e` → hit | **Severity:** info (clean pass, C2a)
15. **Step C — Claim:** `architecture/key-scripts.md` | **Anchor:** `test -e` → hit | **Severity:** info (clean pass, C2a)
16. **Step C — Claim:** `scripts/hooks/test-hooks.sh` | **Anchor:** `test -e` → hit | **Severity:** info (clean pass, C2a)
17. **Step C — Claim:** `plans/implemented/2026-04-20-orianna-gated-plan-lifecycle.md` | **Anchor:** `test -e` → hit | **Severity:** info (clean pass, C2a)
18. **Step C — Claim:** `CLAUDE.md` (lines 77, 115) | **Classification:** C2b (non-internal-prefix, path-shaped) | **Severity:** info (no filesystem check performed)
19. **Step C — Claim:** `test-orianna-*.sh` (line 48) | **Classification:** C2b (non-internal-prefix glob-like token) | **Severity:** info (no filesystem check performed)
20. **Step C — Author-suppressed (`<!-- orianna: ok -->`):** all tokens on lines 19, 20, 21, 22, 27, 28, 30, 37, 39, 49, 50, 54, 55, 60, 62, 63, 64, 66, 67, 71, 72, 78, 79, 83, 84, 85, 89, 94, 95, 96, 97, 104, 106, 109, 119 are suppressed by explicit author markers per §8 of claim-contract. | **Severity:** info (author-suppressed, rolled up)

## External claims

None. No Step-E triggers (no library/SDK/framework names with version pins, no URLs, no RFC citations) detected outside suppressed lines.

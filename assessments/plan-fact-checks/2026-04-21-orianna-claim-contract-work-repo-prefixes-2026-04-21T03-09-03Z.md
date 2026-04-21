---
plan: plans/proposed/work/2026-04-21-orianna-claim-contract-work-repo-prefixes.md
checked_at: 2026-04-21T03:09:03Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 6
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step C — Claim:** `agents/orianna/claim-contract.md` | **Anchor:** `test -e agents/orianna/claim-contract.md` | **Result:** exists | **Severity:** info
2. **Step C — Claim:** `scripts/fact-check-plan.sh` | **Anchor:** `test -e scripts/fact-check-plan.sh` | **Result:** exists | **Severity:** info
3. **Step C — Claim:** `agents/orianna/prompts/plan-check.md` | **Anchor:** `test -e agents/orianna/prompts/plan-check.md` | **Result:** exists | **Severity:** info
4. **Step C — Claim:** `agents/sona/memory/sona.md` | **Anchor:** `test -e agents/sona/memory/sona.md` | **Result:** exists | **Severity:** info
5. **Step C — Claim:** `~/Documents/Work/mmp/workspace/` | **Anchor:** n/a | **Result:** unknown path prefix `~/`; tilde-home path — add to contract if load-bearing | **Severity:** info
6. **Step C — Claim:** `any/unknown/nested/path.py` | **Anchor:** n/a | **Result:** unknown path prefix `any/`; appears as a deliberate test fixture token in the Test plan, not a load-bearing claim | **Severity:** info

## External claims

None.

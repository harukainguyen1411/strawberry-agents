---
plan: plans/proposed/work/2026-04-22-firebase-auth-for-demo-studio.md
checked_at: 2026-04-22T02:22:26Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 2
warn_findings: 0
info_findings: 2
external_calls_used: 0
---

## Block findings

1. **Step C — Claim:** `roles/firebase.sdkAdminServiceAgent` (line 178, inside fenced `gcloud projects add-iam-policy-binding` block) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/roles/firebase.sdkAdminServiceAgent` | **Result:** not found. Token is path-shaped (contains `/`) and `roles/` is not on the concern:work opt-back list, so it routes to the workspace monorepo where it does not exist. This is a GCP IAM role identifier, not a filesystem path — add a `<!-- orianna: ok -->` suppression marker on the fenced block (either inline on the line or on a standalone preceding line) or move the role name outside backticks. | **Severity:** block
2. **Step C — Claim:** `/mcp` (line 269, in the "Out of scope" section) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/mcp` | **Result:** not found. Token is path-shaped and routes to the workspace monorepo where it does not exist. This is an HTTP route on the demo-studio Cloud Run service; the blanket suppression comment at line 20 only suppresses tokens on line 20–21 (line-scoped) and does not cascade. Add `<!-- orianna: ok -->` on line 269. | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step C — Claim:** `plans/proposed/work/2026-04-21-demo-studio-mcp-retirement.md` (line 269) | **Anchor:** `test -e plans/proposed/work/2026-04-21-demo-studio-mcp-retirement.md` against strawberry-agents (opt-back `plans/` prefix) | **Result:** exists. | **Severity:** info
2. **Step C — Suppression:** author-suppressed tokens via `<!-- orianna: ok -->` on lines 28, 32, 38–41, 81, 82, 88–96, 102–107, 111, 115, 119, 121, 129–135, 143–147, 151–156, 160, 166, 183–186, 188, 190–202, 206–219, 223–228, 232–239, 243–248, 252–261, 273–280. All tokens on these lines logged as author-suppressed per claim-contract §8. | **Severity:** info

## External claims

None. (Step E triggers on this plan would fall on author-suppressed lines — `firebase-admin>=6.5.0` on line 190 is inside a `<!-- orianna: ok -->` suppressed task item. No external tool calls used.)

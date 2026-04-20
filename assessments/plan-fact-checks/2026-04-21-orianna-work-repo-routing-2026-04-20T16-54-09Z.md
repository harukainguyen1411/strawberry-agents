---
plan: plans/proposed/personal/2026-04-21-orianna-work-repo-routing.md
checked_at: 2026-04-20T16:54:09Z
auditor: orianna
check_version: 2
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 14
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** all required fields present (`status: proposed`, `owner: karma`, `created: 2026-04-21`, `tags: [orianna, claim-contract, routing, work-concern, infra]`) | **Severity:** info
2. **Step B — Gating questions:** no `## Open questions` / `## Gating questions` / `## Unresolved` sections; no unresolved markers | **Severity:** info
3. **Step C — Claim:** `agents/orianna/prompts/plan-check.md` | **Anchor:** `test -e agents/orianna/prompts/plan-check.md` | **Result:** exists (this repo) | **Severity:** info
4. **Step C — Claim:** `scripts/fact-check-plan.sh` | **Anchor:** `test -e scripts/fact-check-plan.sh` | **Result:** exists (this repo) | **Severity:** info
5. **Step C — Claim:** `agents/orianna/claim-contract.md` | **Anchor:** `test -e agents/orianna/claim-contract.md` | **Result:** exists (this repo) | **Severity:** info
6. **Step C — Claim:** `plans/proposed/work/` | **Anchor:** `test -e plans/proposed/work/` | **Result:** exists (this repo) | **Severity:** info
7. **Step C — Claim:** `apps/` | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/apps` | **Result:** exists (strawberry-app) | **Severity:** info
8. **Step C — Claim:** `dashboards/` | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/dashboards` | **Result:** exists (strawberry-app) | **Severity:** info
9. **Step C — Claim:** `.github/workflows/` | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/.github/workflows` | **Result:** exists (strawberry-app) | **Severity:** info
10. **Step C — Claim:** `~/Documents/Work/mmp/workspace/company-os/` | **Result:** unknown path prefix (`~/`); add to contract routing table if load-bearing (this plan itself defines the new work-concern routing, so this is expected) | **Severity:** info
11. **Step C — Claim:** `orianna-fact-check.sh` (line 59) | **Result:** unknown path prefix (bare script name, no directory); likely `scripts/orianna-fact-check.sh` — consider adding prefix | **Severity:** info
12. **Step C — Claim:** `apps/*`, `dashboards/*`, `.github/workflows/*` (line 34, describing `route_path()` behavior) | **Anchor:** bare prefixes resolve against strawberry-app | **Result:** prefixes exist; globs are descriptive | **Severity:** info
13. **Step C — Author-suppressed:** lines containing `<!-- orianna: ok -->` markers (lines 16, 26, 27, 28, 35, 53, 54, 57) — all tokens on these lines explicitly authorized by plan author | **Severity:** info (author-suppressed)
14. **Step D — Sibling files:** no `2026-04-21-orianna-work-repo-routing-tasks.md` or `-tests.md` found under `plans/` | **Result:** clean, one-plan-one-file rule satisfied | **Severity:** info

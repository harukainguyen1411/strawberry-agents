---
plan: plans/proposed/personal/2026-04-22-orianna-substance-vs-format-rescope.md
checked_at: 2026-04-22T06:48:03Z
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

1. **Step A — Frontmatter:** `status: proposed`, `owner: swain`, `created: 2026-04-22`, `tags: [...]` all present and well-formed | **Severity:** info
2. **Step B — Gating questions:** §10 contains six gating questions (OQ-1 through OQ-6); every one has an explicit `**Resolved:**` line recording Duong's pick. No unresolved `TBD` / `TODO` / `Decision pending` markers anywhere in the plan body | **Severity:** info
3. **Step C — Claim:** `assessments/plan-fact-checks/2026-04-21-demo-studio-v3-e2e-ship-v2-2026-04-21T09-50-32Z.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
4. **Step C — Claim:** `assessments/plan-fact-checks/2026-04-22-firebase-auth-for-demo-studio-2026-04-22T02-15-40Z.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
5. **Step C — Claim:** `assessments/plan-fact-checks/2026-04-22-firebase-auth-for-demo-studio-2026-04-22T02-28-28Z.md` and `assessments/plan-fact-checks/2026-04-22-explicit-model-on-agent-defs-2026-04-22T02-34-14Z.md` | **Anchor:** `test -e` | **Result:** both exist | **Severity:** info
6. **Step C — Claim:** `feedback/2026-04-21-orianna-signing-latency.md`, `feedback/2026-04-21-orianna-signing-followups.md`, `plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md` | **Anchor:** `test -e` | **Result:** all exist | **Severity:** info
7. **Step C — Claim:** `scripts/hooks/pre-commit-zz-plan-structure.sh`, `scripts/_lib_orianna_estimates.sh`, `scripts/_lib_plan_structure.sh`, `scripts/_lib_orianna_architecture.sh`, `scripts/fact-check-plan.sh` | **Anchor:** `test -e` | **Result:** all exist | **Severity:** info
8. **Step C — Claim:** `agents/orianna/claim-contract.md`, `agents/orianna/allowlist.md`, `agents/orianna/prompts/plan-check.md`, `agents/orianna/prompts/task-gate-check.md`, `agents/orianna/prompts/implementation-gate-check.md` | **Anchor:** `test -e` | **Result:** all exist | **Severity:** info
9. **Step C — Claim:** `scripts/orianna-sign.sh`, `scripts/orianna-verify-signature.sh`, `scripts/orianna-hash-body.sh`, `scripts/plan-promote.sh`, `scripts/orianna-fact-check.sh`, `scripts/orianna-memory-audit.sh` | **Anchor:** `test -e` | **Result:** all exist | **Severity:** info
10. **Step C — Claim:** `architecture/plan-lifecycle.md`, `agents/orianna/learnings/index.md` | **Anchor:** `test -e` | **Result:** both exist | **Severity:** info
11. **Step C — Claim:** `scripts/test-fact-check-concern-root-flip.sh`, `scripts/test-fact-check-false-positives.sh`, `scripts/test-fact-check-work-concern-routing.sh`, `scripts/test-orianna-lifecycle-smoke.sh` | **Anchor:** `test -e` | **Result:** all exist | **Severity:** info
12. **Step C — Author-suppressed:** many backtick tokens carry inline `<!-- orianna: ok -->` markers (e.g. `scripts/test-fact-check-substance-format-split.sh` as a prospective output file, the `2026-04-XX-orianna-rescope-canary.md` placeholder filename, Firebase-GitHub-App meta-examples in §4 risks, fenced-content references in §3, `/auth/login` and similar HTTP route citations in test-plan §R1/R2). All author-authorized per claim-contract §8 | **Severity:** info
13. **Step C — Unknown-prefix path tokens (non-block under personal routing):** HTTP route tokens cited in §1 evidence and §R1–R4 (e.g. `POST /auth/login`, `/auth/session/{sid}`, `/build`, `/verify`, `/logs`, `/approve`, `/foo/bar`, `/auth/login`) route to no known prefix; logged as info per current routing rules | **Severity:** info
14. **Step D — Sibling files:** `find plans -name "2026-04-22-orianna-substance-vs-format-rescope-tasks.md" -o -name "...-tests.md"` returned no results; one-plan-one-file rule satisfied | **Severity:** info

## External claims

None. No cited URLs, no library/SDK/version pins, no RFC citations appear in the plan body — Step E triggers not satisfied on any span.

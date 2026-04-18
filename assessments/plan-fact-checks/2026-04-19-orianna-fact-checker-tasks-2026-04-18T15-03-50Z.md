---
plan: plans/in-progress/2026-04-19-orianna-fact-checker-tasks.md
checked_at: 2026-04-18T15:03:50Z
auditor: orianna
claude_cli: present
block_findings: 3
warn_findings: 1
info_findings: 4
---

## Block findings

1. **Claim:** `plans/approved/2026-04-19-orianna-fact-checker.md` | **Anchor:** `test -e plans/approved/2026-04-19-orianna-fact-checker.md` | **Result:** not found (parent ADR now lives in `plans/in-progress/`; references at lines 11, 712, and 731 are stale) | **Severity:** block
2. **Claim:** `plans/proposed/2026-04-19-orianna-smoke-bad-plan.md` | **Anchor:** `test -e plans/proposed/2026-04-19-orianna-smoke-bad-plan.md` | **Result:** not found (seeded bad plan has not been created yet; token appears as a present-tense path in O6.1/O6.3/O6.4/O6.7 without a "Will:"/"Proposed:" marker) | **Severity:** block
3. **Claim:** `assessments/memory-audits/2026-04-19-memory-audit.md` | **Anchor:** `test -e assessments/memory-audits/2026-04-19-memory-audit.md` | **Result:** not found (report artifact from O6.5 has not been produced yet) | **Severity:** block

## Warn findings

1. **Claim:** cross-repo path tokens `apps/bogus/nonexistent.ts`, `apps/foo/bar.ts`, `.github/workflows/does-not-exist.yml` | **Anchor:** `test -e` against `~/Documents/Personal/strawberry-app/` | **Result:** could not verify 3 cross-repo path(s); strawberry-app checkout not found at `~/Documents/Personal/strawberry-app/` (per claim-contract §5) | **Severity:** warn

## Info findings

1. **Claim:** `~/Documents/Personal/strawberry-app/` | **Anchor:** n/a | **Result:** unknown path prefix (home-absolute); add to contract routing table if load-bearing | **Severity:** info
2. **Claim:** glob patterns `agents/*/memory/**`, `agents/*/learnings/**`, `agents/memory/**`, `plans/**`, `architecture/**`, `assessments/**`, `apps/**`, `.github/workflows/**`, `.claude/agents/*.md` | **Anchor:** n/a | **Result:** glob expressions, not concrete paths — not verifiable via `test -e` | **Severity:** info
3. **Claim:** template placeholders `assessments/plan-fact-checks/<plan-basename>-<ISO-timestamp>.md`, `assessments/memory-audits/<ISO-date>-memory-audit.md`, `agents/<name>/inbox.md` | **Anchor:** n/a | **Result:** template paths containing `<...>` placeholders; not literal paths | **Severity:** info
4. **Claim:** `/usr/bin:/bin` | **Anchor:** n/a | **Result:** PATH value in shell invocation example, not a filesystem path claim | **Severity:** info

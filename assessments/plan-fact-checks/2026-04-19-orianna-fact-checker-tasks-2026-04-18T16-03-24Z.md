---
plan: plans/in-progress/2026-04-19-orianna-fact-checker-tasks.md
checked_at: 2026-04-18T16:03:24Z
auditor: orianna
claude_cli: present
block_findings: 1
warn_findings: 0
info_findings: 2
---

## Block findings

1. **Claim:** `plans/approved/2026-04-19-orianna-fact-checker.md` (line 731, "Files touched") | **Anchor:** `test -e plans/approved/2026-04-19-orianna-fact-checker.md` | **Result:** not found — the parent ADR currently lives at `plans/in-progress/2026-04-19-orianna-fact-checker.md`, not `plans/approved/`. The same token on line 712 is suppressed with `<!-- orianna: ok -->`, but the line 731 reference is not. Either suppress it or update the path. | **Severity:** block

## Warn findings

None.

## Info findings

1. **Claim:** Multiple template/glob tokens containing `<...>`, `*`, or `**` (e.g. `agents/<name>/inbox.md`, `agents/*/memory/**`, `plans/**`, `assessments/plan-fact-checks/<plan-basename>-<ISO-timestamp>.md`) | **Anchor:** n/a — these are pattern templates, not literal paths | **Result:** treated as informational; path existence not applicable | **Severity:** info
2. **Claim:** author-suppressed lines via `<!-- orianna: ok -->` (seeded bad-plan paths `apps/bogus/nonexistent.ts`, `.github/workflows/does-not-exist.yml`, `apps/foo/bar.ts`, `plans/proposed/2026-04-19-orianna-smoke-bad-plan.md`, and parent-ADR line 712 / line 732) | **Anchor:** author-suppressed | **Result:** logged per contract §8 | **Severity:** info

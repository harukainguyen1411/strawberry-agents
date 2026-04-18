---
plan: plans/in-progress/2026-04-19-orianna-fact-checker-tasks.md
checked_at: 2026-04-18T16:09:45Z
auditor: orianna
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 2
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Claim:** `plans/approved/2026-04-19-orianna-fact-checker.md` | **Anchor:** `test -e plans/approved/2026-04-19-orianna-fact-checker.md` | **Result:** not found, but every occurrence in the plan (lines 712, 731) is author-suppressed via `<!-- orianna: ok -->` and the parent ADR currently lives at `plans/in-progress/2026-04-19-orianna-fact-checker.md` (O6.8 describes moving it through lifecycle) | **Severity:** info (author-suppressed)

2. **Claim:** Cross-repo path tokens `apps/bogus/nonexistent.ts`, `apps/foo/bar.ts`, `.github/workflows/does-not-exist.yml`, and `plans/proposed/2026-04-19-orianna-smoke-bad-plan.md` | **Anchor:** n/a | **Result:** all occurrences are on lines carrying `<!-- orianna: ok -->` markers (O6.1, O6.3, O6.4, O6.6, O6.7) — they are deliberate bad-plan seed references, explicitly authorized | **Severity:** info (author-suppressed)

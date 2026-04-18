---
plan: plans/in-progress/2026-04-19-orianna-fact-checker-tasks.md
checked_at: 2026-04-18T16:07:15Z
auditor: orianna
claude_cli: present
block_findings: 4
warn_findings: 0
info_findings: 5
---

## Block findings

<!-- Each entry: claim text | anchor attempted | failure reason -->

1. **Claim:** `apps/bogus/...` (line 631) | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/apps/bogus` | **Result:** not found | **Severity:** block
2. **Claim:** `apps/bogus/nonexistent.ts` (line 675) | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/apps/bogus/nonexistent.ts` | **Result:** not found | **Severity:** block
3. **Claim:** `apps/bogus/nonexistent.ts` (line 679) | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/apps/bogus/nonexistent.ts` | **Result:** not found | **Severity:** block
4. **Claim:** `apps/bogus/...` (line 688) | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/apps/bogus` | **Result:** not found | **Severity:** block

Note: these four references discuss the seeded-bad-plan fixture introduced in O6.1 and are meta-examples of the gate's own motivating bug. They appear on lines that lack the `<!-- orianna: ok -->` suppression marker (lines 550, 554, 562, 564, 672 DO carry the marker and pass silently). Author may add the marker to lines 631 / 675 / 679 / 688 to reconcile, or remove the backticks in favor of prose.

## Warn findings

None.

## Info findings

<!-- Author-suppressed (explicit `<!-- orianna: ok -->` marker on line) -->

1. **Claim:** `plans/proposed/2026-04-19-orianna-smoke-bad-plan.md` (lines 548, 562, 564, 602, 606, 696, 704) | **Severity:** info (author-suppressed)
2. **Claim:** `apps/bogus/nonexistent.ts` (line 550) | **Severity:** info (author-suppressed)
3. **Claim:** `.github/workflows/does-not-exist.yml` (line 554) | **Severity:** info (author-suppressed)
4. **Claim:** `apps/foo/bar.ts` (line 672) | **Severity:** info (author-suppressed)
5. **Claim:** `plans/approved/2026-04-19-orianna-fact-checker.md` (lines 712, 731) | **Severity:** info (author-suppressed; parent ADR currently lives at `plans/in-progress/2026-04-19-orianna-fact-checker.md` — path is a future-state lifecycle reference)

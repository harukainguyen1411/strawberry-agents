---
plan: plans/in-progress/2026-04-19-orianna-fact-checker-tasks.md
checked_at: 2026-04-18T15:57:18Z
auditor: orianna
claude_cli: present
block_findings: 1
warn_findings: 0
info_findings: 4
---

## Block findings

1. **Claim:** `plans/proposed/2026-04-19-orianna-smoke-bad-plan.md` | **Anchor:** `test -e plans/proposed/2026-04-19-orianna-smoke-bad-plan.md` | **Result:** not found | **Severity:** block

   Referenced as an existing artifact in O6.3 verification (`./scripts/plan-promote.sh plans/proposed/2026-04-19-orianna-smoke-bad-plan.md approved`), O6.4, O6.6, and O6.7. Task O6.1 is the creation step, and O6.7 is the cleanup-after-tests step, so the plan author may intend this as a forward-reference. If so, add `<!-- orianna: ok -->` to the lines that reference the file before it has been created (e.g. lines 562, 564, 602, 606, 696, 704), or cite the file by its O6.1 task ID instead of by path.

## Warn findings

None.

## Info findings

1. **Claim:** `agents/<name>/inbox.md` (line 94) | **Anchor:** template path with `<name>` placeholder | **Result:** template, not a real path | **Severity:** info — pattern reference, not load-bearing.

2. **Claim:** `assessments/plan-fact-checks/<plan-basename>-<ISO-timestamp>.md` (lines 215, 250) | **Anchor:** template filename with placeholders | **Result:** template, not a real path | **Severity:** info.

3. **Claim:** `assessments/memory-audits/<ISO-date>-memory-audit.md` (line 414) | **Anchor:** template filename with placeholder | **Result:** template, not a real path | **Severity:** info.

4. **Claim:** `.claude/agents/*.md` (line 509) | **Anchor:** glob, not a single path | **Result:** glob expression — agents directory exists with multiple `.md` files | **Severity:** info.

   Suppressed-by-author lines (logged for audit per contract §8): line 185 (`agents/orianna/allowlist.md` Section 2 examples including "Firebase GitHub App"), line 550 (`apps/bogus/nonexistent.ts`), line 554 (`.github/workflows/does-not-exist.yml`), line 672 (`apps/foo/bar.ts`), line 712 (`plans/approved/2026-04-19-orianna-fact-checker.md`), line 732 (`plans/in-progress/...` and `plans/implemented/...`). All carry `<!-- orianna: ok -->` and are explicitly authorized.

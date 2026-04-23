---
plan: plans/proposed/personal/2026-04-22-orianna-sign-staged-scope.md
checked_at: 2026-04-22T07:04:41Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 19
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** `status: proposed` | **Result:** present with expected value | **Severity:** info
2. **Step A — Frontmatter:** `owner: karma` | **Result:** present and non-blank | **Severity:** info
3. **Step A — Frontmatter:** `created: 2026-04-22` | **Result:** present and non-blank | **Severity:** info
4. **Step A — Frontmatter:** `tags: [orianna, plan-lifecycle, scripts, concurrency, bugfix]` | **Result:** present and non-empty | **Severity:** info
5. **Step C — Claim:** `scripts/orianna-sign.sh` (line 20, 93, References) | **Anchor:** `test -e scripts/orianna-sign.sh` | **Result:** exists | **Severity:** info
6. **Step C — Claim:** `scripts/hooks/pre-commit-orianna-signature-guard.sh` (line 21, References) | **Anchor:** `test -e scripts/hooks/pre-commit-orianna-signature-guard.sh` | **Result:** exists | **Severity:** info
7. **Step C — Claim:** `scripts/plan-promote.sh` (line 41, 110, References) | **Anchor:** `test -e scripts/plan-promote.sh` | **Result:** exists | **Severity:** info
8. **Step C — Claim:** `architecture/key-scripts.md` (line 123) | **Anchor:** `test -e architecture/key-scripts.md` | **Result:** exists | **Severity:** info
9. **Step C — Claim:** `plans/implemented/personal/2026-04-20-orianna-gated-plan-lifecycle.md` (References) | **Anchor:** `test -e plans/implemented/personal/2026-04-20-orianna-gated-plan-lifecycle.md` | **Result:** exists | **Severity:** info
10. **Step C — Claim (author-suppressed):** `STAGED_SCOPE` (line 15, title) | **Reason:** line bears `<!-- orianna: ok -->` marker | **Severity:** info
11. **Step C — Claim (author-suppressed):** `plans/` (line 23, prose) | **Reason:** line bears `<!-- orianna: ok -->` marker | **Severity:** info
12. **Step C — Claim (author-suppressed):** `plans/proposed/personal/2026-04-21-pre-lint-rename-aware.md` (line 27) | **Reason:** line bears `<!-- orianna: ok -->` marker (also verified to exist) | **Severity:** info
13. **Step C — Claim (author-suppressed):** `scripts/__tests__/test-orianna-sign-staged-scope.sh` (line 73, new file) | **Reason:** line bears `<!-- orianna: ok -->` marker | **Severity:** info
14. **Step C — Claim (author-suppressed):** `plans/proposed/` (line 75) | **Reason:** line bears `<!-- orianna: ok -->` marker | **Severity:** info
15. **Step C — Claim (author-suppressed):** `bash scripts/orianna-sign.sh <plan> approved` (line 78) | **Reason:** line bears `<!-- orianna: ok -->` marker | **Severity:** info
16. **Step C — Claim (author-suppressed):** `plans/` (line 133, Test plan invariant heading) | **Reason:** line bears `<!-- orianna: ok -->` marker | **Severity:** info
17. **Step C — Claim (author-suppressed):** `scripts/__tests__/` (line 147) | **Reason:** line bears `<!-- orianna: ok -->` marker | **Severity:** info
18. **Step C — Claim (author-suppressed):** `scripts/__tests__/test-orianna-sign-staged-scope.sh` (line 149) | **Reason:** line bears `<!-- orianna: ok -->` marker | **Severity:** info
19. **Step D — Sibling:** no `<basename>-tasks.md` or `<basename>-tests.md` under `plans/`; single-file layout confirmed | **Severity:** info

## External claims

None. Step E trigger heuristic matched no tokens: plan body contains no URLs, no version pins, no RFC/spec citations, and no named third-party library/SDK/framework assertions requiring live-doc verification. All technical claims are internal (git native flags such as `git commit -- <pathspec>` are POSIX/git-builtin commentary, not triggering external lookups).

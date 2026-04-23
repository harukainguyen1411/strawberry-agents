---
plan: plans/proposed/personal/2026-04-22-orianna-sign-staged-scope.md
checked_at: 2026-04-22T07:01:32Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 1
warn_findings: 0
info_findings: 14
external_calls_used: 0
---

## Block findings

1. **Step C — Claim:** `scripts/tests/` (line 144, "Test harness: the existing `scripts/tests/` POSIX bash pattern") | **Anchor:** `test -e scripts/tests/` against this repo's working tree | **Result:** not found — the repo uses `scripts/__tests__/` (and `scripts/hooks/tests/`); there is no `scripts/tests/` directory. The same path also appears unsuppressed in T1's Files entry (line 73) and T1 detail (line 79) — wait, those occurrences carry `<!-- orianna: ok -->` suppression markers, so only the line-144 reference is load-bearing. Either correct the path to `scripts/__tests__/` (and update T1/T2 file paths accordingly), or commit the new `scripts/tests/` directory creation as part of T1's DoD and re-run the gate. | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** `status: proposed` present and correct | **Severity:** info
2. **Step A — Frontmatter:** `owner: karma` present | **Severity:** info
3. **Step A — Frontmatter:** `created: 2026-04-22` present | **Severity:** info
4. **Step A — Frontmatter:** `tags: [orianna, plan-lifecycle, scripts, concurrency, bugfix]` present and non-empty | **Severity:** info
5. **Step C — Claim:** `scripts/orianna-sign.sh` | **Anchor:** `test -e scripts/orianna-sign.sh` | **Result:** exists | **Severity:** info
6. **Step C — Claim:** `scripts/plan-promote.sh` | **Anchor:** `test -e scripts/plan-promote.sh` | **Result:** exists | **Severity:** info
7. **Step C — Claim:** `scripts/hooks/pre-commit-orianna-signature-guard.sh` (line 22, suppressed via `<!-- orianna: ok -->`; also referenced unsuppressed at line 152) | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
8. **Step C — Claim:** `architecture/key-scripts.md` | **Anchor:** `test -e architecture/key-scripts.md` | **Result:** exists | **Severity:** info
9. **Step C — Claim:** `plans/implemented/personal/2026-04-20-orianna-gated-plan-lifecycle.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
10. **Step C — Claim:** `plans/proposed/personal/2026-04-21-pre-lint-rename-aware.md` (frontmatter `related:` reference; also suppressed at line 27) | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
11. **Step C — Suppressed (author-authorized via `<!-- orianna: ok -->`):** `scripts/tests/test-orianna-sign-staged-scope.sh` on lines 73 and 147 — new file to be created in T1; suppression honored. | **Severity:** info
12. **Step C — Suppressed:** `plans/` references on lines 22, 75, 133 (all carry `<!-- orianna: ok -->`); these are conceptual references to the plans subtree, not specific paths. | **Severity:** info
13. **Step C — Suppressed:** title line 15 and instruction lines 27, 78 carry `<!-- orianna: ok -->` markers; tokens on those lines logged as author-suppressed. | **Severity:** info
14. **Step D — Sibling files:** searched `plans/**` for `2026-04-22-orianna-sign-staged-scope-tasks.md` and `2026-04-22-orianna-sign-staged-scope-tests.md` — none found; one-plan-one-file rule satisfied. | **Severity:** info

## External claims

None. (Step E trigger heuristic did not fire: no named libraries/SDKs/frameworks beyond implicitly allowlisted git/bash POSIX tooling, no version numbers, no URLs, no RFC citations.)

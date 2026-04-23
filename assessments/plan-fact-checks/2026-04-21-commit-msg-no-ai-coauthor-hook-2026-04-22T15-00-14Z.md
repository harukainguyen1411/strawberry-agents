---
plan: plans/proposed/personal/2026-04-21-commit-msg-no-ai-coauthor-hook.md
checked_at: 2026-04-22T15:00:14Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 11
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** `owner: karma` present | **Result:** pass | **Severity:** info
2. **Step C — Claim:** `scripts/install-hooks.sh` | **Anchor:** `test -e scripts/install-hooks.sh` | **Result:** exists | **Severity:** info
3. **Step C — Claim:** `scripts/hooks/` | **Anchor:** `test -e scripts/hooks` | **Result:** exists | **Severity:** info (line contains `<!-- orianna: ok` suppressor; author-suppressed)
4. **Step C — Claim:** `scripts/hooks/commit-msg-no-ai-coauthor.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info (author-suppressed on source line)
5. **Step C — Claim:** `architecture/key-scripts.md` | **Anchor:** `test -e architecture/key-scripts.md` | **Result:** exists | **Severity:** info
6. **Step C — Claim:** `scripts/hooks/tests/commit-msg-no-ai-coauthor.test.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info (author-suppressed on source line)
7. **Step C — Claim:** `architecture/plan-lifecycle.md` | **Anchor:** `test -e architecture/plan-lifecycle.md` | **Result:** exists | **Severity:** info (author-suppressed on source line)
8. **Step C — Claim:** `architecture/` | **Anchor:** directory exists | **Result:** exists | **Severity:** info (author-suppressed on source line)
9. **Step C — Claim:** `scripts/hooks/tests/` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info (author-suppressed on source line)
10. **Step C — Non-claim skips:** HTTP-less tokens (commit SHAs `663c274`, `bcc66d1`, `54ac1bf`, `d2cb0e0`, `51383944d7fdfc6e65fdd04e078461116317c102`, `b77f2eb37716392196f0bc3c10946f22a54fe86d`), whitespace-containing trailer examples, regex patterns in §3, and verb tokens (`pre-commit`, `pre-push`, `commit-msg`, `Co-Authored-By:`, `Human-Verified: yes`) classified as non-claim per contract §2 | **Severity:** info
11. **Step D — Sibling check:** `find plans -name 2026-04-21-commit-msg-no-ai-coauthor-hook-{tasks,tests}.md` | **Result:** no sibling files; plan is single-file compliant | **Severity:** info

## External claims

None. (Step E trigger heuristic did not fire: no named libraries/SDKs/versions requiring live-doc verification outside of self-referential tooling. The two http(s) URLs present are GitHub PR/Actions run links used as evidence in the post-hoc `## Test results` section, not factual assertions about external state.)

---
plan: plans/proposed/personal/2026-04-22-concurrent-coordinator-race-closeout.md
checked_at: 2026-04-22T08:57:18Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 2
warn_findings: 0
info_findings: 8
external_calls_used: 0
---

## Block findings

1. **Step C — Claim:** `plans/in-progress/personal/2026-04-22-orianna-sign-staged-scope.md` (frontmatter `related:` entry, line 11) | **Anchor:** `test -e plans/in-progress/personal/2026-04-22-orianna-sign-staged-scope.md` | **Result:** not found — the plan still lives at `plans/proposed/personal/2026-04-22-orianna-sign-staged-scope.md` (has not been promoted to `in-progress/`). Either promote the referenced plan first or correct the path to `proposed/`. | **Severity:** block
2. **Step C — Claim:** `plans/in-progress/personal/2026-04-22-orianna-sign-staged-scope.md` (References section, line 163) | **Anchor:** `test -e plans/in-progress/personal/2026-04-22-orianna-sign-staged-scope.md` | **Result:** not found — same path as finding #1; actual location is `plans/proposed/personal/...`. | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step C — Claim:** `scripts/plan-promote.sh` | **Anchor:** `test -e scripts/plan-promote.sh` | **Result:** exists | **Severity:** info
2. **Step C — Claim:** `scripts/orianna-sign.sh` | **Anchor:** `test -e scripts/orianna-sign.sh` | **Result:** exists | **Severity:** info
3. **Step C — Claim:** `scripts/__tests__/test-orianna-sign-staged-scope.sh` | **Anchor:** `test -e scripts/__tests__/test-orianna-sign-staged-scope.sh` | **Result:** exists | **Severity:** info
4. **Step C — Claim:** `architecture/key-scripts.md` | **Anchor:** `test -e architecture/key-scripts.md` | **Result:** exists | **Severity:** info
5. **Step C — Claim:** `agents/evelynn/inbox/archive/2026-04/2026-04-22-bash-cwd-wedge-feedback.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
6. **Step C — Claim:** `agents/ekko/learnings/2026-04-22-promote-to-implemented-signature-invalidation.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
7. **Step C — Claim:** `scripts/__tests__/test-orianna-sign-lock.sh`, `scripts/__tests__/test-coordinator-lock-shared.sh`, `scripts/_lib_coordinator_lock.sh` (new files proposed by Tasks §1/§2/§3/§7) | **Result:** author-suppressed via trailing `<!-- orianna: ok -->`; not-yet-existing paths expected | **Severity:** info
8. **Step C — Claim:** `.git/strawberry-promote.lock` (proposed runtime lockfile, lines 47/99/103) | **Result:** unknown path prefix `.git/`; add to contract routing table if load-bearing. Author's inline comments on lines 37/47 (`<!-- orianna: ok -- runtime lockfile ... -->`) are a malformed suppression marker (the exact substring `<!-- orianna: ok -->` is not present because the author embedded explanatory text between `--` and `-->`). The path is non-existent-by-design (created at runtime under `.git/`), so no block is emitted, but authors should either use the canonical marker form or add `.git/` to the routing table. | **Severity:** info

## External claims

None.

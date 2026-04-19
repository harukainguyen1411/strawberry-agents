---
plan: plans/proposed/2026-04-19-reviewer-identity-split.md
checked_at: 2026-04-19T12:45:31Z
auditor: orianna
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 12
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Claim:** `scripts/reviewer-auth.sh` | **Anchor:** `test -e scripts/reviewer-auth.sh` | **Result:** exists | **Severity:** info
2. **Claim:** `.claude/agents/senna.md` | **Anchor:** `test -e .claude/agents/senna.md` | **Result:** exists | **Severity:** info
3. **Claim:** `.claude/agents/lucian.md` | **Anchor:** `test -e .claude/agents/lucian.md` | **Result:** exists | **Severity:** info
4. **Claim:** `tools/decrypt.sh` | **Anchor:** `test -e tools/decrypt.sh` | **Result:** exists | **Severity:** info
5. **Claim:** `plans/approved/2026-04-19-stale-green-merge-gap.md` | **Anchor:** `test -e plans/approved/2026-04-19-stale-green-merge-gap.md` | **Result:** exists | **Severity:** info
6. **Claim:** `agents/camille/learnings/2026-04-19-branch-protection-probe-and-rulesets.md` | **Anchor:** `test -e agents/camille/learnings/2026-04-19-branch-protection-probe-and-rulesets.md` | **Result:** exists | **Severity:** info
7. **Claim:** `secrets/encrypted/reviewer-github-token.age` | **Anchor:** unknown path prefix `secrets/`; add to contract if load-bearing (file resolves locally: exists) | **Result:** unknown prefix | **Severity:** info
8. **Claim:** `secrets/encrypted/reviewer-github-token-senna.age` | **Anchor:** unknown path prefix `secrets/`; path is proposed (Phase 2) — not expected to exist pre-promotion | **Result:** unknown prefix | **Severity:** info
9. **Claim:** `secrets/reviewer-github-token-senna.txt` | **Anchor:** unknown path prefix `secrets/`; ephemeral Phase 1 file | **Result:** unknown prefix | **Severity:** info
10. **Claim:** `secrets/branch-protection-pre-rollout.json` | **Anchor:** unknown path prefix `secrets/`; rollback artifact created in Phase 7 | **Result:** unknown prefix | **Severity:** info
11. **Claim:** `senna.md` / `lucian.md` (bare filenames, no prefix) | **Anchor:** unknown path prefix; treated as shorthand for `.claude/agents/<name>.md` which resolve | **Result:** unknown prefix | **Severity:** info
12. **Claim:** `strawberry-reviewers` / `strawberry-reviewers-2` (GitHub account names) | **Anchor:** anchored in plan prose (Context + Phase 1 provisioning); not on vendor allowlist; considered plan-local identifiers being introduced by this ADR | **Result:** plan-local identifier | **Severity:** info

---
plan: plans/proposed/2026-04-19-reviewer-identity-split.md
checked_at: 2026-04-19T12:43:56Z
auditor: orianna
claude_cli: present
block_findings: 1
warn_findings: 0
info_findings: 10
---

## Block findings

1. **Claim:** `plans/proposed/2026-04-19-stale-green-merge-gap.md` | **Anchor:** `test -e plans/proposed/2026-04-19-stale-green-merge-gap.md` | **Result:** not found | **Severity:** block

## Warn findings

None.

## Info findings

1. **Claim:** `scripts/reviewer-auth.sh` | **Anchor:** `test -e scripts/reviewer-auth.sh` | **Result:** exists | **Severity:** info
2. **Claim:** `tools/decrypt.sh` | **Anchor:** `test -e tools/decrypt.sh` | **Result:** exists | **Severity:** info
3. **Claim:** `.claude/agents/senna.md` | **Anchor:** `test -e .claude/agents/senna.md` | **Result:** exists | **Severity:** info
4. **Claim:** `.claude/agents/lucian.md` | **Anchor:** `test -e .claude/agents/lucian.md` | **Result:** exists | **Severity:** info
5. **Claim:** `agents/camille/learnings/2026-04-19-branch-protection-probe-and-rulesets.md` | **Anchor:** `test -e` same | **Result:** exists | **Severity:** info
6. **Claim:** `secrets/encrypted/reviewer-github-token.age` | **Anchor:** unknown path prefix `secrets/`; add to contract routing table if load-bearing | **Result:** unknown prefix (file exists on disk but prefix not routed) | **Severity:** info
7. **Claim:** `secrets/encrypted/reviewer-github-token-senna.age` | **Anchor:** unknown path prefix `secrets/` | **Result:** unknown prefix (net-new file per plan; not yet on disk) | **Severity:** info
8. **Claim:** `secrets/reviewer-github-token-senna.txt` | **Anchor:** unknown path prefix `secrets/` | **Result:** unknown prefix | **Severity:** info
9. **Claim:** `secrets/branch-protection-pre-rollout.json` | **Anchor:** unknown path prefix `secrets/` | **Result:** unknown prefix | **Severity:** info
10. **Claim:** `apps/**` | **Anchor:** cross-repo glob referencing `apps/` in strawberry-app | **Result:** glob pattern, not a concrete path; referenced generically | **Severity:** info

---
plan: plans/proposed/personal/2026-04-20-orianna-web-research-verification.md
checked_at: 2026-04-20T17:12:11Z
auditor: orianna
check_version: 2
claude_cli: present
block_findings: 5
warn_findings: 0
info_findings: 14
---

## Block findings

1. **Step C — Claim:** `.claude/agents/orianna.md` | **Anchor:** `test -e .claude/agents/orianna.md` | **Result:** not found (Decisions §6 asserts the file does not exist today; without a `<!-- orianna: ok -->` suppression marker the gate must still test it and flag absence) | **Severity:** block
2. **Step C — Claim:** `scripts/test-orianna-plan-check-step-e.sh` | **Anchor:** `test -e scripts/test-orianna-plan-check-step-e.sh` | **Result:** not found (marked `(new)` in Task T4; add a `<!-- orianna: ok -->` suppression on the T4 heading/file line or pre-create an empty stub before approval) | **Severity:** block
3. **Step C — Claim:** `WebFetch` (integration-shaped token, appears in Decisions §3/§6 and Tasks T1/T4/Test plan) | **Anchor:** `agents/orianna/allowlist.md` lookup | **Result:** not on allowlist (not in Section 1 vendor bare names nor Section 2 specific integrations); per strict-default rule §4 unverified integration names block | **Severity:** block
4. **Step C — Claim:** `WebSearch` (integration-shaped token, appears in Decisions §3/§6 and Tasks T1/T4/Test plan) | **Anchor:** `agents/orianna/allowlist.md` lookup | **Result:** not on allowlist; per strict-default rule §4 unverified integration names block | **Severity:** block
5. **Step C — Claim:** `context7` (integration-shaped token, appears in Decisions §3/§6 and Tasks T1/T4/Test plan) | **Anchor:** `agents/orianna/allowlist.md` lookup | **Result:** not on allowlist; per strict-default rule §4 unverified integration names block | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** `status: proposed` present and correct.
2. **Step A — Frontmatter:** `owner: karma` present.
3. **Step A — Frontmatter:** `created: 2026-04-20` present.
4. **Step A — Frontmatter:** `tags:` present with non-empty list (orianna, fact-check, tooling, quick-lane).
5. **Step B — Gating questions:** no `## Open questions`, `## Gating questions`, or `## Unresolved` section; no gating markers to resolve.
6. **Step C — Claim:** `agents/orianna/prompts/plan-check.md` | **Anchor:** `test -e` | **Result:** exists.
7. **Step C — Claim:** `plans/proposed/2026-04-19-orianna-role-redesign.md` | **Anchor:** `test -e` | **Result:** exists.
8. **Step C — Claim:** `agents/orianna/profile.md` | **Anchor:** `test -e` | **Result:** exists.
9. **Step C — Claim:** `scripts/orianna-fact-check.sh` | **Anchor:** `test -e` | **Result:** exists.
10. **Step C — Claim:** `scripts/fact-check-plan.sh` | **Anchor:** `test -e` | **Result:** exists.
11. **Step C — Claim:** `agents/orianna/claim-contract.md` | **Anchor:** `test -e` | **Result:** exists.
12. **Step C — Claim:** `plans/proposed/` | **Anchor:** `test -e` | **Result:** exists.
13. **Step C — Claim:** `claude` (CLI tool) | **Anchor:** allowlist.md §Usage notes | **Result:** implicitly allowlisted as a standard CLI tool.
14. **Step D — Sibling files:** no `2026-04-20-orianna-web-research-verification-tasks.md` or `-tests.md` sibling files present; §D3 one-plan-one-file rule satisfied.

## Remediation hints (non-blocking commentary)

- For findings 3–5 (`WebFetch`, `WebSearch`, `context7`): either (a) add these names to `agents/orianna/allowlist.md` Section 1 as Claude Code / MCP tool primitives in a same-PR amendment, or (b) append `<!-- orianna: ok -->` on each line that cites them. Option (a) is preferable since this plan will likely not be the last to reference these tools.
- For finding 1 (`.claude/agents/orianna.md`): add `<!-- orianna: ok -->` at the end of the sentence that cites the path as a known-absent reference, per contract §8.
- For finding 2 (`scripts/test-orianna-plan-check-step-e.sh`): add `<!-- orianna: ok -->` at the end of the T4 `files:` bullet, or use the standalone-marker form on the preceding line.

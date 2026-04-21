---
plan: plans/proposed/personal/2026-04-20-orianna-web-research-verification.md
checked_at: 2026-04-21T02:45:09Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 10
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** all required fields present (`status: proposed`, `owner: karma`, `created: 2026-04-20`, `tags: [orianna, fact-check, tooling, quick-lane]`) | **Severity:** info
2. **Step B — Gating questions:** no `## Open questions` / `## Gating questions` / `## Unresolved` section; no unresolved markers | **Severity:** info
3. **Step C — Claim:** `agents/orianna/prompts/plan-check.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
4. **Step C — Claim:** `plans/proposed/2026-04-19-orianna-role-redesign.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
5. **Step C — Claim:** `agents/orianna/claim-contract.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
6. **Step C — Claim:** `scripts/orianna-fact-check.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
7. **Step C — Claim:** `agents/orianna/profile.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
8. **Step C — Claim:** `scripts/fact-check-plan.sh` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
9. **Step C — Claim:** `assessments/plan-fact-checks/2026-04-20-orianna-web-research-verification-2026-04-21T02-37-29Z.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
10. **Step C — Suppressed (author-authorized):** `.claude/agents/orianna.md` (line 92, known-absent per inline note), `scripts/test-orianna-plan-check-step-e.sh` (line 176, to-be-created new file), `bash scripts/test-orianna-plan-check-step-e.sh` (line 187, preceding standalone marker) | **Severity:** info
11. **Step D — Siblings:** `find plans -name "2026-04-20-orianna-web-research-verification-{tasks,tests}.md"` returned no matches; single-file layout honored | **Severity:** info

## External claims

1. **Step E — External:** tokens `v15.2`, `>=0.30`, `RFC 9110`, `Next.js`, `Anthropic SDK`, `firebase-cli`, `client.completions.create`, `client.messages.create` all appear in prose defining the Step E trigger heuristic itself (Decisions §2, Test plan §1) as META-EXAMPLES of what would trigger Step E, not as active factual assertions the plan relies on | **Tool:** none (trigger not fired — no present-tense claim) | **Result:** classified as meta-examples per claim-contract §2 ("speculative/future-state statements") | **Severity:** info

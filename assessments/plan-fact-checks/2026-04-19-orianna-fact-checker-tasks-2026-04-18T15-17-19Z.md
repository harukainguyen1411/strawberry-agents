---
plan: plans/in-progress/2026-04-19-orianna-fact-checker-tasks.md
checked_at: 2026-04-18T15:17:19Z
auditor: orianna
claude_cli: present
block_findings: 2
warn_findings: 1
info_findings: 6
---

## Block findings

1. **Claim:** `plans/approved/2026-04-19-orianna-fact-checker.md` | **Anchor:** `test -e plans/approved/2026-04-19-orianna-fact-checker.md` | **Result:** not found (the parent ADR currently lives at `plans/in-progress/2026-04-19-orianna-fact-checker.md` per this plan's own frontmatter; body text in §O6.8 references the approved-path location which does not exist on disk) | **Severity:** block

2. **Claim:** `Firebase GitHub App` | **Anchor:** none | **Result:** integration name appears in `agents/orianna/allowlist.md` Section 2 as requiring an anchor (file/line, `gh api` confirmation, or vendor docs link). The plan uses it as a meta/example reference but provides no anchor; per claim-contract §4 strict default, unanchored Section-2 integration names block. | **Severity:** block

## Warn findings

1. **Claim:** cross-repo paths `apps/bogus/nonexistent.ts`, `apps/foo/bar.ts`, `.github/workflows/does-not-exist.yml` | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/...` | **Result:** could not verify 3 cross-repo path(s); strawberry-app checkout not found at `~/Documents/Personal/strawberry-app/`. Per contract §5 the check itself is demoted to warn when checkout is absent. (Note: these tokens are explicitly described in-prose as deliberately-nonexistent test scaffolding for negative smoke tests, so the underlying claims are intentional.) | **Severity:** warn

## Info findings

1. **Claim:** glob/scope patterns `agents/*/memory/**`, `agents/*/learnings/**`, `agents/memory/**`, `plans/**`, `architecture/**`, `assessments/**`, `apps/**`, `.github/workflows/**`, `.claude/agents/*.md` | **Anchor:** n/a | **Result:** unknown path shape (glob patterns, not concrete paths); not load-bearing as filesystem references. | **Severity:** info

2. **Claim:** placeholder paths `plans/in-progress/...`, `plans/implemented/...`, `assessments/plan-fact-checks/<plan-basename>-<ISO-timestamp>.md`, `assessments/memory-audits/<ISO-date>-memory-audit.md`, `agents/<name>/inbox.md` | **Anchor:** n/a | **Result:** template placeholders, not literal paths. | **Severity:** info

3. **Claim:** rule anchors `#rule-plan-writers-no-assignment`, `#rule-prefer-roster-agents` | **Anchor:** n/a | **Result:** unknown path prefix `#`; treated as in-doc rule references. | **Severity:** info

4. **Claim:** future-state output paths flagged `(NEW)` in §O1-§O5 (`agents/orianna/profile.md`, `agents/orianna/inbox.md`, `agents/orianna/memory/MEMORY.md`, `agents/orianna/learnings/index.md`, `agents/orianna/claim-contract.md`, `agents/orianna/allowlist.md`, `agents/orianna/prompts/plan-check.md`, `agents/orianna/prompts/memory-audit.md`, `agents/orianna/runbook-reconciliation.md`, `scripts/orianna-fact-check.sh`, `scripts/fact-check-plan.sh`, `scripts/orianna-memory-audit.sh`, `agents/memory/agents-table.md`, `assessments/memory-audits/.gitkeep`, `assessments/plan-fact-checks/.gitkeep`, `.claude/agents/orianna.md`) | **Anchor:** `test -e` | **Result:** all resolve cleanly in the working tree (the plan is partially implemented). Clean pass, anchors confirmed. | **Severity:** info

5. **Claim:** existing-file references (`scripts/plan-promote.sh`, `agents/memory/agent-network.md`, `agents/evelynn/CLAUDE.md`, `.claude/agents/skarner.md`, `.claude/agents/jhin.md`, `agents/skarner/`, `agents/yuumi/`, `plans/approved/2026-04-19-public-app-repo-migration.md`, `plans/in-progress/2026-04-19-orianna-fact-checker.md`, `plans/proposed/`, `plans/approved/`, `plans/in-progress/`, `plans/implemented/`, `assessments/plan-fact-checks/`, `assessments/memory-audits/`) | **Anchor:** `test -e` | **Result:** all resolve cleanly. | **Severity:** info

6. **Claim:** seeded-bad-plan path `plans/proposed/2026-04-19-orianna-smoke-bad-plan.md` | **Anchor:** `test -e` | **Result:** not present (per §O6.7 it is intentionally deleted at end of smoke testing); future-state in §O6.1, expected absence post-§O6.7. | **Severity:** info

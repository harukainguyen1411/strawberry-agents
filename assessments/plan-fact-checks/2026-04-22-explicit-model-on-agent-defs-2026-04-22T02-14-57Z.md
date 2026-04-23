---
plan: plans/proposed/personal/2026-04-22-explicit-model-on-agent-defs.md
checked_at: 2026-04-22T02:14:57Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 25
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** all required fields present (`status: proposed`, `owner: karma`, `created: 2026-04-22`, `tags: [agents, frontmatter, governance, claude-md-rule-9]`). | **Severity:** info
2. **Step B — Gating:** `## Open questions` section contains "None blocking. One deferral..." — no unresolved TBD/TODO/Decision-pending markers. | **Severity:** info
3. **Step C — Claim:** `.claude/agents/aphelios.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
4. **Step C — Claim:** `.claude/agents/azir.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
5. **Step C — Claim:** `.claude/agents/swain.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
6. **Step C — Claim:** `.claude/agents/kayn.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
7. **Step C — Claim:** `.claude/agents/lux.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
8. **Step C — Claim:** `.claude/agents/karma.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
9. **Step C — Claim:** `.claude/agents/evelynn.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
10. **Step C — Claim:** `.claude/agents/sona.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
11. **Step C — Claim:** `.claude/agents/senna.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
12. **Step C — Claim:** `.claude/agents/lucian.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
13. **Step C — Claim:** `.claude/agents/caitlyn.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
14. **Step C — Claim:** `.claude/agents/xayah.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
15. **Step C — Claim:** `.claude/agents/heimerdinger.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
16. **Step C — Claim:** `.claude/agents/camille.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
17. **Step C — Claim:** `.claude/agents/lulu.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
18. **Step C — Claim:** `.claude/agents/neeko.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
19. **Step C — Claim:** `.claude/_script-only-agents/orianna.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
20. **Step C — Claim:** `.claude/agents/lissandra.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
21. **Step C — Claim:** `.claude/agents/skarner.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
22. **Step C — Claim:** `.claude/agents/yuumi.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
23. **Step C — Claim:** `CLAUDE.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
24. **Step C — Claim:** `plans/pre-orianna/implemented/2026-04-20-agent-pair-taxonomy.md` | **Anchor:** `test -e` | **Result:** found | **Severity:** info
25. **Step D — Sibling-file grep:** no `*-tasks.md` or `*-tests.md` siblings found in `plans/`; one-plan-one-file rule honored. | **Severity:** info

(Many additional backtick spans in the plan body — e.g. command examples like `grep -L "^model:" <files>`, `grep -nE "^model: (opus|sonnet)-[0-9]" ...`, persona names like Aphelios/Azir/etc. covered by §2 non-claim "named agent roles", and frontmatter literals like `model: opus`/`model: sonnet` — are not load-bearing repo paths or unanchored integration names and pass without flag. A large fraction of the plan's path-shaped tokens are also explicitly suppressed via `<!-- orianna: ok -->` markers; those are author-suppressed and pass as info.)

## External claims

None. (Step E was not triggered: the plan contains no library/SDK/framework names with version pins, no http(s):// URLs, and no RFC/spec citations. All claims are internal repo-state assertions covered by Step C.)

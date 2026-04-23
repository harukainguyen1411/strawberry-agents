---
plan: plans/proposed/personal/2026-04-22-explicit-model-on-agent-defs.md
checked_at: 2026-04-22T02:17:57Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 1
warn_findings: 0
info_findings: 21
external_calls_used: 0
---

## Block findings

1. **Step A — Frontmatter:** `status:` field value is `approved`; expected exactly `proposed` for the proposed→approved gate. The plan file lives under `plans/proposed/personal/` but its frontmatter status has been pre-set to `approved`, which bypasses the lifecycle semantics the gate enforces. Use `scripts/plan-promote.sh` (which rewrites `status:` after the Orianna signature is recorded) rather than hand-editing the field. | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step C — Path:** `.claude/agents/aphelios.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
2. **Step C — Path:** `.claude/agents/azir.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
3. **Step C — Path:** `.claude/agents/swain.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
4. **Step C — Path:** `.claude/agents/kayn.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
5. **Step C — Path:** `.claude/agents/lux.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
6. **Step C — Path:** `.claude/agents/karma.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
7. **Step C — Path:** `.claude/agents/evelynn.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
8. **Step C — Path:** `.claude/agents/sona.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
9. **Step C — Path:** `.claude/agents/senna.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
10. **Step C — Path:** `.claude/agents/lucian.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
11. **Step C — Path:** `.claude/agents/caitlyn.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
12. **Step C — Path:** `.claude/agents/xayah.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
13. **Step C — Path:** `.claude/agents/heimerdinger.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
14. **Step C — Path:** `.claude/agents/camille.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
15. **Step C — Path:** `.claude/agents/lulu.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
16. **Step C — Path:** `.claude/agents/neeko.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
17. **Step C — Path:** `.claude/_script-only-agents/orianna.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
18. **Step C — Path:** `CLAUDE.md` | **Anchor:** `test -e` | **Result:** exists | **Severity:** info
19. **Step C — Path:** `scripts/hooks/` (line 134) | **Anchor:** `test -e` | **Result:** exists; also suppressed via `<!-- orianna: ok -->` | **Severity:** info (author-suppressed)
20. **Step C — Author-suppressed:** multiple references on lines 16, 20, 26, 56, 57, 67, 71, 87, 89, 91, 103, 106, 119–128, 134, 140 explicitly blessed via `<!-- orianna: ok -->`. Covers `CLAUDE.md:63`, `plans/pre-orianna/implemented/2026-04-20-agent-pair-taxonomy.md:*`, `.claude/agents/_shared/`, and taxonomy ADR anchors. All logged as author-suppressed per contract §8. | **Severity:** info
21. **Step C — Integration:** "Claude Code" / "Sonnet 4.6" / "Opus 4.7" (model-tier identifiers in prose) | **Anchor:** vendor-generic platform language, not a specific integration per allowlist §2 distinction | **Result:** informational | **Severity:** info

## External claims

None. (No named libraries/SDKs with version pins, no explicit URLs, no RFC/spec citations detected. Step E did not trigger.)

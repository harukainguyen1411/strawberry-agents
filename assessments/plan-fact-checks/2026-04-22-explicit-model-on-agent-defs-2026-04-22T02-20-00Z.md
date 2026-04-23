---
plan: plans/proposed/personal/2026-04-22-explicit-model-on-agent-defs.md
checked_at: 2026-04-22T02:20:00Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 19
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** `status: proposed` present | **Result:** pass
2. **Step A — Frontmatter:** `owner: karma` present | **Result:** pass
3. **Step A — Frontmatter:** `created: 2026-04-22` present | **Result:** pass
4. **Step A — Frontmatter:** `tags: [agents, frontmatter, governance, claude-md-rule-9]` present | **Result:** pass
5. **Step B — Gating:** `## Open questions` contains "None blocking" + one non-blocking deferral; no `TBD`/`TODO`/`Decision pending` markers | **Result:** pass
6. **Step C — Path:** `.claude/agents/aphelios.md` | **Anchor:** `test -e` | **Result:** exists
7. **Step C — Path:** `.claude/agents/azir.md`, `caitlyn.md`, `camille.md`, `evelynn.md`, `heimerdinger.md`, `karma.md`, `kayn.md`, `lucian.md`, `lulu.md`, `lux.md`, `neeko.md`, `senna.md`, `sona.md`, `swain.md`, `xayah.md` (Opus-tier agent batch) | **Anchor:** `test -e` each | **Result:** all exist
8. **Step C — Path:** `.claude/_script-only-agents/orianna.md` | **Anchor:** `test -e` | **Result:** exists
9. **Step C — Path:** `CLAUDE.md` (cited as `CLAUDE.md:63` and bare) | **Anchor:** `test -e CLAUDE.md` | **Result:** exists
10. **Step C — Path:** `plans/pre-orianna/implemented/2026-04-20-agent-pair-taxonomy.md` | **Anchor:** `test -e` | **Result:** exists
11. **Step C — Glob:** `.claude/agents/*.md` (directory reference) | **Anchor:** `test -e .claude/agents/` | **Result:** exists
12. **Step C — Glob:** `.claude/_script-only-agents/*.md` | **Anchor:** `test -e .claude/_script-only-agents/` | **Result:** exists
13. **Step C — Author-suppressed** (line 16): frontmatter/CLAUDE.md citations in Context paragraph | **Marker:** `<!-- orianna: ok -->`
14. **Step C — Author-suppressed** (lines 20, 26, 56, 57, 67, 71, 79, 87, 89, 91, 103, 106, 119, 120, 121, 122, 123, 124, 125, 126, 127, 134, 140): various inline path/command/blockquote citations | **Marker:** `<!-- orianna: ok -->`
15. **Step C — Token:** `model:`, `model: opus`, `model: sonnet`, `model: haiku`, `model: opus-4-7`, `model: sonnet-4-6` | **Classification:** YAML field/value literals, not integration names or paths | **Result:** non-claim
16. **Step C — Token:** `grep`, `ls`, `test`, `grep -L`, `grep -H`, `grep -n`, `grep -nE` | **Classification:** POSIX utilities (implicitly allowlisted per allowlist §Usage notes) | **Result:** pass
17. **Step D — Sibling grep:** `find plans -name "2026-04-22-explicit-model-on-agent-defs-tasks.md" -o -name "2026-04-22-explicit-model-on-agent-defs-tests.md"` | **Result:** no siblings; single-file ADR layout satisfied
18. **Step E — Trigger scan:** plan body contains no URLs, no named libraries/SDKs outside agent-roster names, no RFC citations, no external version numbers | **Result:** Step E did not fire on any token; 0/15 external calls used
19. **Step E — Note:** "Opus 4.7" and "Sonnet 4.6" in TP2/TP3 are Claude model aliases used in prose within an `<!-- orianna: ok -->`-suppressed line (106) or non-triggering context (107); not externally verifiable as vendor SDK claims under §E.1 heuristic

## External claims

None.

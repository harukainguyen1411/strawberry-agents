---
plan: plans/proposed/2026-04-19-claude-usage-dashboard-tasks.md
checked_at: 2026-04-18T16:24:41Z
auditor: orianna
claude_cli: present
block_findings: 2
warn_findings: 0
info_findings: 8
---

## Block findings

1. **Claim:** `dashboards/usage-dashboard/index.html` (line 273, T6 Behavior — `bash build.sh && open dashboards/usage-dashboard/index.html`) | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/dashboards/usage-dashboard/index.html` | **Result:** not found | **Severity:** block
   - Note: Path is slated to be created by T1/T7 of this plan but appears in present-tense behavior text without a "Will:"/"Proposed:" marker. Per claim-contract §2 and §4 strict default, unverifiable repo paths block. Suggest adding `<!-- orianna: ok -->` to the line or marking it as prospective.

2. **Claim:** `dashboards/usage-dashboard/` (line 406, T10 step 1 — "local static server pointing at `dashboards/usage-dashboard/`") | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/dashboards/usage-dashboard` | **Result:** not found | **Severity:** block
   - Same condition as #1 — future-state path appearing in present-tense behavior text.

## Warn findings

None.

## Info findings

1. **Claim:** `plans/approved/2026-04-19-claude-usage-dashboard.md` (line 4 frontmatter `parent:`) | **Anchor:** `test -e plans/approved/2026-04-19-claude-usage-dashboard.md` | **Result:** exists | **Severity:** info (clean pass)

2. **Claim:** `dashboards/test-dashboard/` (lines 307, 418) | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/dashboards/test-dashboard` | **Result:** exists | **Severity:** info (clean pass)

3. **Claim:** `scripts/safe-checkout.sh` (line 34) | **Anchor:** `test -e scripts/safe-checkout.sh` | **Result:** exists | **Severity:** info (clean pass)

4. **Claim:** `apps/**`, `scripts/**`, `dashboards/**` glob bases (lines 33, 467) | **Anchor:** glob bases exist in strawberry-app | **Result:** exists | **Severity:** info (clean pass)

5. **Author-suppressed (`<!-- orianna: ok -->`) lines:** 14, 25, 26, 74, 75, 76, 77, 78, 83, 105, 126, 133, 150, 177, 199, 214, 234, 247, 269, 270, 278, 297, 310, 330, 347, 369, 379, 401, 402, 403, 464, 465 — all tokens extracted from these lines are explicitly authorized per claim-contract §8 and are logged here only. No block/warn emitted.

6. **Unknown path prefix:** `~/Documents/Personal/strawberry-app/` (line 32), `~/Documents/Work/mmp/workspace/agents/` (lines 15, 466), `~/.claude/projects/` (line 108), `~/.claude/strawberry-usage-cache/` (lines 122, 206, 274), `~/.zshrc` — absolute home-directory paths. Not routable via contract §5 prefix table; add to routing table if load-bearing.

7. **Unknown path prefix:** `harukainguyen1411/strawberry-app` (lines 15, etc.) — GitHub `owner/repo` identifier. Not routable; informational.

8. **Bare filename without prefix:** `2026-04-19-claude-usage-dashboard.md` (line 9) — parent plan basename; verified via frontmatter anchor (finding 1). Clean pass.

## Integration-name scan

- Allowlisted (Section 1): `ccusage`, `Chart.js`, `Playwright`, `Node.js`, `npm`, `TypeScript` — all pass without anchor.
- No Section-2 integration names detected outside suppressed lines.

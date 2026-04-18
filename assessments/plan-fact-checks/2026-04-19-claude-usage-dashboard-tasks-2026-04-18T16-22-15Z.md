---
plan: plans/proposed/2026-04-19-claude-usage-dashboard-tasks.md
checked_at: 2026-04-18T16:22:15Z
auditor: orianna
claude_cli: present
block_findings: 7
warn_findings: 0
info_findings: 9
---

## Block findings

Paths below live under the `strawberry-app` repo (checkout: `~/Documents/Personal/strawberry-app/`) and were verified with `test -e`. They appear on narrative/recap lines without the `<!-- orianna: ok -->` suppression marker that covers the equivalent task-action lines. Either add the marker (the author's intent appears to be "these files will be created by this plan") or reword to make the forward-looking nature explicit.

1. **Claim:** `dashboards/usage-dashboard/` (line 14) | **Anchor:** `~/Documents/Personal/strawberry-app/dashboards/usage-dashboard` | **Result:** not found | **Severity:** block
2. **Claim:** `scripts/usage-dashboard/` (line 14) | **Anchor:** `~/Documents/Personal/strawberry-app/scripts/usage-dashboard` | **Result:** not found | **Severity:** block
3. **Claim:** `dashboards/usage-dashboard/index.html` (line 25) | **Anchor:** `~/Documents/Personal/strawberry-app/dashboards/usage-dashboard/index.html` | **Result:** not found | **Severity:** block
4. **Claim:** `scripts/usage-dashboard/refresh-server.mjs` (line 26) | **Anchor:** `~/Documents/Personal/strawberry-app/scripts/usage-dashboard/refresh-server.mjs` | **Result:** not found | **Severity:** block
5. **Claim:** `dashboards/usage-dashboard/app.js` (line 369) | **Anchor:** `~/Documents/Personal/strawberry-app/dashboards/usage-dashboard/app.js` | **Result:** not found | **Severity:** block
6. **Claim:** `dashboards/usage-dashboard/package.json` (line 464) | **Anchor:** `~/Documents/Personal/strawberry-app/dashboards/usage-dashboard/package.json` | **Result:** not found | **Severity:** block
7. **Claim:** `strawberry-app/scripts/usage-dashboard/build.sh` (line 25) | **Anchor:** unknown path prefix `strawberry-app/` — not in contract §5 routing table; ambiguous whether this resolves under the app repo checkout or something else | **Result:** not routable | **Severity:** block

## Warn findings

None.

## Info findings

1. **Claim:** `plans/approved/2026-04-19-claude-usage-dashboard.md` (line 4, frontmatter `parent`) | **Anchor:** `plans/approved/2026-04-19-claude-usage-dashboard.md` | **Result:** found | **Severity:** info
2. **Claim:** `scripts/safe-checkout.sh` (line 34) | **Anchor:** `scripts/safe-checkout.sh` | **Result:** found | **Severity:** info
3. **Claim:** `agents/memory/agent-network.md` (line 76, author-suppressed) | **Anchor:** `agents/memory/agent-network.md` | **Result:** found | **Severity:** info
4. **Claim:** `dashboards/test-dashboard/` (lines 307, 418) | **Anchor:** `~/Documents/Personal/strawberry-app/dashboards/test-dashboard` | **Result:** found | **Severity:** info
5. **Claim:** `apps/` (via glob `apps/**`, lines 33, 467) | **Anchor:** `~/Documents/Personal/strawberry-app/apps` | **Result:** found (glob patterns treated as directory references) | **Severity:** info
6. **Claim:** `~/Documents/Work/mmp/workspace/agents/` (lines 16, 120, 466) | **Anchor:** n/a — unknown path prefix `~/Documents/Work/`; outside the two-repo routing table. Also missing on this machine. Add to contract §5 if load-bearing. | **Result:** unroutable | **Severity:** info
7. **Claim:** `~/.claude/projects/` (line 108, 136) | **Anchor:** n/a — unknown path prefix `~/.claude/`; not in contract §5 routing table. | **Result:** unroutable | **Severity:** info
8. **Claim:** `~/.claude/strawberry-usage-cache/` (lines 78, 122, 206, 274) | **Anchor:** n/a — unknown path prefix; runtime cache directory, not source-controlled. | **Result:** unroutable | **Severity:** info
9. **Claim:** Author-suppressed tokens via `<!-- orianna: ok -->` markers on lines 74–78, 83, 105, 126, 133, 150, 177, 199, 214, 234, 247, 269–270, 278, 297, 310, 330, 347, 379, 401–403, 465 | **Anchor:** n/a | **Result:** explicitly authorized by author | **Severity:** info

---

Note: the block findings above reflect the strict-default rule (contract §4) applied to path-shaped tokens appearing without suppression on context/overview lines. The author already suppressed the equivalent task-section references; extending the same marker to the recap paragraphs (§"Refresh Mechanism", lines 14/25/26, and the risks table at 464) would clear all seven block findings without changing plan semantics.

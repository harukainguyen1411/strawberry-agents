---
plan: plans/proposed/2026-04-19-claude-usage-dashboard-tasks.md
checked_at: 2026-04-19T00:00:00Z
auditor: orianna
claude_cli: present
block_findings: 2
warn_findings: 0
info_findings: 6
---

## Block findings

<!-- Each entry: claim text | anchor attempted | failure reason -->

1. **Claim:** `bash scripts/usage-dashboard/build.sh` (line 220) | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/scripts/usage-dashboard/build.sh` | **Result:** not found | **Severity:** block
   - Note: the defining line for this file (T4 "Where:" at line 199) is suppressed with `<!-- orianna: ok -->`, but the demonstrative `bash ...` command on line 220 is not, and the path does not yet exist in the strawberry-app checkout. Either add the suppression marker to line 220 or land the file first.

2. **Claim:** `node scripts/usage-dashboard/refresh-server.mjs &` (line 254) | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/scripts/usage-dashboard/refresh-server.mjs` | **Result:** not found | **Severity:** block
   - Note: T5 "Where:" at line 234 is suppressed, but the usage example on line 254 is not. Same remediation as above.

## Warn findings

None.

## Info findings

1. **Claim:** `~/Documents/Work/mmp/workspace/agents/` (line 15, 120) | **Anchor:** unknown prefix (`~/`) | **Result:** tilde-prefixed path not in routing table | **Severity:** info — add to contract if load-bearing.
2. **Claim:** `~/Documents/Personal/strawberry-app/` (line 32) | **Anchor:** routing maps to cross-repo checkout directory | **Result:** directory exists at `/Users/duongntd99/Documents/Personal/strawberry-app` | **Severity:** info (clean pass, tilde path).
3. **Claim:** `~/.claude/projects/**/*.jsonl` (line 107, 136) | **Anchor:** unknown prefix (`~/.claude/`) | **Result:** user-home path outside both repos | **Severity:** info.
4. **Claim:** `~/.claude/strawberry-usage-cache/agents.json` (line 122, 207) | **Anchor:** unknown prefix | **Result:** ephemeral cache path outside repos | **Severity:** info.
5. **Claim:** `scripts/safe-checkout.sh` (line 34) | **Anchor:** `test -e scripts/safe-checkout.sh` in this repo | **Result:** exists | **Severity:** info (clean pass, anchor confirmed).
6. **Claim:** `dashboards/test-dashboard/` (lines 307, 418) | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/dashboards/test-dashboard/` | **Result:** exists | **Severity:** info (clean pass, cross-repo anchor confirmed).

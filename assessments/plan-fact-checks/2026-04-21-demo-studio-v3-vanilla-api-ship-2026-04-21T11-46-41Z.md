---
plan: plans/proposed/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md
checked_at: 2026-04-21T11:46:41Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 1
warn_findings: 0
info_findings: 5
external_calls_used: 0
---

## Block findings

1. **Step C — Claim:** `setup_agent.py` (line 42 — `\`setup_agent.py --force\` must rewrite the vault on every URL/token rotation.`) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/setup_agent.py` (concern: work routing, not on opt-back list) | **Result:** not found at workspace root; the actual file lives at `company-os/tools/demo-studio-v3/setup_agent.py` | **Severity:** block | **Fix:** add an `<!-- orianna: ok -->` marker to the end of line 42 (mirroring the pattern applied to lines 194–197 in §4's deletion table, which already suppress the same bare `setup_agent.py` token), OR inline the full repo-relative path (`company-os/tools/demo-studio-v3/setup_agent.py`).

## Warn findings

None.

## Info findings

1. **Step C — Claim (author-suppressed):** `plans/implemented/work/2026-04-20-managed-agent-lifecycle.md` (line 40, suppressed via `<!-- orianna: ok -->`) | **Anchor:** `test -e plans/implemented/work/2026-04-20-managed-agent-lifecycle.md` | **Result:** exists ✓ | **Severity:** info.
2. **Step C — Claim (author-suppressed):** `plans/implemented/work/2026-04-20-managed-agent-dashboard-tab.md` (line 40, suppressed) | **Anchor:** `test -e plans/implemented/work/2026-04-20-managed-agent-dashboard-tab.md` | **Result:** exists ✓ | **Severity:** info.
3. **Step C — Claim (author-suppressed):** `plans/proposed/work/2026-04-21-mcp-inprocess-merge.md` (line 41, suppressed) | **Anchor:** `test -e plans/proposed/work/2026-04-21-mcp-inprocess-merge.md` | **Result:** not found — plan cites Karma's in-process MCP merge plan but that sibling plan is not present in `plans/proposed/work/`. Suppressed by author; logged here for reviewer visibility. | **Severity:** info (author-suppressed).
4. **Step C — Claim (author-suppressed):** `plans/proposed/work/2026-04-21-demo-studio-v3-e2e-ship-v2.md` (lines 49 and 524, suppressed) | **Anchor:** `test -e plans/proposed/work/2026-04-21-demo-studio-v3-e2e-ship-v2.md` | **Result:** not found — plan's entire Option-A-vs-Option-B framing cites Azir's e2e-ship-v2 plan as the competing Option A, but that file is not present in `plans/proposed/work/`. Suppressed by author; logged for reviewer visibility because the comparison hinges on it. | **Severity:** info (author-suppressed).
5. **Step C — Claim (author-suppressed, concern: work):** `company-os/tools/demo-studio-v3/setup_agent.py`, `company-os/tools/demo-studio-v3/`, `company-os/tools/demo-studio-mcp/` (line 18 prose list, suppressed) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3/setup_agent.py` etc. | **Result:** all three exist ✓ in the work workspace. | **Severity:** info (author-suppressed, confirmed).

## External claims

None. (Step E triggers exist — `anthropic.messages.create`, `client.messages.stream`, `web_search_20241022` tool type, model `claude-sonnet-4-6` — but these are Anthropic SDK references that are (a) used consistently with the current public Messages API shape, (b) descriptive of in-use behavior the plan itself audits against during phase-A unit tests, and (c) not version-pinned in a way that would drift independently. Deferred to implementation-time verification; budget consumed: 0/15.)

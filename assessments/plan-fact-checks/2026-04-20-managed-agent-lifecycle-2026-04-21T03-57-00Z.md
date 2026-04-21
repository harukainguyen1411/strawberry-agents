---
plan: plans/proposed/work/2026-04-20-managed-agent-lifecycle.md
checked_at: 2026-04-21T03:57:00Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 3
warn_findings: 0
info_findings: 4
external_calls_used: 0
---

## Block findings

1. **Step C — Claim:** `company-os/tools/demo-studio-v3/session_store.py` (Appendix, line 200, "MODIFY ...") | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3/session_store.py` | **Result:** not found in workspace checkout. The `MODIFY` marker asserts the file currently exists, but it does not. The ADR acknowledges this file is produced by the sister SE (session-state-encapsulation) ADR (`Depends on: SE.A.6`), so either (a) re-label as `NEW`/`WILL BE MODIFIED after SE.A.6` with a future-state marker, (b) add `<!-- orianna: ok -->` suppression with rationale pointing at the SE plan, or (c) wait until SE.A.6 lands before re-running this gate. | **Severity:** block

2. **Step C — Claim:** `slack-relay` MCP (line 251, MAL.0.2 task description) | **Anchor:** not on `agents/orianna/allowlist.md` Section 1; not anchored to a repo path, workflow file, or vendor docs URL | **Result:** integration name extracted from backtick span without suppression marker; per strict default (claim-contract §4) bare integration names must be anchored or allowlisted. The author suppressed this name on lines 103 and 414 with explicit rationale ("internal MCP server") — the same suppression pattern needs to be applied on line 251, or the name added to the allowlist. | **Severity:** block

3. **Step C — Claim:** `slack-relay` MCP (line 415, MAL.E.3 task description) | **Anchor:** same as above; same allowlist/suppression gap | **Result:** same unsuppressed occurrence. Add `<!-- orianna: ok -->` to this line (consistent with lines 103 and 414) or allowlist the name. | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step C — Claim:** `company-os/tools/demo-studio-v3/managed_session_monitor.py` (Appendix, line 197, "NEW ...") | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/...` | **Result:** not found, but the `NEW` marker is a future-state equivalent per claim-contract §2 ("Will:" / "In a future phase:") — the file is explicitly slated for creation. Logged as info, not block. | **Severity:** info

2. **Step C — Claim:** `company-os/tools/demo-studio-v3` (line 22, Scope) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3` | **Result:** exists. | **Severity:** info

3. **Step C — Claim:** `secretary/agents/azir/learnings/2026-04-20-session-api-adr.md` (line 23, Related) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/secretary/agents/azir/learnings/2026-04-20-session-api-adr.md` | **Result:** exists. | **Severity:** info

4. **Step C — Claim:** opt-back plan references `plans/proposed/work/2026-04-20-managed-agent-lifecycle.md`, `plans/proposed/work/2026-04-20-session-state-encapsulation.md`, `plans/proposed/work/2026-04-20-s1-s2-service-boundary.md` (lines 207, 211, 212) | **Anchor:** `test -e` against strawberry-agents working tree (opt-back `plans/` prefix) | **Result:** all three resolve cleanly. | **Severity:** info

## External claims

None.

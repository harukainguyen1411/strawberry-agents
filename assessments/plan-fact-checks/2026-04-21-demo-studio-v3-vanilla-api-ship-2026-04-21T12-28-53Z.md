---
plan: plans/proposed/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md
checked_at: 2026-04-21T12:28:53Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 5
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step C — Claim:** `plans/implemented/work/2026-04-20-managed-agent-lifecycle.md` | **Anchor:** `test -e` against strawberry-agents working tree (opt-back `plans/`) | **Result:** exists; author-suppressed via same-line marker on L40 | **Severity:** info
2. **Step C — Claim:** `plans/implemented/work/2026-04-20-managed-agent-dashboard-tab.md` | **Anchor:** `test -e` against strawberry-agents working tree (opt-back `plans/`) | **Result:** exists; author-suppressed via same-line marker on L40 | **Severity:** info
3. **Step C — Claim:** `plans/proposed/work/2026-04-21-mcp-inprocess-merge.md` | **Anchor:** `test -e` against strawberry-agents working tree (opt-back `plans/`) | **Result:** path not found, but author-suppressed via same-line marker on L41 (prospective sibling plan referenced by Karma) | **Severity:** info
4. **Step C — Claim:** `plans/proposed/work/2026-04-21-demo-studio-v3-e2e-ship-v2.md` | **Anchor:** `test -e` against strawberry-agents working tree (opt-back `plans/`) | **Result:** path not found, but author-suppressed via same-line marker on L49 (Azir Option A comparator plan) | **Severity:** info
5. **Step C — Claims (bulk, work-workspace paths):** `company-os/tools/demo-studio-v3/**`, `company-os/tools/demo-studio-mcp/**`, sibling module/env/route/Firestore/SDK tokens throughout the plan body | **Anchor:** per-line `<!-- orianna: ok -->` markers on each referencing line plus top-of-file scope preamble (L18–L26) declaring the work-workspace resolution root and listing all bare-token classes the plan intends to discuss | **Result:** author-suppressed; plan is architecture-only and creates no strawberry-agents files under those names | **Severity:** info

## External claims

None. (Step E trigger heuristic: sentences reference `claude-sonnet-4-6`, `web_search_20241022`, and `api.anthropic.com` — each is author-suppressed on its containing line via the top-of-file SDK/URL scope preamble and per-line markers; no `http(s)://` URL is asserted as load-bearing independent of that suppression, no RFC citation, no un-suppressed library version claim. Budget unused.)

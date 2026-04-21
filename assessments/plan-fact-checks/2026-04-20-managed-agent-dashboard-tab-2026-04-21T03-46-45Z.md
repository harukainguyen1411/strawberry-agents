---
plan: plans/proposed/work/2026-04-20-managed-agent-dashboard-tab.md
checked_at: 2026-04-21T03:46:45Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 3
warn_findings: 2
info_findings: 6
external_calls_used: 0
---

## Block findings

1. **Step C — Claim:** `plans/2026-04-20-managed-agent-lifecycle.md` (line 23, `## Related:` section) | **Anchor:** `test -e plans/2026-04-20-managed-agent-lifecycle.md` | **Result:** not found — file exists at `plans/proposed/work/2026-04-20-managed-agent-lifecycle.md`. Update the cross-reference path. | **Severity:** block
2. **Step C — Claim:** `plans/2026-04-20-managed-agent-dashboard-tab.md` (line 257, amendment Scope sentence) | **Anchor:** `test -e plans/2026-04-20-managed-agent-dashboard-tab.md` | **Result:** not found — file exists at `plans/proposed/work/2026-04-20-managed-agent-dashboard-tab.md` (this plan's own self-reference). Update path. | **Severity:** block
3. **Step C — Claim:** `plans/2026-04-20-s1-s2-service-boundary.md` (line 257, amendment Scope sentence) | **Anchor:** `test -e plans/2026-04-20-s1-s2-service-boundary.md` | **Result:** not found — file exists at `plans/proposed/work/2026-04-20-s1-s2-service-boundary.md`. Update path. | **Severity:** block

## Warn findings

1. **Step C — Claim:** `managed_session_client.py` (§2, §5, §11 — bare filename) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/managed_session_client.py` | **Result:** not found at workspace root. Plan explicitly declares this a "New file" in §5, so it is correctly future-state, but the bare path is context-dependent (intended to live alongside `company-os/tools/demo-studio-v3/main.py`). Consider qualifying with the intended directory on first mention. | **Severity:** warn
2. **Step C — Claim:** `main.py:2111-2115` (§5) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/main.py` | **Result:** bare `main.py` at workspace root not found; the intended file exists at `~/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3/main.py`. Consider qualifying the path. | **Severity:** warn

## Info findings

1. **Step A — Frontmatter:** `status: proposed`, `owner: Sona`, `created: 2026-04-20`, `tags: [...]` — all required fields present and valid. | **Severity:** info
2. **Step B — Gating questions:** `## 10. Open questions` Q1 (DEFERRED), Q2 (LOCKED), Q3 (resolution inline: lean server-paged cursor, threshold 250), Q4 (DEFERRED). No unresolved `TBD`/`TODO`/`Decision pending` markers found. | **Severity:** info
3. **Step C — Claim:** `company-os/tools/demo-studio-v3` (line 20, Scope) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3` | **Result:** exists. | **Severity:** info
4. **Step C — Claim:** `secretary/agents/azir/learnings/2026-04-20-managed-agent-lifecycle-adr.md` (line 24) | **Anchor:** workspace path exists. | **Severity:** info
5. **Step C — Claim (author-suppressed):** `company-os/plans/2026-04-20-managed-agent-dashboard-tab-bd-amendment.md`, `missmp/company-os` (line 253) and `tools/demo-studio-v3/` (line 261) — both on lines with `<!-- orianna: ok -->`. Confirmed workspace path exists for the BD-amendment ref regardless. | **Severity:** info (author-suppressed)
6. **Step D — Sibling files:** no `<basename>-tasks.md` or `<basename>-tests.md` found under `plans/`. Single-file layout OK. Note: line 317 references `plans/2026-04-20-managed-agent-dashboard-tab-tasks.md` as a future deliverable ("When Kayn issues…"), not an existing sibling — correctly future-state and does not violate §D3. | **Severity:** info

## External claims

None. (Step E triggered no claims: no cited URLs, no RFC references, no pinned version numbers or named library/SDK symbols beyond vendor bare names already covered by the allowlist / present as abstract SDK wrapper surface.)

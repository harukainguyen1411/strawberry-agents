---
plan: plans/proposed/work/2026-04-20-managed-agent-dashboard-tab.md
checked_at: 2026-04-21T02:30:13Z
auditor: orianna
check_version: 2
claude_cli: present
block_findings: 7
warn_findings: 0
info_findings: 6
---

## Block findings

1. **Step B — Gating question:** unresolved `?` sentence in `## 10. Open questions` — Q1 ("Confirmation-modal copy") ends with "is the type-to-confirm gate warranted, or is a single-click-with-modal enough?" with `Owner: Duong + Lulu` still outstanding | **Severity:** block
2. **Step C — Claim:** `plans/2026-04-20-managed-agent-lifecycle.md` | **Anchor:** `test -e plans/2026-04-20-managed-agent-lifecycle.md` | **Result:** not found at that path (actual file lives at `plans/proposed/work/2026-04-20-managed-agent-lifecycle.md`) | **Severity:** block
3. **Step C — Claim:** `plans/2026-04-20-managed-agent-dashboard-tab.md` | **Anchor:** `test -e plans/2026-04-20-managed-agent-dashboard-tab.md` | **Result:** not found at that path (actual file lives at `plans/proposed/work/2026-04-20-managed-agent-dashboard-tab.md`); self-reference uses bare `plans/<date>-<slug>.md` path that does not resolve | **Severity:** block
4. **Step C — Claim:** `plans/2026-04-20-managed-agent-dashboard-tab-bd-amendment.md` | **Anchor:** `find plans -name 2026-04-20-managed-agent-dashboard-tab-bd-amendment.md` | **Result:** not found anywhere under `plans/` (Amendments §header says "Source: ... in `missmp/company-os`. Inlined verbatim." but the bare path in this repo does not resolve) | **Severity:** block
5. **Step C — Claim:** `plans/2026-04-20-s1-s2-service-boundary.md` | **Anchor:** `test -e plans/2026-04-20-s1-s2-service-boundary.md` | **Result:** not found at that path (actual file lives at `plans/proposed/work/2026-04-20-s1-s2-service-boundary.md`) | **Severity:** block
6. **Step C — Claim:** `tools/demo-studio-v3/` | **Anchor:** `test -e tools/demo-studio-v3` (this-repo routing per contract §5) | **Result:** not found in strawberry-agents repo; `tools/demo-studio-v3` does not exist here and the routing rule maps `tools/` to this repo | **Severity:** block
7. **Step C — Claim:** `company-os/tools/demo-studio-v3` | **Anchor:** unknown prefix `company-os/` per contract §5 routing table; load-bearing (declared as Scope in the ADR header) and not anchored to any reachable file. While the prefix is unknown per the routing table, this is a scope-defining claim that the approved-gate cannot verify without an explicit anchor | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step C — Claim:** `secretary/agents/azir/learnings/2026-04-20-managed-agent-lifecycle-adr.md` | unknown path prefix `secretary/`; add to contract if load-bearing | **Severity:** info
2. **Step C — Claim:** `/dashboard` | URL route (not a repo path); unknown path prefix — skip | **Severity:** info
3. **Step C — Claim:** `/api/managed-sessions` | URL route (not a repo path); unknown path prefix — skip | **Severity:** info
4. **Step C — Claim:** `/api/managed-sessions/{managed_session_id}/terminate` | URL route (not a repo path); unknown path prefix — skip | **Severity:** info
5. **Step C — Claim:** `managed_session_client.py`, `config_mgmt_client.py` | bare filenames with recognized extension but no prefix; unknown routing. These are new files the ADR proposes to create; not load-bearing against current tree | **Severity:** info
6. **Step C — Claim:** `main.py:2111-2115` | bare filename + line range reference to a file in the external `company-os` codebase (not this repo); unknown routing | **Severity:** info

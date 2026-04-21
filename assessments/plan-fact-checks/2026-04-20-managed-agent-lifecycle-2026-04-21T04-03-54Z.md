---
plan: plans/proposed/work/2026-04-20-managed-agent-lifecycle.md
checked_at: 2026-04-21T04:03:54Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 16
warn_findings: 0
info_findings: 4
external_calls_used: 0
---

## Block findings

<!-- Step B: gating-markers in ## Open questions -->
1. **Step B — Gating question:** unresolved `?` marker at end of sentence in bullet Q1 ("Does `client.beta.sessions.list()` accept an `agent` filter param?") in `## 9. Open questions` | **Severity:** block
2. **Step B — Gating question:** unresolved `?` marker at end of sentence in bullet Q1 ("Does `retrieve()` return a `lastActivityAt` / `updated_at` / equivalent timestamp?") in `## 9. Open questions` | **Severity:** block
3. **Step B — Gating question:** unresolved `?` marker at end of sentence in bullet Q1 ("does `client.beta.sessions.events.list(session_id)` exist to pull the latest event timestamp?") in `## 9. Open questions` | **Severity:** block
4. **Step B — Gating question:** unresolved `?` marker at end of sentence in bullet Q2 ("Is `#demo-studio-alerts` the correct channel?") in `## 9. Open questions` | **Severity:** block
5. **Step B — Gating question:** unresolved `?` marker at end of sentence in bullet Q2 ("Does the slack-relay bot have membership?") in `## 9. Open questions` | **Severity:** block
6. **Step B — Gating question:** unresolved `?` marker at end of sentence in bullet Q3 ("...should we proactively terminate all active managed sessions?") in `## 9. Open questions` | **Severity:** block

<!-- Step C: path-shaped tokens that fail test -e under concern: work routing -->
7. **Step C — Claim:** `company-os/tools/demo-studio-v3/managed_session_monitor.py` (line 77, "New file") | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3/managed_session_monitor.py` | **Result:** not found; add `<!-- orianna: ok -->` suppression marker (future file) or create a stub | **Severity:** block
8. **Step C — Claim:** `company-os/tools/demo-studio-v3/managed_session_monitor.py` (line 197, Appendix NEW) | **Anchor:** same as #7 | **Result:** not found; missing `<!-- orianna: ok -->` marker on appendix line | **Severity:** block
9. **Step C — Claim:** `feat/demo-studio-v3` (line 208, "Branch:") | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/feat/demo-studio-v3` | **Result:** not found; branch name is path-shaped per heuristic, needs suppression marker as "branch name, not filesystem path" | **Severity:** block
10. **Step C — Claim:** `tests/test_cancel_build_uses_stop_primitive.py` (line 325, MAL.C.1) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/tests/test_cancel_build_uses_stop_primitive.py` | **Result:** not found; future xfail test file — add suppression marker | **Severity:** block
11. **Step C — Claim:** `tests/test_stop_build_phase.py` (line 336, MAL.C.2 acceptance) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/tests/test_stop_build_phase.py` | **Result:** not found; if pre-existing, path is relative to `tools/demo-studio-v3/` — qualify or suppress | **Severity:** block
12. **Step C — Claim:** `test_stop_and_archive.py` (line 344, MAL.C.3 acceptance) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/test_stop_and_archive.py` | **Result:** not found; bare filename missing directory prefix — qualify or suppress | **Severity:** block
13. **Step C — Claim:** `tests/test_monitor_lifecycle_wiring.py` (line 427, MAL.F.1) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/tests/test_monitor_lifecycle_wiring.py` | **Result:** not found; future xfail test file — add suppression marker | **Severity:** block
14. **Step C — Claim:** `tests/test_monitor_config.py` (line 447, MAL.G.1) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/tests/test_monitor_config.py` | **Result:** not found; future xfail test file — add suppression marker | **Severity:** block
15. **Step C — Claim:** `tests/test_monitor_observability.py` (line 467, MAL.H.1) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/tests/test_monitor_observability.py` | **Result:** not found; future xfail test file — add suppression marker | **Severity:** block
16. **Step C — Claim:** `tests/integration/test_stop_managed_session_integration.py` (line 475, MAL.H.2) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/tests/integration/test_stop_managed_session_integration.py` | **Result:** not found; future xfail test file — add suppression marker | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** all four required fields present and well-formed (`status: proposed`, `owner: Sona`, `created: 2026-04-20`, `tags: [...]`) | **Severity:** info
2. **Step C — Claim:** `company-os/tools/demo-studio-v3` (line 18, Scope) | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3` | **Result:** exists | **Severity:** info
3. **Step C — Claim:** opt-back sibling plan paths `plans/proposed/work/2026-04-20-managed-agent-lifecycle.md`, `plans/proposed/work/2026-04-20-session-state-encapsulation.md`, `plans/proposed/work/2026-04-20-s1-s2-service-boundary.md` (lines 207, 211, 212) | **Anchor:** `test -e` against strawberry-agents working tree | **Result:** all exist | **Severity:** info
4. **Step D — Sibling:** no `*-tasks.md` or `*-tests.md` sibling files found for basename `2026-04-20-managed-agent-lifecycle`; Tasks and Test plan are inlined per §D3 one-plan-one-file rule | **Severity:** info

## External claims

None. (Step E not triggered on this pass — no cited URLs with scheme, no pinned library versions, no RFC citations. Named "Anthropic" / "Anthropic SDK" references are self-flagged as Q1/Spike 1 uncertainty by the plan itself — the author's Q1 resolution path is the correct mechanism, not external verification at gate time.)

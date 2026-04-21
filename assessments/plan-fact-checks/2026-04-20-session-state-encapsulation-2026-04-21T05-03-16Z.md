---
plan: plans/proposed/work/2026-04-20-session-state-encapsulation.md
checked_at: 2026-04-21T05:03:16Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 29
warn_findings: 0
info_findings: 5
external_calls_used: 0
---

## Block findings

<!-- Concern is `work`; resolution-root for non-opt-back path tokens is ~/Documents/Work/mmp/workspace/ per claim-contract §5a. The author's line-19 preamble suppressor is line-scoped per §8 — it authorizes tokens on line 19 only, not subsequent occurrences. The many re-occurrences of bare module names and `tools/demo-studio-v3/...` paths on other lines are unsuppressed and resolve to workspace-root paths that do not exist. -->

1. **Step C — Claim:** `session.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/session.py` | **Result:** not found (actual home: `workspace/company-os/tools/demo-studio-v3/session.py`; unsuppressed occurrences on lines 34, 37, 170, 255, 261, 263, 267, 305, 377) | **Severity:** block
2. **Step C — Claim:** `main.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/main.py` | **Result:** not found (unsuppressed lines 170, 263, 514, 751, 829) | **Severity:** block
3. **Step C — Claim:** `auth.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/auth.py` | **Result:** not found (unsuppressed lines 171, 264, 483, 518, 521, 751) | **Severity:** block
4. **Step C — Claim:** `factory_bridge.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/factory_bridge.py` | **Result:** not found (unsuppressed lines 37, 172, 265, 526, 751) | **Severity:** block
5. **Step C — Claim:** `factory_bridge_v2.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/factory_bridge_v2.py` | **Result:** not found (unsuppressed lines 37, 172, 265, 526) | **Severity:** block
6. **Step C — Claim:** `dashboard_service.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/dashboard_service.py` | **Result:** not found (unsuppressed lines 38, 173, 266, 534, 751) | **Severity:** block
7. **Step C — Claim:** `session_store.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/session_store.py` | **Result:** not found (unsuppressed in §§2.1, 3, 6, 6.2, 6.5, 9 and many task bullets; see lines 69, 80, 82, 170, 248, 252, 255, 261, 263, 267, 305, 344, 375, 387, 404, 492, 521, 534, 571, 748) | **Severity:** block
8. **Step C — Claim:** `phase.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/phase.py` | **Result:** not found (unsuppressed lines 534, 535) | **Severity:** block
9. **Step C — Claim:** `validate_v2.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/validate_v2.py` | **Result:** not found (unsuppressed line 530) | **Severity:** block
10. **Step C — Claim:** `sample-config.json` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/sample-config.json` | **Result:** not found (unsuppressed line 530) | **Severity:** block
11. **Step C — Claim:** `tdd-gate.yml` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/tdd-gate.yml` | **Result:** not found (lives at strawberry-agents `.github/workflows/tdd-gate.yml` but `.github/workflows/` is not opt-back for concern:work; unsuppressed line 333) | **Severity:** block
12. **Step C — Claim:** `test_session.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/test_session.py` | **Result:** not found (unsuppressed line 422) | **Severity:** block
13. **Step C — Claim:** `test_session_store_mutations.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/test_session_store_mutations.py` | **Result:** not found (unsuppressed line 422) | **Severity:** block
14. **Step C — Claim:** `test_session_store_list.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/test_session_store_list.py` | **Result:** not found (unsuppressed line 440) | **Severity:** block
15. **Step C — Claim:** `test_session_store_events.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/test_session_store_events.py` | **Result:** not found (unsuppressed line 457) | **Severity:** block
16. **Step C — Claim:** `test_session_store_tokens.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/test_session_store_tokens.py` | **Result:** not found (unsuppressed line 473) | **Severity:** block
17. **Step C — Claim:** `test_session_store_tokens_ttl.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/test_session_store_tokens_ttl.py` | **Result:** not found (unsuppressed line 602) | **Severity:** block
18. **Step C — Claim:** `migrate_session_status.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/migrate_session_status.py` | **Result:** not found (unsuppressed line 570) | **Severity:** block
19. **Step C — Claim:** `test_migrate_session_status.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/test_migrate_session_status.py` | **Result:** not found (unsuppressed line 576) | **Severity:** block
20. **Step C — Claim:** `test_approve_route_gone.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/test_approve_route_gone.py` | **Result:** not found (unsuppressed line 563) | **Severity:** block
21. **Step C — Claim:** `test_call_site_boundary.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/test_call_site_boundary.py` | **Result:** not found (unsuppressed line 751) | **Severity:** block
22. **Step C — Claim:** `drop_used_tokens_collection.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/drop_used_tokens_collection.py` | **Result:** not found (unsuppressed line 618) | **Severity:** block
23. **Step C — Claim:** `plan-promote.sh` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/plan-promote.sh` | **Result:** not found (bare token without opt-back prefix; real home is strawberry-agents `scripts/plan-promote.sh`; unsuppressed line 839) | **Severity:** block
24. **Step C — Claim:** `tools/demo-studio-v3/session_store.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/tools/demo-studio-v3/session_store.py` | **Result:** not found (actual location is `workspace/company-os/tools/demo-studio-v3/session_store.py`; unsuppressed line 388) | **Severity:** block
25. **Step C — Claim:** `tools/demo-studio-v3/main.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/tools/demo-studio-v3/main.py` | **Result:** not found (workspace has `company-os/tools/demo-studio-v3/main.py`; unsuppressed line 514) | **Severity:** block
26. **Step C — Claim:** `tools/demo-studio-v3/scripts/migrate_session_status.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/tools/demo-studio-v3/scripts/migrate_session_status.py` | **Result:** not found (unsuppressed line 571) | **Severity:** block
27. **Step C — Claim:** `tools/demo-studio-v3/scripts/drop_used_tokens_collection.py` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/tools/demo-studio-v3/scripts/drop_used_tokens_collection.py` | **Result:** not found (unsuppressed line 618) | **Severity:** block
28. **Step C — Claim:** `tools/demo-studio-v3/` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/tools/demo-studio-v3/` | **Result:** not found (directory lives under `company-os/`; unsuppressed lines 391, 641, 832) | **Severity:** block
29. **Step C — Claim:** `reference/1-content-gen.yaml` | **Anchor:** `test -e ~/Documents/Work/mmp/workspace/reference/1-content-gen.yaml` | **Result:** not found (per earlier §1.3 suppressor the file lives under `missmp/company-os/reference/`; unsuppressed line 677) | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** `status: proposed` ✓; `owner: Sona` ✓; `created: 2026-04-20` ✓; `tags:` non-empty ✓. All frontmatter checks pass. | **Severity:** info
2. **Step B — Gating questions:** `### Open questions (Duong-blockers)` section (line 719) contains OQ-SE-1 through OQ-SE-5 — all marked RESOLVED. No unresolved `TBD`/`TODO`/`Decision pending` markers inside any gating-titled section. | **Severity:** info
3. **Step D — Sibling files:** searched `plans/` tree for `2026-04-20-session-state-encapsulation-tasks.md` and `-tests.md`; none found. Tasks and amendments are already inlined in the plan body (§ Tasks, § Amendments). | **Severity:** info
4. **Step C — Author-suppressed (bulk):** dozens of `<!-- orianna: ok -->` inline markers suppress company-os-path tokens on their specific lines (e.g. lines 19, 24, 32, 51, 168, 179, 193, 226, 250, 273, 294, 328, 332, 359, 367, 380, 389, 396, 397, 406, 415, 433, 450, 466, 482, 495, 502, 504-511, 512, 520, 528, 536, 538, 543, 552, 560, 562, 573, 580, 589, 611, 621, 630, 638, 642, 656, 671, 683, 691, 759, 781, etc.). All tokens on those lines logged as author-authorized per claim-contract §8 and pass this gate. | **Severity:** info
5. **Step C — Anchor confirmed:** `plans/approved/work/2026-04-20-managed-agent-lifecycle.md`, `plans/approved/work/2026-04-20-managed-agent-dashboard-tab.md`, and self-reference `plans/proposed/work/2026-04-20-session-state-encapsulation.md` resolve cleanly against this repo (plans/ is opt-back for concern:work). | **Severity:** info

## External claims

None. (No library/SDK version pins, URLs, or RFC citations triggered Step E; `google.cloud.firestore` is referenced as an import string without a version or deprecation claim, and `pytest.mark.xfail` / `threading.Lock` are stdlib-allowlisted.)

## Summary for plan author

The gate blocks on a routing mismatch, not on missing files. Your line-19 preamble declares that all bare module names refer to `missmp/company-os/tools/demo-studio-v3/` — which is correct and true — but per claim-contract §8, `<!-- orianna: ok -->` is **line-scoped**: it only suppresses tokens on the line that contains the marker. You've applied inline markers diligently on most occurrences, but ~29 unique unsuppressed path tokens remain on other lines.

Two paths forward:

1. **Add inline `<!-- orianna: ok -->` markers** to each unsuppressed line listed above (the boring option).
2. **Reshape the resolution-root routing** so concern-work plans whose scope is the `company-os/` subtree opt into `workspace/company-os/` as the default root — this would require a claim-contract amendment plus coordinated update to `scripts/fact-check-plan.sh` and `agents/orianna/prompts/plan-check.md`. Out of scope for this gate invocation; flag to Swain if the suppressor pattern is becoming unsustainable.

Frontmatter, gating questions, sibling-file inlining, and external claims all pass cleanly. The block set is purely path-routing coverage.

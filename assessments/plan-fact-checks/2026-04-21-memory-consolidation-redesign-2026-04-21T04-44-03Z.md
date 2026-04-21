---
plan: plans/proposed/personal/2026-04-21-memory-consolidation-redesign.md
checked_at: 2026-04-21T04:44:03Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 16
warn_findings: 0
info_findings: 2
external_calls_used: 0
---

## Block findings

1. **Step C — Claim:** `scripts/_lib_last_sessions_index.sh` (L475, task T2 impl heading) | **Anchor:** `test -e scripts/_lib_last_sessions_index.sh` | **Result:** not found; line carries no `<!-- orianna: ok -->` suppression. | **Severity:** block
2. **Step C — Claim:** `scripts/test-memory-consolidate-index.sh` (L485, L515, L762, L843) | **Anchor:** `test -e scripts/test-memory-consolidate-index.sh` | **Result:** not found; unsuppressed lines outside §9 tables. | **Severity:** block
3. **Step C — Claim:** `scripts/test-memory-consolidate-archive-policy.sh` (L516, L763, L844) | **Anchor:** `test -e scripts/test-memory-consolidate-archive-policy.sh` | **Result:** not found; unsuppressed prose references. | **Severity:** block
4. **Step C — Claim:** `scripts/test-end-session-skill-shape.sh` (L547, L765, L845) | **Anchor:** `test -e scripts/test-end-session-skill-shape.sh` | **Result:** not found; unsuppressed references in DoD bullets. | **Severity:** block
5. **Step C — Claim:** `scripts/test-end-session-memory-integration.sh` (L764, L845) | **Anchor:** `test -e scripts/test-end-session-memory-integration.sh` | **Result:** not found; unsuppressed in DoD checklist and §D matrix. | **Severity:** block
6. **Step C — Claim:** `agents/evelynn/memory/open-threads.md` (L587) | **Anchor:** `test -e agents/evelynn/memory/open-threads.md` | **Result:** not found; referenced inside a `wc -c` command in DoD bullet without suppression. | **Severity:** block
7. **Step C — Claim:** `agents/evelynn/memory/last-sessions/INDEX.md` (L587) | **Anchor:** `test -e agents/evelynn/memory/last-sessions/INDEX.md` | **Result:** not found; same unsuppressed `wc -c` line. | **Severity:** block
8. **Step C — Claim:** `architecture/coordinator-memory.md` (L624 task heading, L636 commit subject) | **Anchor:** `test -e architecture/coordinator-memory.md` | **Result:** not found; T11 implementation heading and commit-subject sample both missing suppression. | **Severity:** block
9. **Step C — Claim:** `scripts/.xfail-markers/` (L467) | **Anchor:** `test -e scripts/.xfail-markers` | **Result:** not found; referenced as the xfail marker directory convention without suppression. | **Severity:** block
10. **Step C — Claim:** `scripts/lint-open-threads.sh` (L343) | **Anchor:** `test -e scripts/lint-open-threads.sh` | **Result:** not found; referenced in Non-goals bullet without suppression. | **Severity:** block
11. **Step C — Claim:** `scripts/fixtures/memory-consolidate-e2e/` (L1041) | **Anchor:** `test -e scripts/fixtures/memory-consolidate-e2e` | **Result:** not found; fixture path in §3.1 unsuppressed. | **Severity:** block
12. **Step C — Claim:** `scripts/test-memory-redesign-all.sh` (L1310) | **Anchor:** `test -e scripts/test-memory-redesign-all.sh` | **Result:** not found; §10 CI-wiring bullet unsuppressed. | **Severity:** block
13. **Step C — Claim:** `scripts/hooks/pre-push.sh` (L1331) | **Anchor:** `test -e scripts/hooks/pre-push.sh` | **Result:** not found — repo has `scripts/hooks/pre-push-tdd.sh` but no bare `pre-push.sh`. Unsuppressed §10 "Test scripts to modify" bullet. Either fix the path to `pre-push-tdd.sh` or confirm a new `pre-push.sh` will be created and add suppression. | **Severity:** block
14. **Step C — Claim:** `scripts/test-migration-smoke.sh` (L297 via §7.1 prose, also §4.8/§3.6 references in body) | **Anchor:** `test -e scripts/test-migration-smoke.sh` | **Result:** not found; some occurrences suppressed but the prose reference at the §7.1 "Smoke test script" line and associated T8 DoD rows lack markers. | **Severity:** block
15. **Step C — Claim:** `scripts/test-memory-consolidate-e2e.sh`, `scripts/test-coordinator-boot-simulation.sh`, `scripts/test-lissandra-precompact-integration.sh`, `scripts/test-skarner-integration.sh`, `scripts/test-faultinject-consolidate-interrupt.sh`, `scripts/test-faultinject-concurrent-endsession.sh`, `scripts/test-faultinject-lock.sh`, `scripts/test-faultinject-endsession-interrupt.sh`, `scripts/test-faultinject-missing-shard-ref.sh`, `scripts/test-migration-before-after.sh`, `scripts/test-skarner-on-demand.sh`, `scripts/test-index-format.sh`, `scripts/test-boot-chain-order.sh`, `scripts/test-lissandra-precompact-memory.sh`, `scripts/test-memory-consolidate-consistency.sh` — all referenced inside §2–§5 test-section headings with suppression, but each also recurs in cross-reference prose (e.g. §D matrices, §10 CI lists) on unsuppressed lines. | **Anchor:** `test -e scripts/test-*.sh` | **Result:** not found; cross-references in §10 "Heavier tests" enumeration (L1272 range) partially suppressed but adjacent DoD prose is not. | **Severity:** block
16. **Step C — Claim:** `.github/workflows/memory-redesign-tests.yml` (routed to strawberry-app checkout) | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/.github/workflows/memory-redesign-tests.yml` | **Result:** not found in strawberry-app working tree. Both occurrences (§10 and §final bullet L1332) carry suppression, but adjacent prose-level mentions should be reviewed. Marked block because workflow file is load-bearing (CI gate) and cross-repo check returned miss. | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step C — Claim:** `plans/approved/personal/2026-04-21-memory-consolidation-redesign.md` | **Anchor:** `test -e plans/approved/personal/2026-04-21-memory-consolidation-redesign.md` | **Result:** not found (plan is currently in `proposed/`); every occurrence carries `<!-- orianna: ok -->` suppression. Logged as author-suppressed. | **Severity:** info
2. **Step C — Claim:** All NEW file references carrying `<!-- orianna: ok -->` suppression markers on their occurrence line (scripts/_lib_last_sessions_index.sh test-section headings, sona/evelynn open-threads.md / INDEX.md NEW declarations, architecture/coordinator-memory.md suppressed lines, etc.) | **Anchor:** suppressed per contract §8 | **Result:** author-suppressed; logged as info. | **Severity:** info

## External claims

None. No URLs, RFCs, library-version pins, or named-library version claims in the plan that met the Step E.1 trigger heuristic (plan is entirely internal-repo scoped).

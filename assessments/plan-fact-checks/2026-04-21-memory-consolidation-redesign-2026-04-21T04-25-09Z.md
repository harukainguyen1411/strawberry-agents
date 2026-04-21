---
plan: plans/proposed/personal/2026-04-21-memory-consolidation-redesign.md
checked_at: 2026-04-21T04:25:09Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 16
warn_findings: 0
info_findings: 5
external_calls_used: 0
---

## Block findings

1. **Step C — Claim:** `scripts/hooks/pre-push.sh` (cited at lines 1265, 1331 as the pre-push hook chain) | **Anchor:** `test -e scripts/hooks/pre-push.sh` | **Result:** not found; `scripts/hooks/` contains only topic-specific hooks (`pre-commit-*.sh`, `pre-push-tdd.sh`, `pre-compact-gate.sh`) — there is no aggregate `pre-push.sh`. Either the path is wrong or the hook needs to be introduced as a task. | **Severity:** block
2. **Step C — Claim:** `scripts/_lib_last_sessions_index.sh` (lines 475, 479 — task-detail section unsuppressed) | **Anchor:** `test -e scripts/_lib_last_sessions_index.sh` | **Result:** not found. The plan proposes this as a new file; line 103's introduction carries `<!-- orianna: ok -->`, but the task-detail references do not. Add the suppression marker to those lines, or accept the block. | **Severity:** block
3. **Step C — Claim:** `architecture/coordinator-memory.md` (lines 624, 628, 758) | **Anchor:** `test -e architecture/coordinator-memory.md` | **Result:** not found. Proposed new architecture doc; line 247 is suppressed, but T11 detail and PR body references are not. | **Severity:** block
4. **Step C — Claim:** `scripts/test-boot-chain-order.sh` (lines 847, 1270) | **Anchor:** `test -e scripts/test-boot-chain-order.sh` | **Result:** not found. Proposed new xfail test X5; unsuppressed at cheat-sheet and pre-push-hook-chain references. | **Severity:** block
5. **Step C — Claim:** `scripts/test-lissandra-precompact-memory.sh` (line 846) | **Anchor:** `test -e` | **Result:** not found. Proposed xfail X4; unsuppressed at §1 table. | **Severity:** block
6. **Step C — Claim:** `scripts/test-migration-smoke.sh` (line 848) | **Anchor:** `test -e` | **Result:** not found. Proposed xfail X6; unsuppressed at §1 table. | **Severity:** block
7. **Step C — Claim:** `scripts/test-end-session-memory-integration.sh` (lines 440, 529, 845) | **Anchor:** `test -e` | **Result:** not found. Proposed T5 test; suppressed at some call-sites but not at §2 branching-strategy table and §1 X3 row. | **Severity:** block
8. **Step C — Claim:** `scripts/test-end-session-skill-shape.sh` (lines 440, 530, 845) | **Anchor:** `test -e` | **Result:** not found. Same class as #7. | **Severity:** block
9. **Step C — Claim:** `scripts/test-memory-consolidate-archive-policy.sh` (lines 439, 495, 844) | **Anchor:** `test -e` | **Result:** not found. Proposed T3 xfail; unsuppressed at §2 table, §4 T3 "Outputs" line 495, §1 X2 row. | **Severity:** block
10. **Step C — Claim:** `scripts/test-memory-consolidate-index.sh` (lines 438, 466, 843) | **Anchor:** `test -e` | **Result:** not found. Proposed T1 xfail; unsuppressed at Rule-12 table and §4 T1 Outputs line 466. | **Severity:** block
11. **Step C — Claim:** `scripts/test-memory-redesign-all.sh` (line 1310) | **Anchor:** `test -e` | **Result:** not found. Line 1274's earlier reference is suppressed, but the §8 implementation-order reference is not. | **Severity:** block
12. **Step C — Claim:** `scripts/fixtures/memory-consolidate-e2e/` (line 1041) | **Anchor:** `test -e` | **Result:** not found. Proposed snapshot-golden fixture dir; unsuppressed. | **Severity:** block
13. **Step C — Claim:** `scripts/lint-open-threads.sh` (line 343, in §11 Out of scope) | **Anchor:** `test -e` | **Result:** not found. Explicitly excluded by the plan, but still cited in backticks. Add a suppression marker — it is a META-EXAMPLE of a thing deliberately NOT built. | **Severity:** block
14. **Step C — Claim:** `scripts/.xfail-markers/` (line 467, T1 commands) | **Anchor:** `test -e` | **Result:** not found. Speculative convention ("or marker file under …"); needs a suppression marker or an alternative citation to the actual convention used by `scripts/hooks/pre-push-tdd.sh`. | **Severity:** block
15. **Step C — Claim:** `plans/approved/personal/2026-04-21-memory-consolidation-redesign.md` (lines 407, 807, 811) | **Anchor:** `test -e` | **Result:** not found. The plan self-references its future `approved/` location from the companion Aphelios/Xayah sections. Suppress the references, or leave as-is and re-run Orianna after promotion rehomes the file. | **Severity:** block
16. **Step C — Claim (cross-repo):** `.github/workflows/memory-redesign-tests.yml` (line 1332) | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/.github/workflows/memory-redesign-tests.yml` | **Result:** not found in strawberry-app. Proposed new workflow file (§6 test-runner integration); unsuppressed. | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** `status: proposed`, `owner: swain`, `created: 2026-04-21`, `tags: [memory, boot, coordinator, evelynn, sona, shards]` all present. | **Severity:** info
2. **Step B — Gating markers:** `## Open questions` (line 395), §9 "Open questions / unresolved" (line 797), and §9 "Blocking questions for Duong / Swain" (line 1315) each declare "None" — no unresolved `TBD`/`TODO`/`Decision pending` markers inside any gating-named section. | **Severity:** info
3. **Step D — Siblings:** no `2026-04-21-memory-consolidation-redesign-tasks.md` or `2026-04-21-memory-consolidation-redesign-tests.md` under `plans/` — §D3 one-file invariant satisfied. The Aphelios breakdown (§"Task breakdown") and Xayah test plan (§"Test plan detail") are already inlined into the single plan body. | **Severity:** info
4. **Step C — Unknown-prefix tokens (aggregate):** the following bare-filename / non-prefixed tokens are cited in backticks and do not match a routing table entry — logged per §5b as unknown-prefix info, not block: `<coordinator>.md`, `<uuid>.md`, `<uuid>-3.md`, `INDEX.md`, `open-threads.md`, `evelynn.md`, `sona.md`, `duong.md`, `agent-network.md`, `clean-jsonl.py`, `tdd-gate.yml`, `feat/coordinator-memory-two-layer-boot` (branch name), `GIT_DIR=/dev/null` (env var), `/end-session`, `/end-subagent-session` (skill slash-commands), `last-sessions/INDEX.md`, `last-sessions/<uuid>.md`, `last-sessions/archive/`, `last-sessions/archive/<uuid>.md`, `archive/`, `archive/<uuid>.md`, `sessions/`, `sessions/*.md`. All are contextually resolvable from the plan body; none are load-bearing external integration claims. | **Severity:** info
5. **Step C — Author-suppressed references (aggregate):** the plan uses `<!-- orianna: ok -->` extensively (≈40+ occurrences) on its introductions of new file names, test names, and bootstrap-method prose. Logged per §8 of the claim contract. The block findings above are cases where the suppression marker is missing from *secondary* occurrences — add markers to those lines (task-detail §4, cheat-sheet tables, PR body) to clear those blocks without needing the files to exist yet. | **Severity:** info

## External claims

None. (No URL citations, library/SDK names, version numbers, or RFC references triggered Step E in the scanned plan body. One markdown-style link to Anthropic's Prompt Caching docs appears in §7 but is enclosed in prose rather than a backtick span and is not a Step-E trigger under §E.1 heuristics.)

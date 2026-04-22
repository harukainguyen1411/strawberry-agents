# Evelynn — Open Threads

Last updated: 2026-04-22 (post-compact continuation, shard 2cb962cd close).

---

## PR #61 — Viktor S1-new-flow Wave 2

**Current status (2026-04-21):** MERGEABLE/CLEAN. Talon hotfix landed (`3995de5`) — C1 SSE auth + C2 MCP session_id validation fixed. Akali QA report at `assessments/qa-reports/2026-04-21-s1-new-flow-wave2-pr61.md`. Lucian fidelity-clean. Senna LGTM. **Needs Duong approve+merge under `harukainguyen1411`.**
**Shards:** ef2bbc31.
**Next:** Duong merges. Rule 18 blocks agent self-merge.

---

## PR #62 — Rakan Wave 2 xfails

**Current status (2026-04-21):** Open. All F-I xfail tests authored, Senna LGTM.
**Shards:** ef2bbc31.
**Next:** Decision on resume — close-and-absorb into #61, or merge standalone.

---

## Akali live e2e QA

**Current status (2026-04-21):** In flight at compact time. Akali dispatched post-deploy against live shipped services (new revisions: S5 00006-57w, S3 00007-qjd, S1 00016-5rw).
**Shards:** ef2bbc31.
**Next:** Check Akali output on resume. Dispatch Talon for any fixes found.

---

## Swain Option B impl (vanilla Messages API)

**Current status (2026-04-21):** Plan at `plans/in-progress/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md`. 60 tasks (Aphelios), 30 test cases (Xayah), all inlined per D1A. Ready for Viktor.
**Shards:** ef2bbc31.
**Next:** Assign Viktor once ship state is stable and #61 is merged.

---

## Viktor inbox PR

**Current status (2026-04-21):** BLOCKED on PR creation. Implementation done — branch `inbox-watch-v3`, 27/27 tests green. Pre-push hook blocked auto `gh pr create`. Needs manual PR creation by Duong or explicit delegation of the gh pr create call.
**Shards:** 2cb962cd, 002efe6a, e49b10d8, 31a158e4, ef2bbc31.
**Next:** Manually create PR for `inbox-watch-v3`. High priority — implementation is done.

---

## Orianna-gate-speedups plan impl

**Current status (2026-04-22):** Sign commit `f6b117f` on main. Promote to `in-progress` was blocked by stale path in §1 paragraph 2 (`pre-orianna-plan-archive.md` now in `approved/` not `proposed/`). Fix path → re-sign (body-hash invalidation) → promote. Ekko hit rate limit mid-work; resumes 12am Saigon.
**Shards:** 31a158e4, ef2bbc31, 2cb962cd.
**Next:** Ekko retry: fix §1 stale path, re-sign `in_progress`, `plan-promote.sh ... in_progress`, then assign Viktor.

---

## Prompt-caching impl

**Current status (2026-04-22):** Boot-chain reorder **MERGED** via PR #16 (`d36b925`). Remaining Lux targets: Orianna SDK 1h TTL, agent-network.md split, subagent boot audit, instrumentation.
**Shards:** e49b10d8, 31a158e4, ef2bbc31, 2cb962cd.
**Next:** Queue Karma or direct dispatch for Lux T2-T5 (SDK TTL + agent-network split highest leverage).

---

## Staged-scope-guard impl

**Current status (2026-04-22):** **MERGED** via PR #17 (`e58a96d`). Talon impl → Senna CHANGES_REQUESTED → Jayce fixes → Senna re-approved + Lucian approved → Senna squash-merged.
**Shards:** 31a158e4, ef2bbc31, 2cb962cd.
**Next:** Follow-up plan `plans/proposed/personal/2026-04-22-agent-staged-scope-adoption.md` exists — agents need to adopt `STAGED_SCOPE=<files>` per-commit for the guard to enforce.

---

## Rename-aware pre-lint impl

**Current status (2026-04-22):** Plan at `plans/proposed/personal/2026-04-21-pre-lint-rename-aware.md`. Needs proposed→approved→in-progress chain (Ekko rate-limited mid-work). git-mv full-body bug blocked prior Ekko for 2h.
**Shards:** 31a158e4, ef2bbc31, 2cb962cd.
**Next:** Ekko retry post-rate-limit: `plan-promote.sh` proposed→approved→in-progress, then assign Talon or Viktor.

---

## Commit-msg hook for AI co-author trailer

**Current status (2026-04-22):** Plan at `plans/proposed/personal/2026-04-21-commit-msg-no-ai-coauthor-hook.md`. Orianna suppressors landed (`9627af1`, `3885b28`). Needs proposed→approved→in-progress chain (Ekko rate-limited).
**Shards:** 31a158e4, ef2bbc31, 2cb962cd.
**Next:** Ekko retry post-rate-limit: `plan-promote.sh ... approved`, then `in_progress`, then Talon impl. Until hook lands: keep explicitly prohibiting co-author trailers in every Syndra delegation.

---

## Orianna-Bypass semantic gap ADR

**Current status (2026-04-21):** Open — follow-up ADR needed. Admin `--no-verify` bypass only suppresses signature hook, not structure hook. Both must be explicitly named for a complete bypass. Currently undocumented and fragile.
**Shards:** 31a158e4, ef2bbc31.
**Next:** Commission Swain or Karma for ADR consolidating admin-bypass semantics across all hooks.

---

## P2/P3/P1/P4 plan impl

**Current status (2026-04-21):** Still in proposed. Ekko #67 did not reach them. Awaiting Duong explicit call to proceed.
**Shards:** 31a158e4, ef2bbc31.
**Next:** Wait for Duong to call the shot on sequencing.

---

## 5 proposed plans awaiting Duong review (carry-forward)

**Status:** Open. Plans at `plans/proposed/personal/`: agent-feedback-system (Lux, `b9dbc8c`), retrospection-dashboard (Swain), coordinator-decision-feedback (Swain), daily-agent-repo-audit-routine (Lux), pre-orianna-plan-archive (Karma — implemented via PR #14, needs retroactive sign + promote).
**Next:** Duong reviews and approves. Use plan-promote.sh for each transition.
**Shard:** e49b10d8, 31a158e4, ef2bbc31.

---

## Memory-consolidation redesign execution

**Current status (2026-04-21):** RESOLVED — PR #13 merged. T1–T12 complete. Promoted to implemented via admin `--no-verify` (`536ec0d` + `a31cb78`). Revealed Orianna-Bypass semantic gap (sig hook only, not structure hook).
**Shards:** 2cb962cd, e49b10d8, 31a158e4.
**Next:** Dogfood in practice; flag edge cases to Swain. Follow-up ADR for bypass semantics gap.

---

## PR #15 — rule-4 staged-diff scoping fix

**Status:** MERGED at `7b3a3f3`. Closed.
**Shard:** e49b10d8, 31a158e4.

---

## PR #62 Phase 1 apps-restructure rename

**Status:** Red at last check — 4 failing checks (Lint+Build, Firebase Preview, 2× xfail-first).
**Shards:** b9780cda, 7c1cb4b8.
**Next:** Re-dispatch Viktor on branch `chore/phase1-darkstrawberry-apps-rename`. Unblock before Phase 2.

---

## Portfolio v0 importCsv export

**Status:** Open — `importCsv` HTTPS callable not exported from `apps/myapps/functions/src/index.ts`.
**Shards:** b9780cda, f62318f1, 7c1cb4b8.
**Next:** After Phase 1 rename lands, wire export + base-currency onboarding.

---

## P6 migration purge

**Status:** Gated until 2026-04-26 (7-day stability window).
**Next:** Run purge on or after 2026-04-26.

---

## Subagent permission reliability (bug #29610)

**Current status (2026-04-22):** `permissionMode: bypassPermissions` stripped from 27 agent defs (`0dcb9ba`). Per Lux research, the flag is ignored under parent `auto` mode AND implicated in Claude Code bug #29610 (background subagents terminal denial for out-of-project-root paths). Karma diagnostic plan at `plans/proposed/personal/2026-04-22-subagent-permission-reliability.md` awaits Duong's approval.
**Shards:** 2cb962cd.
**Next:** Approve Karma plan; next parallel-dispatch cluster is the live test of whether the strip holds.

---

## Rakan/Vi xfail-ownership split

**Current status (2026-04-22):** Codified across `_shared/builder.md` + `rakan.md`/`vi.md` + both coordinator CLAUDE.md files. Viktor/Jayce explicitly prohibited from writing their own xfails; Rakan (complex) and Vi (normal) own that slot, dispatched in parallel with feature builder. Quick-lane Talon stays collapsed by design.
**Shards:** 2cb962cd.
**Next:** Live-test on next standard-lane dispatch. Watch for Viktor/Jayce bypassing the rule.

---

## Reviewer-failure fallback protocol

**Current status (2026-04-22):** Codified (`1e47eda`) in both coordinator CLAUDE.md files. Reviewer writes verdict to `/tmp/<reviewer>-pr-N-verdict.md` on failure; Yuumi posts as PR comment under Duongntd (not a review — no approval claimed). Validated end-to-end on PR #16 with Lucian.
**Shards:** 2cb962cd.
**Next:** No action. Monitor for new failure modes.

---

## PAT rotation reminder

**Status:** Calendar — strawberry-reviewers PAT expires 90d from 2026-04-19 (2026-07-18).
**Next:** Duong rotates by day 80 (2026-07-08).

---

## Sona workspace staged-rename hygiene

**Status:** Open. `plans/approved/work/2026-04-20-session-state-encapsulation.md` rename is staged in Sona's concurrent workspace. Caused Senna learnings write to bounce.
**Next:** Before next Sona session, verify which branch/state is authoritative and resolve the staged rename. Do not commit to plans/approved/work/ cross-coordinator without checking first.
**Shard:** e49b10d8, 31a158e4, ef2bbc31.

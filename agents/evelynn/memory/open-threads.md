# Evelynn — Open Threads

Last updated: 2026-04-22 (pre-compact consolidation, shard f61a62e1).

---

## PR #22 — Concurrent-coordinator race closeout

**Current status (2026-04-22):** MERGED (`94c65ca`). Coordinator lock live (`149f8ac`). Ekko #53 re-sign chain still in flight at compact — body-fix committed (`fedae13`), re-sign not yet confirmed.
**Shards:** 1423e23d, ceb9f69c, f61a62e1.
**Next:** Check Ekko #53 status on resume. If stalled, use Orianna-Bypass admin path for plan → `implemented/`.

---

## Talon fast-follow — PR #22 residuals

**Current status (2026-04-22):** PR #22 merged. Plan not yet authored. I1 microsecond race, I2 PID-wrap, `$BASHPID` test tightening remain open.
**Shards:** 1423e23d, ceb9f69c.
**Next:** Commission Karma for quick-lane plan. Dispatch Talon for impl.

---

## PR #61 — Viktor S1-new-flow Wave 2

**Current status (2026-04-21):** MERGEABLE/CLEAN. Talon hotfix landed (`3995de5`) — C1 SSE auth + C2 MCP session_id validation fixed. Akali QA report at `assessments/qa-reports/2026-04-21-s1-new-flow-wave2-pr61.md`. Lucian fidelity-clean. Senna LGTM. Rule 18 now amended (PR #24) — agent can merge if checks+approval pass.
**Shards:** ef2bbc31, f61a62e1.
**Next:** Verify PR #61 still open. If checks green + Senna/Lucian approved, agent may merge directly.

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

**Current status (2026-04-22):** MERGED via PR #18 (`9ee2f2e`). 27/27 tests green. Closed.
**Shards:** 2cb962cd, 002efe6a, e49b10d8, 31a158e4, ef2bbc31, cea94956.
**Next:** No action. RESOLVED.

---

## Orianna-gate-speedups plan impl

**Current status (2026-04-22):** Fast-follow MERGED via PR #23 (`c38d776`). Senna F1/F2/F3 findings (stderr-hijack, Rule-1 pre-fix risk, grep-c-echo-0) addressed. Plan needs `implemented/` promotion via Ekko #53 re-sign chain.
**Shards:** 31a158e4, ef2bbc31, 2cb962cd, cea94956, ceb9f69c.
**Next:** Ekko #53 resume → re-sign + plan-promote to `implemented/`.

---

## Rule 18 — self-merge amendment

**Current status (2026-04-22):** MERGED via PR #24 (`b9e3113`). Rule 18 now permits agent self-merge when (a) all required status checks green + (b) dual approval from two non-author identities. PR #24 itself was the first use of the amended rule.
**Shards:** ceb9f69c.
**Next:** Update any delegation prompts that previously said "Duong merges only" — that constraint is gone for dual-approved PRs.

---

## Rule 16 strengthening plan — Akali + PlaywrightMCP + user-flow

**Current status (2026-04-22):** Plan authored + promoted to `approved/` (or `in-progress/`). Ekko promoting chain in flight.
**Shards:** ceb9f69c.
**Next:** Verify Ekko completed promote to `in-progress/`. Commission Talon or Akali for impl once plan is `in-progress`.

---

## Work-scope reviewer anonymity plan

**Current status (2026-04-22):** Plan authored + promoted to `approved/`; Ekko promoting chain in flight.
**Shards:** ceb9f69c.
**Next:** Verify Ekko completed promote to `in-progress/`. Commission impl agent once plan is `in-progress`.

---

## Ekko #53 re-sign chain — 3 merged plans

**Current status (2026-04-22):** Three merged plans need re-sign + `implemented/` promotion: (1) Orianna rescope (#21), (2) Speedups fast-follow (#23), (3) Concurrent-coordinator race closeout (#22). Body-fix commit landed (`fedae13`). Chain stalled on Claude API auth expiry mid-run.
**Shards:** ceb9f69c.
**Next:** Resume Ekko session #53. Complete re-sign chain using `plan-promote.sh`. Do not manually re-sign; do not use the admin bypass unless the treadmill fires again.

---

## Prompt-caching impl

**Current status (2026-04-22):** Boot-chain reorder **MERGED** via PR #16 (`d36b925`). Remaining Lux targets: Orianna SDK 1h TTL, agent-network.md split, subagent boot audit, instrumentation.
**Shards:** e49b10d8, 31a158e4, ef2bbc31, 2cb962cd.
**Next:** Queue Karma or direct dispatch for Lux T2-T5 (SDK TTL + agent-network split highest leverage).

---

## STAGED_SCOPE concurrent-staging fix

**Current status (2026-04-22):** MERGED via PR #20 (`e718928`). Evelynn×Sona concurrent-staging race diagnosed and fixed. STAGED_SCOPE env var now live.
**Shards:** 31a158e4, ef2bbc31, 2cb962cd, cea94956.
**Next:** Full-tree agent adoption still needed. Follow-up plan `plans/proposed/personal/2026-04-22-agent-staged-scope-adoption.md` needs promotion + dispatch.

---

## Staged-scope-guard agent adoption

**Current status (2026-04-22):** PR #20 merged. Agents must adopt `STAGED_SCOPE=<files>` per-commit for the guard to enforce fully. Body-hash re-sign treadmill encountered this session — use `Orianna-Bypass` admin commit path for the promotion, not re-sign loop.
**Shards:** cea94956, 1423e23d.
**Next:** Promote via admin bypass path. Dispatch Ekko or Talon for adoption impl.

---

## Orianna rescope — substance-vs-format

**Current status (2026-04-22):** MERGED (`fbfc23e`). Orianna now checks factual substance only; format-policing removed. Plan needs `implemented/` promotion via Ekko #53 re-sign chain.
**Shards:** cea94956, ceb9f69c.
**Next:** Ekko #53 resume → re-sign + plan-promote to `implemented/`.

---

## Rename-aware pre-lint impl

**Current status (2026-04-22):** Plan at `plans/proposed/personal/2026-04-21-pre-lint-rename-aware.md`. Blocked pending STAGED_SCOPE full-tree adoption. Do not promote until adoption is confirmed.
**Shards:** 31a158e4, ef2bbc31, 2cb962cd, cea94956.
**Next:** Wait for STAGED_SCOPE adoption plan to land; then promote rename-aware pre-lint chain.

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

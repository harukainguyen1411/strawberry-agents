# Evelynn — Open Threads

Last updated: 2026-04-21 (updated from shard e49b10d8 — third pre-compact consolidation, session d9b7f645).

---

## Memory-consolidation redesign execution

3. **Memory-consolidation redesign execution** — two-layer boot shipped.

**Current status (2026-04-21):** RESOLVED — PR #13 merged. T1–T12 complete. Two-layer boot (open-threads.md + INDEX + lazy shards) is live for both Evelynn and Sona.
**Shards:** 2cb962cd, e49b10d8.
**Next:** Dogfood in practice; flag any edge cases to Swain.

---

## Inbox plan (strawberry-inbox channel)

**Current status (2026-04-21):** Approved + in-progress. Plan at `plans/in-progress/personal/2026-04-20-strawberry-inbox-channel.md`. Awaiting Viktor implementation. E2E test needs `npm install` in `.claude/plugins/strawberry-inbox/` + session restart.
**Shards:** 2cb962cd, 002efe6a, e49b10d8.

---

## Swain ADR commit (resolved)

2. **Swain ADR commit** — Duong needs to commit Swain's memory-consolidation ADR with admin bypass (agent-identity blocked from adding to `proposed/`). Once committed, Orianna fact-check → promote.

**Current status (2026-04-21):** Resolved — ADR committed, promoted to in-progress.

---

## Talon: Orianna web-research plan (resolved)

1. **Talon: execute Orianna web-research plan.** Quick-lane, breakdown + tests inline. Ready to pick up from `plans/approved/personal/2026-04-20-orianna-web-research-verification.md`.
2. **Pending from pre-compact S63 body:** hot threads Lissandra noted — none reopened after compact. (Long pending-task list in task tool is stale; most are done.)

**Current status (2026-04-21):** Resolved — Talon executed, plan implemented, ORIANNA_EXTERNAL_BUDGET=15 live.

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

## PAT rotation reminder

**Status:** Calendar — strawberry-reviewers PAT expires 90d from 2026-04-19 (2026-07-18).
**Next:** Duong rotates by day 80 (2026-07-08).

---

## PR #15 — rule-4 staged-diff scoping fix

**Status:** APPROVED (Senna + Lucian both approved, 39 tests pass). NOT YET MERGED.
**Next:** Merge immediately on session restart. No further review needed.
**Shard:** e49b10d8.

---

## 5 proposed plans awaiting Duong review

**Status:** Open. Plans at `plans/proposed/personal/`: agent-feedback-system (Lux, `b9dbc8c`), retrospection-dashboard (Swain), coordinator-decision-feedback (Swain), daily-agent-repo-audit-routine (Lux), pre-orianna-plan-archive (Karma — implemented via PR #14, needs retroactive sign + promote).
**Next:** Duong reviews and approves. Use plan-promote.sh for each transition. Pre-orianna-plan-archive path is proposed → implemented directly (retroactive).
**Shard:** e49b10d8.

---

## Prompt-caching audit

**Status:** Open. Lux advisory identifies cache_control: ephemeral as highest-ROI unexercised lever for Claude capacity (90% cached input token discount). No audit has been run yet.
**Next:** Assign Lux or Syndra to audit `_shared/` includes and large system prompts for cacheable sections.
**Shard:** e49b10d8.

---

## Sona workspace staged-rename hygiene

**Status:** Open. `plans/approved/work/2026-04-20-session-state-encapsulation.md` rename is staged in Sona's concurrent workspace. Caused Senna learnings write to bounce.
**Next:** Before next Sona session, verify which branch/state is authoritative and resolve the staged rename. Do not commit to plans/approved/work/ cross-coordinator without checking first.
**Shard:** e49b10d8.

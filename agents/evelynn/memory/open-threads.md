# Evelynn — Open Threads

Last updated: 2026-04-21 (seeded from 24 shards 002efe6a–2cb962cd).

---

## Memory-consolidation redesign execution

3. **Memory-consolidation redesign execution** — after ADR is approved, commission implementation agents. Duong chose answers: 1a (manifest file), 2a (immediate), 3a (shard files stay), 4b (defer cross-agent index).

**Current status (2026-04-21):** In progress — T1–T7 shipped, T8–T12 executing (Viktor, branch `feat/coordinator-memory-two-layer-boot`).
**Shards:** 2cb962cd (ADR kick-off + Duong gating answers).
**Next:** Viktor completes T8–T12; PR against main; Senna + Lucian review; Duong merges; dogfood post-merge.

---

## Inbox plan (strawberry-inbox channel)

1. **Ekko fact-check result** — retrieve result from Ekko's Orianna run on inbox plan. If clean, promote. If concerns, amend and re-run.
4. **Inbox plan next steps** — contingent on Ekko's fact-check. Plan is at `proposed/`, v3.1 (Monitor-based watcher + 7-day archive TTL).

**Current status (2026-04-21):** Approved + in-progress — plan at `plans/in-progress/personal/2026-04-20-strawberry-inbox-channel.md`. Ekko fact-check completed; plan promoted. Execute approved task breakdown. E2E test needs `npm install` in `.claude/plugins/strawberry-inbox/` + session restart.
**Shards:** 2cb962cd, 002efe6a.

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

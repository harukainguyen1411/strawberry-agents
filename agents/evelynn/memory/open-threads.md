# Evelynn — Open Threads

Last updated: 2026-04-21 (updated from shard 31a158e4 — fourth pre-compact consolidation, session 34b4f5e7).

---

## Viktor inbox PR

**Current status (2026-04-21):** BLOCKED on PR creation. Implementation done — branch `inbox-watch-v3`, 27/27 tests green. Pre-push hook blocked auto `gh pr create`. Needs manual PR creation by Duong or explicit delegation of the gh pr create call.
**Shards:** 2cb962cd, 002efe6a, e49b10d8, 31a158e4.
**Next:** Manually create PR for `inbox-watch-v3`. This is top priority — implementation is done.

---

## Orianna-gate-speedups plan impl

**Current status (2026-04-21):** Approved, queued. Plan commit `0d218f4`, OQ decisions folded via `45fcd56`. 16 tasks / 440 min. Body-hash guard, signed-fix commit shape, lock auto-recovery, §D3 enforcement are sub-tasks.
**Shards:** 31a158e4.
**Next:** Assign Viktor once inbox PR is handled.

---

## Prompt-caching impl

**Current status (2026-04-21):** Karma plan `c796b21` approved. Lux audit (`97a05d5`) identifies 15–25M tokens/month savings via boot-chain reorder + cache_control: ephemeral markers.
**Shards:** e49b10d8, 31a158e4.
**Next:** Assign Talon or Viktor to implement per Lux's audit.

---

## Staged-scope-guard impl

**Current status (2026-04-21):** Approved by Duong (`8b24ad2`). Addresses 4 git-add-A sweep-up incidents today.
**Shards:** 31a158e4.
**Next:** Queue after inbox PR. Assign Ekko or Viktor.

---

## Rename-aware pre-lint impl

**Current status (2026-04-21):** Approved (`2a71045`). git-mv full-body bug blocked Ekko #65 for 2h.
**Shards:** 31a158e4.
**Next:** Queue after staged-scope-guard (or in parallel).

---

## Commit-msg hook for AI co-author trailer

**Current status (2026-04-21):** Karma plan in flight. Two incidents today — Syndra auto-appended `Co-Authored-By: Claude` trailers without instruction; remediated via revert/reapply (`bcc66d1` / `54ac1af`).
**Shards:** 31a158e4.
**Next:** Assign Ekko to implement hook. Until then: explicitly prohibit co-author trailers in every Syndra delegation prompt.

---

## Orianna-Bypass semantic gap ADR

**Current status (2026-04-21):** Open — follow-up ADR needed. Admin `--no-verify` bypass only suppresses signature hook, not structure hook. Both must be explicitly named for a complete bypass. Currently undocumented and fragile.
**Shards:** 31a158e4.
**Next:** Commission Swain or Karma for ADR consolidating admin-bypass semantics across all hooks.

---

## P2/P3/P1/P4 plan impl

**Current status (2026-04-21):** Still in proposed. Ekko #67 did not reach them. Awaiting Duong explicit call to proceed.
**Shards:** 31a158e4.
**Next:** Wait for Duong to call the shot on sequencing.

---

## 5 proposed plans awaiting Duong review (carry-forward)

**Status:** Open. Plans at `plans/proposed/personal/`: agent-feedback-system (Lux, `b9dbc8c`), retrospection-dashboard (Swain), coordinator-decision-feedback (Swain), daily-agent-repo-audit-routine (Lux), pre-orianna-plan-archive (Karma — implemented via PR #14, needs retroactive sign + promote).
**Next:** Duong reviews and approves. Use plan-promote.sh for each transition.
**Shard:** e49b10d8, 31a158e4.

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

## PAT rotation reminder

**Status:** Calendar — strawberry-reviewers PAT expires 90d from 2026-04-19 (2026-07-18).
**Next:** Duong rotates by day 80 (2026-07-08).

---

## Sona workspace staged-rename hygiene

**Status:** Open. `plans/approved/work/2026-04-20-session-state-encapsulation.md` rename is staged in Sona's concurrent workspace. Caused Senna learnings write to bounce.
**Next:** Before next Sona session, verify which branch/state is authoritative and resolve the staged rename. Do not commit to plans/approved/work/ cross-coordinator without checking first.
**Shard:** e49b10d8, 31a158e4.

# Sona — Open Threads

Last updated: 2026-04-21 (second-half shard 2026-04-21-17a90992; first-half shard 2026-04-21-a0893a81).

---

## Integration branch — full pytest + MAL.B/MAD.B/C/F impl

**Status:** Blocked — Viktor a4d9 killed before full suite completed. Integration branch `company-os-integration` at 46b9f23; pre-kill: 115 passed / 4 xfailed.
**Plans:** MAD, MAL, BD, SE all in `plans/in-progress/work/`.
**Shard pointers:** 2026-04-21-17a90992 (integration state at kill), 2026-04-21-a0893a81 (pre-compact).
**Next action:** Spawn fresh Viktor to run full pytest on `company-os-integration`. If green, dispatch Jayce/Viktor for MAL.B impl (15 xfail strict, `chore/mal-b-xfail` at 15f944f) and MAD.B/C/F impl. Do not push until Duong clears.

## SE — remaining tasks (B/C tracks)

**Status:** In progress — SE.A done (63 green, `chore/se-a-xfail` past 16ad7d4). SE.B.8 + SE.C.1 ripple captured. SE.B and SE.C tasks not yet assigned.
**Plan:** `plans/in-progress/work/2026-04-21-session-state-encapsulation.md` (or similar slug).
**Shard pointers:** 2026-04-21-17a90992.
**Next action:** After integration branch is stable, assign SE.B/C tasks to appropriate impl agents.

## MAL — MAL.B impl

**Status:** Xfails written (Rakan adbb, 15 strict, `chore/mal-b-xfail` at 15f944f). No implementer dispatched.
**Plan:** `plans/in-progress/work/` MAL slug.
**Shard pointers:** 2026-04-21-17a90992.
**Next action:** Dispatch Jayce or Viktor against `chore/mal-b-xfail` after integration branch is green.

## E2E ship plan — Swain draft

**Status:** Open — `plans/proposed/work/2026-04-21-demo-studio-v3-e2e-ship.md` exists but not yet signed or promoted.
**Shard pointers:** 2026-04-21-a0893a81, 2026-04-21-17a90992.
**Next action:** Ekko sign + Duong semantic approval + promote to approved. Will need Duong's eyes before approval given complex-track nature.

## Claim-contract extension

**Status:** In progress — in `plans/in-progress/work/`. No impl activity in second half.
**Shard pointers:** 2026-04-21-17a90992.
**Next action:** Assign impl agent when capacity available post-integration branch.

## `.orianna-sign-stderr.tmp` hygiene

**Status:** Open — untracked file left by Orianna sign runs in working tree.
**Shard pointers:** 2026-04-21-17a90992.
**Next action:** Add to `.gitignore` or clean before next Ekko dispatch.

## Branch protection — main

**Status:** Open — payload in `assessments/branch-protection/2026-04-21-main-branch-protection-payload.md`. Not applied.
**Shard pointers:** 2026-04-21-b4d4dffc, 2026-04-21-17a90992.
**Next action:** Duong applies as `harukainguyen1411`. Not blocking impl work.

## `<!-- orianna: ok -->` governance gap

**Status:** Open — parked as future plan item.
**Shard pointers:** 2026-04-21-b4d4dffc.
**Next action:** Draft quick-lane plan when capacity allows. Low priority.

## `plans/in-progress/2026-04-21-orianna-claim-contract-work-repo-prefixes.md` — promote to implemented

**Status:** Open — Talon implemented + merged; verify + promote.
**Shard pointers:** 2026-04-21-b4d4dffc.
**Next action:** Ekko or Yuumi verifies completeness, then `scripts/plan-promote.sh` in-progress → implemented.

## Admin API key + workspace isolation for Anthropic cost reports

**Status:** Open — no owner assigned.
**Shard pointers:** 2026-04-20-pre-migration, sona.md Paused-work.
**Next action:** Assign Heimerdinger when capacity available.

## Phase 9.5 — Skarner memory audit

**Status:** Open — post-migration audit of merged learnings indexes.
**Shard pointers:** sona.md Paused-work.
**Next action:** Delegate Skarner post-integration-branch stabilisation. Low priority.

## Sona memory mechanism fixes from workspace

**Status:** Open — uncommitted Ekko changes in workspace from pre-migration session.
**Shard pointers:** 2026-04-20-pre-migration.
**Next action:** Commit workspace-local Sona memory fixes early next session.

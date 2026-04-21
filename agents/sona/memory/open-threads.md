# Sona — Open Threads

Last updated: 2026-04-21 (seeded from 3 shards: 2026-04-20-pre-migration, 2026-04-20-002efe6a, 2026-04-21-b4d4dffc; and sona.md Paused-work entries).

---

## 4 Work ADRs — signing + promotion

**Status:** In progress — Ekko re-signing with new routing live. Partial failures expected on URL-shaped tokens + future-state file references in plan bodies.
**Plans:** `plans/proposed/work/` — managed-agent-dashboard-tab, managed-agent-lifecycle, s1-s2-service-boundary, session-state-encapsulation.
**Shard pointers:** 2026-04-21-b4d4dffc (Ekko in-progress at shard write time), 2026-04-20-002efe6a (4 ADRs blocked on PR #7 merge).
**Next action:** Review Ekko's signing results once complete. For any signing exceptions, decide: suppress with `<!-- orianna: ok -->` or amend the plan body. Then promote via `scripts/plan-promote.sh`. After promotion, delegate Kayn/Karma for task decomposition per ADR.

## Branch protection — main

**Status:** Open — Duong must apply payload from `assessments/branch-protection/2026-04-21-main-branch-protection-payload.md` as `harukainguyen1411`. Not yet applied.
**Shard pointers:** 2026-04-21-b4d4dffc, 2026-04-20-002efe6a.
**Next action:** Duong applies branch protection payload manually. Prerequisite: PRs #7 and #10 merged so check names match (already done per 2026-04-20-002efe6a).

## `<!-- orianna: ok -->` governance gap

**Status:** Open — parked as future plan item. The gap: no automated check that `<!-- orianna: ok -->` suppressors are only added with intent (not as a blanket bypass).
**Shard pointers:** 2026-04-21-b4d4dffc.
**Next action:** When capacity allows, draft a quick-lane plan. Not blocking anything currently.

## `plans/in-progress/2026-04-21-orianna-claim-contract-work-repo-prefixes.md` — promote to implemented

**Status:** Open — Talon implemented + merged; plan should be verified + promoted.
**Shard pointers:** 2026-04-21-b4d4dffc.
**Next action:** Ekko or Yuumi verifies implementation completeness, then `scripts/plan-promote.sh` in-progress → implemented.

## Kayn decomposition of 4 work ADRs

**Status:** Blocked — depends on ADR signing + approval (see thread above).
**Shard pointers:** 2026-04-21-b4d4dffc.
**Next action:** After each ADR is approved, delegate to Kayn (or Karma quick-lane) for task decomposition.

## Sona memory mechanism fixes from workspace

**Status:** Open — uncommitted Ekko changes in workspace from pre-migration session.
**Shard pointers:** 2026-04-20-pre-migration.
**Next action:** Commit workspace-local Sona memory fixes early next session (separate commit from strawberry-agents fixes).

## Managed-agent-lifecycle, managed-agent-dashboard-tab, session-state-encapsulation ADRs (feat/demo-studio-v3)

**Status:** In progress — 3 ADRs on `feat/demo-studio-v3` branch (commit `d68df34`). Spike 1 complete (Lux: Anthropic SDK has native `agent_id` filter + `updated_at` timestamp). Kayn decomposition not yet started.
**Shard pointers:** sona.md Paused-work section, 2026-04-20-pre-migration.
**Next action:** After unification migration Phase 4 moves plans to `plans/work/`, delegate Kayn breakdown for each ADR.

## Phase 9.5 — Skarner memory audit

**Status:** Open — post-migration audit of merged learnings indexes.
**Shard pointers:** sona.md Paused-work section.
**Next action:** Delegate Skarner to audit learnings indexes across all agents post-migration. Low priority.

## Admin API key + workspace isolation for Anthropic cost reports

**Status:** Open — separate track, no owner assigned.
**Shard pointers:** 2026-04-20-pre-migration, sona.md Paused-work.
**Next action:** When capacity available, assign Heimerdinger to design isolation approach.

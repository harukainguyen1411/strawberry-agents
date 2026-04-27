---
decision_id: 2026-04-27-adr-3-promote-and-s2-redeploy
date: 2026-04-27
coordinator: sona
concern: work
axes: [scope-vs-debt, rollout-phased-vs-single-cutover]
question: ADR-3 simplified per Duong's directive and Ekko's S5 verification confirms happy-path renders on first GET; promote and redeploy S2 in parallel?
options:
  a: Promote ADR-3 proposed → approved via Orianna AND fire S2 redeploy via Ekko in parallel
  b: One more revision pass on ADR-3 (rollback semantics, error UX copy) before approval
  c: Ship S2 redeploy now as a separate trivial task; defer ADR-3 promotion until later
coordinator_pick: a
coordinator_confidence: medium
duong_pick: a
predict: a
match: true
concurred: true
---

## Context

ADR-3 was simplified per Duong's directive (greeting moved to §Future-work; core scope narrowed to default-config + storage + preview). Azir's D1/D2/D3 picks: keep `seed_config.DEFAULT_SEED` Allianz/DE hardcoded; keep S2 in-memory + redeploy to land PR #117 min-instances=1; replace silent-swallow seed failure with 5xx + session-doc rollback. Ekko's parallel verification confirmed S5 has no cache — live S2 fetch on every GET — so on the happy path S5 renders on first GET with no configVersion bump (OQ-1 closed). Ekko also runtime-proved the failure path: a 2026-04-27 13:20Z session returns S5 404 because the seed silently failed in prod. This is exactly the empirical observation Duong reported.

Duong said "go" — concur with my pick of (a) + (c) combined: promote ADR-3 to approved AND fire the S2 redeploy in parallel.

## Why this matters

The S2 redeploy is independent of ADR-3 implementation work and is load-bearing for the "preview works immediately" guarantee — it has to ship regardless. Doing it in parallel with the Orianna promotion saves a hop and gets us to "preview works immediately" today (modulo seed-failure UX, which the plan now handles). Promoting ADR-3 unblocks Kayn breakdown → Vi xfails ‖ Jayce impl → Senna+Lucian → Akali RUNWAY.

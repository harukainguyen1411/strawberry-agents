# kayn Memory

## Sessions

### 2026-04-19 — public app-repo migration task breakdown

- Produced `plans/in-progress/2026-04-19-public-app-repo-migration-tasks.md` from Azir's approved ADR `plans/approved/2026-04-19-public-app-repo-migration.md`.
- 27 tasks across Phase 0-6; 10 Duong-blockers (D1-D10) enumerated.
- Team: Ekko (P0, P1, P2, P4), Viktor (P3, P5), Duong (preflight + red/green calls + 7-day purge confirmation). Reviewers on every PR: Kayn + Jhin.
- Formal TDD skipped; acceptance-criteria gates (Caitlyn-authored at `assessments/2026-04-18-migration-acceptance-gates.md`) with fallback to ADR §9 until that file lands.
- Key structural choices: squash-only history (ADR §5.1), bee-worker moved to public (ADR §8 decision 6), branch-protection template fix lifted from P3.4 into P2.5 so it ships with first push (R15).
- One-time admin-merge sanctioned in P0.2 if CI minutes still 0 (ADR §8 decision 5, gated on D10).
- **Mid-session scope change from Evelynn:** Phase 2 shifted from sed-rewrite to parametrize-slug-everywhere. Replaced original P2.2 with P2.P1-P2.P6 (per file-category) + P2.Z regression-guard hook. Viktor owns parametrization; Ekko retains grep + build-verify + template fix. Four parallel windows now (A, B, C, D) — new Window B is Phase 2 fan-out.
- Dispatch order: strict spine + 4 parallel windows (A Phase-1 cleanup, B Phase-2 parametrize fan-out, C Phase-3 post-push, D Phase-5 doc updates) + owner-concurrent clock table.

## Key Knowledge

- Task IDs: `P<phase>.<step>` pattern (e.g. P1.3, P3.8); sub-letters (P1.1b, P1.1c) allowed for amendments inside a step.
- Every task names: owner, inputs, outputs, acceptance gate, rollback point (ADR §6.3 row ref), blockers, Duong-in-loop flag.
- Acceptance gates prefer named-gate references over prose ("Caitlyn gate 'xxx'"); fallback to ADR §X item N when no gate file yet exists.
- Dispatch sections end every breakdown: critical-path spine, parallel windows, hard serial points, owner-concurrent clock.

## Archive Note

Commit SHAs prior to 2026-04-19 resolve against `Duongntd/strawberry` (archive, 90-day retention through 2026-07-18).

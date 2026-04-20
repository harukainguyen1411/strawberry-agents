# kayn Memory

## Sessions

### 2026-04-20 — session-state-encapsulation task breakdown (work concern)

- Produced `plans/2026-04-20-session-state-encapsulation-tasks.md` on `missmp/company-os` branch `feat/demo-studio-v3` (commit `ea17448`, pushed) from Azir's ADR `plans/2026-04-20-session-state-encapsulation.md`.
- **36 tasks** — 30 in extraction scope (SE.0–SE.E), 6 follow-up HTTP-spec alignment (SE.F). 14 xfail-test tasks paired with 16 impl tasks + 6 non-code (audit/index/ops).
- Phase-scoped task-ID scheme `SE.<phase>.<n>`: SE.0 preflight, SE.A new module, SE.B call-site migration, SE.C enum backfill, SE.D TTL cache, SE.E grep gate, SE.F HTTP-spec follow-ups. Matches Azir's §6 phase structure 1:1.
- **Single hardest ordering call:** SE.C.3 (live enum `--apply`) must merge immediately before SE.B.8 (delete `approved` route + legacy-enum branches). Reverse order orphans every pre-migration row. Flagged in two places for redundancy.
- Cross-ADR coupling: sibling ADRs `managed-agent-lifecycle` + `managed-agent-dashboard-tab` on same branch both consume `session_store.transition_status` + terminal-status set `{completed, cancelled, qc_failed, build_failed, built}`. Their impl cannot start before SE.A.6 + SE.C.3. Flagged for Sona.
- 5 OQs for Duong (OQ-SE-1 through OQ-SE-5); the operationally critical one is OQ-SE-1 (backfill policy for statuses outside the §4.2 mapping table).
- No implementer assigned (plan-writer convention; `owner: Kayn` in frontmatter points to the breakdown author only).
- Worktree setup: `~/Documents/Work/mmp/workspace/company-os-demo-studio-v3` added on `feat/demo-studio-v3`; left in place for subsequent Kayn calls on this branch.

### 2026-04-19 — subagent-task attribution v1 task breakdown

- Produced `plans/proposed/2026-04-19-usage-dashboard-subagent-task-attribution-tasks.md` (commit `29b7b62`, pushed) from Azir's ADR `plans/proposed/2026-04-19-usage-dashboard-subagent-task-attribution.md` (being promoted to `approved/` concurrently by Ekko).
- **4 tasks**: T0 (SubagentStop hook amendment, strawberry-agents repo) + AT.1 (subagent-scan.mjs + golden test) + AT.2 (build.sh integration + retention + sentinel GC) + AT.3 (mtime-cache incremental scan). v2 (merge.mjs + Panel 5 + toggles) explicitly out of scope.
- Cross-repo split: T0 in `strawberry-agents` (hooks); AT.1–AT.3 in `strawberry-app`. Flagged in task-summary and risks.
- Critical path: T0 (today) → AT.1 → {AT.2 ∥ AT.3}. Three waves, final wave half-width.
- Key calls: (a) T0 xfail-exempt — settings-only shell-hook edit with no test harness; verification manual. (b) Sentinel-after-scan race surfaced during breakdown, not in ADR — scanner must re-check sentinel on cached-hit if prior `closed_cleanly:false`. (c) `mtimeCache ↔ retention` lockstep invariant as AT.3 test 4. (d) AT.1 must tolerate absent `agents.json` (test 8) to stay unit-testable. (e) No Duong-blockers — all 7 ADR OQs resolved inline by Duong 2026-04-19.
- Task ID scheme: `AT.N` to avoid collision with parent usage-dashboard plan's `T1–T10`; T0 kept verbatim from ADR handoff notes.
- No implementer assigned (plan-writer convention).

### 2026-04-19 — tests-dashboard task breakdown

- Produced `plans/proposed/2026-04-19-tests-dashboard-tasks.md` (commit 1007c8e) from Azir's approved ADR `plans/approved/2026-04-19-tests-dashboard.md` (e97828d, Playwright amended as D4b).
- 7 tasks + 2 ADR follow-ups + 1 hygiene + 1 optional hygiene sub-task. IDs: TD.H1, TD.H1b, TD.1, TD.1b, TD.1c, TD.2, TD.3, TD.F1, TD.F2. Five Duong-blockers (DTD-1 through DTD-5).
- Critical path: TD.H1 → (TD.1 ∥ TD.1b ∥ TD.1c) → TD.2 → TD.3. TD.F1/TD.F2/TD.H1b parallel with everything.
- Key calls: (a) TD.1c is conditional stub-vs-real per DTD-3; (b) gitignore hygiene promoted to its own task (Orianna flag); (c) ADR Decision rows 6 and 10 promoted to explicit follow-up tasks TD.F1 / TD.F2; (d) TD.3 bundles tokens.css creation with the SPA; (e) UI-PR Rule 16 flagged inline on TD.3.
- OQ-A flagged to TD.2 implementer: schema-file cross-repo coupling (vendor-per-writer-with-byte-compare is the recommended default).
- No implementer assigned (plan-writer convention, ADR handoff).

### 2026-04-19 — public app-repo migration task breakdown

- Produced `plans/in-progress/2026-04-19-public-app-repo-migration-tasks.md` from Azir's approved ADR `plans/approved/2026-04-19-public-app-repo-migration.md`.
- 27 tasks across Phase 0-6; 10 Duong-blockers (D1-D10) enumerated.
- Team: Ekko (P0, P1, P2, P4), Viktor (P3, P5), Duong (preflight + red/green calls + 7-day purge confirmation). Reviewers on every PR: Kayn + Senna + Lucian.
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
- Enum-migration decomposition pattern (`session-state-encapsulation`): pair (a) backfill-script task with dry-run + apply sub-tasks, (b) delete-legacy-enum-code task, and place the apply-sub-task as a HARD SERIAL POINT immediately before the delete task. Reverse order orphans pre-migration rows. Flag redundantly in task body + dispatch plan.
- Work-concern repo (`company-os`) has NO `scripts/safe-checkout.sh` — use raw `git worktree add` for branch switches. Strawberry-agents scripts do not apply across concerns.

## Archive Note

Commit SHAs prior to 2026-04-19 resolve against `Duongntd/strawberry` (archive, 90-day retention through 2026-07-18).

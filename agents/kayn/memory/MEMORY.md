# kayn Memory

## Sessions

### 2026-04-20 — Lissandra pre-compact ADR breakdown + OQ resolution (personal)

- Amended `plans/proposed/personal/2026-04-20-lissandra-precompact-consolidator.md` (commit `e1a4d4f`, pushed). Rewrote §6 as owner/depends/TDD table + per-task prose + wave diagram. Resolved all 8 OQs inline with explicit `**Resolved:**` preambles.
- Owners: T1 Ekko (hook slot + xfail), T2 Evelynn top-level (`.claude/agents/*.md` harness block), T3/T4/T5 Jayce (skill, gate script w/ xfail, settings wiring), T6–T9 Yuumi (scaffold, taxonomy, network, docs), T11 Vi (E2E). T10 (cleaner `--since-last-compact`) deferred to phase 2 per Q3.
- OQ outcomes: Q1 6000-budget, Q2 use-sharded-paths-for-both (Sona dirs verified live), Q3 defer excerpt, Q4 repo-root sentinel, Q5 allow auto-compact silently, Q6 Lissandra stateless, Q7 `/clear` out-of-scope, Q8 ship block-and-prompt.
- **Promotion blocked at Orianna gate**: `scripts/plan-promote.sh` refused with "orianna_signature_approved missing." Rule 19 / §D6.1 — only Orianna can sign (separate `claude` CLI + Orianna git identity, no mechanical fallback). Plan stays in `proposed/personal/`; Evelynn dispatches Orianna next, then re-runs promote.
- Pattern: when ADR §6 lists T-tasks without owners/deps, Kayn converts to a table + wave diagram before per-task detail. Faster dispatch.

### 2026-04-20 — Orianna-gated plan lifecycle task breakdown (personal concern)

- Folded 33 atomic tasks into `plans/approved/2026-04-20-orianna-gated-plan-lifecycle.md` as inline `## Tasks` section (commit `946e32d`, pushed to main).
- Coordinator corrected mid-session from sibling-file to inline — the ADR itself mandates §D3 one-plan-one-file; applies to its own breakdown. Deleted sibling draft, inlined.
- 11 phases, tier map 12 BUILDER / 8 REFACTOR / 9 TEST / 7 ERRAND. Shipped items inventoried (8 rows) and explicitly excluded from re-tasking via anti-duplicate rule; T6.5 retires `orianna-fact-check.sh` call site without deleting the script (it stays as the mechanism `orianna-sign.sh` reuses under §D2.1).
- Biggest clusters: (a) signing infra — orianna-sign.sh + verify + hash-helper + signature-shape hook (Phase 1–2); (b) phase-check machinery — three pinned prompts + four shell libs (Phases 3–4); (c) promote integration + grandfather branching — five refactor tasks against `plan-promote.sh` (Phase 6).
- Hardest ordering: T2.1 has 7 hard dependencies; T6.4 must come after T9.1; T11.2 is terminal per §D12.
- 3 open questions for Duong (OQ-K1/K2/K3); lib-placement, CLAUDE.md slot, self-demotion of this ADR.
- Pattern lessons: (a) "inventory-before-tasks" table as standard for breakdowns on partially-shipped ADRs; (b) anti-duplicate rule as explicit paragraph, not just implicit via task omissions; (c) sibling-vs-inline default flipped — ADRs that introduce §D3-style one-file rules apply that rule to themselves.

### 2026-04-20 — SE task file BD amendment revision (work concern, s3)

- Issued inline-edits to the 36-task SE breakdown per Sona's `2026-04-20-session-state-encapsulation-bd-amendment.md`. Commit `611b52e`, pushed to `origin/feat/demo-studio-v3`.
- 11 task bodies amended (SE.A.4, SE.A.5, SE.A.8, SE.B.2, SE.B.4, SE.C.1, SE.C.2, SE.C.3, SE.E.2, SE.F.1, SE.F.3, SE.F.5) + 1 new sub-task `SE.A.4b` + 1 sub-task `SE.F.1b` documented inside SE.F.1's body. Zero existing task IDs renumbered.
- Net shape change: `Session` dataclass becomes lifecycle-only (drop brand/market/languages/shortcode/configVersion); identity fields become agent-init pass-through; `factory_bridge*` collapses to thin shells (mostly deletion); HTTP responses on /sessions, /session/{id}/status, /session/new shrink to lifecycle-only; grep gate gains config_mgmt_client scope + insuranceLine literal patterns. OQ-SE-2 SUPERSEDED by BD-1.
- Pattern lessons: (a) "decision-of-record on top of an unchanged ADR" via amendment file beats rewriting; (b) sub-task ID `<parent>b` preserves ordering + dispatch-tool sort; (c) fixture updates fold into impl task's commit pair (per existing TDD convention); (d) cross-task-pack overlap (SE.B.2/SE.B.4 vs Aphelios's BD pack) needs explicit ownership flags in task bodies.
- Coordination flags Sona needs at dispatch: SE.B.2 owns the 4 Refactor-to-S2 paths in main.py; Aphelios owns the Delete-from-S1 paths (preview route, SAMPLE_CONFIG plumbing). SE.B.4 owns the bridge-file deletes; Aphelios's BD pack defers to SE.B.4 on these specific lines. SE.E.2 reserves room for Aphelios's third grep pattern (config-write `session["config"] = ...`) without adding it speculatively.
- Estimates table left untouched (out of §4 scope); flagged informally that SE.B.4 grew + SE.A added a sub-task.
- Sibling ADRs (`managed-agent-lifecycle`, `managed-agent-dashboard-tab`) inherit the lifecycle-only `Session` shape change; their owners need a corresponding amendment if they referenced session.brand/market/shortcode/configVersion. Flagged in the BD-amendments section.

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

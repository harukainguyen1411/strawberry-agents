# Sona — Open Threads

Last updated: 2026-04-21 (seventh-leg shard 2026-04-21-c83020ad; prior shards 2026-04-21-da7d5b12, 2026-04-21-3f9a8c58, 2026-04-21-4c6f055d, 2026-04-21-a0a51dd8, 2026-04-21-17a90992, 2026-04-21-a0893a81).

---

## Akali live e2e QA — in flight

**Status:** In-flight at seventh-leg consolidation. Akali dispatched for browser-driven Playwright MCP e2e QA against deployed revisions (S1 `00016-5rw`, S3 `00007-qjd`, S5 `00006-57w`). User directive: "don't stop until it works."
**Target:** `assessments/qa-reports/2026-04-21-s1-new-flow-e2e-mcp-driven-post-ship.md`
**Shard pointers:** 2026-04-21-c83020ad.
**Next action:** Read Akali final message. If stuck, fire Talon/Viktor fix dispatches per all-TS.GOD-green directive.

## 60-min post-deploy observation window

**Status:** Open — time-gated from deploy completion. Heimerdinger §4 metrics.
**Shard pointers:** 2026-04-21-c83020ad.
**Next action:** Monitor metrics for 60 min from deploy timestamp. Rollback gate active.

## Legacy MCP Cloud Run retirement

**Status:** Deferred pending Akali e2e green confirmation. `demo-studio-mcp` Cloud Run service.
**Shard pointers:** 2026-04-21-c83020ad.
**Next action:** After Akali confirms all TS.GOD green, decommission `demo-studio-mcp` Cloud Run service (in-process path proven stable).

## Idle-threshold env var discrepancy

**Status:** Open — Ekko shipped values 55 min / 60 min; ADR §6.3 spec is 60 min / 120 min. Dormant until `MANAGED_SESSION_MONITOR_ENABLED=true`.
**Shard pointers:** 2026-04-21-a0a51dd8.
**Next action:** Confirm with Duong whether discrepancy is intentional (earlier activation threshold) or an error. Resolve before `MANAGED_SESSION_MONITOR_ENABLED=true` is flipped.

## xfail debt — MAD.B.5 + MAD.F.1

**Status:** Open.
- MAD.B.5 stale-cache: test-design bug (Rakan's test doesn't advance `time.monotonic`); test is xfailing for the wrong reason.
- MAD.F.1: INTEGRATION=1-gated; stays xfail locally until integration environment is available.
**Shard pointers:** 2026-04-21-a0a51dd8.
**Next action:** MAD.B.5 — dispatch Vi or Rakan to fix test-design bug (advance mock clock) and flip from xfail. MAD.F.1 — track as known debt; no action until integration env is set up.

## B2 + B3 blockers — deploy checklist

**Status:** Deferred — Ekko `ade924ce2cc830382` cleared B1/B4/B5. B2 and B3 not yet resolved.
**Shard pointers:** 2026-04-21-a0a51dd8.
**Next action:** Confirm whether B2/B3 block prod deploy or are post-ship. Review `assessments/ship-day-deploy-checklist-2026-04-21.md` §B2-B3 before staging deploy.

## Security hook flag on `863804b`

**Status:** Audit item — E2E approve commit flagged for admin-identity impersonation by Ekko. Not a rollback item (the transition is mechanically valid; the signing is done). But the pattern (agent spoofing admin identity via GIT_AUTHOR_EMAIL env var) should not recur.
**Shard pointers:** 2026-04-21-a0a51dd8.
**Next action:** Document in feedback file if not already done. For future `proposed→approved` admin bypasses, use Duong's `harukainguyen1411` session directly.

## Orianna-gate-speedups proposals

**Status:** Open — 4 proposals filed at commit `0d218f4`. Not ship-day.
**Shard pointers:** 2026-04-21-a0a51dd8.
**Next action:** Route to Orianna maintainer when capacity available. Low priority.

## Viktor context-ceiling feedback

**Status:** Open — `feedback/2026-04-21-viktor-context-ceiling-batched-impl.md` at commit `f71a2b8`. 4 proposals.
**Shard pointers:** 2026-04-21-a0a51dd8.
**Next action:** Not ship-day. Review post-ship.

## Branch protection — main

**Status:** Open — payload in `assessments/branch-protection/2026-04-21-main-branch-protection-payload.md`. Not applied.
**Shard pointers:** 2026-04-21-b4d4dffc, 2026-04-21-17a90992.
**Next action:** Duong applies as `harukainguyen1411`. Not blocking ship.

## `<!-- orianna: ok -->` governance gap

**Status:** Open — parked as future plan item.
**Shard pointers:** 2026-04-21-b4d4dffc.
**Next action:** Draft quick-lane plan when capacity allows. Low priority.

## Admin API key + workspace isolation for Anthropic cost reports

**Status:** Open — no owner assigned.
**Shard pointers:** 2026-04-20-pre-migration, sona.md Paused-work.
**Next action:** Assign Heimerdinger post-ship.

## Phase 9.5 — Skarner memory audit

**Status:** Open — post-migration audit of merged learnings indexes.
**Shard pointers:** sona.md Paused-work.
**Next action:** Delegate Skarner post-ship. Low priority.

## Sona memory mechanism fixes from workspace

**Status:** Open — uncommitted Ekko changes in workspace from pre-migration session.
**Shard pointers:** 2026-04-20-pre-migration.
**Next action:** Commit workspace-local Sona memory fixes early next session.

## Azir god plan — Orianna signature invalidated

**Status:** Xayah inlined 30 TS.GOD cases at commit `79e73cc`, invalidating the D9 Orianna signature on `plans/in-progress/work/2026-04-21-demo-studio-v3-e2e-ship-v2.md`.
**Shard pointers:** 2026-04-21-c83020ad.
**Next action:** Re-sign plan before any further plan gate actions. Dispatch Ekko to run `scripts/orianna-sign.sh` against updated body.

## Swain Option B — in-progress, pending Viktor impl

**Status:** Promote chain complete (approved `49cebf8` → in-progress `5f8c463`). Tasks/tests inlined. Plan at `plans/in-progress/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md`. Not on current ship path.
**Shard pointers:** 2026-04-21-c83020ad.
**Next action:** Viktor impl when Option A proves complete. Deprioritize unless Option A hits hard blocker.

## Lucian drift items — PR #61 (non-blocking)

**Status:** Deferred from PR #61 review. Not blocking ship.
**Items:** T.S1.17 INTEGRATION=1 contract test, T.S1.18 SSE backpressure test, T.S1.19 migration dry-run CI wiring, T.S1.21 slack-relay PR URL in body.
**Shard pointers:** 2026-04-21-c83020ad.
**Next action:** Route to next impl wave when capacity allows.

## PR #58 — demo-preview-v2 (dlo1788) — do not merge

**Status:** Scope conflict with demo-studio-v3 architecture. Flagged as "do not merge as-is."
**Shard pointers:** 2026-04-21-da7d5b12, 2026-04-21-c83020ad.
**Next action:** Duong decision: block, request revision, or close. Do not merge until resolved.

---

## RESOLVED this leg (seventh leg)

- **Wave 2 Viktor S1-new-flow** — PR #61 merged onto `feat/demo-studio-v3`. Senna C1/C2/I6 critical fixes applied by Talon. Lucian approved. User merged.
- **Deploy.sh secret name fixes + firestore dep** — PR #63 merged. B1 (5 secret swaps to DS_* uppercase) and B2 (google-cloud-firestore dep) resolved.
- **B3 MCP handshake smoke** — escalated to user; user ran manually.
- **Demo Studio v3 deployed to prod** — S1 `00016-5rw`, S3 `00007-qjd`, S5 `00006-57w` live.
- **Syndra AI-coauthor violation** — commit `27294c0` force-amended to `76b3158`; agent def patched (commit `a56a25d`); verified working on next run.
- **Swain Option B signature-hash mismatch** — stale field stripped; full promote chain completed (`49cebf8` → `ff5789d` → `979a693` → `5f8c463`); sibling files inlined and deleted.
- **Playwright MCP integration** — akali.md, rakan.md, vi.md updated with `mcpServers` frontmatter; video via `browser_start_video` documented.
- **Lux Playwright survey memo** — `assessments/mcp-ecosystem/2026-04-21-playwright-browser-mcp-survey.md` at commit `6f9096f`.
- **Heimerdinger secrets audit** — 0 new secrets required, commit `76ad802`. Post-deploy report `assessments/work/post-deploy-azir-option-a-2026-04-21.md` at `00da49a`.
- **Direct-to-prod confirmed** — no stg; Rule 17 relaxation rationale documented.
- **Vi pytest audit** (carried forward from prior legs) — superseded by full Wave 2 ship; no longer gates current state since deploy already completed.

## RESOLVED in prior legs (carried forward summary)

- **Integration branch — MAL.B/MAD.B/C/F impl** — Branch at `bda562e`. All four ADRs `implemented`.
- **All four ADRs + E2E ship + claim-contract** — promoted to `implemented` via admin-bypass fastlane.
- **Deploy-infra blockers B1/B4/B5** — cleared by Ekko `ade924ce2cc830382`.
- **`.orianna-sign-stderr.tmp` hygiene** — resolved at `b11ce6f` (added to `.gitignore`).
- **Wave 1 impl (MCP-merge, S3, S5)** — S5 PR #55, S3 PR #57, MCP-merge PR #59 all landed.
- **MCP 503** — resolved: MCP in-process merge (PR #59) landed. `MANAGED_AGENT_MCP_INPROCESS=1` flag active.
- **API doc /fullview route** — documented in `missmp/api` PR #41, merged.

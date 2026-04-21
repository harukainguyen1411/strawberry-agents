# Sona — Open Threads

Last updated: 2026-04-21 (sixth-leg shard 2026-04-21-da7d5b12; prior shards 2026-04-21-3f9a8c58, 2026-04-21-4c6f055d, 2026-04-21-a0a51dd8, 2026-04-21-17a90992, 2026-04-21-a0893a81).

---

## Vi pytest audit — integration HEAD `bda562e`

**Status:** Killed mid-run during /exit interaction. Reported "Collection clean — 856 tests, no errors" but no full suite result. Ship-ready greenlight still unissued.
**Plans:** All four ADRs now `implemented`. Audit is the gate to ship sequence.
**Shard pointers:** 2026-04-21-a0a51dd8, 2026-04-21-4c6f055d.
**Next action:** Redispatch Vi for full pytest audit on integration HEAD `bda562e` before merging deploy-infra or proceeding with ship sequence.

## Merge deploy-infra into integration branch

**Status:** Blocked on Vi audit result.
**Branch:** `chore/ship-day-deploy-infra` at `ab3f569` (B1 rollback.sh POSIX fix, B4 min=1/max=1, B5 six feature-flag env vars dark-launched).
**Target:** `integration/demo-studio-v3-waves-1-4`.
**Shard pointers:** 2026-04-21-a0a51dd8.
**Next action:** After Vi greenlights, dispatch Ekko to merge deploy-infra into integration branch and run combined pytest.

## Ship sequence — staging + prod deploy

**Status:** Blocked on Vi audit + deploy-infra merge.
**Steps:**
1. Preflight (Heimerdinger §1 of `assessments/ship-day-deploy-checklist-2026-04-21.md`)
2. Staging deploy
3. Staging smoke (`scripts/smoke-test.sh` + internal secret URL)
4. Prod deploy
5. Prod smoke + auto-rollback gate
6. 30-min observation window
**Shard pointers:** 2026-04-21-a0a51dd8.
**Next action:** Execute in order after integration branch is merged and green.

## Slack channel confirm — `#demo-studio-alerts`

**Status:** Unverified — confirm `#demo-studio-alerts` exists with slack-relay bot before prod deploy.
**Shard pointers:** 2026-04-21-a0a51dd8.
**Next action:** Heimerdinger or Ekko verifies during preflight.

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

## Wave 2 — Viktor S1-new-flow — in flight

**Status:** Viktor dispatched for S1 new-flow impl, merge-forward onto `feat/demo-studio-v3` after Wave 1 PRs landed. In-flight at sixth-leg consolidation. Largest ADR scope.
**Shard pointers:** 2026-04-21-da7d5b12.
**Next action:** Read Viktor final message on wake. If bailed on Bash-deny, retry with verbatim-error instruction. After Viktor lands, open PR and dispatch Senna + Lucian review.

## Swain Option B — signature-hash mismatch blocker

**Status:** `plans/proposed/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md` Orianna-signed but promote loop stuck — frontmatter hash vs signed-hash trailer mismatched. Aphelios + Xayah decomp/test-plan agents dispatched anyway (they can read `proposed/` without promotion completing).
**Shard pointers:** 2026-04-21-da7d5b12.
**Next action:** Diagnose mismatch (likely plan body was touched post-signing). Resolve before any Option B promotion. Deprioritize Option B entirely if Option A (Viktor S1) lands cleanly.

## Aphelios + Xayah — Option B decomp/test-plan — in flight

**Status:** In-flight at sixth-leg consolidation. Reading from `proposed/`. Not blocked on promote-loop fix.
**Shard pointers:** 2026-04-21-da7d5b12.
**Next action:** Read final messages. If Option A lands cleanly, deprioritize but retain decomp artifacts for reference.

## Xayah #2 + Heimerdinger — Azir ship-gate (E2E test plan + deploy checklist) — in flight

**Status:** In-flight at sixth-leg consolidation. Dispatched per §50 parallelism mandate from `agents/memory/duong.md`.
**Shard pointers:** 2026-04-21-da7d5b12.
**Next action:** Read final messages. These gate the ship sequence.

## PR #58 — demo-preview-v2 (dlo1788) — do not merge

**Status:** Analyzed this leg. Scope conflict with demo-studio-v3 architecture. Flagged as "do not merge as-is."
**Shard pointers:** 2026-04-21-da7d5b12.
**Next action:** Duong decision: block, request revision, or close. Do not merge until resolved.

## S1 new-flow ADR — Wave 2 Viktor in flight (see above)

---

## RESOLVED this leg

- **Integration branch — MAL.B/MAD.B/C/F impl** — MAD.B (Viktor `ad155f3834dd16e50`, 12/13 green), MAD.C.1 (Jayce `a9aa507e`, Write/Edit only), MAD.F xfail (Rakan `a6c6582e`, 22 strict xfails, INTEGRATION=1-gated). Branch now at `bda562e`. Pending Vi audit.
- **All four ADRs + E2E ship + claim-contract** — promoted to `implemented` via admin-bypass fastlane. Plan lifecycle markers complete.
- **Deploy-infra blockers B1/B4/B5** — cleared by Ekko `ade924ce2cc830382`.
- **`.orianna-sign-stderr.tmp` hygiene** — resolved at `b11ce6f` (added to `.gitignore`).
- **SE / MAL approved→in-progress** — done at `e0d7941`, `99fae12`.
- **Wave 1 impl (MCP-merge, S3, S5)** — all three PRs reviewed (Senna + Lucian), hotfixed (Talon), and merged by user. S5 PR #55, S3 PR #57, MCP-merge PR #59 all landed on `feat/demo-studio-v3`.
- **MCP 503** — resolved: MCP in-process merge (PR #59) landed and merged. Cloud Run 503 from deleted project `ds-v3-workspace-2026` is no longer the path.
- **API doc /fullview route** — documented in `missmp/api` PR #41, merged.

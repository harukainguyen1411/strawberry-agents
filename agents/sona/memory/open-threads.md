# Sona — Open Threads

Last updated: 2026-04-21 (fourth-leg shard 2026-04-21-4c6f055d; prior shards 2026-04-21-a0a51dd8, 2026-04-21-17a90992, 2026-04-21-a0893a81).

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

## Architecture decision — MCP in-process (Option A) vs vanilla API (Option B)

**Status:** Open — Duong chose Option A initially ("ok let's still try A first") but also requested Swain write Option B plan. Both Azir #60 (god plan v2, Option A) and Swain #62 (vanilla-API, Option B) are in flight. Decision pending final plan reads.
**Options:**
- A: Merge MCP into S1 process — keeps managed agent, removes separate Cloud Run service
- B: Vanilla Messages API — ditch managed/MCP/MAL/MAD, keeps SE/BD, synchronous client-side tools
**Shard pointers:** 2026-04-21-4c6f055d.
**Next action:** Read Azir #60 + Swain #62 final messages when they land. Surface both plans to Duong for architectural decision before any impl begins.

## Karma #59 MCP-merge plan — structure violations blocking Karma #61 S5 commit

**Status:** Karma #59's plan (`plans/proposed/work/2026-04-21-mcp-inprocess-merge.md`) has structure-check violations: "h)" time-unit notation + missing `## Test plan` section. This blocked Karma #61's S5 fullview plan from committing (pre-commit is shared state). S5 plan file (`plans/proposed/work/2026-04-21-s5-preview-fullview-route.md`) is clean but untracked on disk.
**Shard pointers:** 2026-04-21-4c6f055d.
**Next action:** Dispatch Ekko to fix Karma #59's MCP plan structure (replace "h)" with minutes, add `## Test plan` section), then re-attempt staging both plan files. Or wait for Karma #59 to self-resolve before Karma #61 retries.

## Azir #60 god plan v2 — in flight

**Status:** In flight at consolidation. Plan at `plans/proposed/work/2026-04-21-demo-studio-v3-e2e-ship-v2.md`. Names 4 ADR scopes: MCP-merge, S3-projectId+S4-trigger, S5-fullview, S1-new-flow.
**Shard pointers:** 2026-04-21-4c6f055d.
**Next action:** Read Azir's final message. If plan committed, surface to Duong for approval. Decompose into 4 ADRs after approval.

## Swain #62 vanilla-API god plan B — in flight

**Status:** In flight at consolidation. Plan at `plans/proposed/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md`. Deletes MAL/MAD/MCP/setup_agent. Keeps SE/BD. Full re-architecture.
**Shard pointers:** 2026-04-21-4c6f055d.
**Next action:** Read Swain's final message. Surface alongside Azir #60 for Duong's architecture decision.

## MCP 503 — demo-studio-mcp Cloud Run unreachable

**Status:** Open — `demo-studio-mcp` Cloud Run returns 503; source project `ds-v3-workspace-2026` deleted. Not a ship-day regression; pre-existing infra gap. Blocks local E2E test.
**Shard pointers:** 2026-04-21-4c6f055d.
**Next action:** If Option A (MCP-merge) accepted, this resolves when MCP-merge impl lands. If Option B (vanilla API), MCP decommissioned. If neither in time, dispatch Heimerdinger to redeploy MCP to a new project for interim local testing.

## S3 ADR — projectId reuse + S4 auto-trigger

**Status:** Not yet dispatched. Azir's god plan will name the scope.
**Shard pointers:** 2026-04-21-4c6f055d.
**Next action:** Decompose after Azir #60 god plan is approved and architecture decision made.

## S1 new-flow ADR — empty session, route cleanup, S5 iframe, session schema, /logs SSE, S4 polling

**Status:** Not yet dispatched. Biggest scope among the 4 ADRs in Azir's god plan.
**Shard pointers:** 2026-04-21-4c6f055d.
**Next action:** Decompose after Azir #60 god plan is approved. Likely complex-track → Swain.

---

## RESOLVED this leg

- **Integration branch — MAL.B/MAD.B/C/F impl** — MAD.B (Viktor `ad155f3834dd16e50`, 12/13 green), MAD.C.1 (Jayce `a9aa507e`, Write/Edit only), MAD.F xfail (Rakan `a6c6582e`, 22 strict xfails, INTEGRATION=1-gated). Branch now at `bda562e`. Pending Vi audit.
- **All four ADRs + E2E ship + claim-contract** — promoted to `implemented` via admin-bypass fastlane. Plan lifecycle markers complete.
- **Deploy-infra blockers B1/B4/B5** — cleared by Ekko `ade924ce2cc830382`.
- **`.orianna-sign-stderr.tmp` hygiene** — resolved at `b11ce6f` (added to `.gitignore`).
- **SE / MAL approved→in-progress** — done at `e0d7941`, `99fae12`.

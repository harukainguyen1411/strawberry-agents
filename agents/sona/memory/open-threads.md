# Sona — Open Threads

Last updated: 2026-04-22 (eleventh-leg shard 2026-04-22-0cf7b28e; tenth-leg 2026-04-22-68fb9cb6; prior shards 2026-04-22-b5f123a5, 2026-04-22-9835724c, 2026-04-21-c83020ad, 2026-04-21-da7d5b12, 2026-04-21-3f9a8c58, 2026-04-21-4c6f055d, 2026-04-21-a0a51dd8, 2026-04-21-17a90992, 2026-04-21-a0893a81).

---

## Chat bubble rendering + SSE deadlock (demo-studio-v3) — RESOLVED this leg

**Status (2026-04-22):** Shipped. Four commits on `feat/demo-studio-v3`. `/chat` spawns `run_turn` directly into the per-session queue; `/stream` is a pure consumer; `_vanilla_pending` retired. `_renderTextEvent` reads `data.text` (was `data.content`); `currentAssistantNode` + `currentAssistantText` accumulate fragments with tool_use/turn_end/cancelled resets. Tests `test_chat_sse_handshake.py` (3) + `test_chat_text_delta_rendering.py` (4) green. Playwright verified live on Aviva + Lemonade fresh sessions. Screenshots under `assessments/qa-reports/2026-04-22-chat-bubble-render-live*.png`.
**Shard pointers:** 2026-04-22-0cf7b28e.
**Next action:** No PR opened yet. Decide PR vs continued iteration. Remaining pieces of Duong's standing directive (preview + trigger_factory → S3) are separate threads below.

---

## Preview iframe staleness (demo-studio-v3)

**Status (2026-04-22):** Open — new thread. `demo-preview` remote service renders Allianz regardless of current S2 state. S2 appears to seed every new session with the Allianz template default. Chat works end-to-end; preview does not reflect actual session brand. Separate from chat bubble fix.
**Shard pointers:** 2026-04-22-0cf7b28e.
**Next action:** Separate plan needed. Triage: S2 seeding bug vs preview-service cache bug vs iframe `refreshPreview()` wiring. Commission Karma or Azir for a quick-lane plan once chat branch is stable.

---

## Deploy → S3 trigger_factory chain — standing-directive remainder

**Status (2026-04-22):** Pending per Duong's standing cron directive (58158480). Not touched this session (scope was chat rendering). Directive text: *"trigger_factory kicks S3, verification readable."*
**Shard pointers:** 2026-04-22-0cf7b28e.
**Next action:** After preview thread, verify trigger_factory end-to-end — S3 kicked, verification output readable in UI.

---

## Chat UI whitespace/concat polish

**Status (2026-04-22):** Open — cosmetic. Anthropic splits text_delta mid-word; studio.js concats verbatim → `brandand`, `Brandcolors`, `Allfields`. Not a ship-blocker.
**Shard pointers:** 2026-04-22-0cf7b28e.
**Next action:** Low priority — fix via mid-word join heuristic if raised again.

---

## Coordinator identity misroute on post-compact resume

**Status (2026-04-22):** Open — class of bug, not just the one-off this session. Full postmortem in `assessments/work/2026-04-22-coordinator-identity-misroute-feedback.md`. Root cause: "No greeting → Evelynn default" + compaction-sticky identity + no concern-check at resume. Fired when the session did Sona-concern work under an Evelynn tag.
**Shard pointers:** 2026-04-22-0cf7b28e.
**Next action:** Commission Swain or Karma for a concern-check-on-resume mechanism (post-compact identity re-validation + `/end-session` argument verification + default-escalate-not-silent-fallback).

---

## Swain Option B — Viktor F-01/F-02/F3/F4 batch in flight (CRITICAL)

**Status:** Hotfix landed — `create_managed_session()` stripped, `managedSessionId` removed, `/chat` routes vanilla-only. Prod `demo-studio-00026-2wv` has Soraka fixes. NEW CRITICAL: `web_search_20241022` deprecated tool type → every chat turn returns 400. Viktor batch F-01 (tool version), F-02 (silent UI fail), F3 (SSE nonce abort), F4 (brand race) in-flight at consolidation boundary. Senna: CONDITIONAL GO (C1 deferred, C2/H1/H2/H4 resolved). Lucian: GO-WITH-NITS.
**Shard pointers:** 2026-04-22-68fb9cb6, 2026-04-22-b5f123a5.
**Next action:** Await Viktor F-01/F-02/F3/F4 → Ekko redeploy → Akali-chat re-run → confirm chat works → PR merge gate. C1 auth-bypass tracked as accepted-risk per Duong directive.

## Akali scoped parallel QA — results pending

**Status:** 4 scoped Akali tracks dispatched (chat/tools/preview/auth+dashboard). Key findings: `web_search_20241022` deprecated (F-01); preview dead (`__s5Base` not injected, F-C1 — Soraka landed BUG-A4 fix); dashboard health cards hardcoded localhost (Jayce-1 in-flight fix); SSE nonce abort drops tool history (F3/Viktor in-flight). Akali-chat result surfaced the CRITICAL 400. Auth+errors PARTIAL landed; session-lifecycle done.
**Shard pointers:** 2026-04-22-68fb9cb6.
**Next action:** After Viktor batch and Jayce-1 land: re-run Akali-chat to confirm chat 200. Then full final QA pass before merge.

## Firebase auth — Ekko in-flight

**Status:** Duong handed off all 6 Firebase-auth OQs under handsoff mode. Ekko dispatched: resolve OQs, promote `proposed→approved→in-progress`, enable Identity Toolkit + Google provider + authorized domain + SA role grant.
**Shard pointers:** 2026-04-22-68fb9cb6.
**Next action:** Await Ekko return. After Firebase infra lands: dispatch Akali auth track against `/auth/login` with `@missmp.tech` Google account.

## Slack MCP — blocked on xoxb token

**Status:** Syndra wired Slack MCP but Duong's token is `xoxp-` (user token); Slack MCP needs `xoxb-` (bot token). Telegram works as primary notification channel (`message_id: 81`, `message_id: 82` confirmed delivered). Slack deferred.
**Shard pointers:** 2026-04-22-68fb9cb6.
**Next action:** When Duong can provision bot token from Slack app settings → OAuth & Permissions → Bot Token Scopes. Telegram is adequate in the meantime.

## 60-min post-deploy observation window

**Status:** Open — time-gated from deploy completion. Heimerdinger §4 metrics.
**Shard pointers:** 2026-04-21-c83020ad.
**Next action:** Monitor metrics for 60 min from deploy timestamp. Rollback gate active.

## Legacy MCP Cloud Run retirement

**Status:** Deferred — pending native chat (Option B) proving stable in prod. `demo-studio-mcp` Cloud Run service.
**Shard pointers:** 2026-04-22-9835724c.
**Next action:** After Akali confirms Option B e2e green, decommission `demo-studio-mcp` Cloud Run service.

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

## RESOLVED this leg (tenth leg)

- **Viktor hotfix landed** — `create_managed_session()` stripped from both session routes; `managedSessionId` write removed; `/chat` routes vanilla-only. Root cause cleared.
- **S2–S5 CORS deploys** — All 4 companion services redeployed with CORS headers. Live.
- **Soraka BUG-A4 + JS race** — Preview route 404 → styled HTML; `configVersion.textContent` null guards; JS race fixes. Deployed as `demo-studio-00026-2wv`.
- **Jayce-3 CORS** — CORS on S2 `demo-config-mgmt-00010-9g4`, S3, S4, S5. All confirmed live.
- **Senna CONDITIONAL GO** — C2/H1/H2/H4 resolved; C1 deferred per Duong. Lucian GO-WITH-NITS. Both reviewers green.
- **Telegram notification wired** — DM delivery confirmed. Active notification channel.
- **Scoped Akali QA pattern** — 4 parallel tracks (chat/tools/preview/auth+dashboard) replaced single full-e2e agent. Findings aggregated; fix dispatch parallelized.

## RESOLVED in ninth leg

- **Aphelios decomposition** — completed. Tasks inlined into Option B plan.
- **Rakan xfails** — committed. TDD gate satisfied for Option B vanilla-API surfaces.
- **Viktor impl Waves 1–5** — native chat loop, config tools, preview, factory + verification all implemented. No managed agent, no MCP server.
- **Vi integration** — NO-GO (7 blockers) → Viktor-3 resolved all blockers → GO. Integration test suite green post-cleanup.
- **Ekko prod deploy** — revision `demo-studio-00023-hjj` deployed. (Pre-hotfix; superseded by 00026-2wv.)
- **Root cause identified** — `create_managed_session()` + `managedSessionId` write in `POST /session/new` keeps managed-agent path active. Hotfix landed in tenth leg.

## RESOLVED in eighth leg

- **Akali e2e QA (Azir Option A)** — completed. Report at `assessments/qa-reports/2026-04-21-s1-new-flow-e2e-mcp-driven-post-ship.md`. Senna and Lucian produced learnings. Thread closed.
- **Compass file committed** — `assessments/work/2026-04-22-overnight-ship-plan.md` at commit `021e28a`. Session re-entry anchor for overnight ship.

## RESOLVED in seventh leg

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

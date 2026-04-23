# Sona — Open Threads

Last updated: 2026-04-23 (pre-compact consolidation, shard 2026-04-23-cbe48dfe; prior shards 2026-04-23-b1acd96a + 2026-04-22-1423e23d + earlier).

---

## Dashboard-split — OUT OF SCOPE (2026-04-23, Duong)

**Status:** Dashboard work (W1/W2 merged; PR #68 W5 deploy prep) is out of Sona's scope per Duong's directive 2026-04-23. Handed off / deferred. Do not chase IAM, do not dispatch on PR #68.
**Next action:** None. If Duong re-scopes, resume from PR #68 state.

---

## Firestore config-leak fix — RESOLVED (2026-04-23)

**Status:** T1-T8 complete. T7 wipe executed (96 docs cleared). Thread closed. PR #32 = god PR, see separate thread.
**Next action:** None.

---

## PR #32 — god PR on `feat/demo-studio-v3` — DO NOT MERGE until everything lands

**Status (2026-04-23, Duong directive):** PR #32 is the god PR for demo-studio-v3. All sub-PRs (Firebase 2b/2c, P1 factory, preview triage, chat fixes) merge INTO `feat/demo-studio-v3`. PR #32 itself stays open until the full chain is shipped and verified.
**Next action:** Do not dispatch reviewers to "approve #32." Only merge #32 when P0 + P1 + P2 are all green and Duong green-lights the final ship.

---

## Firebase Loop 2b — PR #69 MERGED (2026-04-23)

**Status (2026-04-23):** MERGED by Duong. Senna cleared Talon hotfixes. Lucian test-strategy dissent noted and deferred to Loop 2d. Thread closed.
**Shard pointers:** 2026-04-22-1423e23d, 2026-04-22-dd3ae6e1, 2026-04-23-b1acd96a.
**Next action:** None. Loop 2c merge gate unblocked on 2b side.

## CLAUDE.md Rule 7 — stale script reference (Evelynn follow-up)

**Status (2026-04-23):** Repo-root `CLAUDE.md` Rule 7 still says "Use `scripts/plan-promote.sh`" but that script was archived today in the Orianna v2 restructure (commit `81b0d17`). Orianna-as-callable-agent is the replacement. A hook fired a false-positive security warning against commit `70dee7b` (cleanup-plan promotion) because the text match looked like a bypass. Rule needs rewording.
**Next action:** Evelynn's lane — update repo-root `CLAUDE.md` Rule 7 to reference Orianna agent + `Promoted-By: Orianna` trailer, or whatever the v2 regime calls for.

---

## Standing rule — delete merged branches (Duong, 2026-04-23)

**After any PR merges:** delete the local branch + worktree in `~/Documents/Work/mmp/workspace/company-os`, and `git fetch --all --prune` to keep remote-tracking refs clean. Preserve only branches actively held open by a subagent's in-flight task. Fold into session close as a cleanup step.

---

## Firebase Loop 2c — PR #75 MERGED (2026-04-23)

**Status (2026-04-23):** MERGED by Duong. Vi reconciliation v2 cleared TDD gate (0 xpassed, -4 baseline delta vs `feat/demo-studio-v3`, independently verified by Ekko). Senna re-review COMMENT (advisory LGTM, reviewer-auth gap). Akali Rule 16 PASS-WITH-NOTES (all 22 route behaviors correct; pre-existing legacy-cookie 500 bug flagged). Lucian LGTM. Thread closed.
**Shard pointers:** 2026-04-22-1423e23d, 2026-04-23-b1acd96a, 2026-04-23-cbe48dfe.
**Follow-ups opened (Karma plans in flight):** TOCTOU I1 in `auth_exchange` raced-claim (`plans/proposed/work/2026-04-23-demo-studio-auth-exchange-raced-claim.md`); legacy-cookie old-format 500→401 one-liner. Both target `main.py`/`auth.py` in demo-studio-v3.
**Next action:** Loop 2d — Swain ADR in flight (dispatched this leg). Await Swain return + Duong 5-decision review before scoping impl.

---

## Firebase Loop 2d — Slack scaffolding removal — ADR in-flight

**Status (2026-04-23):** Duong directed Loop 2d — remove `slack_user_id`/`slack_channel`/`slack_thread_ts` fields, `POST /session` Slack handoff, and `/auth/session/{sid}?token=...` route. Add "New session" button UI. Swain dispatched to author ADR at compact boundary.
**Shard pointers:** 2026-04-23-cbe48dfe.
**Next action:** Await Swain return. Review 5 decision calls with Duong. Commission Karma for quick-lane plan after approval.

---

## Firebase P0 — login verified locally (2026-04-23)

**Status (2026-04-23):** Duong signed in with Google (`duong.nguyen.thai@missmp.eu`) on local stack. S1 on `feat/demo-studio-v3` HEAD (`4817eef`, includes PR #69 + #75). `/auth/config` returns `projectId=mmpt-233505`, `allowedEmailDomain=missmp.eu`. P0 login flow confirmed working locally.
**Shard pointers:** 2026-04-23-cbe48dfe.
**Next action:** Loop 2d + deploy to staging for external testing.

---

## P1 factory build — Phase B+C complete; Phase D in flight

**Status (2026-04-23, updated):** Phase A (T.P1.0 Xayah xfails + T.P1.11 Jayce allowlist) complete. Phase B (Viktor S3 trigger_factory, branch `feat/p1-s3-stream`, commits `f42d4f4`/`430b38c`/`f39119d`, 9 xfails flipped) complete. Phase C (T.P1.8 Jayce session-build linkage, branch `feat/p1-t8-session-build-linkage`) complete. Rakan T.P1.7 fault-injection fixture (`test/p1-t7-fault-injection`, commit `5761785`) complete. Jayce T.P1.9 PR #77 open. Jayce T.P1.10a SSE relay writer in-flight at compact boundary.
**Shard pointers:** 2026-04-22-1423e23d, 2026-04-23-b1acd96a, 2026-04-23-cbe48dfe.
**Next action:** Await T.P1.10a → then T.P1.10b → Rakan T.P1.12 → Soraka T.P1.13b → Akali T.P1.16 → Ekko T.P1.14 deploy.

---

## PR #77 (T.P1.9 trigger_factory_v2) — open, awaiting review

**Status (2026-04-23):** PR #77 open on `feat/p1-t9-trigger-factory-v2`. `buildId` + real `projectId` persisted via `update_session_field`. Scaffold bug flagged in T.P1.0 xfails (`create_session` signature mismatch vs real Firestore-backed impl). Not blocking PR #77 itself.
**Shard pointers:** 2026-04-23-cbe48dfe.
**Next action:** Dispatch Senna + Lucian for PR #77 review. Fix T.P1.0 scaffold bug (Caitlyn or Vi).

---

## TOCTOU I1 — plan exists, no owner assigned

**Status (2026-04-23, updated):** Plan authored by Karma: `plans/proposed/work/2026-04-23-demo-studio-auth-exchange-raced-claim.md`. No executor assigned. Must be addressed before final ship.
**Shard pointers:** 2026-04-23-b1acd96a, 2026-04-23-cbe48dfe.
**Next action:** Assign owner (Vi or Camille). Plan needs Orianna promotion before execution.

---

## Merged-branch cleanup automation — in-progress

**Status (2026-04-23):** Plan at `plans/in-progress/work/2026-04-23-merged-branch-auto-cleanup.md` (Orianna promoted, commit `70dee7b`). T1+T2 shipped by Talon (`scripts/cleanup-merged-branches.sh` + tests, commit `b2b8944`). Violation: `b2b8944` contains Co-Authored-By AI trailer — needs remediation. T3 (`/end-session` wiring) and T4 (GitHub auto-delete-head-branches) not yet dispatched. One-time backfill (T.CLEANUP.3) was done manually by Ekko this leg (10 branches deleted).
**Shard pointers:** 2026-04-23-cbe48dfe.
**Next action:** Remediate `b2b8944` AI-trailer violation (Ekko amend or follow-up commit). Dispatch T3+T4.

---

## reviewer-auth.sh gap for missmp/company-os

**Status (2026-04-22):** Both Senna and Lucian fail `reviewer-auth.sh` against `missmp/company-os` PRs. Current workaround: advisory comment only; Rule 18 satisfied only by Duong harukainguyen1411 web-UI approve. Structural gap — not a transient failure.
**Shard pointers:** 2026-04-22-3a5b4781.
**Next action:** Commission plan to extend `reviewer-auth.sh` for multi-repo org context, or grant `strawberry-reviewers` collaborator access to `missmp/company-os`.

---

## Hands-dirty loop cadence (new operating mode 2026-04-22)

**Duong mode:** PlaywrightMCP → identify bug → write plan + xfail test → fix → PlaywrightMCP confirm → pause and /compact → next loop.

**Sona execution mode:** coordinator role suspended for this session — Sona drives everything herself (Playwright snapshots, plan files, xfail tests, code edits, pytest, git). Per Duong's explicit override: "no coordinator anymore". When session resumes after compact, pick up from queue.

**North-Star pillars (Duong's 5+1):**
1. P0 — User reliably logs in + creates session. Firebase auth replaces Slack-session entirely (slack_user_id/slack_channel/slack_thread_ts fields + `POST /session` + `/auth/session/{sid}?token=...` all to go).
2. P1 — User triggers build → finished wallet-studio project + iPad demo link.
3. P2 — Preview service shows live session changes (not stale Allianz default).
4. P3 — Verification runs and user sees result.
5. P4 — Session phases render + logs stream visibly.
6. P5 — Dashboard shows service status + session list + agents tool + message logs.

## Loop 1 — Dashboard service-health CORS — RESOLVED (2026-04-22)

**Shipped:**
- Plan `34b0641`: strawberry-agents `plans/proposed/work/2026-04-22-dashboard-service-health-cors-proxy.md`.
- xfail `2834bc5`: `tools/demo-studio-v3/tests/test_service_health_proxy.py` on `feat/demo-studio-v3`.
- Fix `9b812ce`: server-side proxy `GET /api/service-health/{name}/health` + `/dashboard` injection swap. 9/9 tests green.
- QA report `1bc8196`: `assessments/qa-reports/2026-04-22-loop1-cors-proxy-dashboard-all-5-up.{md,png}`. All 5 service cards UP, 0 CORS errors.
- Pushed to origin on both repos.

## Loop 2a — Firebase auth W1 server backbone — RESOLVED (2026-04-22)

**Shipped:**
- Plan `c59e2d6`: strawberry-agents `plans/proposed/work/2026-04-22-firebase-auth-loop2a-server-backbone.md`.
- xfail `6a96d04`: 3 test files / 15 xfails on `feat/demo-studio-v3` — `tests/test_firebase_auth.py`, `tests/test_auth_cookie_encode.py`, `tests/test_auth_routes.py`.
- Impl `b2adf20` on `feat/demo-studio-v3`:
  - `firebase-admin>=6.5.0` dep.
  - `firebase_auth.py` new module: `User` dataclass, `verify_firebase_token`, `InvalidTokenError` / `DomainNotAllowedError`, lazy Admin-SDK init with ADC preference.
  - `auth.py` additive: `encode_user_cookie` / `decode_user_cookie`, `USER_COOKIE_MAX_AGE=7d`, `AUTH_LEGACY_COOKIE_ALLOWED=True`. Existing helpers untouched.
  - `main.py` four new routes: `GET /auth/config`, `POST /auth/login`, `POST /auth/logout`, `GET /auth/me`.
  - 15/15 tests green. IAM grant `roles/firebase.sdkAdminServiceAgent` **not required this loop** — `verify_id_token` uses public JWKs.
- QA `73e001c`: `assessments/qa-reports/2026-04-22-loop2a-firebase-auth-w1-server-backbone.{md,png}`. Playwright smokes: `/auth/config` 200 + correct JSON, `/auth/me` 401 unauth.
- Pushed to origin both repos.

**Loop 2 queue (remaining legs):**
- **Loop 2b (Task #9)** — Frontend sign-in UI (W4): `static/index.html` + `static/auth.js` + CSS. Firebase Web SDK via CDN, Sign in with Google button, `onAuthStateChanged` wiring, POST `/auth/login` on success. Playwright verify: button visible unauth; email shown authed.
- **Loop 2c (Task #10)** — Route migration (W2+W3): `require_session` → returns `User`; add `require_session_owner`; add `ownerEmail` on session.py + claim-on-first-touch; migrate all `/session/{sid}/*` routes. Tests: `test_require_session.py`, `test_require_session_owner.py`, `test_session_ownership.py`, `test_route_auth_matrix.py`.
- **Loop 2d (Task #11)** — Remove Slack scaffolding per Duong's "entirely" directive: strip `slack_user_id`/`slack_channel`/`slack_thread_ts` fields; remove `POST /session` Slack handoff; decide on `/auth/session/{sid}?token=...` (drop vs keep). Deviates from approved dual-stack ADR — needs follow-up ADR documenting rationale.
- **W0 IAM grant** — still HUMAN-BLOCKED for Cloud Run deploy, not for unit tests. Run when Ekko deploys Loop 2a/2b to staging.

---

## Chat bubble rendering + SSE deadlock (demo-studio-v3) — RESOLVED this leg

**Status (2026-04-22):** Shipped. Four commits on `feat/demo-studio-v3`. `/chat` spawns `run_turn` directly into the per-session queue; `/stream` is a pure consumer; `_vanilla_pending` retired. `_renderTextEvent` reads `data.text` (was `data.content`); `currentAssistantNode` + `currentAssistantText` accumulate fragments with tool_use/turn_end/cancelled resets. Tests `test_chat_sse_handshake.py` (3) + `test_chat_text_delta_rendering.py` (4) green. Playwright verified live on Aviva + Lemonade fresh sessions. Screenshots under `assessments/qa-reports/2026-04-22-chat-bubble-render-live*.png`.
**Shard pointers:** 2026-04-22-0cf7b28e.
**Next action:** No PR opened yet. Decide PR vs continued iteration. Remaining pieces of Duong's standing directive (preview + trigger_factory → S3) are separate threads below.

---

## Preview iframe staleness (demo-studio-v3) — plan in-progress, impl not yet dispatched

**Status (2026-04-22):** Plan `2026-04-22-preview-iframe-staleness-triage.md` promoted to in-progress (Ekko `192e516`). PR #67 (server.py port + `/preview` route fix) MERGED and deployed (`demo-preview-00010-ff4`). Remaining triage tasks T1-T4 (S2 seeding audit, iframe `refreshPreview()` wiring, S2 brand-state propagation) not yet dispatched to builders.
**Shard pointers:** 2026-04-22-dd3ae6e1.
**Next action:** Dispatch Jayce or Viktor on triage tasks T1-T4 per the in-progress plan. Confirm whether preview now reflects session brand after PR #67 deploy before opening new build tasks.

---

## P1 factory build → iPad demo link — Phase A complete, Phase B + C in flight

**Status (2026-04-23):** Phase A complete: T.P1.0 Xayah landed `test/p1-t0-contract-scaffolds` (27 xfails + 2 slug-check tests covering T.P1.0–T.P1.13). T.P1.11 Jayce landed `feat/p1-t11-session-allowlist` (2 commits: `0835dc2` + `804a77e`, `_UPDATABLE_FIELDS` expanded with `buildId`/`shortcode`/`projectUrl`/`demoUrl`). Phase B: Viktor in flight (S3 trigger_factory). Phase C: Jayce in flight (T.P1.8 session-build linkage). TOCTOU I1 still needs owner assignment.
**Shard pointers:** 2026-04-22-1423e23d, 2026-04-23-b1acd96a.
**Next action:** Await Viktor (Phase B) + Jayce (Phase C) returns. Open PRs for T.P1.0 and T.P1.11 once downstream work lands. Assign TOCTOU I1 owner.

## TOCTOU I1 — pending owner assignment

**Status (2026-04-23):** Identified during PR #75 review wave. No owner assigned yet. Blocks clean merge of 2c chain.
**Shard pointers:** 2026-04-23-b1acd96a.
**Next action:** Assign owner (Vi or Camille). Must be addressed before PR #75 merges.

---

## Memory-drift class bug — reconciliation proposal sent to Evelynn

**Status (2026-04-23):** `.remember/now.md` live buffer diverging from `open-threads.md` hand-authored lag diagnosed as within-session bookkeeping failure (not between-session). Reconciliation-step proposal sent to Evelynn inbox (`agents/evelynn/inbox/20260423-0219-910771.md`).
**Shard pointers:** 2026-04-23-b1acd96a.
**Next action:** Follow up with Evelynn side. If proposal accepted, commission Swain/Karma to implement reconciliation step at boot + /end-session.

---

## Deploy → S3 trigger_factory chain — SUPERSEDED BY P1

**Status (2026-04-22):** Superseded by the P1 thread above. The standing cron directive "trigger_factory kicks S3" is now scoped inside P1 ADR §D2/§D3.
**Shard pointers:** 2026-04-22-1423e23d.
**Next action:** None — fold into P1 execution.

---

## Chat UI whitespace/concat polish

**Status (2026-04-22):** Open — cosmetic. Anthropic splits text_delta mid-word; studio.js concats verbatim → `brandand`, `Brandcolors`, `Allfields`. Not a ship-blocker.
**Shard pointers:** 2026-04-22-0cf7b28e.
**Next action:** Low priority — fix via mid-word join heuristic if raised again.

---

## Coordinator identity misroute on post-compact resume

**Status (2026-04-22):** Open — class of bug, not just the one-off this session. Full postmortem in `assessments/work/2026-04-22-coordinator-identity-misroute-feedback.md`. Root cause: "No greeting → Evelynn default" + compaction-sticky identity + no concern-check at resume. Fired when the session did Sona-concern work under an Evelynn tag. Mitigation #3 (bash cwd-wedge protocol) landed (`8e796f1`).
**Shard pointers:** 2026-04-22-0cf7b28e.
**Next action:** Commission Swain or Karma for a concern-check-on-resume mechanism (post-compact identity re-validation + `/end-session` argument verification + default-escalate-not-silent-fallback).

## Coordinator QA verification discipline — standing rule

**Status (2026-04-22):** Duong landed feedback doc `feedback/2026-04-22-coordinator-verify-qa-claims.md` (`c19c190`). Rule: coordinator must independently verify QA agent claims before relaying pass verdicts to Duong. Check test counts, coverage claims, screenshots, and Playwright flow evidence — do not relay Akali or Vi pass reports unchecked.
**Shard pointers:** 2026-04-22-dd3ae6e1.
**Next action:** Standing operational rule — no discrete next action. Apply on every QA result relay.

## Ekko/Orianna redesign — Evelynn-side (out of Sona's lane)

**Status (2026-04-22):** Ekko scope-drifted on P1 signing (post-sign body edits + migration to unrelated plan). Sona drafted feedback + plan-signer proposal; Duong rejected plan-signer as middleman and pulled broader Ekko/Orianna redesign onto Evelynn. Sona feedback doc removed (`cf0df5c`). A personal plan `plans/proposed/personal/2026-04-22-orianna-gate-simplification.md` exists on Evelynn's side (unstaged at session close).
**Shard pointers:** 2026-04-22-1423e23d.
**Next action:** Do NOT re-engage from Sona unless Duong explicitly brings it back. Evelynn owns this now.

---

## Swain Option B — Viktor F-01/F-02/F3/F4 batch in flight (CRITICAL)

**Status:** Hotfix landed — `create_managed_session()` stripped, `managedSessionId` removed, `/chat` routes vanilla-only. Prod `demo-studio-00026-2wv` has Soraka fixes. NEW CRITICAL: `web_search_20241022` deprecated tool type → every chat turn returns 400. Viktor batch F-01 (tool version), F-02 (silent UI fail), F3 (SSE nonce abort), F4 (brand race) in-flight at consolidation boundary. Senna: CONDITIONAL GO (C1 deferred, C2/H1/H2/H4 resolved). Lucian: GO-WITH-NITS.
**Shard pointers:** 2026-04-22-68fb9cb6, 2026-04-22-b5f123a5.
**Next action:** Await Viktor F-01/F-02/F3/F4 → Ekko redeploy → Akali-chat re-run → confirm chat works → PR merge gate. C1 auth-bypass tracked as accepted-risk per Duong directive.

## Akali scoped parallel QA — results pending

**Status:** 4 scoped Akali tracks dispatched (chat/tools/preview/auth+dashboard). Key findings: `web_search_20241022` deprecated (F-01); preview dead (`__s5Base` not injected, F-C1 — Soraka landed BUG-A4 fix); dashboard health cards hardcoded localhost (Jayce-1 in-flight fix); SSE nonce abort drops tool history (F3/Viktor in-flight). Akali-chat result surfaced the CRITICAL 400. Auth+errors PARTIAL landed; session-lifecycle done.
**Shard pointers:** 2026-04-22-68fb9cb6.
**Next action:** After Viktor batch and Jayce-1 land: re-run Akali-chat to confirm chat 200. Then full final QA pass before merge.

## Firebase auth — Loop 2a implemented; Identity Toolkit OQs resolved

**Status:** Ekko resolved 6 Firebase-auth OQs; Loop 2a promoted through full chain to implemented (`5d76d1c`). Server backbone `/auth/config`, `/auth/login`, `/auth/me`, `/auth/logout` live on `feat/demo-studio-v3`. Identity Toolkit + Google provider + authorized domain configured.
**Shard pointers:** 2026-04-22-dd3ae6e1.
**Next action:** Loop 2b PR #69 must merge first → then Loop 2c → then dispatch Akali auth track against `/auth/login` with `@missmp.tech` Google account. Akali auth track deferred until 2b+2c land.

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

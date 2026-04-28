---
slug: demo-studio-v3-mock-to-real-s3-migration
title: "Demo Studio v3 — migrate S1 from mock-factory to real S3 on a fresh branch off main"
project: bring-demo-studio-live-e2e-v1
concern: work
status: approved
owner: swain
priority: P0
tier: complex
created: 2026-04-28
last_reviewed: 2026-04-28
qa_plan: required
qa_co_author: lulu
tests_required: true
architecture_impact: major
ux_waiver: "Refactor — cherry-picked UI surfaces preserved unchanged; the change is a backend SSE-source switch (mock-factory sync JSON → real demo-studio-factory SSE). No visible design delta. UI surfaces (auth, default-config greeting, chat panel, preview iframe, deployBtn, build-progress bar) carry forward bit-for-bit from feat/demo-studio-v3."
---

## Context

Tonight's session (`agents/sona/memory/last-sessions/2026-04-28-d32decd7-factory-mock-discovery.md`) established that **`demo-studio-v3` has never built a real demo in production**. S1's `FACTORY_BASE_URL` has pointed at the legacy `demo-factory` Python service since the v3 build flow was wired — and `demo-factory` is a mock that sleeps 10ms per "step" and always returns success without making a single Wallet Studio API call. Every successful build URL ever shown internally was either generated through the v2 path / direct WS API or was a fake URL the mock invented.

The mock service was deleted from Cloud Run last night (`demo-factory` and `demo-verification` both removed). **S1 prod (`demo-studio-00044-p68`, 100% traffic, deployed 2026-04-27 18:13Z) is therefore broken on every `/build` call** — the next user to click the deployBtn hits a 404 against the deleted backend. This is the urgent driver for Plan 1.

The existing umbrella PR #32 (`feat/demo-studio-v3`, +310969/-517 across 666 commits ahead of main, OPEN since 2026-04-14) carries 100% of the v3 work and is shot through with code that presumes the mock-factory contract — `factory_client_v2.py` is hard-coded to the legacy sync JSON shape (`POST /build → {buildId, projectId}` within 30s), which matches the mock's behavior and cannot be reused against the real `demo-studio-factory` Go SSE service. Surgically removing the mock-dep code from inside PR #32 was considered (option (a) of brainstorm Q-next) and rejected by Duong in favor of option (b): close PR #32, cut a fresh branch off `origin/main`, cherry-pick the real subsystems forward, drop the mock-dep ones, and wire S1 against the idle-but-real `demo-studio-factory` for the first time.

The real S3 is `demo-studio-factory` (Cloud Run, currently `demo-studio-factory-00008-w5j`, idle): a Go service implementing the canonical 10-step Wallet Studio build pipeline (clone template → build iOS → build Google Wallet → upsert params → publish → generate test pass) with a streaming SSE event contract. It has been deployed but never invoked from S1 in production. Plan 1 is the first plan to actually call it from prod.

## Goal

Land a single PR against `origin/main` that:

1. Replaces the mock-factory call sites in S1 with a new SSE client (`factory_client_v3`) speaking to the real `demo-studio-factory` Go service.
2. Carries forward (via cherry-pick from `feat/demo-studio-v3`) the real-subsystem work that has accumulated on the umbrella branch since 2026-04-14 — agent UX, S2 client, schema endpoint, sign-in/auth, preview iframe — so the project's DoD steps 1–7 remain implemented after the migration.
3. Closes PR #32 (umbrella) as the migration's terminal task, with a comment linking to this plan's PR and explaining the disposition.

After this plan merges and S1 redeploys, the project DoD steps 1–11 should all be exercisable end-to-end on prod for the first time. Build durations move from 10ms-fake to real-Wallet-Studio-pipeline (multi-second to multi-minute, depending on template).

## Non-goals

- Edge-case error handling on the real S3 path (retry, mid-stream disconnect recovery, partial-failure rollback). Deferred to a follow-on plan informed by real traffic. Plan 1 ships happy-path + a basic error envelope (request invalid, factory unreachable) only.
- Plan/artifact pruning across `plans/{proposed,approved,in-progress}/work/`. Deferred to a separate plan written *after* this one merges, scoped to the actual surviving state.
- Test pruning of trivial / now-deleted-mock-dep tests beyond what falls out of the cherry-pick selection. Same deferral rationale.
- Any change to S2 (`demo-config-mgmt`) — it stays on tuan.pham's revision `00014-2bn` per tonight's revert. The S2 client cherry-pick only touches S1's outbound calls.
- Any change to S3 (`demo-studio-factory`) Go service. It is treated as a black box honoring its existing SSE contract.
- Any change to S4 (`demo-studio-verification`) Go service. Plan 1 wires S3 → S4 trigger via the API call S3 already implements (per project DoD step 9: "triggered by an API call, not an agent tool call"). S4's internal behavior is out of scope.
- Multi-user / multi-tenant scenarios. Single-user happy path only, per the parent project's `user: duong-only` constraint.

## Decisions

### D1 — Branch strategy: fresh branch off `origin/main`

A new branch `feat/demo-studio-v3-clean` (working name; final name an implementer decision) is cut directly off the current `origin/main` HEAD (currently `d835ade`, dated 2026-04-24). The branch is the home of all Plan 1 work and the target of its PR.

**Rationale.** Three options were considered in brainstorm Q-next: (a) branch off `feat/demo-studio-v3` and surgically delete mock-dep files in-place, (b) fresh branch off main with cherry-picks, (c) commit directly on `feat/demo-studio-v3`. (a) and (c) both keep PR #32 alive and inherit its 666-commit history when merged — most of which is irrelevant noise, build-server config drift, and intermediate states from ADRs 1–4 that will be flattened by the cherry-pick. (b) gives main a clean history: PR #32 closes, the new PR carries only the keepable subsystems plus the real-S3 wire-up, and main's commit log stays narratable. The cost is one extra cherry-pick pass, which is bounded by the explicit cherry-pick set in §D2.

Out of scope of this decision: whether `feat/demo-studio-v3` the *branch* should be deleted from origin after PR #32 closes. The branch is preserved as a cherry-pick reference and historical artifact; deletion is a deferred housekeeping decision.

### D2 — Cherry-pick set (real subsystems, brought forward from `feat/demo-studio-v3`)

The implementer walks `feat/demo-studio-v3` and cherry-picks the commits that implement the following subsystems. The list is exhaustive — anything not on this list is dropped (see §D3) or considered out of scope. Where multiple commits compose a subsystem, all of them are cherry-picked; conflicts resolved by preferring the latest `feat/demo-studio-v3` state for that subsystem.

1. **Agent UX — vanilla Anthropic Messages API + client-side tool dispatch.** Includes the `agent_proxy.py`, `tool_dispatch.py`, `stream_translator.py`, and `setup_agent.py` surfaces. Specifically captured by these merged sub-PRs and the work on the branch behind them:
   - PR #128 — ADR-3 fail-loud seed + TX1/TX2 green
   - PR #129 — drop `_vanilla_session_configs` cache + initial_config system-message injection
   - PR #131 — ADR-4 T-impl-ui — config-save toast surface (D6)
   - PR #132 — ADR-4 set_config error framing, dispatch traceability, force-retry deletion
   - All antecedent commits implementing the vanilla-API path that PRs #128–#132 build on (tracing back to roughly 2026-04-14 — implementer determines the merge-base via `git log --first-parent` on `feat/demo-studio-v3`).
2. **S2 client — `tools/demo-studio-v3/config_mgmt_client.py`.** The HTTP client S1 uses to call S2. Includes:
   - PR #126 — `_handle_error` for HTTP 422 (config-validation defensiveness on the client side)
   - All antecedent commits scoping the v3 S2 client surface.
3. **Schema endpoint — `/v1/schema` wire-up to canonical `schema.yaml`.** Captured by PR #130. Note: tuan's `00014-2bn` already has the schema content live on S2; this cherry-pick brings forward the *S1-side* code that consumes `/v1/schema` (validation in `_handle_set_config`, schema fetch on session boot, etc.).
4. **Sign-in / Firebase Auth integration.** Captured by `feat/demo-studio-v3`'s auth-related commits (Firebase Auth boot, `missmp.eu` allowlist enforcement, session cookie issuance, `/build` dual-auth wiring per PR #127). The deployBtn surface (UI control, not an agent tool call) is included here.
5. **Preview iframe.** Live preview pane that refreshes on config save. The S2-driven refresh wiring is part of this; the iframe component's CSS, route, and contract are part of this.
6. **Deploy hygiene — PR #133 (`.gcloudignore` so `schema.yaml` survives `gcloud source` upload)** if applicable post-rebase. If the post-rebase deploy script no longer relies on `gcloud source`, this cherry-pick is dropped as moot — implementer judgment.

**Explicitly dropped from cherry-pick (Duong directive, brainstorm 2026-04-28): the studio dashboard.** No dashboard surface, no `/dashboard` route, no dashboard component, no related auth scopes for it. If incidental commits couple dashboard code to a real-subsystem cherry-pick, the dashboard portion is stripped during conflict resolution.

### D3 — Drop set (mock-dep code, NOT cherry-picked, deleted if it appears via merge resolution)

The following surfaces presume the legacy `demo-factory` mock contract and are not viable against real S3. They are NOT cherry-picked. If any of them appear on the new branch via incidental merge resolution, they are deleted before the PR opens.

- `tools/demo-studio-v3/factory_client_v2.py` — the sync JSON client built for `POST /build → {buildId, projectId}` within 30s. The real S3 contract is SSE-streamed; this client cannot speak it.
- `tools/demo-studio-v3/factory_bridge_v2.py` — adapter to the v2 factory client. Becomes dead with `factory_client_v2.py` gone.
- `/session/{sid}/build` handler in `tools/demo-studio-v3/main.py` — the existing handler routes to `factory_client_v2`. Replaced by a new handler (§D4) that routes to `factory_client_v3`.
- In-process S4 poller in `main.py` — the legacy mock returned a `buildId` that the v3 handler then polled S4 against, in-process. The real S3 calls S4 itself via API call (per project DoD step 9 and the canonical S3→S4 contract). S1's in-process poller is dead code.
- `S4_VERIFY_URL` env var scaffold in `main.py` and any deploy/manifest references. The real S3 owns this URL; S1 does not need to know about it.

**Note.** PR #127's `trigger_factory` removal stays — that's *kept*, not dropped. The change made `deployBtn` the sole build trigger, which is exactly what the new design also wants.

### D4 — New code introduced by Plan 1 (only on the new branch, not present anywhere on `feat/demo-studio-v3`)

1. **`tools/demo-studio-v3/factory_client_v3.py`** — SSE client speaking to real `demo-studio-factory`. Contract:
   - `POST <FACTORY_V3_BASE_URL>/build` with the session's resolved config payload.
   - Receives an SSE stream of events. Event taxonomy honored: `step_start`, `step_complete`, `step_failed`, `build_complete`, `build_failed`, `error`. (Implementer confirms the event names against `tools/demo-studio-factory/` source on `origin/main` during xfail authoring; if the Go service uses different names, the client matches.)
   - Translates each SSE event to S1's existing internal event schema so the cherry-picked progress-bar UI (ADR-1 / ADR-2 work, brought forward in §D2.1) consumes them without modification.
   - Emits `build_complete` event to S1's session state machine; S3 itself triggers S4 (per project DoD step 9), so S1 does NOT initiate a verify call. S1 listens for S4's progress events via the same SSE channel S3 multiplexes them on, OR via a separate verify-progress channel — implementer confirms against S3's actual contract.
2. **`/session/{sid}/build` handler in `main.py`, replaced** — drives `factory_client_v3` instead of `factory_client_v2`. Auth: dual-auth (session cookie OR Firebase ID token) per PR #127. Idempotency: rejects with 409 if `lastBuildAt` < N seconds ago AND `status == "building"` (watchdog handles stale state — see §D4.3).
3. **Stale-`lastBuildAt` watchdog** — the field is already written at `main.py:2562` on every `/build` call. Plan 1 makes it readable: a session whose `status == "building"` AND `lastBuildAt` more than a configurable timeout ago (default 15 minutes) is considered stale; on the next user action (`GET /session/{sid}` or attempted rebuild) the watchdog flips `status=failed` with `failure_reason="build_pipeline_timeout"` and allows the user to trigger a fresh build. Resolves the wedged-session class of bug seen in tonight's session `93ddfa6b…`.
4. **Tests** — xfail-first per Rule 12, then de-xfailed by the impl pair-mate (Rakan, complex tier). Coverage:
   - Happy-path SSE handshake against a captured replay of `demo-studio-factory`'s stream (replay fixture lives under `tools/demo-studio-v3/tests/fixtures/`).
   - `step_failed` event → session state `failed`, no further events processed.
   - Factory-unreachable (connection refused, DNS failure) → 503 to client, session `failed`.
   - Invalid request (missing `config`, malformed `session_id`) → 400 to client, session not transitioned.
   - Watchdog stale-detect → status flips `building` → `failed` after N seconds; subsequent build attempt accepted.
   - Watchdog non-stale → in-flight build is not disturbed.

### D5 — Scope: happy-path real-S3 only

Plan 1's error envelope is intentionally thin: invalid request (400), factory unreachable (503), watchdog stale (failed). Deferred to a follow-on plan, with rationale: real S3 has never been exercised from prod, so we don't yet know the empirical shape of its failure modes. Specifying retry counts, backoff curves, mid-stream-disconnect recovery, and observability/telemetry up front would be speculative; better to ship the happy path, exercise it under real load (single-user, Duong only), and let the next plan be informed by what actually breaks.

The follow-on plan is not authored as part of Plan 1 and not committed-to in this document. It will be written when its scope becomes clear.

### D6 — Disposition of PR #32 (umbrella `feat/demo-studio-v3`)

PR #32 closes — without merge — as Plan 1's terminal task, after Plan 1's PR has merged to main and S1 prod is deployed off the new code. The close comment on PR #32 links to Plan 1's PR, references this plan, and notes that the keepable subsystems were carried forward via cherry-pick (§D2) and the mock-dep ones were intentionally dropped (§D3). The `feat/demo-studio-v3` branch itself is preserved on origin as a historical artifact and cherry-pick reference; deletion is a separate housekeeping decision (out of scope).

This decision supersedes the parent project's prior "PR target stays `feat/demo-studio-v3`; PR #32 stays open and merges into `main` last" framing in `projects/work/active/bring-demo-studio-live-e2e-v1.md` §Decisions / 2026-04-27 ADR sequencing. The project doc is updated as part of Plan 1's last commit (a one-line edit referencing this plan's slug).

## Architecture impact

**Major.** Plan 1 changes the runtime topology of S1's build path from a synchronous JSON RPC against a Python mock to an SSE stream against a Go service. The change is invisible to UI surfaces (the progress-bar SSE consumer is identical; only the upstream source differs) but invasive to the build call site, the session state machine, and the deploy manifest (`FACTORY_BASE_URL` → `FACTORY_V3_BASE_URL` rename + value swap).

The change to main's commit history is large in line count (effectively re-introducing v3 minus the dashboard and minus mock-dep) but bounded by the explicit cherry-pick set. No commit on the new branch should originate from outside §D2 except the strictly-new code in §D4 and the project-doc one-liner in §D6.

## File structure

The implementer (Aphelios for the breakdown, Viktor for impl per the complex-track routing) walks the branch's `tools/demo-studio-v3/` tree post-cherry-pick to confirm. At a high level:

**Created on the new branch (not present on `origin/main`, not cherry-picked):**
- `tools/demo-studio-v3/factory_client_v3.py`
- `tools/demo-studio-v3/tests/fixtures/factory_v3_sse_replay/*.txt` — captured SSE event streams for replay testing.
- `tools/demo-studio-v3/tests/test_factory_client_v3.py` — xfail-first test suite for the new client.
- `tools/demo-studio-v3/tests/test_build_handler_v3.py` — xfail-first test suite for the new `/build` handler.
- `tools/demo-studio-v3/tests/test_lastbuildat_watchdog.py` — xfail-first test suite for the watchdog.

**Created on the new branch via cherry-pick (whole subsystems, exhaustive list determined by `git log feat/demo-studio-v3 -- <path>`):**
- `tools/demo-studio-v3/main.py` (cherry-pick brings forward agent surfaces; new `/build` handler in §D4 is a follow-on commit on this same file after the cherry-picks)
- `tools/demo-studio-v3/agent_proxy.py`
- `tools/demo-studio-v3/tool_dispatch.py`
- `tools/demo-studio-v3/stream_translator.py`
- `tools/demo-studio-v3/setup_agent.py`
- `tools/demo-studio-v3/config_mgmt_client.py`
- `tools/demo-studio-v3/schema_client.py` (or whatever the schema-endpoint consumer is named)
- `tools/demo-studio-v3/auth/*`
- `tools/demo-studio-v3/static/*` (preview iframe assets — minus dashboard assets)
- `tools/demo-studio-v3/templates/*` (preview iframe templates — minus dashboard templates)
- `tools/demo-studio-v3/tests/*` (cherry-picked test files for the brought-forward subsystems; mock-dep test files are NOT cherry-picked)
- Deploy manifest / `.gcloudignore` per §D2.6 if applicable.

**Modified on the new branch (post-cherry-pick edits):**
- `tools/demo-studio-v3/main.py` — replace `/session/{sid}/build` handler body to drive `factory_client_v3`; remove any incidental references to `factory_client_v2` / `factory_bridge_v2` / S4 poller / `S4_VERIFY_URL` that survived cherry-pick (defensive sweep).
- Deploy manifest — `FACTORY_BASE_URL` → `FACTORY_V3_BASE_URL` env var rename, value swap to `https://demo-studio-factory-4nvufhmjiq-ew.a.run.app` (or canonical).
- `projects/work/active/bring-demo-studio-live-e2e-v1.md` — one-line edit per §D6.

**NOT created (explicitly dropped per §D2 last paragraph and §D3):**
- Anything under a `dashboard/` path or named `dashboard*` — Duong directive.
- `tools/demo-studio-v3/factory_client_v2.py`
- `tools/demo-studio-v3/factory_bridge_v2.py`
- Tests targeting any of the dropped surfaces.

## Tasks

(High-level — Aphelios produces the bite-sized breakdown.)

1. **T1 — Branch creation and base sanity.** Cut `feat/demo-studio-v3-clean` off `origin/main` (`d835ade`). Run baseline tests (`pytest tools/demo-studio-v3/tests/` if any exist on main — likely none). Push; open a draft PR titled `feat(demo-studio-v3): mock-to-real-S3 migration on a fresh branch off main` referencing this plan.
2. **T2 — Cherry-pick the agent UX subsystem (§D2.1).** Walk `feat/demo-studio-v3` for commits implementing the vanilla Messages API path. Cherry-pick in chronological order. Resolve conflicts in favor of the latest state for that subsystem. Run agent-surface tests; fix any test-fixture conflicts. Commit per cherry-pick (preserve original authorship; `chore(cherrypick):` prefix on the merge commit if a `git cherry-pick -m 1` is needed for merge commits).
3. **T3 — Cherry-pick S2 client (§D2.2).** Same shape as T2.
4. **T4 — Cherry-pick schema endpoint (§D2.3).** Same shape.
5. **T5 — Cherry-pick sign-in / Firebase Auth + deployBtn (§D2.4).** Same shape.
6. **T6 — Cherry-pick preview iframe (§D2.5).** Same shape, with explicit dashboard exclusion: any conflict between iframe code and dashboard code is resolved by dropping the dashboard side.
7. **T7 — Cherry-pick deploy hygiene (§D2.6) if applicable.**
8. **T8 — Defensive drop sweep (§D3).** Confirm none of the dropped surfaces survived cherry-pick. Where they did, delete with a `chore: drop mock-dep <surface>` commit.
9. **T9 — xfail tests for new code (§D4.4).** Rakan (complex-track test impl) authors. Commit on the same branch before T10. Per Rule 12, no impl commit may precede an xfail commit on the same branch.
10. **T10 — Implement `factory_client_v3` (§D4.1).** Viktor. De-xfails the relevant tests from T9.
11. **T11 — Replace `/build` handler (§D4.2).** Viktor. De-xfails the build-handler tests.
12. **T12 — Implement watchdog (§D4.3).** Viktor. De-xfails the watchdog tests.
13. **T13 — Deploy manifest update.** `FACTORY_V3_BASE_URL` env var, value points at `demo-studio-factory` Cloud Run URL.
14. **T14 — Project-doc one-liner (§D6).** Edit `projects/work/active/bring-demo-studio-live-e2e-v1.md` to note the disposition change.
15. **T15 — Akali QA (§QA Plan).** Full DoD walk. Reports under `assessments/qa-reports/`.
16. **T16 — Senna + Lucian PR review per Rule 18.** Verdicts as PR comments under `duongntd99` (work scope identity model).
17. **T17 — Merge to main + stg deploy + smoke + prod deploy + smoke per Rule 17.**
18. **T18 — Close PR #32 (§D6).** Final task. `gh pr close 32 --repo missmp/company-os --comment <link to Plan 1's PR + this plan>`.

## QA Plan

**UI involvement:** yes

The cherry-picked UI surfaces (auth flow, default-config greeting, chat panel, preview iframe, deployBtn, build-progress bar) are exercised end-to-end. Akali Playwright + screenshot narrative required per Rule 16. No Figma reference declared on the parent project doc, so Figma diff is not required (per Rule 16's opt-in clause); screenshot-with-narrative satisfies the UI branch.

### Acceptance criteria

Reviewer (Senna code-quality + Lucian plan-fidelity) confirms via code-check; Akali confirms via Playwright RUNWAY:

- New branch contains zero references to `factory_client_v2`, `factory_bridge_v2`, `S4_VERIFY_URL`, or any in-process S4 poller. (`grep -r` on the branch returns zero matches.)
- New branch contains no `dashboard/` path or `*dashboard*` files (per Duong directive). (`find . -iname '*dashboard*'` on the branch returns zero results within `tools/demo-studio-v3/`.)
- `factory_client_v3` exists and tests pass green.
- `/build` handler routes to `factory_client_v3` and tests pass green.
- Watchdog tests pass green; a synthesized stale-`lastBuildAt` session does flip to `failed` after the configured timeout and accepts a fresh build attempt.
- Deploy manifest references `FACTORY_V3_BASE_URL` with the correct Cloud Run URL; no residual `FACTORY_BASE_URL` references survive.
- `projects/work/active/bring-demo-studio-live-e2e-v1.md` carries the one-line disposition note (§D6).
- PR #32 is CLOSED (not MERGED) with a comment linking to Plan 1's PR.

### Happy path (user flow)

Akali Playwright RUNWAY — full DoD walk.

1. Akali signs in via Google (`@missmp.eu` test account); lands in studio shell. (DoD step 1)
2. Akali clicks "New session"; lands in `/session/{sid}` with the seeded default config greeting and a live preview iframe attached. (DoD steps 2–3)
3. Akali types: "make the brand AXA Germany". Agent calls `set_config` (canonical save). UI: green toast "Config saved as v2"; preview iframe refreshes to AXA branding. (DoD steps 4–5; cherry-picked from ADR-3 / ADR-4 — visual delta is identical.)
4. Akali clicks the **deployBtn** ("Build project"). UI shows the build progress bar incrementing through the S3 step taxonomy in real time — and the times between steps are **multi-second to multi-minute**, not 10ms-fake. This is the empirical signal that the real S3 is now being called. (DoD steps 6–7)
5. Build completes. Chat receives an agent message announcing completion; UI state changes to "verifying". (DoD step 8)
6. Verify auto-fires (S3 → S4 API call, no agent intervention). UI shows verify progress bar. (DoD steps 9–10)
7. Verify completes. Agent narrates the result, the project ID, and the demo link in chat. UI shows the demo link as a clickable element. (DoD step 11)
8. Akali clicks the demo link; opens to a live, working demo URL backed by real Wallet Studio artifacts. (Validates that the URL is real, not a mock-invented placeholder.)

### Failure modes (what could break)

Smoke-shaped, not full Playwright. Exercised by Vi (test execution) against a stg deploy before the prod cutover:

- Factory unreachable: stg `FACTORY_V3_BASE_URL` temporarily pointed at a 127.0.0.1:nonexistent. Click deployBtn → red error toast within ~2s; session state is `failed`, not stuck `building`.
- Factory rejects request (synthesized 400 from a stub): UI shows the structured error; session state `failed`.
- Watchdog: a session is poked into `status=building, lastBuildAt=<now-30min>` via a debug endpoint; next `GET /session/{sid}` flips it to `failed` and allows a fresh build trigger.

### QA artifacts expected

The PR body must carry the following markers, each pointing at a real artifact:

- `QA-Report: assessments/qa-reports/2026-04-28-demo-studio-v3-mock-to-real-s3-migration.md` — Akali's full Playwright RUNWAY narrative with per-screenshot observations (what was checked, observed vs expected, pass/fail) for every step of the §Happy path (user flow) above. Required by Rule 16.
- `Visual-Diff: <screenshots-directory or none>` — the cherry-picked UI surfaces are bit-for-bit per `ux_waiver`; if Akali's RUNWAY confirms zero visual delta against a baseline screenshot capture from `feat/demo-studio-v3` qa-adr2-c (or equivalent), the value is `none — refactor with no visible delta confirmed`. If any visual delta IS observed, the marker points at a side-by-side comparison.
- `Accessibility-Check: <command-or-tool-output>` — axe-core run against the staged S1 sign-in page and session shell post-deploy; no new violations vs. baseline. Output captured as part of the QA report.
- `Design-Spec: ux_waiver` — frontmatter-declared UX-Waiver lifts the §UX Spec requirement; this marker points at the waiver line.

Akali's deliverable (the Playwright run video + screenshot narrative) lives under `assessments/qa-reports/`. The video file pairs with the markdown report (same slug, `.mp4` extension).

The stg-deploy smoke evidence (per Rule 17) comprises:

- Cloud Run inbound-traffic log line on `demo-studio-factory` confirming the first SSE request from `demo-studio` (S1) — captured from `gcloud run services logs read demo-studio-factory --region=europe-west1 --limit=50` immediately after Akali's stg run.
- Stg `/build` SSE stream capture (curl -N output) showing the canonical event taxonomy.
- Watchdog smoke log: a synthesized stale-`lastBuildAt` session flipping `building → failed` after the configured timeout.

The prod-deploy smoke evidence (also per Rule 17) is one Akali pass against prod after the stg run is green; produces an additional QA report under the same `assessments/qa-reports/` slug suffixed `-prod`. Failure on prod triggers `scripts/deploy/rollback.sh` per Rule 17 and a follow-up incident plan.

### Non-UI verification

(Per Rule 16 non-UI branch shape — even though this PR has UI involvement, the backend SSE plumbing benefits from a non-UI smoke too):

- `curl -N <stg S1>/session/<test-sid>/build` against a test session: receives an SSE stream with the expected event taxonomy (`step_start`, `step_complete`, ..., `build_complete`).
- Cloud Run logs on `demo-studio-factory` show inbound traffic from `demo-studio` (S1) for the first time in production.

## Test plan

Authored by Xayah (complex-track resilience / fault-injection planner). Executed by Rakan (xfail authoring) against the new branch from §D1. All xfail commits land **before** the paired Viktor impl commit on the same branch, per Rule 12. Pair-mate commit ordering is called out per task in DoD.

### Scope and proportionality

Plan 1 is scoped to happy-path real-S3 (§D5). The fault-injection coverage below is the **floor** for the complex-track tier — it covers the four classes of failure that *must* hold before any S1 user clicks deployBtn against the real Go service for the first time in production:

1. **Contract conformance** — the client correctly parses the canonical SSE event taxonomy emitted by `demo-studio-factory` source (not the names assumed in §D4.1). Establishes the basis on which all other failure tests are written.
2. **Terminal-error handling** — the two terminal failure events (`step_error`+`build_error`) flip the session to `failed` exactly once and stop processing further bytes.
3. **Transport failure** — the four ways an SSE connection can fail outside the protocol (DNS, refused, mid-stream close, truncation without terminal event) all land the session in `failed`, never wedged in `building`.
4. **Watchdog liveness** — the stale-`lastBuildAt` flip is the only mechanism that can recover a session whose build process died without emitting any signal. The watchdog tests are non-negotiable; without them, a transport-failure escape that bypasses (3) silently wedges the user.

Coverage that is **explicitly out of scope** for Plan 1 (per §D5): retry counts, exponential backoff curves, mid-stream-disconnect *recovery* (vs. clean failure), keep-alive interval tuning, telemetry/metrics emission, multi-tenant fairness, partial-failure rollback semantics. Tests for these are deferred to the follow-on plan referenced in §D5. Rakan does **not** author xfails for this deferred set.

### Pre-requisite — confirm the real SSE event taxonomy from source

The plan in §D4.1 lists the event taxonomy as `step_start`, `step_complete`, `step_failed`, `build_complete`, `build_failed`, `error`. **The real `demo-studio-factory` service uses different names** — confirmed by reading `tools/demo-studio-factory/openapi.yaml` (sibling repo `~/Documents/Work/mmp/workspace/company-os-w3-impl/tools/demo-studio-factory/`). The canonical names per source are:

| Event | Terminal? | Payload (per openapi.yaml §POST /build response 200) |
|-------|-----------|-------------------------------------------------------|
| `step_start` | no | `{"step": <int>, "totalSteps": 10, "name": "<step_name>"}` |
| `step_complete` | no | `{"step": <int>, "name": "<step_name>", "duration_ms": <int>}` |
| `step_error` | no — always followed by `build_error` | `{"step": <int>, "name": "<step_name>", "error": {"code": "BUILD_FAILED", "message": "<str>"}}` |
| `build_complete` | yes (stream closes) | `{"sessionId": "<str>", "projectId": <int>, "projectUrl": "<url>", "demoUrl": "<url>", "passUrls": {"apple": "<url>", "google": "<url>"}}` |
| `build_error` | yes (stream closes; project archived before emission) | `{"failedStep": <int>, "failedStepName": "<step_name>", "projectId": <int>, "archived": true, "error": {"code": "<code>", "message": "<str>"}}` |

The `error` event in §D4.1 does not exist in the source. The names `step_failed` / `build_failed` from §D4.1 are wrong; the real names are `step_error` / `build_error`. **All test fixtures and `factory_client_v3` parser code use the real names.** Rakan's first task (T9.0 below) is to re-confirm this by re-reading the openapi.yaml on `origin/main` of the sibling repo at xfail-authoring time (in case the contract changed between this plan's authoring and impl); if any names disagree, Rakan flags to Sona for a plan-amendment pass before T9.1.

Additional contract details that the test plan assumes (also confirmed from openapi.yaml, §POST /build):

- **Request envelope** is `{"sessionId": "<str>"}` — NOT `{"config": {...}}` as one might infer from §D4.1's "session's resolved config payload" phrasing. Real S3 fetches the resolved config from S2 (Config Mgmt) itself, given only the sessionId. This is a **plan-impl mismatch** Rakan flags to Sona during T9.0 — the impl in T10 must send `sessionId`, not `config`. Tests assert the request body shape.
- **Auth** is `Authorization: Bearer <DS_CONFIG_MGMT_TOKEN>`. Tests cover the unauthenticated 401 case.
- **501 `NOT_CONFIGURED`** is returned when S3's S2 wiring is missing. This shouldn't fire in stg/prod but the client MUST handle it as a failure (not a retryable state).
- **502 `CONFIG_FETCH_FAILED`** is returned when S3 cannot reach S2. From S1's perspective this is indistinguishable from any other upstream failure — session goes to `failed`.

### Surface map — what each test file owns

Three new test files are added on the new branch under `tools/demo-studio-v3/tests/`. Each is owned by a specific surface and lists xfail-marked tests that pair 1:1 with Viktor impl tasks:

- **`test_factory_client_v3.py`** — the SSE client itself: parser, transport, error-translation. Pairs with §Tasks T10.
- **`test_build_handler_v3.py`** — the `/session/{sid}/build` route handler: auth, request validation, idempotency, session-state transitions, response envelope. Pairs with §Tasks T11.
- **`test_lastbuildat_watchdog.py`** — the watchdog logic on `GET /session/{sid}` and `/build`. Pairs with §Tasks T12.

A fourth artifact directory holds replay fixtures consumed by all three test files:

- **`tools/demo-studio-v3/tests/fixtures/factory_v3_sse_replay/`** — captured-and-trimmed SSE byte streams. Captured via `curl -N -H 'Authorization: Bearer ...' <stg-factory-url>/build-from-direct-config?sessionId=test-replay-001 -d @<fixture-config>.json > happy_path.txt` against the stg deploy of `demo-studio-factory`. Synthetic-but-realistic byte streams (with hand-edited terminal events) are used for the `step_error` and `build_error` cases since those require provoking real failures upstream.

### Test tasks (resilience / fault-injection layer for §D4.4)

Each task is an xfail-first commit. The xfail commit lands on the new branch from §D1 **before** the paired Viktor impl commit. `parallel_slice_candidate` is set per the slicing rule in `agents/xayah/CLAUDE.md`. Files: paths relative to repo root.

#### T9.0 — Confirm SSE event taxonomy from `demo-studio-factory` source

- [ ] **T9.0** — Re-read `~/Documents/Work/mmp/workspace/company-os-w3-impl/tools/demo-studio-factory/openapi.yaml` on `origin/main` HEAD. Diff its event taxonomy against the table in §Test plan above. estimate_minutes: 15. Files: (read-only — no commit). DoD: (a) Confirm event names `step_start`, `step_complete`, `step_error`, `build_complete`, `build_error` are still canonical. (b) Confirm `/build` request body is `{"sessionId": "<str>"}`. (c) If any name or shape differs, Rakan posts to `agents/sona/inbox/` with a flag and waits for Sona's go/no-go before continuing T9.1+. (d) Otherwise, log "taxonomy-confirmed-<git-sha-of-openapi.yaml>" in Rakan's session memory and proceed. parallel_slice_candidate: no.

#### T9.1 — Capture happy-path SSE replay fixture

- [ ] **T9.1** — Capture a real happy-path SSE stream from stg `demo-studio-factory` against a small `direct-config` fixture (single template, single language). estimate_minutes: 30. Files: `tools/demo-studio-v3/tests/fixtures/factory_v3_sse_replay/happy_path.txt`, `tools/demo-studio-v3/tests/fixtures/factory_v3_sse_replay/happy_path_config.json`, `tools/demo-studio-v3/tests/fixtures/factory_v3_sse_replay/README.md`. DoD: (a) `happy_path.txt` is the verbatim `curl -N` output of a successful build, with all 10 `step_start`+`step_complete` pairs and a terminal `build_complete`. (b) `README.md` documents the capture command, stg revision SHA, and date. (c) Sensitive values (auth tokens, real projectIds) scrubbed; replace with placeholders `__REDACTED__`. (d) Committed before T9.2 since downstream fixtures derive from this byte stream. parallel_slice_candidate: wait-bound (capture is bounded by real build duration ~minutes).

#### T9.2 — Synthesize failure-mode replay fixtures

- [ ] **T9.2** — Hand-edit copies of `happy_path.txt` to produce three failure-mode byte streams. estimate_minutes: 30. Files: `tools/demo-studio-v3/tests/fixtures/factory_v3_sse_replay/step_error_then_build_error.txt`, `.../truncated_after_step_3.txt`, `.../empty_stream.txt`. DoD: (a) `step_error_then_build_error.txt` truncates at step 4, emits a `step_error` event with `{"step":4, "name":"build_ios_template", "error":{"code":"BUILD_FAILED", "message":"validate ios template: missing translation key"}}`, then a terminal `build_error` event with `archived: true`. (b) `truncated_after_step_3.txt` ends abruptly mid-byte after `step_complete` for step 3 — no terminal event. (c) `empty_stream.txt` is a 0-byte file (server returned 200 but emitted nothing before disconnect). parallel_slice_candidate: no.

#### T9.3 — xfail: happy-path SSE handshake against replay fixture (pairs with T10)

- [ ] **T9.3** — Add xfail test `test_happy_path_replay_drives_session_to_built` covering parse-and-translate of every event in `happy_path.txt`. estimate_minutes: 45. Files: `tools/demo-studio-v3/tests/test_factory_client_v3.py`. DoD: (a) Test loads `happy_path.txt`, feeds bytes through `factory_client_v3.parse_stream()`, asserts each emitted internal event matches expected step name + duration. (b) Asserts the terminal `build_complete` translates to a session-state transition `building → built` with `projectId`, `demoUrl`, `passUrls.apple`, `passUrls.google` populated. (c) Marked `@pytest.mark.xfail(reason="factory_client_v3 not yet implemented", strict=True)`. (d) Committed before T10 per Rule 12. parallel_slice_candidate: yes.

#### T9.4 — xfail: terminal step_error + build_error → session failed (pairs with T10)

- [ ] **T9.4** — Add xfail test `test_step_error_then_build_error_flips_session_to_failed`. estimate_minutes: 35. Files: `tools/demo-studio-v3/tests/test_factory_client_v3.py`. DoD: (a) Test feeds `step_error_then_build_error.txt` through the client. (b) Asserts session state transitions `building → failed` exactly once. (c) Asserts `failure_reason` equals `"step_error: build_ios_template: BUILD_FAILED"` (or whatever canonical shape the impl chooses — Rakan picks a shape, Viktor implements to match). (d) Asserts no internal event is emitted after the `build_error` (parser stops reading; even if more bytes follow, they are discarded). (e) xfail until T10. Committed before T10 per Rule 12. parallel_slice_candidate: yes.

#### T9.5 — xfail: factory unreachable (connection refused, DNS failure) → 503 + session failed (pairs with T11)

- [ ] **T9.5** — Add xfail test `test_factory_unreachable_returns_503_and_fails_session`. estimate_minutes: 40. Files: `tools/demo-studio-v3/tests/test_build_handler_v3.py`. DoD: (a) Two parametrized cases: (i) `FACTORY_V3_BASE_URL` points at `http://127.0.0.1:1` (connection refused), (ii) `FACTORY_V3_BASE_URL` points at `http://nonexistent-host-deadbeef.invalid` (DNS NXDOMAIN). (b) `POST /session/{sid}/build` returns HTTP 503 to the client within ~2s (assert `response.elapsed < 5s` to catch hangs). (c) Session state is `failed`, `failure_reason` ∈ {`"factory_unreachable"`, `"factory_dns_failure"`}. (d) Response body contains a structured error envelope (shape decided by Viktor in T11). (e) xfail until T11. Committed before T11 per Rule 12. parallel_slice_candidate: yes.

#### T9.6 — xfail: mid-stream SSE disconnect / truncation → session failed cleanly (pairs with T10/T11)

- [ ] **T9.6** — Add xfail test `test_mid_stream_truncation_does_not_wedge_session`. estimate_minutes: 50. Files: `tools/demo-studio-v3/tests/test_factory_client_v3.py`. DoD: (a) Use a local fake SSE server (pytest fixture, `aiohttp.test_utils` or equivalent) that emits the bytes of `truncated_after_step_3.txt` then closes the TCP connection without flushing a terminal event. (b) Client detects the close-without-terminal condition and raises a typed exception (e.g. `FactoryStreamTruncatedError`). (c) Handler catches the exception, transitions session to `failed`, `failure_reason="factory_stream_truncated"`. (d) Assert session is **never** observed in `building` state after the disconnect (poll session state for 2s post-disconnect; must be `failed` within that window). (e) Also covers the `empty_stream.txt` case — server returns 200 with 0 bytes, client raises `FactoryStreamEmptyError`, session → `failed`. (f) xfail until T10 + T11 both land. Committed before whichever lands first per Rule 12. parallel_slice_candidate: yes.

#### T9.7 — xfail: invalid request envelope → 400, session not transitioned (pairs with T11)

- [ ] **T9.7** — Add xfail test `test_invalid_request_envelope_returns_400_no_transition`. estimate_minutes: 30. Files: `tools/demo-studio-v3/tests/test_build_handler_v3.py`. DoD: Three parametrized cases — (i) empty body, (ii) malformed `session_id` (e.g. contains `/`), (iii) session_id refers to a session whose config has never been saved (no S2 record). (a) Each returns HTTP 400 with a structured error code (`MISSING_BODY`, `INVALID_SESSION_ID`, `NO_CONFIG_FOR_SESSION` respectively — Viktor picks final names). (b) Critically: session state in S1 is **NOT** transitioned — if it was `idle` before the call it remains `idle`; `lastBuildAt` is **not** written. (c) Assert no SSE connection to S3 was opened (use a counting mock client; `mock.call_count == 0`). (d) xfail until T11. Committed before T11. parallel_slice_candidate: yes.

#### T9.8 — xfail: factory returns 4xx/5xx pre-stream → session failed (pairs with T11)

- [ ] **T9.8** — Add xfail test `test_factory_pre_stream_error_responses_fail_session`. estimate_minutes: 35. Files: `tools/demo-studio-v3/tests/test_build_handler_v3.py`. DoD: Five parametrized cases against a fake S3 that returns the response code synchronously without opening a stream — (i) 400 `INVALID_REQUEST`, (ii) 400 `INVALID_CONFIG`, (iii) 401 `UNAUTHORIZED` (auth misconfigured), (iv) 501 `NOT_CONFIGURED`, (v) 502 `CONFIG_FETCH_FAILED`. (a) For each, S1 session goes to `failed` with `failure_reason` carrying the upstream code. (b) S1 returns 502 to the user (the upstream's status is internal; user sees a "factory error" envelope). (c) Note: this is **not** retry — Plan 1 is happy-path-only per §D5. The client surfaces the failure cleanly; retry policy is the follow-on plan's job. (d) xfail until T11. Committed before T11. parallel_slice_candidate: yes.

#### T9.9 — xfail: watchdog stale-detect flips building → failed and accepts fresh build (pairs with T12)

- [ ] **T9.9** — Add xfail test `test_watchdog_stale_session_flips_to_failed_and_accepts_rebuild`. estimate_minutes: 40. Files: `tools/demo-studio-v3/tests/test_lastbuildat_watchdog.py`. DoD: (a) Seed a session with `status="building"` and `lastBuildAt = now - (configured_timeout + 60s)`. (b) Call `GET /session/{sid}` — assert response carries `status="failed"`, `failure_reason="build_pipeline_timeout"`. (c) Assert the session record in store has been mutated (not just the response) — re-fetch directly via store API confirms `status==failed`. (d) Issue `POST /session/{sid}/build` immediately after — assert it is accepted (200/202), not rejected with 409. (e) Watchdog timeout configurable via env var (`FACTORY_V3_WATCHDOG_TIMEOUT_SECONDS`, default 900); test parametrizes on a 60s timeout for speed. (f) xfail until T12. Committed before T12. parallel_slice_candidate: yes.

#### T9.10 — xfail: watchdog non-stale leaves in-flight build undisturbed (pairs with T12)

- [ ] **T9.10** — Add xfail test `test_watchdog_non_stale_does_not_disturb_in_flight_build`. estimate_minutes: 30. Files: `tools/demo-studio-v3/tests/test_lastbuildat_watchdog.py`. DoD: (a) Seed a session with `status="building"` and `lastBuildAt = now - 30s` (well under the 60s test timeout). (b) Call `GET /session/{sid}` — assert response carries `status="building"`, `failure_reason` absent. (c) Assert the session record is **not** mutated (re-fetch confirms `status==building`, `lastBuildAt` unchanged within 1s tolerance). (d) Issue `POST /session/{sid}/build` — assert it is rejected with HTTP 409 `BUILD_IN_PROGRESS` (per §D4.2 idempotency). (e) xfail until T12. Committed before T12. parallel_slice_candidate: yes.

#### T9.11 — xfail: idempotency under rapid double-click (pairs with T11)

- [ ] **T9.11** — Add xfail test `test_rapid_double_build_second_call_returns_409`. estimate_minutes: 30. Files: `tools/demo-studio-v3/tests/test_build_handler_v3.py`. DoD: (a) Call `POST /session/{sid}/build` twice in quick succession (second call within 1s of the first, both before any SSE events arrive). (b) Assert first call returns 200/202 and opens an SSE stream. (c) Assert second call returns HTTP 409 with `error.code = "BUILD_IN_PROGRESS"` and does NOT open a second SSE stream to S3 (counting mock confirms `S3.build_call_count == 1`). (d) Models the deployBtn-double-click case which today's mock-factory tolerated invisibly. (e) xfail until T11. Committed before T11. parallel_slice_candidate: yes.

#### T9.12 — xfail: auth — unauthenticated /build is rejected pre-stream (pairs with T11)

- [ ] **T9.12** — Add xfail test `test_unauthenticated_build_rejected_before_factory_call`. estimate_minutes: 25. Files: `tools/demo-studio-v3/tests/test_build_handler_v3.py`. DoD: (a) Call `POST /session/{sid}/build` with neither a valid session cookie nor a Firebase ID token. (b) Assert HTTP 401 returned. (c) Assert no S3 call was made (counting mock `call_count == 0`). (d) Assert session state untouched. (e) xfail until T11 (T11 cherry-picks the dual-auth wiring from §D2.4 / PR #127, then plumbs it). parallel_slice_candidate: yes.

#### T9.13 — Audit: sweep for missing-coverage gaps after impl green

- [ ] **T9.13** — After Viktor's T10/T11/T12 land and all xfails de-xfail, Rakan re-reads the test files and the impl to flag any uncovered branch. estimate_minutes: 45. Files: (read-only audit; output is a comment trail or follow-on issue, not new tests). DoD: (a) Walk `factory_client_v3.py`, `main.py` `/build` handler, and watchdog code paths line-by-line. (b) For each conditional, confirm at least one test exercises both branches OR document the unexercised branch as a known follow-on plan item (with rationale). (c) Output: PR comment on Plan 1's PR titled "Coverage audit — Xayah/Rakan complex-track" linking each conditional to its test or to a follow-on item. (d) Does NOT block PR merge — informational signal for reviewers and the follow-on plan. parallel_slice_candidate: no.

### Coverage matrix

| Failure class | Test task(s) | Assertion floor |
|---------------|--------------|-----------------|
| Happy path conformance | T9.3 | All 10 steps + terminal `build_complete` parsed; session reaches `built` with all artifact URLs populated |
| Terminal protocol failure (`step_error` + `build_error`) | T9.4 | Session → `failed` once, no events processed after `build_error` |
| Transport — connection refused / DNS | T9.5 | 503 to client < 5s; session → `failed`; `failure_reason` distinguishes refused vs DNS |
| Transport — mid-stream truncation / empty stream | T9.6 | Client raises typed exception; session → `failed`; never wedged in `building` |
| Request validation (envelope, session_id, no config) | T9.7 | 400 to client; session NOT transitioned; no S3 call made |
| Pre-stream upstream errors (S3 4xx/5xx) | T9.8 | Session → `failed` with upstream code in `failure_reason`; user sees 502 |
| Watchdog — stale flip + recovery | T9.9 | `building → failed` after timeout; subsequent build accepted |
| Watchdog — non-stale safety | T9.10 | In-flight build undisturbed; concurrent build attempt → 409 |
| Idempotency — double-click | T9.11 | Second call → 409; only one S3 stream opened |
| Auth — unauthenticated | T9.12 | 401 returned; no S3 call; session untouched |
| Coverage audit | T9.13 | Every conditional in new code is covered or explicitly deferred |

### Hand-off contract to Rakan

Rakan executes T9.0 through T9.12 in commit order. The recommended commit-graph shape on the new branch from §D1, woven with Viktor's impl tasks:

```
... (cherry-picks T2..T8 land first) ...
T9.0 (no commit — confirmation only; or a `chore: confirm factory SSE taxonomy from origin/main` note commit if desired)
T9.1 (chore: capture factory v3 happy-path SSE replay fixture)
T9.2 (chore: synthesize factory v3 failure-mode SSE fixtures)
T9.3 (test: xfail factory_client_v3 happy-path replay)
T9.4 (test: xfail factory_client_v3 step_error then build_error)
T9.6 (test: xfail factory_client_v3 mid-stream truncation)         ← split: client-side cases land before T10
T10  (feat: implement factory_client_v3 against real S3 SSE)        ← Viktor; de-xfails T9.3, T9.4, T9.6 client-side cases
T9.5 (test: xfail build handler factory unreachable)
T9.6 (already committed; de-xfail completes after T11 lands)
T9.7 (test: xfail build handler invalid request envelope)
T9.8 (test: xfail build handler factory pre-stream errors)
T9.11 (test: xfail build handler rapid double-click idempotency)
T9.12 (test: xfail build handler unauthenticated)
T11  (feat: replace /build handler to drive factory_client_v3)      ← Viktor; de-xfails T9.5, T9.6 handler-side, T9.7, T9.8, T9.11, T9.12
T9.9 (test: xfail watchdog stale flip)
T9.10 (test: xfail watchdog non-stale safety)
T12  (feat: implement lastBuildAt watchdog)                          ← Viktor; de-xfails T9.9, T9.10
T13  (deploy manifest)
T14  (project doc one-liner)
T9.13 (audit — comment on PR; does not block merge)
T15..T18 (QA, review, merge, close PR #32)
```

T9.6 spans both T10 and T11; commit it once (before T10) but its `strict=True` xfail flips green only after T11 lands as well. If pytest's xfail strictness errors at T10's de-xfail attempt because T9.6's handler-path is still red, Rakan splits T9.6 into T9.6a (client-side, lands before T10) and T9.6b (handler-side, lands before T11).

### Plan-impl mismatches Rakan flags during T9.0

These are not test-plan tasks; they are **flags Rakan posts to Sona's inbox** so Sona can re-route to Aphelios for a §D4 amendment if needed:

1. **Event names.** §D4.1 says `step_failed` / `build_failed` / `error`. Source says `step_error` / `build_error`; no `error` event exists. Impact: `factory_client_v3` parser must use the real names; the v3 progress-bar UI translation layer (cherry-picked from ADR-1/ADR-2) may already use the wrong names if the cherry-picked code reused §D4.1's strings.
2. **Request body shape.** §D4.1 says "session's resolved config payload"; openapi.yaml says `{"sessionId": "<str>"}`. Impact: `factory_client_v3.build()` sends sessionId only — the real S3 fetches the config from S2 itself. (`/build-from-direct-config` accepts inline JSON, but Plan 1 uses `/build`.)
3. **S3 → S4 trigger channel.** §D4.1 says "S1 listens for S4's progress events via the same SSE channel S3 multiplexes them on, OR via a separate verify-progress channel". The openapi.yaml does not document S4 events on the S3 stream — `build_complete` is terminal. **This may mean S3 does NOT multiplex S4 progress.** Rakan flags this open question to Sona; resolution may require either reading more S3 source (e.g. `pkg/logic/`) or talking to Heimerdinger/Ekko about how the S3→S4 hop is wired in the deployed Cloud Run revision. Tests for the S3→S4 progress UI are explicitly **deferred** to the follow-on plan if this remains unresolved at impl time.

### Out-of-scope (deferred to follow-on plan per §D5)

The following coverage is intentionally **not** authored by Rakan in Plan 1; tests for these are reserved for the follow-on plan informed by real-traffic empirical data:

- Retry on transient SSE disconnect (Plan 1 fails cleanly; retry is follow-on).
- Recovery from partial step failures (e.g. step 8 fails after step 7 succeeded — does the project get cleaned up server-side? Plan 1 trusts S3's `archived: true` flag in `build_error`).
- Telemetry / metrics emission (no Prometheus, no structured logs assertions).
- Concurrent multi-session fairness (single-user constraint per parent project).
- SSE keep-alive interval tuning (real builds take minutes; if S1's HTTP client times out reading idle stream, that's a follow-on tune).
- Schema-version skew between S1's local schema cache and S2's live `/v1/schema` (`config_mgmt_client.py` cherry-picked tests cover this within their own surface; not a `factory_client_v3` concern).

## Risks

- **Real S3 contract drift.** The Go `demo-studio-factory` service has never been exercised from prod. Its SSE event names, payload shapes, and error envelopes may differ from what the implementer infers from source. Mitigation: implementer reads `tools/demo-studio-factory/` source on origin/main during T9 xfail authoring; tests use replay fixtures captured from a stg invocation, not invented payloads.
- **Cherry-pick conflict resolution.** The 666 commits on `feat/demo-studio-v3` include intermediate states from ADRs 1–4 that may resolve oddly when cherry-picked in a different order than they were merged. Mitigation: implementer cherry-picks subsystems in the order §D2 lists them, runs the test suite after each subsystem's set, and flags any conflict that requires non-trivial resolution to Sona for an Aphelios re-breakdown.
- **Dashboard-coupling.** The dashboard may be coupled to other cherry-pick targets via shared state, shared route registration, or shared component imports. Mitigation: T6's explicit dashboard-exclusion rule; if the coupling is structural, the implementer flags it in a check-in and Sona decides whether to (a) salvage by excising dashboard imports inline or (b) escalate the dashboard exclusion as a follow-on plan task.
- **First real-S3 build duration.** Real Wallet Studio pipeline takes minutes; agent UX, watchdog timeouts, and SSE keep-alive intervals were all tuned against the 10ms mock. Mitigation: §D4.3 watchdog timeout is configurable; default 15 minutes is generous. Akali QA observes actual durations and the follow-on plan tunes from there.
- **Akali QA on prod.** DoD step #8 (demo link clickable) requires a real demo URL backed by real Wallet Studio artifacts. If the build pipeline produces a malformed artifact, the demo link is broken even though the migration code is correct. Mitigation: scope-limited — this risk falls outside Plan 1's responsibility (S3 owns artifact correctness) but Akali surfaces it if observed and Sona triages whether it blocks Plan 1's merge.

## Open questions (to be resolved during breakdown / impl, not blockers for plan approval)

- Exact SSE event names emitted by `demo-studio-factory` — implementer confirms from source during T9 xfail authoring.
- Whether S3 → S4 progress is multiplexed on the same SSE channel or a separate one — implementer confirms from source.
- Final branch name (`feat/demo-studio-v3-clean` is a working name; implementer may choose a more descriptive slug at T1).
- Whether PR #133's `.gcloudignore` change is still relevant post-rebase (§D2.6 leaves this as implementer judgment).

## Routing for breakdown and impl

Per the work-concern complex-track routing in `agents/sona/CLAUDE.md` §Delegation Quick-Reference:

- **Breakdown:** Aphelios (complex-track) — produces bite-sized task list against §Tasks.
- **Test plan:** Xayah (complex-track) — authors the resilience / fault-injection layer for D4.4 (factory unreachable, mid-stream truncation, watchdog stale).
- **xfail authoring:** Rakan (complex-track) — sub-pair of Xayah; lands xfails on the new branch before Viktor's impl per Rule 12.
- **Impl:** Viktor (complex-track) — invasive feature, cross-module work, refactor-as-part-of-build.
- **Frontend:** the cherry-picked UI surfaces are bit-for-bit; no Seraphine / Soraka work is needed unless cherry-pick conflicts surface a UI-shaped resolution. Lulu / Neeko advisory only.
- **Review:** Senna (code quality + security), Lucian (plan fidelity).
- **QA:** Akali (Playwright + screenshot narrative — no Figma diff, per the project's lack of Figma-Ref).
- **Deploy:** Ekko (DevOps execution) under Heimerdinger advisory.

The above is authorship guidance only — Sona makes the actual delegation calls per Rule "Plan writers never assign implementers" in `agents/sona/CLAUDE.md`.

## Approval gate

This plan moves from `plans/proposed/work/` → `plans/approved/work/` via Orianna once Duong approves. Promotion is a single Orianna invocation; no other agent moves the file.

## Orianna approval

- **Date:** 2026-04-28
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Structural gates (qa_plan frontmatter, qa_plan body sub-headings, §UX Spec linter with valid `ux_waiver`) all pass on pass 3. Plan has clear owner (swain), explicit cherry-pick set (§D2) and drop-set (§D3), strictly-new code enumerated (§D4) with xfail-first commitment per Rule 12, explicit PR #32 disposition (§D6), and concrete §QA Plan covering happy-path Playwright RUNWAY, failure-mode smoke, and the full Rule-17 stg+prod evidence chain. Risks honestly flag the empirical unknowns of first-prod real-S3 invocation. Tasks T1–T18 are actionable.

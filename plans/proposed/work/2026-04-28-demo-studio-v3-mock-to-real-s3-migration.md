---
slug: demo-studio-v3-mock-to-real-s3-migration
title: "Demo Studio v3 — migrate S1 from mock-factory to real S3 on a fresh branch off main"
project: bring-demo-studio-live-e2e-v1
concern: work
status: proposed
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

### Happy path (Akali Playwright RUNWAY — full DoD walk)

1. Akali signs in via Google (`@missmp.eu` test account); lands in studio shell. (DoD step 1)
2. Akali clicks "New session"; lands in `/session/{sid}` with the seeded default config greeting and a live preview iframe attached. (DoD steps 2–3)
3. Akali types: "make the brand AXA Germany". Agent calls `set_config` (canonical save). UI: green toast "Config saved as v2"; preview iframe refreshes to AXA branding. (DoD steps 4–5; cherry-picked from ADR-3 / ADR-4 — visual delta is identical.)
4. Akali clicks the **deployBtn** ("Build project"). UI shows the build progress bar incrementing through the S3 step taxonomy in real time — and the times between steps are **multi-second to multi-minute**, not 10ms-fake. This is the empirical signal that the real S3 is now being called. (DoD steps 6–7)
5. Build completes. Chat receives an agent message announcing completion; UI state changes to "verifying". (DoD step 8)
6. Verify auto-fires (S3 → S4 API call, no agent intervention). UI shows verify progress bar. (DoD steps 9–10)
7. Verify completes. Agent narrates the result, the project ID, and the demo link in chat. UI shows the demo link as a clickable element. (DoD step 11)
8. Akali clicks the demo link; opens to a live, working demo URL backed by real Wallet Studio artifacts. (Validates that the URL is real, not a mock-invented placeholder.)

### Failure-mode walk (smoke-shaped, not full Playwright)

These are exercised by Vi (test execution) against a stg deploy before the prod cutover:

- Factory unreachable: stg `FACTORY_V3_BASE_URL` temporarily pointed at a 127.0.0.1:nonexistent. Click deployBtn → red error toast within ~2s; session state is `failed`, not stuck `building`.
- Factory rejects request (synthesized 400 from a stub): UI shows the structured error; session state `failed`.
- Watchdog: a session is poked into `status=building, lastBuildAt=<now-30min>` via a debug endpoint; next `GET /session/{sid}` flips it to `failed` and allows a fresh build trigger.

### Non-UI verification

(Per Rule 16 non-UI branch shape — even though this PR has UI involvement, the backend SSE plumbing benefits from a non-UI smoke too):

- `curl -N <stg S1>/session/<test-sid>/build` against a test session: receives an SSE stream with the expected event taxonomy (`step_start`, `step_complete`, ..., `build_complete`).
- Cloud Run logs on `demo-studio-factory` show inbound traffic from `demo-studio` (S1) for the first time in production.

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

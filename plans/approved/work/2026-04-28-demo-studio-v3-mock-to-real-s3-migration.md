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

### Bite-sized breakdown (T<N>.<step>)

Aphelios breakdown — 2026-04-28. Granular task list executable by Viktor (impl) and Rakan (xfail authoring) against the working repo `~/Documents/Work/mmp/workspace/company-os-w3-impl/` on branch `feat/demo-studio-v3-clean` cut off `origin/main` (`d835ade`). Each task is ≤60 minutes, has explicit DoD, and tags `parallel_slice_candidate` per the slicing rules. Rule-12 ordering is honored per pair: every Viktor impl commit is preceded on the same branch by the matching Rakan xfail commit.

**Phase A — Branch creation and base sanity (T1 expansion)**

- [ ] **T1.1** — Cut fresh branch off `origin/main`. estimate_minutes: 5. Files: working repo only. DoD: `git fetch origin && git worktree add ../w3-feat-demo-studio-v3-clean -b feat/demo-studio-v3-clean origin/main` succeeds; `git rev-parse HEAD` matches `d835ade` (or current `origin/main` HEAD if main has advanced since plan approval — record the actual HEAD in a commit comment). parallel_slice_candidate: no.
- [ ] **T1.2** — Baseline test sanity on the fresh branch. estimate_minutes: 10. Files: `tools/demo-studio-v3/tests/` (likely empty on main). DoD: `pytest tools/demo-studio-v3/tests/ -q` runs cleanly (zero collected or all green); `pytest tools/demo-studio-factory/tests/ -q` (S3 Go service tests, if reachable from this repo) is recorded as out-of-scope baseline. Capture output to commit comment. parallel_slice_candidate: no.
- [ ] **T1.3** — Push branch and open draft PR. estimate_minutes: 10. Files: PR body only (no repo files). DoD: `git push -u origin feat/demo-studio-v3-clean`; `gh pr create --draft --base main --head feat/demo-studio-v3-clean --title "feat(demo-studio-v3): mock-to-real-S3 migration on a fresh branch off main" --body <link to plan + skeleton checklist of T1.1–T18>`; PR URL recorded in plan as `pr_url:` frontmatter (post-merge). parallel_slice_candidate: no.

**Phase B — Cherry-pick the real subsystems (T2–T7 expansion)**

Phase B is strictly serial — cherry-picks all land on the same branch and conflict on `main.py`, `tests/`, and `static/`. Do NOT parallelize.

- [ ] **T2.1** — Discover the agent-UX commit set on `feat/demo-studio-v3`. estimate_minutes: 30. Files: none (read-only `git log`). DoD: `git log --first-parent feat/demo-studio-v3 -- tools/demo-studio-v3/agent_proxy.py tools/demo-studio-v3/tool_dispatch.py tools/demo-studio-v3/stream_translator.py tools/demo-studio-v3/setup_agent.py` enumerated; merge-base with main identified; commit SHA list (chronological) saved to `agents/viktor/memory/last-sessions/2026-04-28-cherrypick-agent-ux-commits.md` for traceability. Verify PR #128, #129, #131, #132 SHAs are in the set. parallel_slice_candidate: no.
- [ ] **T2.2** — Cherry-pick the agent-UX antecedent commits (pre-PR-#128). estimate_minutes: 45. Files: `tools/demo-studio-v3/{agent_proxy,tool_dispatch,stream_translator,setup_agent}.py` and adjacent test files. DoD: `git cherry-pick <sha-range>` succeeds or all conflicts resolved in favor of latest `feat/demo-studio-v3` state; `pytest tools/demo-studio-v3/tests/test_agent_proxy.py` etc. green or xfail as on source. parallel_slice_candidate: no.
- [ ] **T2.3** — Cherry-pick PR #128 (ADR-3 fail-loud seed + TX1/TX2 green). estimate_minutes: 30. Files: per the PR's diff. DoD: cherry-pick clean; PR-128 tests green on the new branch. parallel_slice_candidate: no.
- [ ] **T2.4** — Cherry-pick PR #129 (drop `_vanilla_session_configs` cache + initial_config system-message injection). estimate_minutes: 30. Files: per PR diff. DoD: cherry-pick clean; PR-129 tests green. parallel_slice_candidate: no.
- [ ] **T2.5** — Cherry-pick PR #131 (ADR-4 T-impl-ui — config-save toast surface). estimate_minutes: 30. Files: `tools/demo-studio-v3/static/*` (toast UI), `tools/demo-studio-v3/main.py` (toast wiring). DoD: cherry-pick clean; PR-131 tests green; static asset diff sanity-checked (no dashboard files). parallel_slice_candidate: no.
- [ ] **T2.6** — Cherry-pick PR #132 (ADR-4 set_config error framing, dispatch traceability, force-retry deletion). estimate_minutes: 30. Files: per PR diff. DoD: cherry-pick clean; PR-132 tests green. parallel_slice_candidate: no.
- [ ] **T2.7** — Run agent-UX test suite as a Phase-B.T2 gate. estimate_minutes: 15. Files: tests only. DoD: `pytest tools/demo-studio-v3/tests/ -q -k 'agent or proxy or dispatch or stream or setup'` green; commit a `chore(cherrypick): agent-ux subsystem gate green` marker commit if any housekeeping applied. parallel_slice_candidate: no.
- [ ] **T3.1** — Discover and cherry-pick S2-client antecedent commits. estimate_minutes: 30. Files: `tools/demo-studio-v3/config_mgmt_client.py` + tests. DoD: `git log --first-parent feat/demo-studio-v3 -- tools/demo-studio-v3/config_mgmt_client.py` enumerated; antecedent commits cherry-picked clean. parallel_slice_candidate: no.
- [ ] **T3.2** — Cherry-pick PR #126 (`_handle_error` for HTTP 422). estimate_minutes: 20. Files: per PR diff. DoD: cherry-pick clean; PR-126 tests green; `pytest tools/demo-studio-v3/tests/test_config_mgmt_client.py -q` green. parallel_slice_candidate: no.
- [ ] **T4.1** — Cherry-pick S1-side schema-endpoint consumer (PR #130 + antecedents). estimate_minutes: 45. Files: `tools/demo-studio-v3/schema_client.py` (or canonical name) + `_handle_set_config` validation in `main.py` + session-boot schema fetch. DoD: `git log --first-parent feat/demo-studio-v3 -- tools/demo-studio-v3/schema_client.py tools/demo-studio-v3/main.py` filtered to schema-relevant SHAs; cherry-picks clean; schema-endpoint tests green; sanity check that `/v1/schema` URL points at S2 not at any in-tree mock. parallel_slice_candidate: no.
- [ ] **T5.1** — Discover and cherry-pick auth subsystem (Firebase Auth boot + `missmp.eu` allowlist + session cookie). estimate_minutes: 45. Files: `tools/demo-studio-v3/auth/*`, `tools/demo-studio-v3/main.py` (auth wiring), `tools/demo-studio-v3/static/*` (sign-in UI). DoD: `git log --first-parent feat/demo-studio-v3 -- tools/demo-studio-v3/auth/` enumerated; cherry-picks clean; sign-in tests green; allowlist enforcement test passes for `@missmp.eu` and rejects others. parallel_slice_candidate: no.
- [ ] **T5.2** — Cherry-pick PR #127 (deployBtn dual-auth + `trigger_factory` removal). estimate_minutes: 30. Files: per PR diff. DoD: cherry-pick clean; PR-127 tests green; **explicit verification** that `trigger_factory` agent-tool removal is preserved (it is intentionally KEPT per §D3 Note). parallel_slice_candidate: no.
- [ ] **T6.1** — Cherry-pick preview iframe subsystem with explicit dashboard exclusion. estimate_minutes: 60. Files: `tools/demo-studio-v3/static/preview/*`, `tools/demo-studio-v3/templates/preview*`, `tools/demo-studio-v3/main.py` (iframe route), S2-driven refresh wiring. DoD: cherry-picks clean; **on every conflict where a hunk touches dashboard code, the dashboard side is dropped** (record each dashboard-strip in commit message); preview-iframe tests green; `find tools/demo-studio-v3 -iname '*dashboard*'` returns zero results. parallel_slice_candidate: no.
- [ ] **T7.1** — Cherry-pick PR #133 (`.gcloudignore`) if still relevant. estimate_minutes: 15. Files: `.gcloudignore` at repo root or `tools/demo-studio-v3/.gcloudignore`. DoD: implementer judgment per §D2.6 — if the post-cherry-pick deploy script still uses `gcloud source` upload, cherry-pick lands; otherwise skip with a `chore: skip PR #133 cherry-pick — deploy no longer uses gcloud source` note in the PR body. parallel_slice_candidate: no.

**Phase C — Defensive drop sweep (T8 expansion)**

- [ ] **T8.1** — Grep for surviving mock-dep symbols. estimate_minutes: 10. Files: read-only grep across `tools/demo-studio-v3/`. DoD: `grep -rn 'factory_client_v2\|factory_bridge_v2\|S4_VERIFY_URL' tools/demo-studio-v3/` returns the exhaustive list of leftovers; output captured to T8.2's commit body. parallel_slice_candidate: no.
- [ ] **T8.2** — Delete surviving mock-dep surfaces. estimate_minutes: 30. Files: `tools/demo-studio-v3/factory_client_v2.py`, `tools/demo-studio-v3/factory_bridge_v2.py`, S4-poller block in `main.py`, `S4_VERIFY_URL` references in `main.py` + deploy manifest. DoD: each file removed via `git rm`; in-place edits to `main.py` strip the S4-poller block and `S4_VERIFY_URL` references; `grep` from T8.1 now returns zero matches; commit `chore: drop mock-dep surfaces (factory_client_v2, factory_bridge_v2, S4 poller, S4_VERIFY_URL)`. parallel_slice_candidate: no.
- [ ] **T8.3** — Verify dashboard exclusion holds. estimate_minutes: 5. Files: read-only. DoD: `find tools/demo-studio-v3 -iname '*dashboard*'` returns zero results; `grep -rni 'dashboard' tools/demo-studio-v3/` returns zero matches in code (matches in unrelated comments — implementer judgment to leave or strip). parallel_slice_candidate: no.

**Phase D — xfail-first new code (T9 expansion, Rakan)**

Per Rule 12, every xfail commit in this phase MUST land on the branch BEFORE the matching Viktor impl commit in Phase E. Within Phase D, the three sub-suites (D.1 factory_client_v3, D.2 build_handler_v3, D.3 watchdog) can be authored in parallel by Rakan if she chooses — they touch independent test files. The shared T9.0 reconnaissance task is a hard prerequisite for D.1 and D.2.

- [ ] **T9.0** — Reconnaissance: read `tools/demo-studio-factory/` Go source on `origin/main` to confirm SSE event names, payload shapes, and S3→S4 trigger contract. estimate_minutes: 45. Files: read-only across `tools/demo-studio-factory/`. DoD: confirmed event taxonomy (`step_start`, `step_complete`, `step_failed`, `build_complete`, `build_failed`, `error` — or actual names if different) recorded in `agents/rakan/memory/last-sessions/2026-04-28-s3-sse-contract-recon.md`; resolution of OQ "S3→S4 multiplexed-or-separate channel" recorded; resolution of OQ "exact SSE event names" recorded. **Blocks T9.1, T9.2, T9.4, T9.5, T9.6.** parallel_slice_candidate: no.
- [ ] **T9.1** — Capture SSE replay fixtures from a live `demo-studio-factory` invocation against a stg session. estimate_minutes: 60. Files: `tools/demo-studio-v3/tests/fixtures/factory_v3_sse_replay/{happy_path,step_failed,build_failed}.txt`. DoD: three replay files exist; each is a verbatim capture of `curl -N <stg-factory-url>/build` for a representative case; happy_path covers all 10 canonical steps; step_failed truncates at a representative mid-stream failure; build_failed terminates on the build-level failure event. Commit `chore(test-fixtures): capture S3 SSE replay corpus for factory_client_v3`. parallel_slice_candidate: no.
- [ ] **T9.2** — Author xfail tests for `factory_client_v3` happy-path SSE handshake. estimate_minutes: 45. Files: `tools/demo-studio-v3/tests/test_factory_client_v3.py`. DoD: test file imports a not-yet-existing `factory_client_v3` module; uses `pytest.mark.xfail(reason="impl pending — plan 2026-04-28-demo-studio-v3-mock-to-real-s3-migration §D4.1")`; covers happy-path replay → all events translated to S1's internal event schema; `pytest -q` shows the test in xfail. Commit `test(xfail): factory_client_v3 happy-path SSE handshake`. parallel_slice_candidate: yes.
- [ ] **T9.3** — Author xfail tests for `factory_client_v3` error envelopes. estimate_minutes: 45. Files: `tools/demo-studio-v3/tests/test_factory_client_v3.py` (append). DoD: xfail tests added for: (a) `step_failed` → session state `failed`, no further events processed; (b) factory unreachable (mocked connection refused / DNS failure) → 503 to client, session `failed`; (c) invalid request (missing `config`, malformed `session_id`) → 400, session not transitioned. Per-suite xfail markers; `pytest -q` shows tests in xfail. Commit `test(xfail): factory_client_v3 error envelopes (D5 happy-path scope)`. parallel_slice_candidate: yes.
- [ ] **T9.4** — Author xfail tests for new `/build` handler routing to `factory_client_v3`. estimate_minutes: 45. Files: `tools/demo-studio-v3/tests/test_build_handler_v3.py`. DoD: xfail tests cover: (a) `POST /session/{sid}/build` with valid auth + config → factory_client_v3 invoked once with the resolved config; (b) dual-auth gate (session cookie OR Firebase ID token); (c) idempotency 409 when `lastBuildAt < N seconds` AND `status == "building"`; (d) absence of `factory_client_v2` reference in handler call graph. xfail markers reference §D4.2; `pytest -q` shows tests in xfail. Commit `test(xfail): /build handler v3 routing + idempotency`. parallel_slice_candidate: yes.
- [ ] **T9.5** — Author xfail tests for stale-`lastBuildAt` watchdog. estimate_minutes: 45. Files: `tools/demo-studio-v3/tests/test_lastbuildat_watchdog.py`. DoD: xfail tests cover: (a) synthesized `status=building, lastBuildAt=<now-30min>` session → `GET /session/{sid}` flips to `status=failed, failure_reason="build_pipeline_timeout"`; (b) subsequent `POST /build` accepted (no 409); (c) non-stale in-flight session NOT disturbed (timeout default 15min from §D4.3 honored); (d) configurable timeout via env or settings. xfail markers reference §D4.3; `pytest -q` shows tests in xfail. Commit `test(xfail): stale-lastBuildAt watchdog`. parallel_slice_candidate: yes.
- [ ] **T9.6** — Push the Phase-D xfail commits to origin and verify TDD gate is happy. estimate_minutes: 10. Files: none (push only). DoD: `git push origin feat/demo-studio-v3-clean`; pre-push hook passes (TDD gate sees xfails in place); CI `tdd-gate.yml` green for the head commit. parallel_slice_candidate: no.

**Phase E — Implement new code (T10–T12 expansion, Viktor)**

Per Rule 12, this phase begins ONLY after Phase D is fully pushed. Within Phase E, T10/T11/T12 are sequential because they share `main.py` and the new client module.

- [ ] **T10.1** — Implement `factory_client_v3` SSE client skeleton. estimate_minutes: 60. Files: `tools/demo-studio-v3/factory_client_v3.py` (created). DoD: module exposes `FactoryClientV3` class with `__init__(base_url)` + async `build(session_id, config) -> AsyncIterator[InternalEvent]`; SSE wire-up uses `httpx`/`aiohttp` consistent with the existing `config_mgmt_client.py` style; emits a placeholder `InternalEvent` per SSE chunk; `pytest tools/demo-studio-v3/tests/test_factory_client_v3.py -q -k happy` de-xfails (now passes). Commit `feat(demo-studio-v3): factory_client_v3 SSE client skeleton (de-xfails T9.2)`. parallel_slice_candidate: no.
- [ ] **T10.2** — Implement event-translation layer (S3 SSE → S1 internal event schema). estimate_minutes: 45. Files: `tools/demo-studio-v3/factory_client_v3.py` (extend) + possibly `stream_translator.py` (extend if reused). DoD: each S3 SSE event name (per T9.0 reconnaissance) maps to S1's existing internal event schema bit-compatible with the cherry-picked progress-bar UI; happy-path replay test still green; cross-checked manually against one fixture chunk. Commit `feat(demo-studio-v3): factory_client_v3 event translation (S3 SSE → S1 internal schema)`. parallel_slice_candidate: no.
- [ ] **T10.3** — Implement error-envelope handling in `factory_client_v3`. estimate_minutes: 45. Files: `tools/demo-studio-v3/factory_client_v3.py` (extend). DoD: `step_failed` raises a typed exception caught by `/build` handler → session `failed`; connection-refused / DNS failure surfaces as a typed `FactoryUnreachable`; invalid request raises `FactoryRequestInvalid`; `pytest tools/demo-studio-v3/tests/test_factory_client_v3.py -q` fully green (all xfails de-xfailed). Commit `feat(demo-studio-v3): factory_client_v3 error envelopes (de-xfails T9.3)`. parallel_slice_candidate: no.
- [ ] **T11.1** — Replace `/session/{sid}/build` handler body in `main.py`. estimate_minutes: 60. Files: `tools/demo-studio-v3/main.py` (modify). DoD: handler instantiates `FactoryClientV3` with `os.environ["FACTORY_V3_BASE_URL"]`; preserves dual-auth (session cookie OR Firebase ID token per PR #127); rejects with 409 when idempotency guard fires; rejects with 400 on missing/malformed payload; surfaces 503 on `FactoryUnreachable`; streams the translated events back to the SSE consumer; **no reference to `factory_client_v2` or `factory_bridge_v2` survives**. `pytest tools/demo-studio-v3/tests/test_build_handler_v3.py -q` fully green (all T9.4 xfails de-xfailed). Commit `feat(demo-studio-v3): /build handler routes to factory_client_v3 (de-xfails T9.4)`. parallel_slice_candidate: no.
- [ ] **T12.1** — Implement watchdog: stale-`lastBuildAt` detection on `GET /session/{sid}`. estimate_minutes: 45. Files: `tools/demo-studio-v3/main.py` (extend `GET /session/{sid}` handler) + new helper `tools/demo-studio-v3/watchdog.py` if needed for testability. DoD: `BUILD_PIPELINE_TIMEOUT_SECONDS` (default 900 = 15 min) read from env; `GET /session/{sid}` flips a stale `building` session to `failed` with `failure_reason="build_pipeline_timeout"`; non-stale in-flight sessions untouched; `pytest tools/demo-studio-v3/tests/test_lastbuildat_watchdog.py -q` fully green (all T9.5 xfails de-xfailed). Commit `feat(demo-studio-v3): stale-lastBuildAt watchdog (de-xfails T9.5)`. parallel_slice_candidate: no.
- [ ] **T12.2** — Allow watchdog-`failed` session to accept a fresh `POST /build`. estimate_minutes: 20. Files: `tools/demo-studio-v3/main.py` (idempotency guard tweak). DoD: idempotency guard distinguishes `failed` (allow new build) from `building` (reject 409); the T9.5(b) xfail-de-xfailed test path is still green; commit `feat(demo-studio-v3): allow rebuild after watchdog timeout`. parallel_slice_candidate: no.

**Phase F — Deploy + project-doc + final wiring (T13–T14)**

- [ ] **T13.1** — Update deploy manifest to use `FACTORY_V3_BASE_URL`. estimate_minutes: 20. Files: `tools/demo-studio-v3/deploy/cloudrun.yaml` (or actual manifest path), `tools/demo-studio-v3/Makefile` if it references the env var, `.env.example`. DoD: `FACTORY_BASE_URL` removed; `FACTORY_V3_BASE_URL=https://demo-studio-factory-4nvufhmjiq-ew.a.run.app` (or canonical Cloud Run URL — verify via `gcloud run services describe demo-studio-factory --region=europe-west1 --format='value(status.url)'`); `S4_VERIFY_URL` removed; `grep -rn 'FACTORY_BASE_URL\|S4_VERIFY_URL' tools/demo-studio-v3/` returns zero matches. Commit `ops: deploy manifest — FACTORY_V3_BASE_URL (real S3) + drop FACTORY_BASE_URL/S4_VERIFY_URL`. parallel_slice_candidate: no.
- [ ] **T14.1** — Project-doc one-liner per §D6. estimate_minutes: 10. Files: `projects/work/active/bring-demo-studio-live-e2e-v1.md` (Edit only). DoD: §Decisions / 2026-04-27 ADR-sequencing block updated with a one-line note "Superseded 2026-04-28 by plan `2026-04-28-demo-studio-v3-mock-to-real-s3-migration`: PR #32 closes without merge; new PR replaces it." Commit `chore: project-doc — note PR #32 disposition supersession (plan 2026-04-28)`. parallel_slice_candidate: no.

**Phase G — QA + review + deploy + close (T15–T18)**

- [ ] **T15.1** — Akali full Playwright RUNWAY against stg deploy. estimate_minutes: 60. Files: `assessments/qa-reports/2026-04-28-demo-studio-v3-mock-to-real-s3-migration.md` + paired `.mp4`. DoD: per §QA Plan happy-path steps 1–8; per-screenshot observation narrative ("what was checked, observed vs expected, pass/fail"); axe-core run output captured under `Accessibility-Check:`; report linked from PR body via `QA-Report:` marker per Rule 16. parallel_slice_candidate: wait-bound.
- [ ] **T15.2** — Akali failure-mode smoke (Vi shadowing): factory unreachable + 400 + watchdog stale. estimate_minutes: 45. Files: same QA report (append §Failure modes). DoD: stg `FACTORY_V3_BASE_URL` temporarily pointed at `127.0.0.1:1` → red error toast within ~2s; synthesized 400 → structured error; debug-poked stale session → flips to `failed` and accepts fresh build trigger. parallel_slice_candidate: no.
- [ ] **T16.1** — Senna code-quality + security review (PR review identity). estimate_minutes: 45. Files: PR comment (no repo files). DoD: Senna reviews diff; verdict APPROVE or REQUEST_CHANGES posted as PR review under `strawberry-reviewers` identity; cycle bounded ≤3 rounds per Rule 18. parallel_slice_candidate: yes.
- [ ] **T16.2** — Lucian plan-fidelity review. estimate_minutes: 45. Files: PR comment. DoD: Lucian verifies §D2 cherry-pick set is exhaustive and §D3 drop set is fully removed (`grep` against branch); §D4 new code matches the plan's contract; verdict APPROVE or REQUEST_CHANGES posted under `strawberry-reviewers-2`. parallel_slice_candidate: yes.
- [ ] **T17.1** — Mark draft PR ready and merge to main. estimate_minutes: 15. Files: PR state only. DoD: all required CI checks green (`e2e.yml`, `tdd-gate.yml`, `pr-lint.yml`); both reviewer approvals from non-author identities present; `gh pr ready <num>`; `gh pr merge <num> --merge`; main HEAD now contains the merge commit. parallel_slice_candidate: no.
- [ ] **T17.2** — Stg redeploy + smoke. estimate_minutes: 30. Files: deploy manifest only (no edits — re-trigger). DoD: Cloud Build / deploy pipeline rolls a new revision of `demo-studio` on stg pointed at `FACTORY_V3_BASE_URL`; Cloud Run inbound-traffic log line on `demo-studio-factory` confirms first SSE request from S1; `curl -N <stg-S1>/session/<test-sid>/build` returns the expected event taxonomy. Evidence captured to QA report. parallel_slice_candidate: wait-bound.
- [ ] **T17.3** — Prod deploy + smoke per Rule 17. estimate_minutes: 30. Files: deploy manifest re-trigger. DoD: Cloud Run rolls new prod revision of `demo-studio`; Akali runs one prod-smoke pass; QA report `-prod` suffix variant produced under `assessments/qa-reports/`. **On prod-smoke failure: `scripts/deploy/rollback.sh` triggers per Rule 17 and a follow-up incident plan opens.** parallel_slice_candidate: wait-bound.
- [ ] **T18.1** — Close PR #32. estimate_minutes: 10. Files: GitHub PR state only. DoD: `gh pr close 32 --repo missmp/company-os --comment "Superseded by PR #<this-pr-num> per plan plans/approved/work/2026-04-28-demo-studio-v3-mock-to-real-s3-migration.md §D6 — keepable subsystems carried forward via cherry-pick (§D2), mock-dep surfaces dropped (§D3). Branch feat/demo-studio-v3 preserved as historical artifact."`; PR #32 state is CLOSED (not MERGED); branch `feat/demo-studio-v3` retained on origin per §D6. parallel_slice_candidate: no.

**Dependency summary (Rule-12 ordering and phase gates)**

- Phase A blocks all later phases.
- Phase B is strictly serial (cherry-picks share files); blocks Phase C.
- Phase C (drop sweep) gates Phase D.
- Phase D xfail commits MUST land before the matching Phase E impl commit per Rule 12: T9.2/T9.3 → T10.1/T10.2/T10.3; T9.4 → T11.1; T9.5 → T12.1/T12.2.
- Phase E blocks Phase F (deploy manifest references new env var; project-doc edit happens after impl is real).
- Phase F blocks Phase G.
- Within Phase G: T15 happens before T16 (reviewers want QA evidence); T16 blocks T17.1; T17.1 blocks T17.2; T17.2 blocks T17.3; T17.3 blocks T18.1 (Plan 1 PR must be merged + prod-smoke green BEFORE PR #32 closes per §D6).

**Open questions surfaced during breakdown (OQ-A1..OQ-A4)**

- OQ-A1 — exact `gcloud source` deploy-script status post-cherry-pick (decides T7.1 cherry-pick of PR #133). Resolved during T7.1 by inspecting the actual deploy script on the new branch.
- OQ-A2 — confirmed canonical Cloud Run URL for `demo-studio-factory` for T13.1 manifest update. Resolved by `gcloud run services describe demo-studio-factory --region=europe-west1 --format='value(status.url)'` at T13.1 time.
- OQ-A3 — exact SSE event names emitted by `demo-studio-factory` (mirrors plan-§OpenQs item 1). Resolved at T9.0.
- OQ-A4 — multiplexing of S3→S4 progress on the same SSE channel vs. a separate one (mirrors plan-§OpenQs item 2). Resolved at T9.0.

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

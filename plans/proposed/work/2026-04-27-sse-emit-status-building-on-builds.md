---
plan_id: 2026-04-27-sse-emit-status-building-on-builds
title: SSE /session/{id}/stream must emit `status: building` during builds
owner: karma
tier: quick
complexity: normal
concern: work
project: bring-demo-studio-live-e2e-v1
status: proposed
orianna_gate_version: 2
tests_required: true
qa_plan: inline
priority: P0
last_reviewed: 2026-04-27
created: 2026-04-27
---

## Why

ADR-1 (Build Progress Bar) is QA-blocked at Akali run #7 with FAIL category `progress-bar-never-mounts`. The frontend bar component is wired correctly (CP1 PASS, `window.buildProgress.{applyEvent,mount,unmount,seed}` loaded; `mountBuildProgress()` correctly listens for `data.status === 'building'` on both `connected` and `status` SSE events in `static/studio.js` lines 1185-1238). The polling channel (`/build-status`) works — phase stepper advances CONFIGURE→BUILD→TWEAK during a real build cycle. **The SSE channel `/session/{id}/stream` is silent on the building transition.**

Akali evidence (run #7, `demo-studio-00036-lgn`, build `build-850a49e3154a`, project `proj-262625720d66`):
- DOM MutationObserver caught zero `.build-progress-bar` insertions over a ~3-min real build
- `EventSource('/session/{sid}/stream')` opened post-build → `connected` event timed out after 10s
- `[data-phase]` wrapper stayed at `"configure"` — `setPhase('build')` never called from SSE handler

QA report: `assessments/qa-reports/2026-04-27-adr-1-build-progress-bar-rev00036-lgn-run7.md`

## Root cause

The demo-studio UI uses the **vanilla SSE path** (no `managedSessionId` set on session creation — see `main.py` line 2027-2030). The vanilla branch in `session_stream` (`main.py` lines 3229-3251) does **two** things wrong for the build use case:

1. **No `connected` seed event.** It immediately blocks on `await sse_queue.get()` — never emits the `connected` frame the frontend `addEventListener('connected', ...)` handler depends on (line 1185 in `studio.js`). Result: `EventSource` opens, server never sends a connect-level frame, frontend's `connected` handler — which holds the seed branch with `mountBuildProgress()` (line 1190-1197) — never fires.
2. **No status-change broadcasting.** The vanilla queue is fed only by `_run_vanilla_turn` (chat turns). When `POST /build/start` calls `transition_session_status(session_id, 'configuring', 'building')` (line 2679) and then `factory_bridge_v2.trigger_factory_v2(...)` (line 2737), **nothing writes a status frame into `_vanilla_sse_queues[session_id]`**. The managed branch's `_poll_stream` (lines 3253-3320) does poll session status every 2s and emits a `status` event on change (lines 3303-3306) — vanilla has no equivalent.

So even though `/build-status` (HTTP one-shot) correctly reports `building`, the persistent SSE stream is structurally incapable of pushing the transition to the browser.

## Approach

Bring the vanilla SSE generator to feature-parity with the managed `_poll_stream` for the status-frame surface only. Two minimal changes scoped to `_vanilla_sse_generator`:

1. **Emit `connected` seed frame** as the first yield, carrying current `{sessionId, status, phase}`. Mirrors the managed branch's line 3259. This makes mid-build reconnects hydrate the bar instantly.
2. **Add a status-change poller** that runs concurrently with the chat-queue drain. On every tick (2s), re-fetch session via `get_session(session_id)`; if `status` changed since `last_status`, emit a `status` SSE frame with `{status, phase}`. Mirrors managed lines 3303-3306.

Implementation shape: replace the `while True: item = await sse_queue.get()` blocking loop with an `asyncio.wait` on two coroutines — `sse_queue.get()` and a 2s ticker that polls session status — so the generator yields chat-queue events AND status frames as they arrive. On disconnect (`request.is_disconnected()`), exit cleanly.

Estimated diff: ~30-40 lines in `main.py` `_vanilla_sse_generator` block (lines 3229-3251), no other modules touched. No frontend changes (event names already match). No schema changes.

### Why this is the right shape

- The frontend already handles both `connected` and `status` events correctly with identical `data.status === 'building'` branches. Backend is the only side missing the emission.
- The fix is symmetric with the managed branch — same polling cadence (2s), same event frame shape — so future consolidation between vanilla and managed SSE generators is unblocked.
- No new state, no new endpoints, no new database fields. The session doc already carries `status` and `phase` (set by `transition_session_status` and `/build/start` respectively).

### Considered and rejected

- **Push-based hook from `transition_session_status`**: would require wiring a session→queue map and writing into the queue at every status-transition site. More invasive (touches `session_store.py`, every `/build/start`, `/stop-build`, and factory-callback path). 2s poll is sufficient for a progress-bar UX (the bar mounts within 2s of build start; subsequent step updates flow through the existing `/build-status` poll path, not SSE).
- **Frontend falls back to `/build-status` polling on connected timeout**: defeats the purpose of having an SSE stream and adds a second source of truth. Backend is broken; fix the backend.

## Tasks

### T1: Add xfail integration test for vanilla SSE status-building emission [kind: test, estimate_minutes: 30, parallel_slice_candidate: true]

- **Files:** `tools/demo-studio-v3/tests/test_sse_status_building.py` (new). <!-- orianna: ok -->
- **Detail:** Pytest async test using `httpx.AsyncClient` + FastAPI test app. Setup: create a vanilla session (no managedSessionId), assert it lands in `configuring`. Open `EventSource`-equivalent (httpx streaming GET) against `/session/{sid}/stream`. Assert (a) within 5s a `connected` SSE frame arrives with `status` field present, (b) after `transition_session_status(sid, "configuring", "building")` is called (synthetic, no real factory trigger), within 5s a `status` SSE frame arrives whose JSON payload has `status: "building"`. Mark `@pytest.mark.xfail(strict=True, reason="2026-04-27-sse-emit-status-building-on-builds T2 not yet implemented")`.
- **DoD:** Test commits before T2. Runs red (xfail) on `feat/adr-1-build-progress-bar` HEAD. Plan ID referenced in xfail reason per Strawberry Rule 12.

### T2: Implement `connected` seed + status-poll in `_vanilla_sse_generator` [kind: code, estimate_minutes: 60]

- **Files:** `tools/demo-studio-v3/main.py` (edit `_vanilla_sse_generator` at lines ~3229-3251).
- **Detail:**
  1. As the first yield in `_vanilla_sse_generator`, emit `f"event: connected\ndata: {json.dumps({'sessionId': session_id, 'status': session.get('status', 'unknown'), 'phase': session.get('phase', '')})}\n\n"`.
  2. Replace the blocking `await sse_queue.get()` loop with concurrent waits: use `asyncio.wait({queue_task, ticker_task}, return_when=FIRST_COMPLETED)` where `queue_task = asyncio.create_task(sse_queue.get())` and the ticker is a 2s sleep. After each tick, re-`get_session(session_id)`, compare `status`/`phase` to a `last_status`/`last_phase` local; if changed, yield `event: status\ndata: {json.dumps({'status': current_status, 'phase': current_phase})}\n\n`. Cancel pending tasks at end of iteration to avoid leaks.
  3. Honor `request.is_disconnected()` between iterations to exit cleanly (mirrors managed path lines 3265, 3308).
  4. Preserve existing chat-queue drain semantics: when `sse_queue.get()` returns `None`, break (end-of-turn sentinel); when it returns `(event, data)`, yield as before.
- **DoD:** T1 flips from xfail to pass. No regression in `test_chat_sse_handshake.py`, `test_sse_relay.py`, `test_sse_reconnect_persistence.py`, `test_sse_route_rewire.py`. Manual smoke: open studio in browser, click Generate, observe `.build-progress-bar` mount within ~2s of `/build/start` returning.
- **Remove the xfail marker** in T1's test file as the final edit.

### T3: Re-deploy and re-run Akali QA [kind: ops, estimate_minutes: 15]

- **Files:** none (deploy via existing `tools/demo-studio-v3/deploy.sh` or PR-merge auto-deploy path).
- **Detail:** After T1+T2 PR merges and `demo-studio-v3` redeploys, instruct Akali to re-run the ADR-1 Build Progress Bar QA flow against the new revision. Akali's check matrix: (a) DOM MutationObserver catches `.build-progress-bar` insertion within 5s of clicking Generate, (b) `connected` SSE frame arrives within 2s of EventSource open, (c) `[data-phase]` wrapper transitions to `"build"` within 5s of `/build/start` returning, (d) progress steps advance as `/build-status` polls report new `step` values.
- **DoD:** Akali QA report PASS for `progress-bar-never-mounts` category. Linked in PR body via `QA-Report:` line per Strawberry Rule 16.

## QA Plan

**Invariants protected:**
1. **SSE seed frame on connect** — every `EventSource` open against `/session/{id}/stream` for a vanilla session receives a `connected` event within 2s carrying current `{sessionId, status, phase}`. Without this, mid-build reconnects can never hydrate the progress bar.
2. **SSE status-change emission** — when a vanilla session's `status` field transitions (e.g. `configuring`→`building`, `building`→`complete`/`failed`), a `status` SSE frame is pushed within 2s. Without this, the persistent stream and the session-doc state diverge.

**Test surface:**
- `test_sse_status_building.py::test_connected_seed_frame_emitted` — open stream, assert `connected` frame with `status` field arrives within 5s.
- `test_sse_status_building.py::test_status_building_emitted_on_transition` — open stream, fire `transition_session_status(sid, "configuring", "building")`, assert `status` frame with `status: "building"` arrives within 5s.
- (optional) `test_sse_status_building.py::test_status_complete_emitted_on_transition` — same shape, building→complete. Not strictly required for ADR-1 unblock but cheap to add and protects the same invariant on the terminal side.

**Re-run instruction for Akali (T3 prerequisite):**
- Wait for `demo-studio-v3` revision newer than `00036-lgn` to be live (check `gcloud run revisions list --service=demo-studio-v3 --region=...`).
- Run the ADR-1 Build Progress Bar QA matrix per `assessments/qa-reports/2026-04-27-adr-1-build-progress-bar-rev00036-lgn-run7.md` reproduce-steps.
- File new report `assessments/qa-reports/2026-04-27-adr-1-build-progress-bar-rev<NEW>-run8.md`.

**Existing tests that must remain green:**
- `tests/test_chat_sse_handshake.py` (chat-queue path)
- `tests/test_sse_relay.py`
- `tests/test_sse_reconnect_persistence.py` (Last-Event-ID replay)
- `tests/test_sse_route_rewire.py`
- `tests/test_build_status_endpoint.py` (HTTP one-shot, not SSE — unaffected but adjacent)

## Done when

- T1 xfail test committed first on `feat/adr-1-build-progress-bar` (Strawberry Rule 12).
- T2 lands; T1 flipped to pass; full vanilla-SSE test suite green.
- PR opened, dual-reviewed, all required checks green (per Strawberry Rule 18).
- Post-merge: new `demo-studio-v3` revision deployed; T3 Akali re-run reports PASS for `progress-bar-never-mounts`.
- ADR-1 QA-block lifted; `bring-demo-studio-live-e2e-v1` project advances toward DoD.

## Open questions

- None blocking. The fix shape is mechanical and the frontend contract is already in place.

## References

- QA report: `assessments/qa-reports/2026-04-27-adr-1-build-progress-bar-rev00036-lgn-run7.md`
- Backend SSE handler: `tools/demo-studio-v3/main.py` lines 3146-3320 (`session_stream`, `_vanilla_sse_generator`, managed `_poll_stream`)
- Frontend SSE handlers: `tools/demo-studio-v3/static/studio.js` lines 1185-1262 (`connected`, `status` listeners with `mountBuildProgress()`)
- Build trigger path: `tools/demo-studio-v3/main.py` lines 2670-2770 (`/build/start`, `transition_session_status`, `factory_bridge_v2.trigger_factory_v2`)
- HTTP seed endpoint (working, for contrast): `tools/demo-studio-v3/main.py` lines 2884-2945 (`/session/{id}/build-status`)
- Project: `projects/work/active/bring-demo-studio-live-e2e-v1.md`

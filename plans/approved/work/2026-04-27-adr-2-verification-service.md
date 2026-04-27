---
slug: adr-2-verification-service
title: "ADR-2 — Verification service (auto-trigger + live progress + final-result contract)"
project: bring-demo-studio-live-e2e-v1
concern: work
status: approved
owner: swain
priority: P1
tier: standard
created: 2026-04-27
last_reviewed: 2026-04-27
qa_plan: required
qa_co_author: lulu
tests_required: true
architecture_impact: minor
---

## Context

DoD steps 9–11 of `projects/work/active/bring-demo-studio-live-e2e-v1.md` require:

- **Step 9 — Auto-verify.** The verification service starts immediately after build completes, triggered by an **API call** (not an agent tool call), with no user prompt.
- **Step 10 — Live verify progress.** The user watches verification with a visible progress bar in the same studio UI.
- **Step 11 — Final result + handoff.** Verify completion produces the project ID and demo link, narrated back to the user in chat. (Step 11 itself is owned by ADR-4 — async agent notifications — but ADR-2 must define the **output contract** ADR-4 consumes.)

The project doc calls verification the **highest pre-build unknown**. The actual finding after investigation is the opposite: the service exists and is well-built. The pre-build unknown is **why nothing happens today** when a build completes — the trigger is wired but mismatched, and no progress events are emitted because the service runs synchronously.

### Existing-state analysis

**Demo Studio Verification (S4)** lives at `tools/demo-studio-verification/` (Go, ~5,000 LOC, owner Khang, currently deployed as Cloud Run revision `demo-studio-verification-00005-756`).

What it does today (verified by reading `tools/demo-studio-verification/main.go`, `internal/api/handler.go`, `internal/checks/run.go`, `README.md`):

- **Synchronous** deterministic QC. `POST /verify` body `{sessionId, projectId}` runs 8 categories of checks (`identity`, `branding`, `card_fields`, `journey`, `token_ui`, `ipad_demo`, `gpay`, `i18n_sweep`, plus opt-in `test_pass`) sequentially and returns the full `QcReport`. Persists to Firestore. Typical duration: tens of seconds.
- `GET /verify/{session_id}` returns the latest persisted report. **Note the path key: `session_id`, not `project_id`.**
- `GET /logs` ring-buffer; `GET /health` liveness.
- Auth: `X-Verification-Token` or `Authorization: Bearer <VERIFICATION_TOKEN>`.
- No progress events. No SSE. No async job model. No LLM. No browser.

**BFF S4 poller** lives at `tools/demo-studio-v3/main.py:502-617` and is **wired but broken in four independent ways** that together mean verification *never actually runs* in the live flow today:

1. **`S4_VERIFY_URL` is unset in prod.** Per `plans/in-progress/work/2026-04-22-p1-factory-build-ipad-link.md` L49 + L310, `S4_VERIFY_URL` is currently empty in the deployed BFF env. `poll_s4_verify` (`main.py:509-512`) explicitly returns `{"status": "in_progress"}` when the env var is empty — a deliberate scaffold sentinel — so the poller spins forever until timeout regardless of any other fix.
2. **No trigger.** `start_s4_poller` is fired by `POST /session/{id}/build` callback success (`main.py:2748-2753`), but the poller only does `GET /verify/{project_id}` — **nothing in the system calls `POST /verify`**. The synchronous `POST /verify` is the only path that runs the checks; without it, every `GET` (once the URL was set) returns 404.
3. **Path-key mismatch.** Poller uses `project_id` in the URL (`main.py:513`); service routes `GET /verify/{session_id}`. Even if a `POST /verify` had been made, the poller would still 404 unless `project_id == session_id` (which is not the case in the new flow — see `_apply_build_complete`).
4. **Status enum mismatch.** Poller terminal states are `passed` / `failed` (`main.py:551`); service returns `status: pass | fail`. The poller would never recognise a real terminal and would always fall through to the in-progress branch.

Net effect on prod today: build succeeds, BFF starts poller, poller spins on the unset-`S4_VERIFY_URL` sentinel for 300 s (default `VERIFICATION_POLL_TIMEOUT_S`), then writes `verificationStatus: failed, report: {reason: timeout, elapsed_s: 300}` to the session doc. The frontend never sees verification progress because no `event: verification` chunk ever reaches `/session/{id}/logs` with a meaningful status. The agent then sees a `failed` verification and would (per ADR-4 once wired) report failure, despite the build being fine.

**Conclusion: the service is healthy; the wiring is broken.** This is a small surface change, not a from-scratch design problem.

### Recommended posture: **EXTEND**

Concretely:

- **Extend** S4: add SSE streaming on `POST /verify` so the service emits `category_start` / `category_complete` events during the run plus a terminal `verify_complete` / `verify_error`. Keep the existing JSON-body response semantics for non-SSE callers (Accept-header switch). Persistence and `GET /verify/{session_id}` semantics unchanged.
- **Replace** the BFF poller with a direct, server-to-server SSE-ingest call. BFF on build-callback success opens a streaming `POST /verify`, forwards each event into the existing per-session verification queue (already multiplexed into `/session/{id}/logs` as `event: verification`), and writes the terminal report via the existing `set_verification_result(...)` setter on stream-end.
- **Wrap is rejected**: a wrapper service adds an extra Cloud Run hop, a second auth token, and a third place that knows about projectId↔sessionId. No invariant forces it.
- **Replace is rejected**: S4's existing 60+ deterministic checks across 8 categories is the value. Recreating them is wasted effort. The SSE bolt-on is small (~1 source file plus channel plumbing through `checks.Run`).

Why this is justified by the simplicity rule: the only durable additions are (a) SSE emission inside the existing run-loop and (b) one new BFF outbound call replacing a broken poller. No new service. No new auth surface. No new persistence. The progress contract reuses ADR-1's UI-progress shape verbatim.

## Goal

When a build completes successfully, verification runs automatically and the studio UI shows a live progress bar in the same component slot ADR-1 vacated, ending with a final state that the chat agent can pick up via session-doc fields and narrate back to the user (ADR-4).

The architectural decision answers six questions:

1. **Who triggers verification?** BFF, on build-callback success. Server-to-server. No agent tool, no frontend trigger, no user prompt.
2. **What signal triggers it?** The existing `POST /session/{id}/build` callback path (factory → BFF, internal-secret-gated, already fires `start_s4_poller`).
3. **What is the wire shape?** Streaming `POST /verify` from BFF to S4 with `Accept: text/event-stream`. S4 emits per-category SSE events.
4. **How does the UI see progress?** Reuses BFF multiplexer `/session/{id}/logs` (already exists, tags verification events as `event: verification`). Reuses ADR-1's UI-progress translator + component, parameterised by source.
5. **How does the agent see completion?** Via session-doc fields written by `set_verification_result` (`verificationStatus`, `verificationReport`) plus pre-existing build fields (`projectUrl`, `demoUrl`, `shortcode`). Same mechanism the agent already uses to observe build state. ADR-4 wraps this into a chat push.
6. **What is the output contract for ADR-4?** A flat session-doc shape: `{verificationStatus, verificationReport, projectId, demoUrl, projectUrl, shortcode}`. Defined in §D6.

## Service definition

| Field | Value |
|---|---|
| Service name | `demo-studio-verification` (S4) — unchanged |
| Cloud Run service | existing `demo-studio-verification` (currently `…-00005-756`) — extends in place |
| Runtime | Go (unchanged) |
| Deployment shape | single Cloud Run service, IAM-authenticated, `X-Verification-Token` for app-level auth (unchanged) |
| New surface in this ADR | streaming response on existing `POST /verify` (Accept-header negotiated); no new routes |
| New env vars | none required for v1 (per-category timing is in-process) |
| Persistence | unchanged — Firestore via `internal/store` |
| `TEST_PASS_ENABLED` (S4 env) | **`0` in prod** (resolved OQ6 hands-off-autodecide 2026-04-27). The 8-category bar is canonical. The `test_pass` 9th category creates and downloads a real wallet pass — heavy I/O side effect on WS — and is opted out of the live flow. Surface as 9-category bar only if/when explicitly re-enabled. |

**Service map after ADR-2:**

- S1 — `demo-studio-v3` (BFF + frontend; orchestrator)
- S2 — `demo-config-mgmt`
- S3 — `demo-studio-factory`
- S4 — `demo-studio-verification` ← extended here
- S5 — `demo-preview`

No new service introduced. No service merged or removed.

## Architecture decisions

### D1 — BFF triggers verification on build-callback success via streaming `POST /verify`. The existing poller is deleted.

The build callback at `tools/demo-studio-v3/main.py:2649-2753` (`POST /session/{session_id}/build`, internal-secret) is the trigger point. Today it kicks `start_s4_poller`. ADR-2 replaces that with a function `start_s4_verify_stream(session_id, project_id)` that:

1. Opens a streaming HTTP request: `POST {S4_VERIFY_URL}/verify` with header `Accept: text/event-stream`, header `X-Verification-Token`, body `{sessionId, projectId}`.
2. Iterates the SSE response, parsing each `event: <name>\ndata: <json>\n\n` chunk and forwarding it through `emit_sse_event(session_id, "verification", payload)` into the per-session queue (already multiplexed by `/session/{id}/logs`).
3. On terminal event (`verify_complete` or `verify_error`), parses the embedded `report` and calls the existing `set_verification_result(session_id, status, report)` setter (writes `verificationStatus` + `verificationReport` to the session doc atomically).
4. On stream error / connection drop / timeout: writes `set_verification_result(session_id, "failed", {reason: "stream_error", error: <str>})` and emits a final `event: verification` with `{status: "failed"}`. **No retry in v1** (resolved OQ3 hands-off-autodecide 2026-04-27 — honest fast-fail to "could not run verification" UX; user retriggers the build. Defer retry/back-off policy to a follow-up).

**Why streaming and not polling.** The existing poller approach has three independent bugs (path-key, status enum, no trigger). Fixing each individually leaves a system that polls 404s with no useful progress signal between polls. SSE is the minimum-surface fix: one outbound call, real per-step granularity, uses the same multiplexer ADR-1 already wires through to the UI.

**Why server-to-server (BFF → S4) and not factory-to-S4.** The session doc is owned by S1 (BFF). The verification result must land on it. If factory S3 called S4 directly, S3 would need to know about the session-doc and how to write to it — surface creep, second writer, harder reasoning. Keeping the trigger in BFF preserves the single-writer invariant.

**Rejected alternatives:**

- **Keep polling, only fix the three bugs.** Even fixed, polling can't represent per-category progress unless S4 also exposes a fine-grained status endpoint. That makes S4 stateful in a new way (per-job in-flight progress in memory) just to feed a polling consumer. SSE is strictly less work.
- **WebSocket.** Same arguments as ADR-1 §D1: short-lived flow, Cloud Run idle quirks, would force a parallel transport from `/logs`.
- **Move trigger to factory S3.** Rejected per single-writer invariant above.
- **Synchronous POST without SSE.** Loses the live progress bar.
- **Async job queue + GET-polling for progress.** Adds queue, durable state, separate progress endpoint. Out of proportion for an 8-category sequential run.

### D2 — S4 emits SSE on `POST /verify` when `Accept: text/event-stream`. Default JSON-body response is preserved for existing/admin callers.

Header negotiation:

- `Accept: text/event-stream` → response is `Content-Type: text/event-stream` with the events listed in D3. Last event before stream close is `verify_complete` or `verify_error`, embedding the full `QcReport` in `data:`.
- Any other Accept (or no Accept) → existing behaviour: synchronous `application/json` body containing the full `QcReport`. Backwards-compatible.

`internal/checks.Run(ctx, cfg, snap, httpClient, opts)` is refactored to accept an optional event sink (`opts.OnEvent func(name string, payload any)`). When non-nil, each category emits `category_start` before its checks and `category_complete` after, along with a per-category mini-summary (`{category, passed, failed, skipped, duration_ms}`). The handler writes events to the response writer, flushes after each, and finally writes `verify_complete` or `verify_error` carrying the full `Report`.

**Why category-level granularity and not check-level.** There are 60+ individual checks but only 8 categories; the run already groups them in `Run`. Category-level events give the user a meaningful progress unit (~8 events over 30-60s ≈ one event every few seconds) without flooding the SSE channel or making the bar jitter wildly. ADR-1's pattern (10-step factory pipeline → 10 events) is the same philosophy.

**Why both Accept modes.** The verification service has admin / debug usage outside the live flow (Khang runs `POST /verify` from curl, automation may scrape `GET /verify/{session_id}` afterwards). Forcing SSE-only would break those callers. Header negotiation is a one-line guard.

### D3 — SSE event vocabulary

Mirrors factory S3's contract shape so ADR-1's UI-progress translator handles both with a single mapping table swap.

| Event | When emitted | Data shape |
|---|---|---|
| `verify_start` | Once, immediately on entering the run. | `{sessionId, projectId, totalCategories: 8}` (or 9 if `test_pass` is enabled). |
| `category_start` | Before each category begins. | `{category, index, totalCategories, name}` (`name` is human-readable copy). |
| `category_complete` | After each category finishes (regardless of pass/fail of inner checks — only a hard error skips this). | `{category, index, totalCategories, summary: {passed, failed, skipped}, duration_ms}`. |
| `verify_complete` | Terminal. Stream closes after. | Full `QcReport` (see §D6). |
| `verify_error` | Terminal on hard run-error (e.g. WS unreachable mid-run, config fetch failed). Stream closes after. | `{reason, error, partialReport?}`. `reason ∈ {config_fetch_failed, ws_unavailable, snapshot_failed, internal_error}`. |

`totalCategories` is sourced from the run itself (count categories enabled by `Options`). Frontend percent = `(completedCategories / totalCategories) * 100`. Same formula as ADR-1.

### D4 — UI surface reuses ADR-1's progress component, swapping the source and label table

The studio UI does **not** introduce a second progress component. ADR-1's `buildProgress.js` is generalised to a `progressComponent` (or remains build-named with an explicit source switch — naming detail for Lulu in §UX Spec). On terminal `build_complete` arriving from `event: build`, the component:

1. Holds at 100% with label "Build complete" for the dwell time set by ADR-1 OQ-3 (recommended 1.5 s).
2. Resets to 0% with label "Verifying demo…" (indeterminate spinner) and switches its source to `event: verification`.
3. Renders the verification progress bar using the verification step-name table (the 8 category names mapped to user-facing copy).
4. Holds at 100% on `verify_complete` with status-aware label: green "Verification passed" if `report.status === "pass"`, red "Verification failed — N issues" if `report.status === "fail"`.
5. On `verify_error`: red bar + label "Verification could not run — {reason}".

The UI-progress contract from ADR-1 §D2 is reused verbatim. Source-specific state is kept in a single discriminator (`'build' | 'verify'`).

**Step-name mapping (frontend table):**

| Category key | User-facing copy |
|---|---|
| `identity` | "Checking identity & branding metadata…" |
| `branding` | "Checking colors, logos, and assets…" |
| `card_fields` | "Checking card content…" |
| `journey` | "Checking demo journey…" |
| `token_ui` | "Checking demo widget…" |
| `ipad_demo` | "Checking iPad preview…" |
| `gpay` | "Checking Google Wallet pass…" |
| `i18n_sweep` | "Checking translations…" |
| `test_pass` | "Issuing test pass…" (only if enabled — `TEST_PASS_ENABLED=1`) |

Owned by Lulu in T8; the table above is a starting point.

### D5 — Reload resume mirrors ADR-1's mechanism, parameterised on source

ADR-1 §D6 introduces `GET /session/{sessionId}/build-status`. ADR-2 generalises it to `GET /session/{sessionId}/state` returning the union of build and verify state, so a single call seeds the progress component on reload regardless of which phase the session is in.

Response shape:

```ts
{
  buildId?: string,
  buildStatus?: 'configuring' | 'building' | 'complete' | 'failed',
  buildStep?: number, buildTotalSteps?: number, buildStepName?: string,
  verificationStatus?: 'in_progress' | 'pass' | 'fail',
  verificationCategory?: string, verificationCategoryIndex?: number,
  verificationTotalCategories?: number,
  projectUrl?: string, demoUrl?: string, shortcode?: string,
  error?: { phase: 'build'|'verify', reason: string, message: string }
}
```

Auth: `require_session_or_owner` (same as ADR-1).

For `verificationStatus === 'in_progress'`: **no upstream call** to S4 is needed for seed — the in-flight progress lives only in the SSE stream, which the frontend re-subscribes to immediately after seeding. The seed shows "Verifying demo…" indeterminate; the SSE fans in the latest `category_start`/`category_complete` events naturally because the BFF buffers up to `_verification_queues[session_id]` (asyncio.Queue maxsize=512) — pending events are still in the queue if the user reloads quickly. **Caveat (resolved OQ5 hands-off-autodecide 2026-04-27 — NO replay buffer in v1):** if the user reloads after the queue has been drained (queue is consume-once today), the bar shows indeterminate until the next event arrives. This is acceptable for v1 (events arrive every few seconds, reload during a 30-60 s window is rare). Promotion of the queue to a replay-buffer is punted to v2 if observed in practice.

For terminal verification states: returns directly from session-doc `verificationStatus`/`verificationReport`.

**Endpoint name:** `/state` (resolved OQ1 hands-off-autodecide 2026-04-27 — option (a)). ADR-2 commits to a single `GET /session/{sessionId}/state` seed endpoint covering both build and verify phases. ADR-1's previously-introduced `/build-status` is renamed to `/state` and absorbs the verify fields; frontend makes one seed call on reload regardless of phase. This requires a matching ADR-1 amendment (rename `/build-status` → `/state`); captured under §Cross-ADR coupling as a residual owned by parallel-Sona's session.

### D6 — Output contract consumed by ADR-4

When verification terminates, the following session-doc fields are guaranteed populated and stable for ADR-4's chat push to read:

| Field | Source | Shape | Set by |
|---|---|---|---|
| `verificationStatus` | session doc | `'pass' \| 'fail'` (or `'failed'` on stream/timeout error — see note) | `set_verification_result(...)` (`session.py:326`) |
| `verificationReport` | session doc | Full `QcReport` JSON (D3 `verify_complete` payload) on success; `{reason, error, partialReport?}` on error | `set_verification_result(...)` |
| `projectId` | session doc | string (the WS project id) | already set by build callback |
| `demoUrl` | session doc | string (URL) | already set by `_apply_build_complete` |
| `projectUrl` | session doc | string (URL) | already set by `_apply_build_complete` |
| `shortcode` | session doc | string | already set by `_apply_build_complete` |
| `lastVerificationAt` | session doc | ISO-8601 timestamp | already set by `set_verification_result` (Phase D field) |

**Status enum reconciliation (important).** Today's mismatch (poller says `passed`/`failed`, service says `pass`/`fail`) is resolved in this ADR by **adopting the service's `pass`/`fail`** as canonical. The poller is deleted, so the `passed`/`failed` strings only existed in dead code. ADR-4 reads `verificationStatus ∈ {'pass', 'fail', 'failed'}` where `'failed'` is reserved for the wrapper-side error path (stream error / timeout / unreachable). This ADR commits to the three-value enum explicitly so ADR-4 doesn't have to negotiate it.

**Demo link contract** (resolved OQ7 hands-off-autodecide 2026-04-27). The chat surfaces `demoUrl` (the public Wallet Studio demo URL — the share-with-customer link). `projectUrl` (Wallet Studio admin URL) is **not** posted in the default chat narration; it is exposed only when the user explicitly clicks "Open in Wallet Studio". ADR-2 commits to **populating BOTH `demoUrl` AND `projectUrl`** on the session doc (already done by `_apply_build_complete`); ADR-4 codifies the chat-surface choice (which field gets verbalised). The "project ID" is the WS project id stored as `projectId`. All three are set by build before verification runs; ADR-2 does not generate them. If ADR-3/ADR-5 later changes the build → demo-url derivation, this contract still holds because it cites session-doc field names, not derivation logic.

**Project-ID lifecycle on reverify** (resolved OQ8 hands-off-autodecide 2026-04-27). `verificationReport` and `verificationStatus` **overwrite** on each reverify run — latest wins. This matches the existing `set_verification_result(...)` setter semantics (it does not append history). v1 has no reverify-without-rebuild path, so this is forward-looking. **Forward-looking note:** if v2 introduces reverify-without-rebuild (e.g. user clicks "re-run verification" against the same `projectId`), revisit whether to retain the prior report under a `previousVerificationReport` field for diff UX.

### D7 — Terminal cleanup and idempotency

- `start_s4_verify_stream` is idempotent per `session_id`: if a stream task is already running for that session, a new build-callback fire is a noop (mirrors current `start_s4_poller` idempotency at `main.py:604`).
- On terminal (`verify_complete` / `verify_error` / stream error / timeout), the stream task removes itself from `_active_pollers` (renamed `_active_verify_streams` for clarity). Final `event: verification` with `{status, report}` is enqueued before queue teardown.
- The S4 service holds no per-job in-memory state beyond the goroutine running the request. If S4 instance dies mid-run, the BFF's stream connection drops → BFF writes `failed reason=stream_error`. No cross-instance recovery in v1; the user retries by triggering a new build.

### D8 — Failure modes considered, not designed-for in v1

The project DoD targets the happy path; failure UX is out of scope. The following modes were considered while designing and explicitly punted to a follow-up:

1. **Verification-service unreachable (Cloud Run cold start, network partition).** Stream-open fails → BFF writes `failed reason=stream_error`. UI shows red "Verification could not run." Retry behaviour: no auto-retry; user re-triggers build. Punt: design proper retry/circuit-breaker.
2. **Run takes longer than `VERIFICATION_POLL_TIMEOUT_S` (default 300 s).** With SSE, "in-progress without progress" is detectable: BFF watches inter-event gap with a **60 s no-event watchdog** (resolved OQ4 hands-off-autodecide 2026-04-27 — initial value, tune after first prod measurement) and treats expiry as stream stall → terminate with `failed reason=stream_stalled`. **Footnote:** the `gpay` category makes external HEAD-checks against CDNs and may approach the 60 s threshold under slow-network conditions; if false-positive stalls are observed in prod, raise the threshold (or shard it per category) before adding retries. Punt: tune timing for genuine slow categories.
3. **`verify_error` mid-run (e.g. WS API down between categories).** S4 emits `verify_error` with `partialReport`. UI shows red. Agent sees `verificationStatus: 'fail'`. Punt: surface partial-report in chat with category-level diagnosis.
4. **Concurrent builds for the same session.** v1 is single-user-single-build; idempotency handles it (second `start_s4_verify_stream` is a noop). Punt: properly-modelled job lifecycle.
5. **Verification passes but `demoUrl` is null** (build wrote `projectId` but not `demoUrl` — should not happen, but defensive). UI shows verify success without a clickable demo link; chat agent in ADR-4 must guard. Punt: tighten build-callback invariants.
6. **Cancellation.** No user-facing cancel for verification in v1. Once started, runs to terminal. Punt: add a cancel button + `DELETE /verify/{session}`.

## UX Spec

### User flow

1. User in a session. Build is in flight (ADR-1 progress bar visible).
2. Build terminal `build_complete`. ADR-1 component fills to 100%, holds at "Build complete" for ~1.5 s.
3. **Auto-transition.** Same component slot resets to 0% with indeterminate spinner and label "Verifying demo…". No user click. No agent message. (DoD step 9: triggered by API call, not agent.)
4. First `category_start` arrives over `event: verification`. Bar switches to determinate. Label updates per the D4 mapping table.
5. Each `category_complete` advances the bar by `(1 / totalCategories) * 100` percent. Label updates to next category on the next `category_start`.
6. Terminal `verify_complete`:
   - If `report.status === "pass"`: bar at 100%, green, label "Verification passed".
   - If `report.status === "fail"`: bar at 100%, amber/red, label "Verification completed with issues — {N} failed".
7. **Final-result handoff to chat (ADR-4).** ADR-2 does NOT render the demo link in the progress component — that's the agent's responsibility (ADR-4 reads `demoUrl` + `projectId` from session doc and posts a chat message). Progress component holds visible until the user dismisses it OR until a new build starts.
8. Failure path (`verify_error`): red bar, label "Verification could not run — {reason}".

### Component states (extends ADR-1's table)

| State | Bar | Label | Visible? |
|---|---|---|---|
| build `complete` (handoff) | 100% briefly | "Build complete" | visible 1.5 s, then resets |
| verify (no events yet) | indeterminate | "Verifying demo…" | visible |
| verify (category N) | determinate, value = (N-1)/8 → N/8 | "{D4 label table copy}" | visible |
| verify `pass` | 100% green | "Verification passed" | visible until dismissed or new build |
| verify `fail` | 100% amber | "Verification completed with issues — {N} failed" | visible until dismissed |
| verify `error` | last value, red | "Verification could not run — {reason}" | visible until dismissed |

### Responsive behavior

Inherited from ADR-1 §UX Spec (single-line desktop, label-wrap mobile, full container width). No new breakpoints introduced.

### Accessibility (per process.md floor)

- `aria-valuetext` updates per category transition: `"Verifying demo, step 3 of 8, Checking demo journey"`.
- Terminal status announce via `aria-live="polite"`: `"Verification passed"` / `"Verification completed with 2 issues"` / `"Verification could not run"`.
- Color is not the sole carrier of pass/fail — label text is explicit.
- Keyboard-dismissible in terminal states (Escape).

### Wireframe reference

ADR-1's wireframe is sufficient as the visual is the same component. Verification-specific copy + the `verify_pass`/`verify_fail`/`verify_error` end-states should be added to ADR-1's wireframe doc by Lulu in T8 (single annotated diagram covering both phases). No Figma frame required for v1.

## Tasks

Refined inline by Aphelios 2026-04-27 (D1A). Owner lanes name *roles*, not specific implementers — Sona dispatches to actual agents (Jayce/Viktor for Go/Python impl, Vi/Rakan for tests, Lulu for copy). `parallel_slice_candidate` is read by the dispatch coordinator to decide whether to slice into parallel streams.

### Phase A — S4 service: SSE streaming on `POST /verify`

> **Phase A gate: `khang-confirm`** (CC2 / OQ2 resolution 2026-04-27). S4 (`tools/demo-studio-verification/`) is Khang-owned. Before dispatching ANY of T1/T2/T3/T4/T11, Sona must surface a courtesy heads-up to Khang ("ADR-2 extends S4 with SSE on `POST /verify`, churn ~1 source file + handler branch + tests, ETA Tuesday") and obtain ack. Single ack unblocks all five tasks. If Khang signals he wants to own implementation himself, Phase A converts to a hand-off: Aphelios's spec stays, Khang implements; Phases B/C/D/E unaffected. The `gate: khang-confirm` field on each Phase A task is a dispatch-time check, NOT a re-litigation of the EXTEND decision.
>
> **Phase A internal ordering:** T3 (encoder util) is a leaf with no deps; T1 (event-sink hook) and T3 can run in parallel. T2 (handler SSE branch) consumes both T1 and T3 outputs. T4 (backwards-compat smoke) covers the JSON branch which is unchanged but must be re-verified post-T2 merge.

#### T1 — `internal/checks` event-sink hook
`kind: feature`
`estimate_minutes: 45`
`gate: khang-confirm`
`owner_lane: jayce-go-impl`
`parallel_slice_candidate: no`
`blocked_by: phase-a-gate`
`tdd_xfail_reference: T11 (Phase D — S4 SSE handler tests; xfail committed first against the OnEvent callback contract)`
`files:`
- `tools/demo-studio-verification/internal/checks/run.go` — extend `Options` struct with `OnEvent func(name string, payload any)`; thread through the per-category dispatch loop. Wrap each category invocation (`runIdentity`, `runBranding`, `runCardFields`, `runJourney`, `runTokenUI`, `runIpadDemo`, `runGpay`, `runI18nSweep`, opt-in `runTestPass`) with `OnEvent("category_start", {...})` before and `OnEvent("category_complete", {...})` after.
- `tools/demo-studio-verification/internal/checks/options.go` (or wherever `Options` is currently declared — confirm during impl) — add `OnEvent` field.

Mini-summary payload on `category_complete`: `{category, index, totalCategories, summary: {passed, failed, skipped}, duration_ms}` per D3. Compute `duration_ms` via `time.Since(start)` around each runX call. No behaviour change when `OnEvent == nil` — guard each emission with a nil-check. Skipped categories (per `Options` opt-out) do NOT emit start/complete events; only enabled categories count toward `totalCategories`.

#### T2 — Handler SSE response when `Accept: text/event-stream`
`kind: feature`
`estimate_minutes: 50`
`gate: khang-confirm`
`owner_lane: jayce-go-impl`
`parallel_slice_candidate: no`
`blocked_by: T1, T3`
`tdd_xfail_reference: T11 (Phase D — S4 SSE handler tests; xfail asserts header-negotiated branch + event order)`
`files:`
- `tools/demo-studio-verification/internal/api/handler.go::HandleVerify` — branch on `r.Header.Get("Accept") == "text/event-stream"` at the top of the handler.

SSE branch:
- Set response headers: `Content-Type: text/event-stream`, `Cache-Control: no-cache`, `Connection: keep-alive`, `X-Accel-Buffering: no`.
- Assert `http.Flusher` interface on `w` (return 500 if not supported — Cloud Run supports it).
- Emit `verify_start` with `{sessionId, projectId, totalCategories}` (count enabled categories from `Options`).
- Construct `Options.OnEvent` closure that calls T3's encoder util to write each event to the writer + flush.
- Call `checks.Run(ctx, cfg, snap, httpClient, opts)`.
- On `Run` success: emit `verify_complete` with the full `Report` JSON-encoded into `data:`.
- On hard error mid-run (config fetch fail, WS snapshot fail, internal error): emit `verify_error` with `{reason, error, partialReport?}` per D3.
- Persist `Report` to Firestore as today via the existing store call (unchanged).
- Close stream cleanly (single SSE response, no chunked-keepalive after terminal).

JSON branch: existing behaviour, untouched. The Accept-negotiation guard is a single early branch — do NOT duplicate the run logic.

#### T3 — SSE event encoding util
`kind: feature`
`estimate_minutes: 25`
`gate: khang-confirm`
`owner_lane: jayce-go-impl`
`parallel_slice_candidate: no`
`blocked_by: phase-a-gate`
`tdd_xfail_reference: T11 (covered transitively — encoder unit-tested via the handler integration; no separate xfail required for the leaf util, just a table-test in the same package)`
`files:`
- `tools/demo-studio-verification/internal/api/sse.go` (new) — exports `WriteEvent(w io.Writer, flusher http.Flusher, name string, payload any) error`. Marshals `payload` to JSON, writes the wire frame `event: <name>\ndata: <json>\n\n`, then `flusher.Flush()`. Returns the underlying write/flush error so the handler can decide whether to abort.
- Companion table-test in `internal/api/sse_test.go` (new) covering: simple payload roundtrip, JSON-unmarshalable payload (error return), flush failure (error return).

Pure-leaf util, no external deps beyond `encoding/json` + `net/http`. Reused by all SSE emissions in T2.

#### T4 — Backwards-compat smoke for non-SSE callers
`kind: test`
`estimate_minutes: 30`
`gate: khang-confirm`
`owner_lane: vi-go-tests`
`parallel_slice_candidate: no`
`blocked_by: T2`
`tdd_xfail_reference: self (this IS the regression-test task — committed before T2 merge as xfail, flips green when T2 lands)`
`files:`
- `tools/demo-studio-verification/internal/api/handler_test.go` — add table-driven test `TestHandleVerify_BackwardsCompatNonSSE` covering: (a) `POST /verify` with no Accept header returns `application/json` body matching `QcReport` shape; (b) `POST /verify` with `Accept: application/json` returns same JSON body; (c) Firestore persistence still invoked once with the same `Report`.

Use the existing test fixtures / mocks in the package (do NOT introduce new mock infrastructure). The test must run in CI under the existing `go test ./...` invocation.

### Phase B — BFF: replace S4 poller with streaming ingest

#### T5 — Replace BFF poller with `start_s4_verify_stream`
`kind: feature`
`estimate_minutes: 60`
`owner_lane: viktor-python-impl`
`parallel_slice_candidate: no`
`blocked_by: T2 (depends on S4 SSE branch landing — though Phase B can author against the documented contract before T2 is merged, end-to-end verification requires T2 in the dev environment)`
`tdd_xfail_reference: T12 (Phase D — BFF stream-ingest tests, xfail-first against canned SSE chunks)`
`files:`
- `tools/demo-studio-v3/verify_stream.py` (new) — exports `async def start_s4_verify_stream(session_id: str, project_id: str) -> None`. Internally:
  - Uses `httpx.AsyncClient` with `stream("POST", f"{S4_VERIFY_URL}/verify", ...)`, headers `{Accept: text/event-stream, X-Verification-Token: ...}`, body `{sessionId, projectId}`.
  - Iterates `response.aiter_lines()`, parses SSE frames (`event:` / `data:` line pairs separated by blank line).
  - For each event: forwards via `emit_sse_event(session_id, "verification", payload)` (existing in `main.py`).
  - On terminal `verify_complete`: parses embedded `report`, calls `set_verification_result(session_id, report.status, report)` (existing in `session.py:326`).
  - On terminal `verify_error`: calls `set_verification_result(session_id, "failed", {reason, error, partialReport})`.
  - On HTTP error / connection drop: calls `set_verification_result(session_id, "failed", {reason: "stream_error", error: str(exc)})` and emits final `event: verification` with `{status: "failed", reason: "stream_error"}`.
  - Idempotency tracked via `_active_verify_streams: dict[str, asyncio.Task]` (renamed from `_active_pollers`); second call for same session is a noop (mirrors existing `start_s4_poller` semantics at `main.py:604`).
  - Self-removes from `_active_verify_streams` on terminal/error in a `finally` block.
- `tools/demo-studio-v3/main.py:2748-2753` — swap `start_s4_poller(session_id, project_id)` call for `start_s4_verify_stream(session_id, project_id)`. Update import.
- `tools/demo-studio-v3/main.py:502-617` — DELETE `poll_s4_verify`, `run_s4_poller`, `start_s4_poller` and the `_active_pollers` dict (replaced by `_active_verify_streams` in `verify_stream.py`).
- `tools/demo-studio-v3/main.py` — any remaining `_active_pollers` references (search `grep -n _active_pollers main.py`) updated or removed.

Logging: structured log on stream-open, each event forwarded (debug level), terminal (info level), errors (warn/error). Match existing log conventions in this file.

#### T6 — Stream-stall watchdog (60 s no event)
`kind: feature`
`estimate_minutes: 35`
`owner_lane: viktor-python-impl`
`parallel_slice_candidate: no`
`blocked_by: T5`
`tdd_xfail_reference: T12 (Phase D — extends BFF stream-ingest test with stall scenario; canned chunks with artificial 70 s gap)`
`files:`
- `tools/demo-studio-v3/verify_stream.py` — wrap the `async for line in response.aiter_lines()` loop with `asyncio.wait_for(...)` per-line read using a 60 s timeout. On `asyncio.TimeoutError`: call `set_verification_result(session_id, "failed", {reason: "stream_stalled", elapsed_s: 60})`, emit final `event: verification` with `{status: "failed", reason: "stream_stalled"}`, exit cleanly.

Watchdog applies between events, not to total stream duration. Reset timer on every line received (including SSE keepalive/comment lines if S4 emits any). Footnote in D8.2 notes `gpay` HEAD-checks may approach the threshold — if false-positive stalls are observed in prod, raise the threshold per category before adding retries.

#### T7a — Set `S4_VERIFY_URL` + token in BFF deploy env
`kind: chore`
`estimate_minutes: 40`
`owner_lane: viktor-ops`
`parallel_slice_candidate: yes`
`blocked_by: phase-a-gate (env plumbing can land in parallel with T1–T6 since it's pure config; verification of end-to-end requires T5)`
`tdd_xfail_reference: n/a (chore, no test xfail required — verified via T13 e2e and Akali QA gate)`
`files:`
- `tools/demo-studio-v3/deploy.sh` — add `--set-env-vars S4_VERIFY_URL=https://demo-studio-verification-...run.app` (resolve real URL via `gcloud run services describe demo-studio-verification --region europe-west1 --format='value(status.url)'`).
- `tools/demo-studio-v3/deploy.sh` — add `--set-secrets S4_VERIFY_TOKEN=demo-studio-verification-token:latest` (or named env consistent with BFF — confirm against current `VERIFICATION_TOKEN` env name in `verify_stream.py`).
- Secret Manager: confirm `demo-studio-verification-token` secret exists; if not, create via `gcloud secrets create` mirroring the value already set on the S4 Cloud Run service env.
- IAM: confirm BFF service account has `roles/secretmanager.secretAccessor` on the secret.

Without this, every other change in this ADR is inert (per Existing-state §1: empty `S4_VERIFY_URL` short-circuits to in_progress sentinel). Apply to both stg and prod env profiles.

Slice candidate `yes`: env plumbing + secret check + IAM grant are three independently verifiable workstreams; can be parallelised if dispatch wants to compress wall-clock.

#### T7b — Expose head-SHA via `/__build_info` on demo-studio-v3 BFF
`kind: feature`
`estimate_minutes: 40`
`owner_lane: viktor-python-impl`
`parallel_slice_candidate: yes`
`blocked_by: none (independent; Akali QA gate references it but T7b can land before any of T1–T7)`
`tdd_xfail_reference: regression-test inline (small new endpoint — single test asserting shape + headers committed alongside impl; no separate xfail-first task)`
`files:`
- `tools/demo-studio-v3/main.py` — add route `@app.get("/__build_info")` returning JSON `{revision: BUILD_SHA, builtAt: BUILD_AT, service: "demo-studio-v3"}`. Read both from env (default to `"unknown"` if unset). No auth (read-only metadata). CORS: same-origin fetch is sufficient; no extra CORS middleware change needed if the frontend is same-origin.
- `tools/demo-studio-v3/deploy.sh` — at image-build time, capture `BUILD_SHA=$(git rev-parse HEAD)` + `BUILD_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)` and substitute via `--set-env-vars` on the Cloud Run revision.
- `tools/demo-studio-v3/tests/test_main.py` (or wherever existing route tests live — confirm during impl) — add `test_build_info_endpoint` asserting 200, JSON shape, no auth required.

**Discovery step (first thing the impl agent does):** grep `tools/demo-studio-v3/` for an existing revision marker (`/version`, `/healthz` body, response header). If found, reuse it and amend the QA Plan reference (§QA Plan setup step 4) instead of adding a new endpoint. Report back to Sona either way.

Slice candidate `yes`: independent of the verification stream work; can be sliced to a separate dispatch and run in parallel with Phase A.

#### T7 — Status enum unification
`kind: chore`
`estimate_minutes: 35`
`owner_lane: viktor-python-impl`
`parallel_slice_candidate: yes`
`blocked_by: none (independent grep-and-replace; can land in parallel with T5/T6)`
`tdd_xfail_reference: regression-test inline (existing tests asserting `passed`/`failed` are flipped to `pass`/`fail`/`failed` in this same task — they ARE the regression coverage)`
`files:`
- `tools/demo-studio-v3/mcp_tools.py:78-105` — update any `verificationStatus` reads/comparisons to canonical `pass | fail | failed` enum.
- `tools/demo-studio-v3/session.py` — confirm `set_verification_result` writes only `pass | fail | failed`; update `_UPDATABLE_FIELDS` validator if it carries an explicit enum constraint.
- `tools/demo-studio-v3/main.py` — grep for `passed`/`failed` literals in verification context; replace.
- All BFF + MCP tests asserting `verificationStatus == "passed"` → `== "pass"` (see `tests/` directory).
- Frontend: grep `apps/demo-studio-frontend/` (or wherever the studio frontend lives — discover during impl) for `verificationStatus === 'passed'` and update.

**Verification step:** `grep -rE "verificationStatus.*\"passed\"|verificationStatus.*'passed'" tools/ apps/` returns zero hits after the change. The test plan §Test plan already asserts this.

### Phase C — UI integration

#### T8 — Frontend: extend progress component for verification source
`kind: feature`
`estimate_minutes: 55`
`owner_lane: seraphine-frontend-impl (impl) + lulu-copy (verify-step label table)`
`parallel_slice_candidate: yes`
`blocked_by: ADR-1 progress component landed (otherwise this task is grafting onto a moving target)`
`tdd_xfail_reference: T13 (Phase D — end-to-end logs integration also exercises the frontend transition; component-level xfail in the studio frontend test suite if one exists)`
`files:`
- `apps/demo-studio-frontend/.../buildProgress.js` (or wherever ADR-1 landed the progress component — discover during impl) — add a `source: 'build' | 'verify'` discriminator. Source-specific state (label table, total steps, terminal copy) selected via the discriminator.
- New `verifyLabels` table mapping the 8 category keys to the user-facing copy from D4 (`identity` → "Checking identity & branding metadata…", etc.). Lulu owns the copy review.
- Terminal state copy table: `pass` → "Verification passed" (green), `fail` → "Verification completed with issues — N failed" (amber), `error` → "Verification could not run — {reason}" (red).
- Accessibility per D4 §UX Spec: `aria-valuetext` and `aria-live="polite"` announcements for verify state transitions.

UI-progress contract from ADR-1 §D2 is reused verbatim — do NOT introduce a parallel progress contract or a second component. Single component, two sources.

Slice candidate `yes`: copy table (Lulu) + component code (Seraphine) + accessibility annotations are independent enough to parallelise if dispatch wants three streams.

#### T9 — Frontend: subscribe handoff (build_complete → verify)
`kind: feature`
`estimate_minutes: 40`
`owner_lane: seraphine-frontend-impl`
`parallel_slice_candidate: no`
`blocked_by: T8`
`tdd_xfail_reference: T13 (e2e covers the handoff timing); component-level test optional`
`files:`
- `apps/demo-studio-frontend/.../buildProgress.js` (same file as T8) — on `event: build` arrival with `build_complete` data: hold bar at 100% with "Build complete" label for 1.5 s (per ADR-1 OQ-3 dwell time), then reset bar to 0% indeterminate with "Verifying demo…" label, switch source discriminator to `'verify'`.
- Reuse the **same** `EventSource` connection — do NOT close and re-open. The multiplexer at `/session/{id}/logs` continues to deliver both `event: build` and `event: verification` chunks; the component just routes them by `event` field.
- Wire dispatcher: incoming `MessageEvent` with `event === 'verification'` → existing verify handler from T8; with `event === 'build'` → existing build handler from ADR-1.

The 1.5 s dwell is a setTimeout; cancellable if a new build starts before it expires (defensive).

#### T10 — `GET /session/{sessionId}/state` (unified build+verify seed)
`kind: feature`
`estimate_minutes: 50`
`owner_lane: viktor-python-impl`
`parallel_slice_candidate: no`
`blocked_by: T5 (verify fields), CC1 (ADR-1 `/build-status` → `/state` rename owned by parallel-Sona)`
`cross_adr_blocked_by: ADR-1-T-rename (parallel-Sona's ADR-1 rename of `/build-status` → `/state`; if ADR-1 ships under `/build-status` first, T10 must include a transitional alias — see CC1)`
`tdd_xfail_reference: T14 (Phase D — page-reload resume integration test, xfail-first)`
`files:`
- `tools/demo-studio-v3/main.py` — implement `@app.get("/session/{session_id}/state")` route. Reads session doc once via existing Firestore client; assembles the unified shape per D5 (build + verify fields). Auth: `require_session_or_owner` decorator (existing).
- For `verificationStatus === 'in_progress'`: NO upstream call to S4. The seed returns the indeterminate marker; the frontend re-subscribes to SSE immediately after seeding and picks up future events from the multiplexer.
- For terminal verify states: returns `verificationStatus`/`verificationReport` directly from session doc.
- Coordinate with parallel-Sona: if ADR-1's `/build-status` ships before this rename lands, T10 adds a transitional alias `@app.get("/session/{session_id}/build-status")` that delegates to the same handler, returning the unified shape. Mark for removal in a follow-up.

CC1 coupling: this task is the ADR-2-side terminus of the rename. Aphelios surfaces the cross-ADR blocker explicitly; Sona must coordinate with parallel-Sona (ADR-1 holder) before kicking off T10.

### Phase D — Tests

> **Phase D is a logical grouping, not a chronological one.** Per project rule §12 (TDD gate), each test task is xfail-committed BEFORE its covered impl tasks land on the same branch. So in branch-time, the order is roughly: T11 xfail → T1/T2/T3 impl (T11 flips green); T12 xfail → T5/T6 impl (T12 flips green); T13 xfail → T5 impl; T14 xfail → T10 impl. T4 (backwards-compat smoke for non-SSE callers, kept in Phase A as the JSON-branch regression) follows the same xfail-first discipline against T2.

#### T11 — S4 SSE handler tests
`kind: test`
`estimate_minutes: 55`
`gate: khang-confirm`
`owner_lane: vi-go-tests`
`parallel_slice_candidate: no`
`blocked_by: T1, T2, T3 (covers all three S4-side impl tasks)`
`covers: T1 + T2 + T3 (event-sink hook + handler SSE branch + encoder util)`
`tdd_xfail_reference: self (this IS the xfail-first test for T1+T2+T3 — committed BEFORE T1/T2/T3 land, flips green when they all merge)`
`files:`
- `tools/demo-studio-verification/internal/api/handler_test.go` — add `TestHandleVerify_SSEBranch_EventSequence` asserting:
  - Request with `Accept: text/event-stream` returns `Content-Type: text/event-stream` + flushable body.
  - Event order on the wire: `verify_start` → 8 × (`category_start`, `category_complete`) → `verify_complete`.
  - Each event payload shape matches D3 (totalCategories, category index, summary, etc.).
  - Hard error mid-run (mock config client returns error) → `verify_error` with correct `reason` enum value, stream closes after.
  - Firestore persistence still invoked (existing mock).
- Mock the WS client + config client using existing test fixtures in the package.

xfail-first protocol per project rule §12: this test is committed (with `t.Skip` or build-tag-gated) on a branch BEFORE T1/T2/T3 implementation commits. The TDD gate verifies it precedes impl in branch history.

#### T12 — BFF stream-ingest tests
`kind: test`
`estimate_minutes: 55`
`owner_lane: rakan-python-tests`
`parallel_slice_candidate: no`
`blocked_by: none (xfail-first; precedes T5 + T6)`
`covers: T5 + T6 (stream ingest + stall watchdog)`
`tdd_xfail_reference: self (this IS the xfail-first test for T5/T6 — committed BEFORE T5/T6 land, flips green when they merge)`
`files:`
- `tools/demo-studio-v3/tests/test_verify_stream.py` (new) — pytest test module:
  - `test_stream_ingest_terminal_complete`: feed canned SSE chunks (verify_start + 8 category pairs + verify_complete) via httpx mock; assert `set_verification_result(session_id, "pass", report)` called exactly once, each `event: verification` chunk reached `_verification_queues[session_id]` (assert via queue drain).
  - `test_stream_ingest_terminal_error`: feed canned SSE ending in `verify_error`; assert `set_verification_result(session_id, "failed", {reason, error, partialReport})`.
  - `test_stream_ingest_connection_drop`: simulate httpx connection error mid-stream; assert `set_verification_result(session_id, "failed", {reason: "stream_error", ...})`.
  - `test_stream_stall_watchdog` (T6): simulate 70 s gap between events (mock `asyncio.wait_for` or use a timing scaffold); assert `set_verification_result(session_id, "failed", {reason: "stream_stalled"})` and final `event: verification` emitted.
  - `test_stream_idempotent`: two concurrent calls for same session_id; second is noop, only one `_active_verify_streams` entry.

xfail-first per project rule §12: tests committed on a branch with `pytest.mark.xfail(strict=True)` BEFORE T5/T6 impl commits. Flip strict-passing once impl lands.

#### T13 — End-to-end `/session/{id}/logs` integration
`kind: test`
`estimate_minutes: 60`
`owner_lane: rakan-python-tests`
`parallel_slice_candidate: no`
`blocked_by: T5, T7a (needs S4_VERIFY_URL plumbed even in test env), and ideally T2 (if integration runs against a real S4 dev instance)`
`covers: T5 + build-callback path + multiplexer + session-doc terminal write`
`tdd_xfail_reference: self (xfail-first; committed before T5 lands, flips green when full pipeline is up)`
`files:`
- `tools/demo-studio-v3/tests/test_e2e_verify_pipeline.py` (new) — integration test:
  - Mock S4 with a local HTTP server (httpx ASGI app or `aiohttp` test server) that serves `POST /verify` returning canned SSE.
  - Trigger `POST /session/{id}/build` callback (internal-secret) on the BFF.
  - Subscribe to `GET /session/{id}/logs` via SSE client.
  - Assert: `event: verification` chunks arrive in order matching the canned upstream sequence; terminal `verify_complete` lands on session doc as `verificationStatus="pass"` + `verificationReport` populated; bounded total time < 30 s for the test scenario.

This is the integration that proves the full chain works without real S4. Akali's QA gate against the deployed env covers the production-path integration.

#### T14 — Page-reload resume integration
`kind: test`
`estimate_minutes: 50`
`owner_lane: rakan-python-tests`
`parallel_slice_candidate: no`
`blocked_by: T10 (the `/state` endpoint must exist), T9 (frontend re-subscribe behaviour)`
`covers: T10 + T9 reload path`
`tdd_xfail_reference: self (xfail-first; committed before T10 lands)`
`files:`
- `tools/demo-studio-v3/tests/test_e2e_reload_resume.py` (new) — integration test:
  - Trigger build → wait for verify start → simulate page-reload by closing the SSE connection mid-verify.
  - Issue `GET /session/{id}/state`; assert response shape includes `verificationStatus: "in_progress"`, indeterminate seed (no progress fields populated).
  - Re-open SSE; assert remaining `category_*` events arrive normally and terminal `verify_complete` lands.
  - Edge case: queue drained between disconnect and reconnect (per D5 caveat) — bar shows indeterminate until next event arrives. Test asserts indeterminate seed + correct flow once next event arrives.

Bounded total time < 30 s.

### Phase E — Review

#### T15 — Component visual smoke (Lulu / Caitlyn)
`kind: review`
`estimate_minutes: 45`
`owner_lane: lulu-design-review`
`parallel_slice_candidate: wait-bound`
`blocked_by: T8, T9, T10 (frontend impl deployed) + Akali QA gate run`
`tdd_xfail_reference: n/a (review task, not impl)`
`files:`
- `assessments/qa-reports/2026-04-27-adr-2-verification-service-<rev-sha>/lulu-visual-review.md` (new) — visual review of verify states on the `feat/demo-studio-v3` deployment, comparing rendered states (in-progress / pass / fail / error) against the §UX Spec and the D4 step-name mapping table copy.

Slice candidate `wait-bound`: review duration is dominated by waiting for the deployment to land + Akali's QA artifacts to deposit; cannot be parallelised by slicing.

## Test plan

Authored inline by Xayah 2026-04-27 (D1A). Layer below the §QA Plan: unit / integration / contract / resilience / fault-injection. xfail-first per project rule §12 — every test task in §Tasks Phase D commits BEFORE the impl task it covers, on the same branch. Akali UI flow (above, §QA Plan) is the user-flow gate; this section is the developer-test gate.

**Global rollup (acceptance):**
- All Phase D unit + integration tests green in CI (pytest + `go test ./...`).
- Status enum is `{pass, fail, failed}` everywhere (BFF + MCP tools + tests + frontend). Grep verifies no surviving `passed` literal in `tools/` or `apps/`.
- Deleted poller does not regress: `grep -r 'start_s4_poller\|run_s4_poller\|poll_s4_verify' tools/demo-studio-v3/` returns zero hits.
- Pre-push hook + CI green; PR e2e green; PR-lint detects required `Design-Spec:`, `Accessibility-Check:`, `Visual-Diff:`, `QA-Report:` markers.
- Akali §QA Plan executes against `feat/demo-studio-v3` deployment with all checkpoints green (covers user-flow layer; this §Test Plan covers code layer).

### Coverage matrix

Each impl task is paired with its xfail-first test task per project rule §12. Test types: **unit** = single-package, no I/O; **integration** = multi-component within a service; **contract** = wire-format / event-vocabulary assertion; **e2e** = cross-service via test-server fakes; **resilience** = fault-injected behaviour.

| Impl task | Covered by | Test type(s) | xfail-first posture |
|---|---|---|---|
| T1 — `internal/checks` event-sink hook (Go) | T11 | unit + integration + contract | T11 committed BEFORE T1; flips green when T1+T2+T3 land |
| T2 — Handler SSE branch (Go) | T11 + T4 | integration + contract + resilience | T11 + T4 both xfail BEFORE T2 |
| T3 — SSE encoder util (Go) | T11 (transitive) + T3-inline table-test | unit + contract | T3's own table-test commits with the impl; T11 covers integration |
| T4 — Backwards-compat smoke (non-SSE) | T4 (self) | unit + contract | T4 IS the regression for T2 JSON branch — committed before T2 merge as xfail |
| T5 — `start_s4_verify_stream` (Python) | T12 + T13 | integration + contract + resilience | T12 + T13 xfail BEFORE T5 |
| T6 — Stream-stall watchdog (Python) | T12 (extended) | resilience (fault injection) | Same xfail commit as T12 |
| T7 — Status enum unification | T7-inline (existing tests flipped to canonical enum) | unit | Tests ARE the regression; flipped in same task |
| T7a — `S4_VERIFY_URL` deploy env | T13 (e2e gates depends on env plumbed) + Akali QA gate | e2e (transitively) | n/a — chore; verified via T13 + Akali |
| T7b — `/__build_info` endpoint | T7b-inline (`test_build_info_endpoint`) | unit | Test commits with impl; small surface |
| T8 — Frontend progress component (verify source) | T13 (transitively) + Lulu visual review T15 | e2e + visual | T13 xfail BEFORE T8 |
| T9 — Build→verify handoff (frontend) | T13 + Akali §QA Plan happy-path step 4 | e2e + UI flow | Covered by T13 e2e + Akali |
| T10 — `GET /session/{id}/state` | T14 | integration + contract | T14 xfail BEFORE T10 |

Layer summary: 4 unit-bearing tasks (T3 inline, T4, T7 inline, T7b inline), 1 unit/integration/contract bundle (T11), 1 integration/contract/resilience bundle (T12), 2 e2e bundles (T13, T14), 1 visual review (T15). Resilience cases concentrated in T11 (handler-side `verify_error`) and T12 (BFF-side stream-error / stalled / drop / idempotency).

### Unit tests

Pure-package, no network, no Firestore writes (mocked). Run under `go test ./...` and `pytest`.

#### S4 (Go) — `internal/api/sse_test.go` (companion to T3)
Lives with T3 impl. Covers the SSE encoder util in isolation:
- `TestWriteEvent_RoundtripSimplePayload` — `{a:1, b:"x"}` produces wire frame `event: foo\ndata: {"a":1,"b":"x"}\n\n` and `Flush()` is invoked exactly once.
- `TestWriteEvent_UnmarshalableReturnsError` — payload with channel/func field returns the JSON marshal error; nothing is written; flusher is NOT called.
- `TestWriteEvent_FlushFailureSurfaces` — fake flusher returning error; the flush error is returned to caller (handler can decide to abort).
- `TestWriteEvent_NewlinesInPayloadEscaped` — JSON-encoded payload with embedded `\n` doesn't break the SSE frame boundary (`\n\n` terminator detection stays unambiguous).

#### S4 (Go) — `internal/checks/run_test.go` extension (covered by T11 but unit-shaped at the leaf)
Adds a unit-level slice to T11's coverage:
- `TestRun_OnEventNilIsNoop` — when `Options.OnEvent == nil`, no panic, no observable behaviour change vs. pre-T1 baseline (assert against the same `QcReport` shape today's tests produce).
- `TestRun_OnEventEmitsPerCategoryStartCompletePairs` — capture all callbacks into a slice; assert exactly `2 * enabledCategoryCount` callbacks, alternating `category_start` / `category_complete`, with monotonic `index`.
- `TestRun_SkippedCategoriesNotEmitted` — disable `gpay` via `Options`; assert no `category_start` for `gpay` and `totalCategories` reflects 7 (not 8).
- `TestRun_DurationMsPositive` — every `category_complete` payload has `duration_ms >= 0`.

#### BFF (Python) — `tools/demo-studio-v3/tests/test_verify_stream_unit.py` (companion to T12)
Pure-unit slice of T12, no real httpx network:
- `test_parse_sse_frame_well_formed` — feed a known `event: x\ndata: {...}\n\n` byte string into the SSE-frame parser helper; assert event name + parsed JSON payload.
- `test_parse_sse_frame_malformed_chunk_dropped` — feed a chunk missing the blank-line terminator or with a non-JSON `data:` payload; parser returns None / raises a typed error and the consumer logs+skips (does NOT terminate the stream early).
- `test_active_streams_dict_idempotency` — call helper that registers a session-task into `_active_verify_streams`; second call for same session returns the existing task and does not create a new one.

#### BFF (Python) — `tools/demo-studio-v3/tests/test_main.py` extension (companion to T7b)
- `test_build_info_endpoint` — `GET /__build_info` returns 200, JSON shape `{revision, builtAt, service: "demo-studio-v3"}`, no auth required.
- `test_build_info_defaults_when_unset` — env unset → `revision == "unknown"`, `builtAt == "unknown"`.

#### BFF (Python) — `tools/demo-studio-v3/tests/test_session.py` extension (companion to T7)
- `test_set_verification_result_canonical_enum` — calling with `"pass"`, `"fail"`, `"failed"` writes verbatim; calling with the legacy `"passed"` either rejects (preferred) or normalises (acceptable) — assert behaviour is one of the two and is documented.
- `test_set_verification_result_persists_lastVerificationAt` — ISO-8601 timestamp set on every write.

### Integration tests

Cross-component within a service. Use existing in-package fixtures + mocks (S4) or `aiohttp`/`httpx` test servers (BFF). No real Cloud Run, no real Firestore.

#### S4 (Go) — `internal/api/handler_test.go::TestHandleVerify_SSEBranch_EventSequence` (T11)
Per task spec. Drives `HandleVerify` with `Accept: text/event-stream`, asserts:
1. `Content-Type: text/event-stream`, `Cache-Control: no-cache`, `Connection: keep-alive`, `X-Accel-Buffering: no` headers all present on the response.
2. Wire event order: `verify_start` → 8 × (`category_start`, `category_complete`) → `verify_complete` (8-category default; `test_pass` disabled per §Service definition `TEST_PASS_ENABLED=0`).
3. Each event payload conforms to D3 shape — see §Contract tests for the explicit shape assertions.
4. Existing Firestore mock receives the same `Report` it does in the JSON branch (persistence parity).
5. `http.Flusher` is asserted to be invoked at least once per event (no buffering of >1 event into a single flush).

#### S4 (Go) — `internal/api/handler_test.go::TestHandleVerify_BackwardsCompatNonSSE` (T4)
Per task spec. Three sub-cases (table-driven):
- (a) No `Accept` header → `Content-Type: application/json`, body is `QcReport`.
- (b) `Accept: application/json` → same as (a).
- (c) Firestore persistence invoked exactly once with the canonical `Report`.

T4 is the JSON-branch regression and the proof that the Accept-header guard is a single-branch early-return, not a duplicated run path.

#### BFF (Python) — `test_verify_stream.py` (T12 — see §Resilience for the fault-injection cases)
Happy path:
- `test_stream_ingest_terminal_complete` — feed canned SSE bytes (`verify_start` + 8 category-pairs + `verify_complete`) via httpx mock transport. Assert:
  - `set_verification_result(session_id, "pass", report)` invoked exactly once with the embedded report.
  - Each `event: verification` chunk reached `_verification_queues[session_id]` (drain queue and assert event sequence + count).
  - `_active_verify_streams[session_id]` is removed in the `finally` block (post-condition).

#### BFF (Python) — `test_e2e_verify_pipeline.py` (T13)
Per task spec. Mock S4 with a local `aiohttp` test server serving canned SSE on `POST /verify`. Cross-component:
1. `POST /session/{id}/build` callback (internal-secret header) lands → `start_s4_verify_stream` task spawns.
2. Subscribe to `GET /session/{id}/logs` SSE channel — assert `event: verification` chunks arrive in order matching the upstream canned sequence.
3. Terminal `verify_complete` causes `set_verification_result(session_id, "pass", report)` → assert via session-doc read or mock spy.
4. Total wall-clock < 30 s under normal scheduling.

This is the layer below Akali — it proves the chain works without a real S4 binary and without a real browser.

#### BFF (Python) — `test_e2e_reload_resume.py` (T14)
Per task spec. Mock S4 emits a slow stream (artificial delay between category events). Mid-stream, simulate page-reload by closing the BFF-facing SSE consumer. Then:
1. `GET /session/{id}/state` returns the unified shape from §D5: `verificationStatus: "in_progress"`, no progress fields populated (indeterminate seed, per D5 caveat — no replay buffer in v1).
2. Re-open SSE consumer; assert remaining `category_*` events arrive normally; terminal `verify_complete` lands on session doc.
3. **Dual-state assertion (T10 cross-ADR coupling, see §CC1).** If T10 ships under a transitional alias `/build-status`, run the same scenario twice — once issuing `GET /session/{id}/state` and once `GET /session/{id}/build-status`. Both must return the same unified body. Drop the alias half once ADR-1's rename to `/state` is in main.

### Contract tests

Pin the SSE event vocabulary in §D3 so frontend, BFF, and S4 cannot drift independently. Lives partly in T11 (Go side) and partly in T12 (Python side).

**Event vocabulary under test (per D3 — snake_case, NOT the kebab-case sketched in some upstream notes):**

| Event | Fields asserted present | Fields asserted typed |
|---|---|---|
| `verify_start` | `sessionId`, `projectId`, `totalCategories` | `totalCategories: int` |
| `category_start` | `category`, `index`, `totalCategories`, `name` | `index: int`, `0 <= index < totalCategories` |
| `category_complete` | `category`, `index`, `totalCategories`, `summary.{passed,failed,skipped}`, `duration_ms` | all ints; `duration_ms >= 0` |
| `verify_complete` | full `QcReport`: `status ∈ {pass, fail}`, `summary`, `checks[]` | `status` is exactly `"pass"` or `"fail"` (NOT `"passed"`/`"failed"`) |
| `verify_error` | `reason ∈ {config_fetch_failed, ws_unavailable, snapshot_failed, internal_error}`, `error: str`, optional `partialReport` | `reason` is from the closed enum |

S4-side contract assertions live inside T11 sub-cases:
- `TestSSEContract_VerifyStartShape` — table-test asserting required keys + types.
- `TestSSEContract_CategoryStartIndexMonotonic` — across the 8-category run, `index` is strictly increasing 0..7.
- `TestSSEContract_CategoryCompleteSummaryShape` — `summary` always has `passed`, `failed`, `skipped` as ints; sum equals total checks in that category.
- `TestSSEContract_VerifyErrorReasonEnum` — drive the run with each of the four `reason` paths (mock config client fail, mock WS-unreachable, mock snapshot fail, mock internal error); assert the emitted `reason` is the corresponding enum value, never an unbounded string.
- `TestSSEContract_TerminalEnumPassFail` — `verify_complete.report.status` is exactly `"pass"` or `"fail"` literally — no `"passed"` / `"failed"` regression.

BFF-side contract assertions in T12:
- `test_contract_status_enum_canonical` — every `set_verification_result` call sees one of `{"pass", "fail", "failed"}`. `"passed"` would raise. (Pairs with T7 status-enum unification chore.)
- `test_contract_event_passthrough_unchanged` — payloads forwarded via `emit_sse_event(session_id, "verification", payload)` are byte-equivalent to upstream (no BFF mutation of the wire shape — frontend depends on this).

**Frontend contract** is asserted transitively by T13 happy-path event-order assertion; an explicit frontend-side contract test is optional for v1 (component is small enough that ADR-1's existing assertions plus T13 cover it).

### Resilience / fault injection

The fault-injection lane. Each scenario is a deterministic test (no flakiness from real timing) that drives the system into a failure mode and asserts the documented response from §D7 / §D8.

#### R1 — S4 dies mid-stream (BFF connection drop) — covered by T12
Test: `test_stream_ingest_connection_drop`. Mock httpx transport raises `httpx.RemoteProtocolError` after the 4th `category_complete`. Assert:
- `set_verification_result(session_id, "failed", {reason: "stream_error", error: <str>})` invoked exactly once.
- Final `event: verification` with `{status: "failed", reason: "stream_error"}` enqueued before queue teardown.
- `_active_verify_streams[session_id]` removed in `finally`.

#### R2 — Malformed SSE chunk from S4 — covered by T12 + unit (`test_parse_sse_frame_malformed_chunk_dropped`)
Test: `test_stream_ingest_malformed_chunk_skipped` (T12 sub-case, NEW — flagged for Aphelios in §Reply gaps). Inject a chunk with bad JSON in `data:` between two valid category events. Assert:
- The malformed chunk is logged at warn level, dropped, and the stream continues processing subsequent valid chunks.
- The terminal event still reaches `set_verification_result`.
- The malformed chunk does NOT terminate with `stream_error` (transient parse error, not a connection failure).

> **Gap:** if Aphelios judges malformed-chunk handling should fail-loud (terminate stream → `stream_error`) instead, the test flips to assert termination. Pinging Aphelios in reply.

#### R3 — Stream stalls (60 s no event) — covered by T12 (`test_stream_stall_watchdog`, T6's home)
Per task spec. Mock httpx feeds 3 category events then stops emitting. Test scaffold either uses real `asyncio.sleep` with a fast-clock fixture (recommended: `pytest-asyncio` + `freezegun` or asyncio loop's `time` patched to advance) OR mocks `asyncio.wait_for` to raise `TimeoutError` directly. Assert:
- After the 60 s threshold expires, watchdog terminates with `set_verification_result(session_id, "failed", {reason: "stream_stalled", elapsed_s: 60})`.
- Final `event: verification` with `{status: "failed", reason: "stream_stalled"}` enqueued.
- Watchdog timer resets on every line received (assert with a 50 s gap + 1 line + 50 s gap scenario — should NOT trigger stall, total elapsed > 60 s but no single inter-event gap exceeds threshold).

#### R4 — Watchdog reset semantics edge — sub-case of R3
Test: `test_stream_stall_watchdog_resets_on_keepalive_comment`. If S4 emits SSE comments (`: keepalive\n\n`) every 30 s during a slow `gpay` category, those comment lines must reset the watchdog timer. Assert no `stream_stalled` over a 90 s window with comments at 30 / 60 s.

> **Gap:** D8.2 footnote acknowledges `gpay` may approach 60 s; if S4 doesn't actually emit keepalive comments today, this test exposes a real prod-stability hole. Pinging Aphelios — may need a T-impl follow-up to add S4-side keepalive emission. NOT adding the test-task unilaterally.

#### R5 — Idempotency on duplicate `start_s4_verify_stream` — covered by T12 (`test_stream_idempotent`)
Per task spec. Two concurrent `start_s4_verify_stream(session_id, project_id)` calls. Assert:
- Only one `_active_verify_streams[session_id]` entry exists.
- Only one outbound `POST /verify` is fired (mock httpx call count == 1).
- Second caller's coroutine returns immediately (noop).

#### R6 — `verify_error` mid-run from S4 — covered by T11 + T12
S4-side (T11): drive the run with mocked WS-unavailable error in the middle of `card_fields`. Assert handler emits `verify_error` with `reason: "ws_unavailable"` + a `partialReport` carrying the categories completed so far. Stream closes after.

BFF-side (T12): canned SSE ending in `verify_error`. Assert:
- `set_verification_result(session_id, "failed", {reason: "ws_unavailable", error: "...", partialReport: {...}})` invoked.
- Frontend receives final `event: verification` with `{status: "failed", reason: "ws_unavailable"}`.

#### R7 — S4 unreachable (Cloud Run cold start / network partition) — covered by T12
Test: `test_stream_ingest_open_fails`. Mock httpx transport raises `httpx.ConnectError` on stream-open (BEFORE any bytes arrive). Assert:
- `set_verification_result(session_id, "failed", {reason: "stream_error", error: "<connect error str>"})` invoked.
- Final `event: verification` with `{status: "failed"}` enqueued.
- No retry attempted (per OQ3 resolution — fast-fail in v1).

#### R8 — Status enum drift regression — covered by T7 + T12 contract
Grep-test (chore, runs in CI as part of T7):
- `scripts/ci/grep-no-passed-literal.sh` (or equivalent in existing CI) — `grep -rE 'verificationStatus.*"passed"|verificationStatus.*\\'"'"'passed\\'"'"''` over `tools/` + `apps/` returns zero hits. Hard-fail CI on regression.

#### R9 — Network partition mid-build-callback (idempotency-on-retry of upstream callback) — defensive
Test: `test_build_callback_retry_does_not_double_start_verify`. If factory S3 retries the `POST /session/{id}/build` callback (network blip, 5xx-then-2xx), the second invocation MUST hit the existing `_active_verify_streams[session_id]` idempotency guard and noop. Asserts the production-grade idempotency contract from §D7.

#### R10 — Concurrent builds for same session — punt-acknowledged in §D8.4 but assertion-cheap
Test: `test_concurrent_build_callbacks_single_verify_stream`. Fire two `POST /session/{id}/build` callbacks 100 ms apart. Assert exactly one `start_s4_verify_stream` task is active. (v1 single-user-single-build invariant — punted in §D8 but cheap to lock down at test time.)

### Khang-confirm gate

Phase A is gated per §CC2 and the Phase A preamble. The following test tasks are **blocked at dispatch** by the same gate:

- **T11 — S4 SSE handler tests** carries `gate: khang-confirm`. Cannot start until Khang acks the EXTEND posture.
- **T4 — Backwards-compat smoke for non-SSE callers** carries `gate: khang-confirm`. Same gate (it touches `internal/api/handler_test.go`).
- **T3 inline `sse_test.go`** is part of T3 (Khang-gated).

If Khang opts to own S4 implementation himself per §CC2 fall-through, **Xayah's Phase A test plan stays valid** — Khang implements against the same xfail tests; Phase A becomes a hand-off, the test layer is unchanged. Phase B/C/D test tasks (T12, T13, T14) are NOT Khang-gated and dispatch on their own schedule.

### Test artifacts expected

Files that land in the tree as part of test impl. Provides Aphelios + Sona a checklist.

#### Go side (Phase A)
- `tools/demo-studio-verification/internal/api/sse_test.go` — NEW (T3 companion).
- `tools/demo-studio-verification/internal/api/handler_test.go` — extended with `TestHandleVerify_SSEBranch_EventSequence` + sub-cases (T11) and `TestHandleVerify_BackwardsCompatNonSSE` (T4).
- `tools/demo-studio-verification/internal/checks/run_test.go` — extended with `TestRun_OnEvent*` family (T11 leaf).
- `tools/demo-studio-verification/internal/checks/testdata/` — fixtures for canned `QcReport` shapes asserted in contract tests. Specifically:
  - `testdata/qcreport_pass_8cat.json` — golden `verify_complete` payload (8 categories, all pass).
  - `testdata/qcreport_fail_branding.json` — `status: fail` with one branding failure (also referenced by Akali F4).
  - `testdata/qcreport_partial_ws_unavailable.json` — `partialReport` for `verify_error` cases.

#### Python side (Phases B + C + D)
- `tools/demo-studio-v3/tests/test_verify_stream.py` — NEW (T12 home — happy-path + 8 resilience sub-cases).
- `tools/demo-studio-v3/tests/test_verify_stream_unit.py` — NEW (T12 unit slice — frame parser + idempotency dict).
- `tools/demo-studio-v3/tests/test_e2e_verify_pipeline.py` — NEW (T13).
- `tools/demo-studio-v3/tests/test_e2e_reload_resume.py` — NEW (T14).
- `tools/demo-studio-v3/tests/fixtures/sse_canned/` — NEW directory holding canned SSE byte streams as `.txt` files:
  - `verify_pass_happy.sse` — full happy path.
  - `verify_fail_branding.sse` — fail-path terminal.
  - `verify_error_ws_unavailable.sse` — error-path terminal with `partialReport`.
  - `verify_stalled_3cat_then_silence.sse` — feeds 3 categories then silence (R3).
  - `verify_malformed_midstream.sse` — bad JSON `data:` in chunk 5 (R2).
- `tools/demo-studio-v3/tests/test_main.py` — extended (T7b `test_build_info_endpoint`).
- `tools/demo-studio-v3/tests/test_session.py` — extended (T7 status-enum unification).

#### CI scripts
- `scripts/ci/grep-no-passed-literal.sh` — NEW (R8 grep regression). Runs as a step in the existing PR-lint workflow alongside the existing markers checks.

#### Visual-review (T15)
- `assessments/qa-reports/2026-04-27-adr-2-verification-service-<rev-sha>/lulu-visual-review.md` — per task spec. Lives outside the test-impl tree; produced by Lulu, consumed by Sona at sign-off.

## QA Plan

**Akali Playwright script** (browser-environment isolation: incognito; ENV URL: `https://demo-studio-4nvufhmjiq-ew.a.run.app` once PR #120 lands, otherwise `https://demo-studio-266692422014.europe-west1.run.app`).

### Setup

1. Open incognito browser context (fresh, no cookies).
2. Navigate to ENV URL `/`.
3. **Sign in via real Firebase Auth flow** — click "Sign in with Google", complete OAuth in popup with `duong@missmp.eu`. **Do not use nonce URL bypass**, do not use any session-handoff URL parameter. The QA gate explicitly requires the real OAuth path (per project §Decisions 2026-04-27 and the trigger-learning around Akali's RUNWAY scope-gap on 2026-04-27). Capture screenshot `01-signed-in.png`.
4. Verify the deployed revision matches the head SHA under test: open browser console, fetch `/__build_info` (or equivalent revision marker exposed by BFF — confirm with breakdown). Capture `02-revision-match.png` showing the SHA. **PASS only if SHA matches.**

### Happy path (user flow)

(Per-step actions — happy path lane.)

| Step | Action | Pass criterion | Screenshot |
|---|---|---|---|
| 1 | Click "+ New session" → land in new session, `status == "configuring"` | ADR-3 default config visible. No progress bar. | `03-new-session.png` |
| 2 | Trigger build (mechanism per ADR-3/5; for QA assume "Deploy Demo" button) | Session transitions to `building`. ADR-1 progress bar appears. | `04-build-starting.png` |
| 3 | Wait for `build_complete` (network panel `text/event-stream` channel for `/session/.../logs` shows `event: build` with `build_complete` data) | Bar at 100%, label "Build complete". | `05-build-complete.png` |
| 4 | **Within 2 seconds of build_complete**, observe transition | Same component slot resets to indeterminate, label "Verifying demo…". **No page reload, no user click between build complete and verify start.** No agent chat message about verification starting. | `06-verify-starting.png` |
| 5 | Wait for first `category_start` event in network panel | Bar switches to determinate. Label reads e.g. "Checking identity & branding metadata…". `value` ≥ 0. | `07-verify-mid-1.png` |
| 6 | Wait until at least 3 `category_complete` events have been observed in DevTools network panel | Bar `value` ≥ 30% (3 of 8 categories). Label updated to a later category. | `08-verify-mid-2.png` |
| 7 | **Page reload mid-verify** (Cmd+R) | Bar reappears within 2 s at indeterminate "Verifying demo…" with the verify phase active. Network panel shows one `GET /session/{id}/state` (or `/verify-status`) call followed by re-opened `EventSource`. Subsequent SSE events advance the bar normally. | `09-verify-reload.png` |
| 8 | Wait for `verify_complete` | Bar at 100%, **green**, label "Verification passed". `report.status === "pass"` in network panel data. | `10-verify-passed.png` |
| 9 | Confirm session-doc state via `GET /session/{id}` (BFF debug or DevTools) | `verificationStatus === "pass"`, `verificationReport` populated, `projectId`, `demoUrl`, `projectUrl`, `shortcode` all present and non-empty, `lastVerificationAt` is recent. | `11-session-doc.png` |
| 10 | Open browser console | No JS errors. EventSource closed cleanly (readyState === 2). | `12-console-clean.png` |

### Failure modes (what could break)

Two failure-mode lanes are exercised as separate test runs: the verification-fail path (S4 returns `status: fail` for valid project state with bad config) and the verification-error path (S4 itself unreachable / stream errored). Both are required for sign-off.

#### Verification-fail path (separate test run)

Pre-condition: pre-set the session config to one that passes build but fails one or more verification checks (e.g. wrong logo URL → `branding` category fails).

| Step | Action | Pass criterion | Screenshot |
|---|---|---|---|
| F1 | Trigger build, wait until `build_complete` | ADR-1 happy path — build succeeds. | — |
| F2 | Wait for verification to start (per step 4 happy path) | Verify component appears as expected. | — |
| F3 | Wait for `verify_complete` | Bar at 100%, **amber/red**, label "Verification completed with issues — N failed" (N matches `report.summary.failed`). | `13-verify-failed.png` |
| F4 | Open `verificationReport` via DevTools | `status === "fail"`, `summary.failed >= 1`, `checks[]` includes failed `branding` check, `diagnosis[]` includes corresponding entry. | `14-verify-report.png` |

#### Verification-error path (separate test run)

Pre-condition: temporarily set `S4_VERIFY_URL` env on a one-off Cloud Run revision to a non-routable URL (or kill the S4 service). Restore after.

| Step | Action | Pass criterion | Screenshot |
|---|---|---|---|
| E1 | Trigger build, wait through `build_complete` | Build path normal. | — |
| E2 | Wait up to 5 s after build_complete | Verify component shows red bar with label matching `"Verification could not run — stream_error"` (or similar `reason` value per D8.1). | `15-verify-stream-error.png` |
| E3 | Confirm session doc | `verificationStatus === "failed"`, `verificationReport.reason === "stream_error"`. | `16-session-doc-error.png` |

### Acceptance criteria

(Pass / fail criteria for the QA gate.)

**PASS** if:
- All happy-path checkpoints render their expected UI within the time budgets (≤ 2 s for transition steps, total verify duration ≤ 120 s for typical projects).
- No JS console errors throughout.
- Network panel confirms the documented SSE event sequence (`verify_start` → ≥ 1 `category_start` → ≥ 1 `category_complete` → `verify_complete`).
- Session-doc shape matches §D6 contract.
- `head_sha:` of the deployed revision matches the commit under test (per QA two-stage architecture ADR D6.f).

**FAIL** if:
- Verification does not auto-start within 5 s of `build_complete` (DoD step 9 violation).
- Progress bar fails to update through at least 3 distinct category states (DoD step 10 violation).
- Session doc lacks any required field after terminal verify (D6 contract violation).
- Any FAIL/PARTIAL in Akali's report is `cite_kind: inferred` rather than `verified` (per QA two-stage ADR D2).

### QA artifacts expected

Akali deposits the following under `assessments/qa-reports/2026-04-27-adr-2-verification-service-<rev-sha>/`:

- **Screenshots (happy path):** `01-signed-in.png`, `02-revision-match.png`, `03-new-session.png`, `04-build-starting.png`, `05-build-complete.png`, `06-verify-starting.png`, `07-verify-mid-1.png`, `08-verify-mid-2.png`, `09-verify-reload.png`, `10-verify-passed.png`, `11-session-doc.png`, `12-console-clean.png`.
- **Screenshots (failure modes):** `13-verify-failed.png`, `14-verify-report.png`, `15-verify-stream-error.png`, `16-session-doc-error.png`.
- **QA report markdown:** `report.md` with the §QA two-stage ADR template — `head_sha:` frontmatter, per-step OBSERVE/VERIFY findings, each tagged `cite_kind: verified | inferred` with `cite_evidence:` (screenshot path or DevTools quote).
- **Network HAR (optional but preferred):** `network.har` capturing `/session/.../logs` SSE channel for the happy-path run, used for re-deriving the event sequence under audit.
- **Console log dump:** `console.log` from DevTools for the happy-path run, asserting JS-error-free.

PR body links the report folder via `QA-Report:` line per Rule 16.

### Citation discipline

`cite_kind: verified` markers required on every observation Akali claims. Inferred FAIL/PARTIAL claims must be hand-tagged for Senna review (per QA two-stage ADR D2).

## Out of scope

- **Build progress bar.** Owned by ADR-1. ADR-2 inherits the component.
- **Default-config greeting / new-session flow.** Owned by ADR-3.
- **Async agent chat narration of build/verify completion.** Owned by ADR-4. ADR-2 only commits to the session-doc output contract in §D6.
- **Trigger surface for build itself** (button vs agent tool). Owned by ADR-3 / ADR-5.
- **Verification job queue, durable progress, replay-after-S4-restart.** v1 single-user happy path. Out of scope.
- **Per-check granularity** (60+ check-level events instead of 8 category-level). Possible v2 if user research finds 8 events too coarse.
- **Cancel-verification button.** Out of scope per §D8.
- **Failure-mode UX beyond inline message.** Per project doc §Out of scope.
- **Additional check categories beyond the 8+1 today.** Service-evolution territory, not project-DoD territory.
- **Verification-service own-deploy pipeline changes.** This ADR adds SSE handling but does not change the deploy script, IAM config, or env-var surface.

## Open Questions for Duong

All nine OQs resolved by Duong via hands-off autodecide on 2026-04-27 (compact form: 1a 2-extend 3-no 4-60s 5-no 6-off 7-demoUrl 8-overwrite 9-task-it). Audit trail preserved below; resolutions are baked into §Service definition, §Architecture decisions, §Tasks, and the new §Cross-ADR coupling block above.

1. **`/build-status` vs `/state` endpoint shape.** ADR-1 introduces `GET /session/{sessionId}/build-status`; ADR-2 wants verify-state on the seed too. Three choices: (a) **rename ADR-1's endpoint to `/state` and amend ADR-1**, single endpoint covers both phases; (b) keep `/build-status` and add a sibling `/verify-status`, frontend calls both on reload; (c) keep `/build-status` and put verify fields on the same response. Recommend (a). **RESOLVED (hands-off-autodecide): (a) — rename to `/state`, ADR-2 commits to a single seed endpoint covering build + verify. ADR-1 amendment is owned by parallel-Sona; captured under §Cross-ADR coupling as a residual.**
2. **Is S4 (Khang's service) modifiable in this scope?** ADR-2 commits to extending `internal/checks.Run` + `HandleVerify` with SSE. If Khang's surface is frozen, we fall back to BFF-side synthetic progress — recommend NOT doing that. **RESOLVED (hands-off-autodecide): assume YES (modifiable). EXTEND posture stands. All Phase A tasks (T1, T2, T3, T4, T11) carry `gate: khang-confirm`; Aphelios's breakdown surfaces a Khang-confirm checkpoint before any S4-touching task starts.**
3. **Auto-retry on stream error.** Today: zero auto-retry (single user, fast-fail to "could not run" UX, user retriggers build). Should v1 retry once on `stream_error` with a 2 s back-off? Recommend NO. **RESOLVED (hands-off-autodecide): NO. Honest fast-fail to "could not run verification" UX; user retriggers the build. Defer retry/back-off policy to a follow-up.**
4. **Stream-stall threshold.** D8.2 proposes a 60 s no-event watchdog as "stalled". Some categories (especially `gpay` with HEAD-checks against external CDNs) may genuinely take > 30 s. Recommend 60 s as initial value; tune after first prod measurement. **RESOLVED (hands-off-autodecide): 60 s initial value. Footnote in D8.2 notes `gpay` HEAD-checks may approach the threshold; revisit if false-positive stalls observed.**
5. **Reload-mid-verify queue replay.** D5 documents that the asyncio `_verification_queues[session_id]` is consume-once today. If the user reloads after the queue drains but before terminal, indeterminate spinner persists until next event. **RESOLVED (hands-off-autodecide): NO replay buffer in v1. Reload-during-verify produces an indeterminate spinner until the next event. Punt to v2 if observed.**
6. **`test_pass` category in production.** D3 lists 9th category as opt-in via `TEST_PASS_ENABLED=1`. This category creates and downloads a real wallet pass — heavy I/O side effect on WS. Recommend `TEST_PASS_ENABLED=0`. **RESOLVED (hands-off-autodecide): `TEST_PASS_ENABLED=0` in prod. The 8-category bar is canonical. Documented in §Service definition.**
7. **Demo-link URL contract.** D6 says "demo link" surfaced to chat = `demoUrl` field. Confirm: is this the iPad-preview URL, the GPay-direct URL, or something else? Today `_apply_build_complete` writes both `projectUrl` (Wallet Studio admin link) and `demoUrl` (public demo). **RESOLVED (hands-off-autodecide): chat surfaces `demoUrl`; `projectUrl` only on user click ("Open in Wallet Studio"). ADR-2 commits to populating BOTH fields on the session doc; ADR-4 codifies the chat-surface choice.**
8. **Project-ID lifecycle across reverify.** v1 has no reverify (single build, single verify). If v2 adds reverify-without-rebuild, does `verificationReport` overwrite or append? **RESOLVED (hands-off-autodecide): overwrite (latest wins) — matches existing `set_verification_result(...)` semantics. Forward-looking note in D6: if v2 adds reverify-without-rebuild, revisit retaining prior report under `previousVerificationReport`.**
9. **Akali revision SHA marker.** §QA Plan step 4 references a `/__build_info` endpoint or "equivalent revision marker". Confirm with breakdown that this exists or task its creation; otherwise the head-SHA verification step in the QA gate is unenforceable. **RESOLVED (hands-off-autodecide): assume not yet present. New task T7b tasks creation of `/__build_info` (or equivalent revision marker) on demo-studio-v3 BFF so the QA gate's head-SHA verification step is enforceable.**

### Residuals (forward-looking, not blockers for promotion)

These are tracked in §Cross-ADR coupling below.

## Cross-ADR coupling

Forward-looking dependencies created by the OQ-resolution amendments. None block ADR-2 promotion; all are owned outside this plan.

### CC1 — ADR-1 endpoint rename `/build-status` → `/state` (from OQ1 resolution)

ADR-2 D5 commits to a single seed endpoint `GET /session/{sessionId}/state` covering both build and verify phases. ADR-1 currently introduces `GET /session/{sessionId}/build-status` (per ADR-1 §D6 / §QA Plan step 5). To honour the unified-seed decision, ADR-1 must be amended to:

- Rename the endpoint to `GET /session/{sessionId}/state`.
- Extend the response shape to include the verify-phase fields enumerated in ADR-2 D5 (so a single GET seeds both phases on reload).
- Update ADR-1's QA Plan step 5 (the page-reload-mid-build checkpoint) to reference `/state` instead of `/build-status`.

**Owner:** parallel-Sona's session (the coordinator who holds ADR-1). ADR-2 promotion does not block on this; both ADRs can land in parallel as long as the rename is completed before any T10-equivalent task in either ADR is dispatched. If ADR-1 ships first under `/build-status`, T10 in ADR-2 must include a transitional alias.

### CC2 — Khang-confirm gate on Phase A tasks (from OQ2 resolution)

S4 (`tools/demo-studio-verification/`) is owned by Khang. The EXTEND posture assumes the service is modifiable, but courtesy and operational continuity demand a Khang-confirm checkpoint before any S4-touching task starts.

**Affected tasks:** T1, T2, T3, T4, T11 (each carries `gate: khang-confirm` in §Tasks).

**Mechanism:** Aphelios's breakdown surfaces a single `gate: khang-confirm` checkpoint at the top of Phase A. Sona (or whoever dispatches Phase A) must confirm with Khang before kickoff. Confirmation can be lightweight — a Slack-thread "heads up, ADR-2 is extending S4 with SSE on `POST /verify`, expected churn ~1 source file + handler branch + tests, ETA Tuesday" — and acknowledgment unblocks all five tasks at once. The gate is a courtesy notification, not a re-litigation of the EXTEND decision.

**Failure mode:** if Khang signals he wants to own the S4 changes himself, Phase A converts to a hand-off (Aphelios writes the spec, Khang implements). Phase B / C / D / E are unaffected.

## Orianna approval

- **Date:** 2026-04-27
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan is impressively lean: EXTEND posture on S4 (one source file + handler branch + tests), one outbound BFF call replacing a broken poller, reuses ADR-1's progress component / multiplexer / UI-progress contract verbatim. All 9 OQs resolved by Duong hands-off-autodecide on 2026-04-27 with full audit trail; resolutions baked into §Service definition, §Architecture decisions, §Tasks, and the new §Cross-ADR coupling section. Owner clear (swain), §Tasks actionable across 5 phases with `tests_required: true` honoured by Phase D (T4, T11–T14). §QA Plan now carries the four canonical sub-headings (Acceptance criteria, Happy path, Failure modes, QA artifacts expected) plus Setup and Citation discipline — Akali Playwright script is concrete and deposit-path-explicit. Cross-ADR residual (ADR-1 `/build-status` → `/state` rename) is correctly captured as non-blocking and owned outside this plan.

## Orianna approval

- **Date:** 2026-04-27
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Third-pass gate. All structural checks pass (qa_plan frontmatter, qa_plan body with canonical sub-headings, §UX Spec linter). Plan has clear owner (swain), no unresolved gating TBDs (task estimates are explicitly delegated to Aphelios/Xayah per protocol), and concrete actionable tasks across 5 phases. Architectural posture (EXTEND S4 with SSE) is well-justified with explicit rejected alternatives (wrap, replace, polling, WebSocket, factory-trigger). All 9 OQs resolved with audit trail preserved; cross-ADR couplings (CC1 endpoint rename, CC2 Khang-confirm) correctly classified as forward-looking residuals rather than blockers. Output contract for ADR-4 (D6) is explicit and stable.

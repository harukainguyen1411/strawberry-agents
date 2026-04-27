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

(Skeleton — Aphelios + Xayah will detail estimate_minutes and substeps. Authoring agent does not assign implementers.)

### Phase A — S4 service: SSE streaming on `POST /verify`

> **All Phase A tasks carry `gate: khang-confirm`** (resolved OQ2 hands-off-autodecide 2026-04-27). S4 (`tools/demo-studio-verification/`) is owned by Khang. Aphelios's breakdown must surface a Khang-confirm checkpoint before any of T1/T2/T3/T4/T11 starts. The EXTEND posture (assume modifiable: YES) stands; this gate is a courtesy verification, not a re-litigation.

#### T1 — `internal/checks` event-sink hook
`kind: feature`
`estimate_minutes: TBD by Aphelios`
`gate: khang-confirm`

Refactor `checks.Run` to accept an optional `Options.OnEvent func(name string, payload any)` callback. Each category emits `category_start` before its `runX(...)` call and `category_complete` after, with a mini-summary. No behaviour change when `OnEvent == nil`.

#### T2 — Handler SSE response when `Accept: text/event-stream`
`kind: feature`
`estimate_minutes: TBD by Aphelios`
`gate: khang-confirm`

In `internal/api/handler.go::HandleVerify`, branch on Accept header. SSE branch:

- Set `Content-Type: text/event-stream`, `Cache-Control: no-cache`, `Connection: keep-alive`.
- Emit `verify_start` with totalCategories.
- Wire `Options.OnEvent` to flush each event to the writer (with `http.Flusher`).
- On `Run` completion, emit `verify_complete` with the full `Report`.
- On hard error mid-run (config fetch fail, WS snapshot fail), emit `verify_error` with the in-flight partial state.
- Persist Report to Firestore as today (unchanged).

JSON branch: existing behaviour, untouched.

#### T3 — SSE flush + tabbed-event encoding util
`kind: feature`
`estimate_minutes: TBD by Aphelios`
`gate: khang-confirm`

Helper for `event: <name>\ndata: <json>\n\n` formatting + flush. Reused by all event types.

#### T4 — Backwards-compat smoke for non-SSE callers
`kind: test`
`estimate_minutes: TBD by Xayah`
`gate: khang-confirm`

Verify existing curl-style `POST /verify` (no Accept header) still returns the JSON body identical to today. Persistence still hits Firestore.

### Phase B — BFF: replace S4 poller with streaming ingest

#### T5 — Delete `start_s4_poller` / `run_s4_poller` / `poll_s4_verify` / replace with `start_s4_verify_stream`
`kind: feature`
`estimate_minutes: TBD by Aphelios`

New module `tools/demo-studio-v3/verify_stream.py` with `start_s4_verify_stream(session_id, project_id)`. Idempotency identical to current `start_s4_poller` semantics. On terminal: calls existing `set_verification_result` + emits final SSE via existing `emit_sse_event`. Build callback path at `main.py:2748-2753` swaps `start_s4_poller` for `start_s4_verify_stream`.

#### T6 — Stream-stall watchdog (60 s no event)
`kind: feature`
`estimate_minutes: TBD by Aphelios`

Wraps the SSE-ingest loop with an inactivity timer. If no event arrives in 60 s, treat as stalled, write `failed reason=stream_stalled`, emit final `event: verification`.

#### T7a — Set `S4_VERIFY_URL` in BFF deploy env
`kind: chore`
`estimate_minutes: TBD by Aphelios`

Plumb the live `demo-studio-verification` Cloud Run URL into the BFF's prod and stg environment via `deploy.sh` / Cloud Run env config. Without this, every other change in this ADR is inert (per Existing-state §1). Confirm the URL via `gcloud run services describe demo-studio-verification --region=...`. Plumb `VERIFICATION_TOKEN` as `S4_VERIFY_TOKEN` (or named env consistent with BFF) into BFF env via Secret Manager — verify whether this secret already exists or needs creation.

#### T7b — Expose head-SHA via `/__build_info` on demo-studio-v3 BFF
`kind: feature`
`estimate_minutes: TBD by Aphelios`

Resolves OQ9 (hands-off-autodecide 2026-04-27). The Akali QA gate's revision-SHA verification step (§QA Plan setup step 4) needs an enforceable revision marker to confirm the deployed Cloud Run revision matches the head SHA under test. Today no such endpoint exists.

Add `GET /__build_info` to the demo-studio-v3 BFF returning `{revision: "<git-sha>", builtAt: "<iso-8601>", service: "demo-studio-v3"}` (or equivalent shape — bike-shed in breakdown). Source the SHA from a build-time-substituted env var (`BUILD_SHA`, plumbed via `deploy.sh` at image-build time). No auth — read-only, harmless metadata. CORS-permissive for fetch from the same-origin frontend console.

If a revision marker already exists under another path on demo-studio-v3 BFF (e.g. `/version`, `/healthz` body), reuse it and amend the QA Plan reference instead of adding a new endpoint — confirm during breakdown discovery.

#### T7 — Status enum unification
`kind: chore`
`estimate_minutes: TBD by Aphelios`

Update `verificationStatus` writes/reads across BFF + MCP tools (`mcp_tools.py:78-105`) to canonical `pass | fail | failed`. Update `_UPDATABLE_FIELDS` validator if needed. Update tests that assert `passed`/`failed` to `pass`/`fail`/`failed`.

### Phase C — UI integration

#### T8 — Frontend: extend progress component for verification source
`kind: feature`
`estimate_minutes: TBD by Aphelios`

Per D4. Source discriminator `'build' | 'verify'`, separate label tables, terminal state copy. Re-uses ADR-1's UI-progress contract. Owns the Lulu mapping table copy in §D4.

#### T9 — Frontend: subscribe handoff
`kind: feature`
`estimate_minutes: TBD by Aphelios`

On `event: build` `build_complete` arrival, hold component for 1.5 s, then reset and start consuming `event: verification` chunks from the same `EventSource`. No new connection.

#### T10 — `GET /session/{sessionId}/state` (or amend `/build-status`)
`kind: feature`
`estimate_minutes: TBD by Aphelios`

Per D5. Returns unified build+verify seed shape. Auth `require_session_or_owner`. For in-progress verify, no upstream call — returns indeterminate seed.

### Phase D — Tests

#### T11 — S4 SSE handler tests
`kind: test`
`estimate_minutes: TBD by Xayah`
`gate: khang-confirm`

Tests `POST /verify` SSE branch emits the documented event sequence in order (`verify_start` → 8× `category_start`/`category_complete` → `verify_complete`). Mock the WS + config clients.

#### T12 — BFF stream-ingest tests
`kind: test`
`estimate_minutes: TBD by Xayah`

xfail-first: feed canned SSE chunks into `start_s4_verify_stream` (httpx mock) and assert `set_verification_result` called once with the embedded report and that each `event: verification` chunk reaches `_verification_queues[session_id]`.

#### T13 — End-to-end `/session/{id}/logs` integration
`kind: test`
`estimate_minutes: TBD by Xayah`

Build callback success → BFF subscribes upstream → upstream emits 8 categories → BFF re-emits as `event: verification` chunks → terminal report lands on session doc within bounded time.

#### T14 — Page-reload resume integration
`kind: test`
`estimate_minutes: TBD by Xayah`

xfail-first. Mid-verify reload: `/state` returns indeterminate seed; SSE re-opens; remaining `category_*` events reach the bar.

### Phase E — Review

#### T15 — Component visual smoke (Lulu / Caitlyn)
`kind: review`
`estimate_minutes: TBD by Lulu`

Visual review of verify states (in-progress / pass / fail / error) on `feat/demo-studio-v3` deployment.

## Test plan

- All Phase D unit + integration tests green in CI.
- Akali QA Plan executes against `feat/demo-studio-v3` deployment with all checkpoints green.
- Status enum is `{pass, fail, failed}` everywhere (BFF + MCP tools + tests + frontend). Grep verifies no surviving `passed` literal.
- The deleted poller files do not regress (`grep -r 'start_s4_poller\|run_s4_poller\|poll_s4_verify' tools/demo-studio-v3/` returns nothing).
- Pre-push hook + CI green; PR e2e green; PR-lint detects required `Design-Spec:`, `Accessibility-Check:`, `Visual-Diff:`, `QA-Report:` markers.

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

---
slug: adr-1-build-progress-bar
title: "ADR-1 — Live build progress bar (factory S3 → studio v3 UI)"
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

DoD step 7 of `projects/work/active/bring-demo-studio-live-e2e-v1.md` requires the user to watch the build progress live with a visible progress bar. Today, on prod revision `demo-studio-00031-kc9` (validated by Akali earlier on 2026-04-27), the user clicks an action that triggers a build, the BFF returns `{buildId, projectId}` near-instantly, and there is **no per-step UI feedback** — only a `deployBtn` text flip from "Deploy Demo" → "Building..." → "Deployed" driven by coarse session-doc status events on the existing chat stream.

The architectural risk for this DoD step is overstated. Almost everything needed already exists; the gap is wiring + a UI component:

1. **Factory S3 already streams SSE.** `tools/demo-studio-factory/openapi.yaml:128-239` documents `POST /build` (and `/build-from-direct-config`) emitting four event types over a 10-step pipeline:
   - `step_start` — `{step, totalSteps: 10, name}`
   - `step_complete` — `{step, name, duration_ms}`
   - `step_error` — `{step, name, error}` (always followed by `build_error`)
   - `build_complete` / `build_error` — terminal, stream closes.
   - Factory exposes a per-build-id replay endpoint `GET /build/{buildId}/events` (consumed today by the BFF — `tools/demo-studio-v3/main.py:412-460`).
2. **The BFF already proxies and multiplexes the stream.** `tools/demo-studio-v3/main.py:2770-2854` implements `GET /session/{session_id}/logs` — auth-gated by `require_session_or_owner`, multiplexes S3 build events (tagged `event: build`) and S4 verification events (tagged `event: verification`) into one SSE stream the browser can subscribe to. It also handles fallback GET when the upstream stream closes without a terminal event.
3. **Terminal events already update session-doc state for the chat agent.** `_apply_build_complete` / `_apply_build_failed` write `shortcode`, `projectUrl`, `demoUrl`, `outputUrls`, and `status` — the agent observes via the existing chat `/stream` on the next turn (see ADR-4 for asynchronous push of completion into chat).

What is missing for DoD step 7:

- The frontend does not open an `EventSource` against `/session/{id}/logs` — only against `/session/{id}/stream` (chat agent activity). It has no progress component.
- There is no UI element that renders step-by-step progress. Two parallel build-trigger paths exist today, neither with granularity: (a) the `deployBtn` (UI affordance — hidden by default via `display: none`, only revealed by `showDeployButton()` when an SSE event carries `awaitingApproval: true` or the agent's text matches `/ready to deploy|approve|click.*deploy/i`), and (b) the agent's `trigger_factory` tool, which fires a build directly from the chat path with no UI surface at all. The `deployBtn` carries only a coarse text flip ("Deploy Demo" → "Building…" → "Deployed"); the `trigger_factory` path emits no UI feedback at all beyond the chat session-doc status events. ADR-1 must mount the progress component on the `status: building` SSE event regardless of which trigger path fired the build, since the chat-driven `trigger_factory` path is the more common in practice and never touches `deployBtn`.
- No documented contract for how progress is split between "UI-only" (per-step) vs "agent-observable" (terminal). Without this contract, ADR-4 (async agent notifications) cannot cleanly decide what to push into chat.

Note on the project-level constraint that "Build button is **not** an agent tool call": today the agent invokes `trigger_factory` (and a separate `POST /session/{id}/build` endpoint exists at `main.py:2635`, internal-secret gated). Reconciling button-vs-tool for DoD step 6 is **out of scope for ADR-1** and is owned by ADR-3 (default-config greeting / new-session flow) or ADR-5 (conflict sweep). ADR-1 assumes a build is in flight (a `buildId` exists on the session doc) and renders progress regardless of how it was triggered.

## Goal

When the user is in a session with `status == "building"`, the studio UI shows a visible, live-updating progress bar:

- A visual bar fills from 0% → 100% as `step_complete` events arrive (10 steps → 10% per step).
- A textual current-stage label reads the human-readable step name (e.g. "Building iOS template…").
- A failure path renders the failed step name and the error message inline (no toast).
- The bar reaches 100% on `build_complete` and disappears (or transitions to a "Build complete — verifying…" placeholder owned by ADR-2) on terminal success.
- Survives a full page reload mid-build: the component re-subscribes by `buildId` (already on the session doc) and resumes from current factory state, with no duplicated state corruption.

The architectural decision answers four questions:

1. **Does factory S3 emit progress?** Yes, already. SSE, four event types, 10 steps. No factory change required.
2. **What transport?** Existing BFF SSE multiplexer at `GET /session/{session_id}/logs`. No new transport, no WebSocket, no new endpoint.
3. **What UI surface?** A `<progress>` + status-label component bound to the existing `currentStatus === "building"` state, in the studio main column near the existing `deployBtn`.
4. **Does the chat agent observe via the same channel?** No — clean separation. The agent observes terminal state via session-doc updates already written by `_apply_build_complete`; ADR-4 owns the chat-side push. The `/logs` SSE is the **UI-only** progress channel. This pre-shapes ADR-4 cleanly: it depends on terminal-event session-doc fields (`status`, `demoUrl`, `projectUrl`), not on the SSE stream.

## Architecture decisions

### D1 — Reuse the existing S3 SSE stream and BFF multiplexer end-to-end. No new transport, no new endpoint, no factory change.

Frontend opens an `EventSource('/session/{sessionId}/logs')` whenever the session enters `status == "building"`. It listens for `event: build` chunks, parses the embedded SSE event type from the data payload (`step_start`, `step_complete`, `step_error`, `build_complete`, `build_error`), and updates the progress component. The connection closes naturally when the upstream factory stream closes after a terminal event, or when the user leaves the session.

**Rejected alternatives:**

- **WebSocket.** Cloud Run supports WS but with quirks (idle-timeout reconnects, no native server-push reconnection). Build is short (typically <2 min); SSE auto-reconnect is sufficient and simpler. Using WS would force a parallel transport for verification too (ADR-2) when it already shares this multiplexer.
- **Long-poll on `GET /build/{buildId}` status.** Loses per-step granularity unless we change S3 to expose interim status, which violates the "no factory change" simplicity preference. Polling at 1Hz also wastes Cloud Run cycles for a 10-step pipeline that emits ~20 events total.
- **A new dedicated `/session/{id}/build/progress` endpoint.** Strictly redundant with `/session/{id}/logs` which already does multiplexed SSE with auth. Adding a second SSE endpoint per session would force two `EventSource` connections (one for build, one for verify) and complicate cleanup.

**Why this is justified by the simplicity rule:** the multiplexer endpoint and upstream SSE both exist and are tested. The only additions are (a) a frontend subscriber and (b) a UI component. No new server code paths.

### D2 — Define a thin **UI-progress contract** that wraps the raw factory event stream. Frontend never depends on factory wire-shape directly.

Introduce a small frontend translator (`buildProgress.js` or a function block in `studio.js`) that consumes **pre-parsed** factory event objects (shape: `{type, step?, totalSteps?, name?, error?}`) and produces a UI-progress object. The frontend `EventSource` layer parses raw SSE chunks; the translator transforms parsed objects only — clean separation of parse-from-translate (resolved 2026-04-27 hands-off-autodecide for X1, decision log `2026-04-27-adr-1-breakdown-oqs.md`).

```ts
type BuildProgress = {
  status: 'in_progress' | 'complete' | 'failed';
  step: number;          // 1..10 (current or last-completed)
  totalSteps: number;    // 10 today, sourced from step_start.totalSteps
  stepName: string;      // human-readable e.g. "Building iOS template"
  percent: number;       // 0..100, derived: (lastCompletedStep / totalSteps) * 100
  error?: { code: string, message: string };
}
```

`stepName` is derived from `step_start.name` via a small mapping table (the 10 step names are stable; mapping table lives in the frontend so factory can rename internal step keys without breaking copy). `percent` is computed from `step_complete.step` (not `step_start.step` — only completed steps fill the bar).

**Why this contract exists:** it is the single load-bearing seam between factory's wire shape and the UI. If factory pipeline grows from 10 to 12 steps, `totalSteps` updates dynamically from `step_start`. If factory renames `build_ios_template` → `compile_ios_template`, only the mapping table changes. The contract also makes ADR-4 trivial: it does NOT consume the contract; it only consumes session-doc terminal fields.

### D3 — Progress bar mounts above the chat input, full-column-width. Native `<progress>` indeterminate while waiting for the first `step_start`, then determinate as events arrive.

Render a single composite directly above the chat input row (full main-column width — not in the right-side iPad demo panel, not below the chat header):

- A native `<progress max="100" value="...">` element. The browser's built-in `<progress>` (no `value` attribute) handles the indeterminate state — accessibility and styling come for free, no custom spinner CSS, no new dependencies.
- A small label reading "Step N of 10 — {stepName}".
- ARIA: `role="progressbar"` with `aria-valuenow` / `aria-valuemax` / `aria-valuetext` for screen readers.
- Initial state when `status == "building"` but no events received yet: native indeterminate `<progress>` with label "Starting build…". On first `step_start`, set `value` and switch to determinate.
- Failure state: red bar + error message inline; both **auto-clears on next build retry** AND offers a manual dismiss button (close icon) for users who want to read the error and walk away. The two dismiss mechanisms are non-overlapping: auto-clear fires on the next `status == "building"` transition; manual dismiss simply unmounts the component.

**Rejected alternatives:**

- **Modal overlay.** Too heavy; build is short and the user should still see chat updates from the agent narrating the build (ADR-4).
- **Floating toast.** Hides on scroll; bad for accessibility; makes it harder to verify in Akali's screenshot suite.
- **In-chat progress message.** Mixes build telemetry with conversation; muddies the agent's role (which observes, not narrates step-by-step). Single in-chat message on completion is fine — that's ADR-4's surface.
- **Below chat header / in iPad demo panel.** The demo panel is reserved for the live preview of the wallet; mixing build progress there fights the panel's purpose. Below the chat header pushes chat content down on every build. Above the input keeps progress visually adjacent to the trigger affordance and out of the chat scroll region.
- **Custom CSS spinner for indeterminate state.** Reinvents what `<progress>` ships natively. Loses platform-default accessibility semantics. Rejected per simplicity rule.

### D4 — Resume-by-buildId on page reload. Component reads `buildId` from session doc, opens `/session/{id}/logs`, and re-renders from current factory state.

The BFF's `s3_build_sse_stream` already calls `GET /build/{buildId}/events` on the upstream factory, which returns from current state — early steps that already completed won't replay, but the in-flight `step_start` (if any) plus future `step_complete` events do arrive. To recover lost progress, the frontend on subscribe-after-reload performs a one-shot `GET` against the existing factory `/build/{buildId}` status endpoint (already used by the BFF's `_sse_fallback_get` at `main.py:344`) to seed the bar to the current step before SSE events fan in.

If the build already terminated before the user reloaded, the SSE will be empty; the session doc's `status` field (`complete` / `failed`) drives the final UI state — same as today.

**Cross-ADR contract:** ADR-1 introduces (or reuses) a frontend-callable `GET /session/{sessionId}/build-status` BFF endpoint that returns `{step, totalSteps, status, stepName}` — this seed call. If the BFF doesn't already expose this for the frontend (today `_sse_fallback_get` is server-side only), ADR-1 adds it. Single-method, single-shape, no auth surprises (reuses `require_session_or_owner`).

### D5 — Cross-ADR contracts (called out explicitly):

- **ADR-1 → ADR-2 (verification progress).** ADR-2 reuses the same `/session/{id}/logs` multiplexer and the same UI-progress contract shape (D2), parameterised by source (`event: build` vs `event: verification`). On terminal `build_complete`, the build bar dwells at 100% for **1.5 seconds** (long enough for the user to register the win, short enough to keep momentum), then **hard-swaps** to the verification bar in the same DOM slot with a **200ms color shift** transition (build-blue → verify-green) — no fade, no slide, no reflow. One UI component, two data sources, no duplication, no perceptible latency.
- **ADR-1 → ADR-4 (async agent notifications).** ADR-1 does **not** push events into chat. The agent observes terminal state via session-doc fields written by `_apply_build_complete` / `_apply_build_failed` (already implemented). ADR-4 owns the mechanism that signals the agent that a build terminated (chat-side push or agent-loop poll). ADR-1's frontend may emit a single chat message on terminal events ("Build complete — preparing verify…") but this is a **UI-rendered system message**, not an agent message. Final agent response on completion is ADR-4's surface.
- **ADR-1 → ADR-3 (default-config greeting) / ADR-5 (conflict sweep).** ADR-1 is decoupled from how the build was triggered. Whether `trigger_factory` is a tool call or a button-fired `POST /session/{id}/build`, ADR-1 needs only a `buildId` on the session doc. Reconciling the trigger surface is owned by ADR-3 / ADR-5.
- **No factory S3 changes.** ADR-1 commits to **zero** changes in `tools/demo-studio-factory/`. If breakdown discovers a missing event needed for UX, the cost (factory PR, deploy, version-pin) must be re-scoped via plan amendment — the simplicity rule says: do not justify factory changes from the UI side without a hard invariant.

### D6 — Page-reload resume: seed via `GET /session/{sessionId}/build-status`, then SSE fans in.

Add a small read-only BFF endpoint `GET /session/{sessionId}/build-status`:

- Auth: `require_session_or_owner` (same as `/logs`).
- Returns `{buildId, status, step, totalSteps, stepName, projectUrl?, demoUrl?, error?}`.
- For `status == "building"`: makes a single upstream `GET /build/{buildId}` call to factory, parses the latest step from response (factory documents this in `openapi.yaml`), returns it.
- For terminal states: returns directly from session-doc fields (`status`, `projectUrl`, `demoUrl`, `error.reason`).
- **No caching.** Two reloads in 5 seconds = two upstream factory calls. Single-user happy-path v1 doesn't justify defensive caching; revisit in v2 if real traffic shows hot-spotting (resolved 2026-04-27 hands-off-autodecide for X2, decision log `2026-04-27-adr-1-breakdown-oqs.md`).

Frontend startup sequence on page-load with `status == "building"`: (1) call `/build-status` once → seed the bar; (2) open `EventSource('/session/{sessionId}/logs')` → fan in subsequent steps.

This avoids a flash-of-empty-progress on reload and keeps the SSE stream as the only event-shape source-of-truth in steady state.

## UX Spec

### User flow

1. User is in a session, `status == "configuring"`. No progress bar visible. `deployBtn` is hidden (`display: none`) until the agent reaches `awaitingApproval`; if the build is going to be triggered via the chat-driven `trigger_factory` path, the user may never see `deployBtn` at all in this flow.
2. Build is triggered. Two paths are equally valid and both must mount the progress component: (a) agent invokes `trigger_factory` (no UI affordance, common path), or (b) user clicks `deployBtn` after it appears on `awaitingApproval` (UI affordance, less common). Trigger-surface reconciliation is owned by ADR-5 — ADR-1 stays trigger-agnostic. Session doc transitions `configuring` → `building` and gains a `buildId`.
3. Chat `/stream` emits `status: building`. Frontend **mounts the progress component above the chat input**, full-column-width — regardless of whether `deployBtn` is currently visible. If `deployBtn` is visible (path b), it retains its coarse "Building…" text-flip (unchanged from today); if it is hidden (path a), the progress component is the sole UI signal. The progress component is additive, not a replacement, in both cases.
4. Frontend opens `EventSource('/session/{sessionId}/logs')`. While zero events received, component shows the **native `<progress>` indeterminate state** with label "Starting build…".
5. First `step_start` arrives. Component switches to determinate. Bar shows 0% with label "Step 1 of 10 — {softened step copy from T4}".
6. Each `step_complete` advances the bar by 10%; label updates to the next softened step copy on the next `step_start`.
7. Terminal `build_complete`: bar fills to 100%, label reads "Build complete". Component **dwells at 100% for 1.5 seconds**, then **hard-swaps with a 200ms color shift** (build-blue → verify-green) to ADR-2's verification progress in the same DOM slot.
8. Failure path (`step_error` → `build_error`): bar freezes at last completed step, turns red, label reads "Build failed at {stepName}: {error.message}". Component stays mounted with **two non-overlapping dismiss mechanisms**: (a) **auto-clear on next build retry** — the next `configuring` → `building` transition unmounts the failed bar and remounts a fresh one; (b) **manual close button** (×) inside the failed bar — clicking it unmounts immediately, leaving the user in the existing failed-state UI of `deployBtn`.

### Component states

| State | Bar | Label | Visible? | Position |
|---|---|---|---|---|
| `configuring` | — | — | hidden | — |
| `building` (no events yet) | native `<progress>` indeterminate | "Starting build…" | visible | above chat input, full-width |
| `building` (step N) | determinate, value = (N-1)*10 → N*10 | "Step N of 10 — {softened stepName}" | visible | above chat input, full-width |
| `complete` | 100% | "Build complete" | visible **1.5s**, then **hard-swap with 200ms color shift** to verify bar (ADR-2) | same slot |
| `failed` | last value, red, with × close button | "Build failed at {stepName}: {message}" | visible until **auto-clear on retry** OR **× clicked** | above chat input, full-width |

### Responsive behavior

Component is single-line on desktop (≥768px): bar inline left, label right. On mobile (<768px), label wraps below the bar. Bar fills 100% of available container width. No fixed pixel widths.

### Accessibility (per process.md floor)

- `role="progressbar"` with `aria-valuenow`, `aria-valuemax="100"`, `aria-valuetext="Step 3 of 10, Building iOS template"`.
- Color-contrast for both default and failed states meets WCAG AA against the studio background.
- Failed state announces via `aria-live="polite"` so screen readers narrate the failure without trapping focus.
- Keyboard-dismissible when in failed state (Escape closes dismiss button, Enter activates).

### Wireframe reference

Local wireframe to be authored by Lulu during the §UX Spec review pass — no Figma frame required for v1 (single component, no novel pattern, placement and states fully specified above). Suggested location: `assessments/personal/2026-04-27-adr-1-build-progress-bar-wireframe.md` with an inline SVG or annotated screenshot showing: (a) the bar above the chat input, (b) the indeterminate state, (c) determinate at step 5 of 10, (d) the failed state with × close button, (e) the 100%-with-color-shift hand-off frame.

## Tasks

(Skeleton — Aphelios + Xayah will detail estimate_minutes and substeps. Authoring agent does not assign implementers.)

### T1 — Add `GET /session/{sessionId}/build-status` BFF endpoint

`kind: feature`
`estimate_minutes: TBD by Aphelios`

Wire a read-only endpoint returning `{buildId, status, step, totalSteps, stepName, projectUrl?, demoUrl?, error?}`. Auth via `require_session_or_owner`. For `status == "building"`, performs one upstream `GET /build/{buildId}` to factory; for terminal states, returns from session-doc fields directly.

### T2 — Frontend: build-progress component

`kind: feature`
`estimate_minutes: TBD by Aphelios`

New module `static/buildProgress.js` (or function block in `studio.js`). Exposes `mount(sessionId, container)`, `unmount()`, `seed(buildStatus)`, `applyEvent(rawSseChunk)`. Implements the UI-progress contract from D2.

### T3 — Frontend: subscribe to `/session/{sessionId}/logs` for build events

`kind: feature`
`estimate_minutes: TBD by Aphelios`

On `status == "building"`, mount component, call `/build-status` for seed, open EventSource against `/logs`, route `event: build` chunks into `applyEvent`. Tear down on terminal event or session change.

### T4 — Step-name mapping table

`kind: feature`
`estimate_minutes: TBD by Aphelios`

Frontend constant mapping the 10 factory step keys (`clone_blank_template`, `rename_and_apply_colors`, `upload_logos`, `build_ios_template`, `build_google_wallet`, `build_token_ui`, `upsert_params_and_translations`, `create_journey_actions`, `publish_token_ui_and_ios`, `generate_test_pass`) to user-facing copy. Lulu owns the copy.

### T5 — Failure-state rendering with dual-dismiss

`kind: feature`
`estimate_minutes: TBD by Aphelios`

Renders red bar + step-name + error.message inline. Implements **both** dismiss paths:
- **Auto-clear on retry** — the next `configuring` → `building` transition unmounts the failed bar and remounts a fresh indeterminate one. No flicker.
- **Manual close button** (× icon) inside the failed bar — keyboard-accessible (Enter/Space), unmounts on click, returns user to existing `deployBtn` failed-state UI.

The two paths are non-overlapping: auto-clear is event-driven, manual close is user-driven. Either fires independently.

### T6 — Page-reload resume integration test

`kind: test`
`estimate_minutes: TBD by Xayah`

xfail-first test: reload page mid-build, assert `/build-status` is called once, then `EventSource` opens, then progress reflects current step within 2 seconds.

### T7 — Unit tests for UI-progress contract translator

`kind: test`
`estimate_minutes: TBD by Xayah`

Pure-function tests of `applyEvent` against canned **pre-parsed event objects** (per D2-X1 resolution): `step_start`, `step_complete`, `step_error`, `build_complete`, `build_error`, malformed/unknown event names (must no-op without crash). Rakan reads both this section and §Test plan (Xayah's TX-* tests) and unifies fixture names + mock-factory shape inline during xfail authoring — no upfront contract document needed (resolved 2026-04-27 hands-off-autodecide for K1, decision log `2026-04-27-adr-1-breakdown-oqs.md`).

### T8 — Component visual smoke (Lulu / Caitlyn)

`kind: review`
`estimate_minutes: TBD by Lulu`

Visual review of the rendered component on `feat/demo-studio-v3` deployment against the §UX Spec wireframe.

### T9 — Hand-off transition stub (ADR-2 seam)

`kind: feature`
`estimate_minutes: TBD by Aphelios`

Implement the 1.5s dwell + 200ms color-shift hard-swap mechanism on `build_complete`. ADR-1 ships the dwell timer and the color-shift CSS class; the `verify` mode of the same component is wired up later in ADR-2. Until ADR-2 lands, the post-hand-off slot shows a placeholder bar in `verify-green` with label "Verifying…" indeterminate. This is the documented seam between ADR-1 and ADR-2 — both ADRs amend the same component.

**Implementation mechanism (X3 resolution 2026-04-27 hands-off-autodecide, decision log `2026-04-27-adr-1-breakdown-oqs.md`):** Use `element.classList.replace('progress--build', 'progress--verify')` on the same DOM node — DO NOT use `replaceChild` or any node-swap. The QA Plan FAIL guard explicitly forbids node-swap (TX-seam-2 hard-asserts DOM-node identity across the transition). Color values defined in CSS variables `--progress-build-color` / `--progress-verify-color`; the 200ms transition is a CSS `transition: background-color 200ms ease-out` on the bar element.

## Task breakdown (Aphelios)

Authored 2026-04-27. Impl pair: `viktor` (complex builder; mixed-lane — handles both BFF Python/FastAPI and frontend JS/CSS for ADR-1; Seraphine reserve only) + `rakan` (complex test-impl). Lulu owns the T4 copy table per `qa_co_author` frontmatter. Base branch is `feat/demo-studio-v3` (not main); all impl PRs ride PR #32. No factory-S3 changes (D1). No new SSE endpoint beyond the read-only `/build-status` GET seed (D5/D6).

Critical-path estimate (longest dep chain): **T7 → T2 → T3 → T9 → T5 → T8 ≈ 235 minutes** of serial work. Several tasks are slice-candidates (see flags) — actual wall-clock with parallel dispatch is shorter.

Test-plan coupling with Xayah: T6 (xfail integration) + T7 (unit-fixture suite) reference the test_plan_ref Xayah is authoring in parallel. T7 fixtures (canned SSE chunks) MUST land before T2 implementation can land green; sequencing enforced by `dependencies: T7` on T2. T6 integration scaffold can be authored before T1, but its assertions go green only after T1+T2+T3 ship.

- [ ] **T1** — BFF endpoint `GET /session/{sessionId}/build-status`. estimate_minutes: 35. Files: `tools/demo-studio-v3/main.py`, `tools/demo-studio-v3/tests/test_build_status_endpoint.py`. kind: impl. owner_pair: viktor (impl) / rakan (test). parallel_slice_candidate: no. dependencies: none. DoD: route registered with `require_session_or_owner` auth; for `status == "building"` performs exactly ONE upstream `GET /build/{buildId}` to factory and returns `{buildId, status, step, totalSteps, stepName, projectUrl?, demoUrl?, error?}`; for terminal states returns directly from session-doc fields without upstream call (verified by mock-call counter); 5 unit tests cover all five states (configuring / building-with-buildId / building-no-events-yet / complete / failed); pre-commit hook green; xfail test from rakan precedes impl commit on the same branch (Rule 12).

- [ ] **T2** — Frontend build-progress component module. estimate_minutes: 55. Files: `tools/demo-studio-v3/static/buildProgress.js` (new), `tools/demo-studio-v3/static/buildProgress.css` (new). kind: impl. owner_pair: viktor (impl) / rakan (unit fixtures via T7). parallel_slice_candidate: no. dependencies: T7. DoD: exports `mount(sessionId, container)`, `unmount()`, `seed(buildStatus)`, `applyEvent(rawSseChunk)`; `applyEvent` implements the D2 contract translator (`step_start` / `step_complete` / `step_error` / `build_complete` / `build_error`); unknown event names no-op without crash; native `<progress>` indeterminate when no events yet, determinate after first `step_start`; ARIA attributes per state table in §UX Spec; T7 unit suite green against the implementation; no new dependencies beyond what `studio.js` already imports.

- [ ] **T3** — Subscribe to `/session/{sessionId}/logs` and route `event: build` chunks. estimate_minutes: 35. Files: `tools/demo-studio-v3/static/studio.js`. kind: impl. owner_pair: viktor / rakan. parallel_slice_candidate: no. dependencies: T1, T2. DoD: on session `status` transition to `"building"`, frontend calls `GET /session/{id}/build-status` exactly once (network-panel verifiable), then opens `EventSource('/session/{sessionId}/logs')`; only `event: build` chunks routed into `applyEvent` (verification chunks ignored — that's ADR-2); `EventSource` torn down on terminal event (`readyState === 2`) AND on session change (verified by no-leaked-listeners test); no double-mount on rapid re-render (idempotent `mount`); page-reload path runs the same seed-then-subscribe sequence.

- [ ] **T4** — Step-name mapping table (Lulu copy). estimate_minutes: 25. Files: `tools/demo-studio-v3/static/buildProgress.js` (constant block at top of module). kind: impl. owner_pair: viktor (wires constant) / lulu (authors copy — qa_co_author frontmatter binds her to final UI copy). parallel_slice_candidate: yes (independent of T2 logic; pure data; Lulu authors the 10 strings while Viktor wires T2 plumbing — merges trivially). dependencies: none. DoD: ten softened user-facing strings (one per factory step key listed in skeleton T4) exported as `STEP_COPY` const map; Lulu sign-off recorded as `Copy-Owner: Lulu` trailer on the impl commit (NOT `Co-Authored-By:` — Rule 21); strings render correctly in T2 component for all 10 step keys; T8 visual-smoke confirms copy reads naturally on the deployed revision.

- [ ] **T5** — Failure-state rendering with dual-dismiss (auto-clear + manual ×). estimate_minutes: 40. Files: `tools/demo-studio-v3/static/buildProgress.js`, `tools/demo-studio-v3/static/buildProgress.css`. kind: impl. owner_pair: viktor / rakan. parallel_slice_candidate: no. dependencies: T2, T9. DoD: red-bar state mounts on `step_error` → `build_error`; bar `value` freezes at last completed step (verified by unit test against canned chunk); inline label reads `"Build failed at {STEP_COPY[stepName]}: {error.message}"`; × button is keyboard-accessible (Tab focus, Enter/Space activate, Escape closes per §UX Spec); auto-clear path: next `configuring → building` transition unmounts failed bar and remounts indeterminate one in a single repaint (no flicker — verified by render-count assertion); manual × click unmounts immediately and restores `deployBtn` to enabled state; `aria-live="polite"` on the failed-state region.

- [ ] **T6** — Page-reload resume integration test (xfail-first, then green). estimate_minutes: 50. Files: `tools/demo-studio-v3/tests/integration/test_build_progress_resume.py` (new) OR Playwright spec under the e2e suite — chosen by rakan in coordination with Xayah's test plan. kind: test. owner_pair: rakan (author) / viktor (debug if green-path fails). parallel_slice_candidate: yes (test file is independent of impl files; xfail can land before T1/T2/T3; rakan can author scaffolding while Viktor builds T1 in parallel). dependencies: Xayah's test plan ref must land first (provides fixtures + assertion vocabulary); xfail commit lands BEFORE T1 impl on the same branch (Rule 12). DoD: xfail test committed first with `@pytest.mark.xfail(reason="ADR-1 T1+T2+T3 not yet implemented")` and a plan/task reference comment; after T3 lands, test removes xfail and asserts: (a) on page reload mid-build, `GET /session/{id}/build-status` is invoked exactly once before EventSource opens; (b) progress component renders the current step within 2 seconds of reload; (c) no duplicate `EventSource` instances; (d) `head_sha` of the test environment matches the commit under test (per QA two-stage ADR D6.f).

- [ ] **T7** — Unit tests for UI-progress contract translator (`applyEvent`). estimate_minutes: 45. Files: `tools/demo-studio-v3/static/__tests__/buildProgress.test.js` (new), `tools/demo-studio-v3/static/__tests__/fixtures/sse-chunks.js` (new). kind: test. owner_pair: rakan / viktor. parallel_slice_candidate: yes (pure-function fixture suite; can be authored fully against the D2 contract spec without waiting on T2 impl). dependencies: Xayah's test plan ref (fixture-naming convention). DoD: canned SSE chunk fixtures cover all five real event types (`step_start`, `step_complete`, `step_error`, `build_complete`, `build_error`) plus one malformed/unknown-name fixture; pure-function tests of `applyEvent` assert the resulting `BuildProgress` object matches the D2 contract for each input; malformed fixture returns previous state unchanged (no throw); CI runs the suite via the existing pre-commit jest harness; 100% line coverage of `applyEvent` (sharp gate — no missed branches).

- [ ] **T8** — Component visual smoke review (Lulu / Caitlyn). estimate_minutes: 30. Files: `assessments/qa-reports/2026-04-27-adr-1-build-progress-bar-rev<NNNNN>-<short-sha>.md` (new — review report). kind: review. owner_pair: lulu (visual sign-off) / caitlyn (a11y sign-off). parallel_slice_candidate: wait-bound (gated on a deployed revision of `feat/demo-studio-v3` carrying T1–T5+T9; duration dominated by deploy-and-render wait, not reviewer effort). dependencies: T1, T2, T3, T4, T5, T9. DoD: Lulu confirms component placement above chat input full-width matches §UX Spec; copy strings from T4 read naturally in context; color-shift on hand-off is perceptible but not jarring; Caitlyn confirms WCAG-AA contrast for default + failed states, screen-reader narration of state changes, keyboard-focus order; review report committed with `Visual-Diff:` and `Accessibility-Check:` markers (per Rule 22 / PR-lint gate); no blocking findings.

- [ ] **T9** — Hand-off transition (1.5s dwell + 200ms color shift) to ADR-2 seam. estimate_minutes: 35. Files: `tools/demo-studio-v3/static/buildProgress.js`, `tools/demo-studio-v3/static/buildProgress.css`. kind: impl. owner_pair: viktor / rakan. parallel_slice_candidate: no. dependencies: T2. DoD: on `build_complete`, bar fills to 100% and dwells `1500ms ± 100ms` (timer-measured in unit test using fake timers; happy-path Akali check accepts 1400-1600ms window per QA Plan); after dwell, the SAME `<progress>` element is re-classed (no remount, no DOM detach — verified by stable element-id assertion across the transition) with `transition: background-color 200ms`; verify-green CSS class applies; placeholder label "Verifying…" renders with native indeterminate semantics until ADR-2 takes the slot; unit test asserts no double-fire on rapid re-events.

### Open coupling with Xayah's test plan (OQ-K1)

T6 and T7 declare hard dependencies on Xayah's parallel test plan: fixture-naming, mock-factory shape, and the canonical xfail comment vocabulary. If Xayah lands a different fixture convention, T7 fixtures may need a one-line rename pass; T6 may need to retarget assertion helpers. Resolution path: at T7/T6 dispatch time, Sona reconciles the two breakdowns or pings Aphelios+Xayah for a 5-min sync. No structural conflict expected — both authors read the same plan §QA Plan and §Verification.

## Verification

- All unit tests in T7 pass green in CI.
- Page-reload resume test in T6 passes green.
- Akali QA Plan §QA Plan executes against `feat/demo-studio-v3` deployment with all checkpoints green.
- `tests/test_build_status_endpoint.py` covers all five states (configuring/building-with-buildId/building-no-events-yet/complete/failed).
- Pre-push hook + CI green; PR e2e green; PR-lint detects required `Design-Spec:`, `Accessibility-Check:`, `Visual-Diff:`, `QA-Report:` markers.

## QA Plan

**Akali Playwright script.** Browser-environment isolation: incognito context. ENV URL: `https://demo-studio-4nvufhmjiq-ew.a.run.app` once PR #120 lands, otherwise `https://demo-studio-266692422014.europe-west1.run.app`. Sign-in protocol: real Firebase Auth via Google OAuth popup with the throwaway QA account `duong.missmp.qa@gmail.com` (credentials at `secrets/work/qa-bot-credentials.env`, mode 600, gitignored). The QA account is not in the `missmp.eu` Workspace; it is allowlisted at the app layer via the `ALLOWED_QA_EMAILS` env var on the Cloud Run revision under test. Nonce URL bypass is **not** permitted (per Akali RUNWAY 2026-04-27 trigger learning). All Akali claims must carry `cite_kind: verified` markers per QA two-stage ADR D2. The deployed revision must match the commit under test (`head_sha:` frontmatter check per QA two-stage ADR D6.f).

### Acceptance criteria

**PASS** if all checkpoints in the happy-path lane AND the failure-modes lane render their expected UI within the documented time budgets, AND no JS console errors are observed, AND `head_sha:` of the deployed revision matches the commit under test.

**FAIL** if any of the following occur:
- The progress bar fails to render within 5 seconds of the session entering `status == "building"`.
- The bar's `value` or step label disagrees with the SSE event stream observed in DevTools Network panel (`text/event-stream` channel on `/session/.../logs`).
- The failure path silently hides the bar without rendering the error inline.
- The build-complete dwell falls outside the 1400-1600ms window.
- The hand-off transition to the verify placeholder is missing the 200ms color shift, OR remounts the `<progress>` element instead of re-classing it.
- Page-reload mid-build does not call `GET /session/{id}/build-status` exactly once before re-opening the EventSource.
- Either failure-mode dismiss path (manual × button, auto-clear on retry) does not unmount cleanly.

### Happy path (user flow)

1. Open incognito browser context.
2. Navigate to ENV URL `/`.
3. Sign in via real Firebase Auth flow — click "Sign in with Google", complete OAuth in popup with `duong.missmp.qa@gmail.com` (password from `secrets/work/qa-bot-credentials.env`). Capture `01-signed-in.png`.

| Step | Action | Pass criterion | Screenshot |
|---|---|---|---|
| 1 | Click "+ New session" | Lands in new session, `status == "configuring"`. `deployBtn` is **hidden** (`display: none` per `studio.css:186`) — it is only revealed when the agent reaches `awaitingApproval`. No progress bar visible. | `02-new-session.png` |
| 2 | Drive the agent through configuring until a build is triggered. **Two trigger paths must be covered by separate runs of this script** (path coverage is mandatory, ADR-5 reconciliation notwithstanding): **(a)** chat-driven `trigger_factory` (more common — type "go ahead and build" in chat once the agent is ready, agent invokes `trigger_factory` tool, `deployBtn` may never appear); **(b)** UI-driven `deployBtn` click (less common — wait for the agent to enter `awaitingApproval` so `showDeployButton()` reveals the button, then click it). For both paths: session transitions to `status == "building"`. Progress bar appears within 2 seconds **directly above the chat input row**, full-column-width. Bar is **native `<progress>` indeterminate** with label "Starting build…" (or already determinate if first `step_start` arrived fast). DOM check: `<progress>` element has no `value` attribute when indeterminate. | `03a-build-triggered-chat-path.png`, `03b-build-triggered-button-path.png` |
| 3 | Wait up to 10 seconds | Bar is determinate. `value` ≥ 0 and ≤ 100. Label reads "Step N of 10 — {step name}". | `04-progress-mid.png` |
| 4 | Wait until any `step_complete` event observed (network panel `text/event-stream` channel for `/session/.../logs` shows `event: build` with `step_complete` data) | Bar `value` jumped by ≥ 10. Label updated to next step name. | `05-step-advance.png` |
| 5 | **Page reload mid-build** (Cmd+R) | Bar reappears within 2 seconds at the current step (not 0%). Network shows one `GET /session/{id}/build-status` call followed by re-opened `EventSource`. | `06-reload-mid-build.png` |
| 6 | Wait for `build_complete` | Bar fills to 100%. Label reads "Build complete". Component dwells visible for **~1.5 seconds** (timer-measured: 1400-1600ms acceptable). Then **hard-swap with 200ms color shift** (build-blue → verify-green) to ADR-2's verification placeholder in the same DOM slot — same `<progress>` element re-classed, no remount, no reflow. | `07a-build-complete-100pct.png` (during dwell), `07b-handoff-color-shift.png` (mid-transition), `07c-verify-placeholder.png` (post-handoff) |
| 7 | Open browser console | No JS errors. No SSE reconnect errors. EventSource is closed (readyState === 2). | `08-console-clean.png` |

### Failure modes (what could break)

Run as a separate test run from the happy path; same setup (incognito + real Firebase OAuth).

| Step | Action | Pass criterion | Screenshot |
|---|---|---|---|
| F1 | Pre-set the session config to one that fails factory step 4 (e.g. invalid translation key) | Build runs, fails at step 4 | — |
| F2 | Trigger build, wait | Bar freezes at 30-40% (step 3 completed, step 4 errored). Bar turns red. Label reads "Build failed at {softened iOS step copy}: {error.message}". A × close button is visible inside the failed bar, keyboard-focusable. | `09-build-failed.png` |
| F3a | Click the × close button | Component unmounts immediately. `deployBtn` restored to "Deploy Demo" enabled state. | `10a-failed-manual-dismiss.png` |
| F3b | (Separate run) Re-trigger build instead of dismissing | Failed bar auto-clears on `configuring` → `building` transition; fresh indeterminate bar mounts with no flicker (single repaint between unmount and remount). | `10b-failed-auto-clear-on-retry.png` |

Other failure modes the script must surface (no separate row needed; covered by "Acceptance criteria" FAIL list):
- SSE stream closes without a terminal event mid-build (BFF fallback GET should fire — covered today by `_sse_fallback_get` at `tools/demo-studio-v3/main.py:344`; UI should still reach a terminal state).
- Build is triggered but no `step_start` event arrives within 10s (bar should remain in indeterminate state with "Starting build…" — never silently disappear).
- Page reload after `build_complete` but before user navigates away: `GET /build-status` returns terminal state; UI shows verify-placeholder without re-running build.

### QA artifacts expected

**Screenshot set** (12 files total — happy path + failure modes):

| File | When captured |
|---|---|
| `01-signed-in.png` | After successful Firebase OAuth |
| `02-new-session.png` | After "+ New session" click, pre-build |
| `03-build-triggered.png` | Within 2s of `status == "building"`, indeterminate bar visible above chat input |
| `04-progress-mid.png` | Determinate bar at any mid-build step |
| `05-step-advance.png` | Immediately after a `step_complete` event, bar value jumped ≥ 10 |
| `06-reload-mid-build.png` | After Cmd+R during build, bar re-rendered at current step |
| `07a-build-complete-100pct.png` | During the 1.5s dwell at 100% |
| `07b-handoff-color-shift.png` | Mid 200ms color-shift transition (build-blue → verify-green) |
| `07c-verify-placeholder.png` | Post hand-off, ADR-2's verify placeholder mounted in the same slot |
| `08-console-clean.png` | DevTools console panel showing zero errors after build complete |
| `09-build-failed.png` | Failure mode F2: red bar + × close button visible |
| `10a-failed-manual-dismiss.png` | Failure mode F3a: post-× click, component unmounted |
| `10b-failed-auto-clear-on-retry.png` | Failure mode F3b: post-retry, fresh indeterminate bar mounted |

**QA report path:** `assessments/qa-reports/2026-MM-DD-adr-1-build-progress-bar-rev<NNNNN>-<short-sha>.md`. Linked from PR body via the `QA-Report:` line per CLAUDE.md Rule 16.

**Frontmatter requirement:** the QA report MUST include a `head_sha:` field matching the deployed revision's commit SHA, per QA two-stage ADR D6.f. Mismatch = automatic FAIL regardless of screenshots.

**Network capture:** retain the DevTools Network HAR file as evidence for steps 4 and 5 (SSE event stream verification + reload-resume single GET). Save alongside the screenshots: `network-happy.har`, `network-failure.har`.

**Citation tagging:** every observation in the QA report body must carry `cite_kind: verified | inferred` and `cite_evidence:` per QA two-stage ADR D2. Verified = directly observed in screenshot or HAR; inferred = derived from observation but not directly visible.

## Out of scope

- **Build trigger surface** (button vs agent tool call). **Owned by ADR-5 (sanity sweep) — confirmed 2026-04-27.** Today's `trigger_factory` MCP tool reconciliation against the project DoD constraint ("Build button is NOT an agent tool call") stays in ADR-5's lane. ADR-1 is trigger-agnostic: it needs only a `buildId` on the session doc, regardless of how the build was started.
- **Verification progress bar.** Owned by ADR-2. ADR-1 hands off to ADR-2 on `build_complete` via the same UI slot.
- **Async agent notifications on build completion** (chat-side push). Owned by ADR-4. ADR-1 only renders UI; agent observes via session-doc state.
- **Build history / list of past builds.** Single-user happy path means the only relevant build is the active one.
- **Failure-mode UX beyond inline message + dismiss.** Detailed failure-mode flows are explicitly out of scope per project §Out of scope.
- **Factory S3 server-side changes.** Zero by design; if breakdown surfaces a need, plan must be amended.
- **Multi-build-per-session UI** (concurrent builds). v1 is single-user, single-build-at-a-time.
- **SSE-blocked-proxy polling fallback.** Deferred to v2. v1 is single-user happy path; Duong's environment does not strip SSE (verified by `/stream` working today). Adding defensive polling without a real failure mode violates the simplicity rule.

## Open Questions for Duong

All seven OQs resolved by Duong via hands-off autodecide on 2026-04-27. Audit trail preserved below; resolutions are baked into §Architecture decisions, §UX Spec, §Tasks, and §QA Plan above.

1. **Step-name copy.** Should the user-facing labels match the factory step keys verbatim (e.g. "Build iOS template") or be softened ("Preparing iPhone wallet pass…")? Recommend: softened, owned by Lulu in T4. **Resolved 2026-04-27 (hands-off autodecide): softened — Lulu owns the copy in T4.**
2. **Component placement.** Below chat header, above chat input, or in the right-side iPad demo panel? Recommend: above chat input, full-column-width — it is build-status, not session-meta. **Resolved 2026-04-27 (hands-off autodecide): above chat input, full-column-width.**
3. **Build-complete dwell time.** How long should the 100% state stay visible before the verification component takes the slot? Recommend: 1.5s — long enough to register the win, short enough to keep momentum. **Resolved 2026-04-27 (hands-off autodecide): 1.5 seconds.**
4. **Failed-state dismissibility.** Auto-clear on next build trigger, manual dismiss button, or both? Recommend: both. Auto-clear on retry; manual dismiss for users who want to read the error and walk away. **Resolved 2026-04-27 (hands-off autodecide): both — auto-clear on retry AND manual close button. Two non-overlapping mechanisms.**
5. **`/build-status` polling fallback if SSE is blocked.** Some corporate proxies strip SSE. Should the component fall back to 2-second polling on `/build-status` if `EventSource` fails to open within 5 seconds? Recommend: not in v1 (single-user happy path, Duong's environment doesn't strip SSE — verified by `/stream` working today). Defer to v2. **Resolved 2026-04-27 (hands-off autodecide): deferred to v2. No defensive code without a real failure mode.**
6. **Indeterminate-spinner UX.** Browser-native `<progress>` (no `value`) or a custom CSS spinner during the pre-first-event window? Recommend: native — accessibility for free, zero new dependencies. **Resolved 2026-04-27 (hands-off autodecide): native `<progress>`.**
7. **Hand-off to ADR-2 visual.** Should the build bar fade out and the verify bar fade in (transition), or hard-swap? Recommend: hard-swap with a 200ms color shift — keeps perceived latency low. **Resolved 2026-04-27 (hands-off autodecide): hard-swap with 200ms color shift.**

### Scope-boundary clarification (added 2026-04-27, team-lead directive)

- **Trigger-tool reconciliation stays in ADR-5 (sanity sweep), NOT pulled into ADR-1.** ADR-1 remains UI-only: it consumes a `buildId` from the session doc and renders progress, regardless of whether the build was started by an agent `trigger_factory` tool call (today's behaviour) or a user button click against `POST /session/{id}/build` (project DoD target). See §Out of scope.

## Test plan

_Authored by Xayah on 2026-04-27 (complex-track). Pair: Rakan (test impl) ↔ Viktor (impl). xfail-first per Rule 12: every TX-xfail-* test below lands as its own commit on `adr-1-test-plan` BEFORE the impl task it pairs with._

### Coverage matrix (what each test protects)

| Surface | Count | Invariant |
|---|---|---|
| Unit (contract translator) | 7 | `BuildProgress` shape (D2) is the single seam between factory wire-shape and UI; no caller depends on raw event names. |
| Integration (xfail, end-to-end SSE → UI) | 4 | BFF `/session/{id}/logs` → frontend `EventSource` → `BuildProgress` state pipeline emits the contract D2 declares; reload-resume seeds via `/build-status` then SSE fans in (D6). |
| Fault injection | 6 | UI never wedges, never silently disappears, never double-applies a terminal event when factory or transport misbehaves. |
| Cross-ADR contract | 2 | The `BuildProgress` shape (D2) and the same DOM slot (D5) are reused by ADR-2 (verify) without modification. |

**Total: 19 test tasks** — 7 unit, 4 xfail integration, 6 fault-injection, 2 cross-ADR seam.

### Pairing & ordering with Aphelios's §Tasks

- T7 (unit translator tests) → expanded below as **TX-unit-1..TX-unit-7**. Pairs with Aphelios's T2 (translator impl). Ordering: TX-unit-* commits land BEFORE T2 impl on the same branch.
- T6 (page-reload resume integration test) → expanded below as **TX-int-3 (xfail)**. Pairs with Aphelios's T3 + T1 (subscribe + `/build-status` endpoint). Ordering: TX-int-3 lands BEFORE T1/T3 impl.
- New: **TX-int-1, TX-int-2, TX-int-4 (xfail)**, **TX-fault-1..TX-fault-6**, **TX-seam-1..TX-seam-2** — Xayah-introduced; Aphelios picks them up into his §Tasks under T6/T7's pair-mate ownership when he sees this section.

### Unit tests — `buildProgress.js` translator (T7 expansion)

All seven tests are pure-function: feed canned SSE chunk strings (or pre-parsed event objects, depending on translator surface) into `applyEvent(state, chunk)` and assert the resulting `BuildProgress` shape. No DOM, no network, no timers.

- [ ] **TX-unit-1** — translator: `step_start` builds initial `BuildProgress`. estimate_minutes: 25. Files: `tools/demo-studio-v3/static/buildProgress.test.js` (or equivalent test file colocated with the new module). DoD: feeding `event: build` + `data: {"event":"step_start","step":1,"totalSteps":10,"name":"clone_blank_template"}` produces `{status:'in_progress', step:1, totalSteps:10, stepName:<mapped from T4 table>, percent:0, error:undefined}`. **Committed before T2 impl per Rule 12.** parallel_slice_candidate: no.
- [ ] **TX-unit-2** — translator: `step_complete` advances `percent`. estimate_minutes: 20. Files: `tools/demo-studio-v3/static/buildProgress.test.js`. DoD: after `step_complete{step:3,name:'upload_logos',duration_ms:1200}`, `percent === 30` and `step === 3`. Asserts `percent` derives from `step_complete.step`, NOT `step_start.step` (D2 explicit). **Committed before T2 impl per Rule 12.** parallel_slice_candidate: no.
- [ ] **TX-unit-3** — translator: `step_error` sets `status:'failed'` + freezes `step` at last completed. estimate_minutes: 25. Files: `tools/demo-studio-v3/static/buildProgress.test.js`. DoD: sequence `step_complete{step:3}` → `step_start{step:4}` → `step_error{step:4,name:'build_ios_template',error:'X'}` → result is `{status:'failed', step:3, percent:30, stepName:<step 4 mapped name>, error:{message:'X', code:?}}`. Bar freezes at last *completed* step (D3 failure-state row in UX Spec). **Committed before T2 impl per Rule 12.** parallel_slice_candidate: no.
- [ ] **TX-unit-4** — translator: `build_complete` sets terminal state. estimate_minutes: 15. Files: `tools/demo-studio-v3/static/buildProgress.test.js`. DoD: `build_complete{shortcode:'X', projectUrl:..., demoUrl:...}` → `{status:'complete', percent:100, stepName:'Build complete'}`. Idempotency check: applying it twice yields identical state and no thrown error. **Committed before T2 impl per Rule 12.** parallel_slice_candidate: no.
- [ ] **TX-unit-5** — translator: `build_error` without preceding `step_error` still sets failed. estimate_minutes: 15. Files: `tools/demo-studio-v3/static/buildProgress.test.js`. DoD: from a `step_complete{step:5}` mid-state, applying `build_error{error:'global'}` directly (no `step_error` first) produces `{status:'failed', step:5, percent:50, error:{message:'global'}}` — translator must not require the `step_error` precursor. **Committed before T2 impl per Rule 12.** parallel_slice_candidate: no.
- [ ] **TX-unit-6** — translator: malformed/unknown event names no-op. estimate_minutes: 20. Files: `tools/demo-studio-v3/static/buildProgress.test.js`. DoD: feeding `data: {"event":"unknown_thing"}`, `data: {malformed json`, empty string, `event: build` with empty data — translator returns prior state unchanged, no throw. Asserts the wire-shape isolation guarantee (D2: factory can rename internals without UI crash). **Committed before T2 impl per Rule 12.** parallel_slice_candidate: no.
- [ ] **TX-unit-7** — translator: `step_complete.step > totalSteps` clamps to 100% without throwing. estimate_minutes: 15. Files: `tools/demo-studio-v3/static/buildProgress.test.js`. DoD: `step_start{step:1,totalSteps:10}` then `step_complete{step:11}` → `percent === 100` (clamped), `status` stays `in_progress` until terminal event. Guards against factory off-by-one. **Committed before T2 impl per Rule 12.** parallel_slice_candidate: no.

### Integration tests — end-to-end SSE → UI (T6 expansion + new)

These exercise the BFF multiplexer + frontend subscriber + component together. Use a stubbed upstream factory SSE source (replay canned event sequences over a local HTTP server) and a JSDOM/headless browser harness for the frontend.

- [ ] **TX-int-1 (xfail)** — happy-path full pipeline: 10-step build renders 0% → 100% in DOM. estimate_minutes: 50. Files: `tests/integration/test_build_progress_e2e.py` (or `.spec.js` if the harness is JS; pick whatever sibling integration tests already use). DoD: stub factory emits all 10 `step_start`/`step_complete` pairs + `build_complete`; assertions: `<progress value>` advances monotonically through `0,10,20,...,100`; label updates on every `step_start`; `EventSource.readyState === 2` (closed) after terminal. xfail because component does not exist yet. **Committed before T2/T3 impl per Rule 12.** parallel_slice_candidate: yes.
- [ ] **TX-int-2 (xfail)** — failure-path full pipeline: `step_error` at step 4 surfaces inline error + × button. estimate_minutes: 40. Files: `tests/integration/test_build_progress_e2e.py`. DoD: stub factory emits steps 1-3 complete, then `step_start{4}` + `step_error{4}` + `build_error`; assertions: bar value frozen at 30, bar has `failed` class (red), label contains the error message verbatim, × button is in DOM and keyboard-focusable (`tabindex >= 0`), clicking × unmounts the component. xfail because component does not exist yet. **Committed before T2/T3/T5 impl per Rule 12.** parallel_slice_candidate: yes.
- [ ] **TX-int-3 (xfail)** — page-reload resume seeds via `/build-status` then SSE fans in (T6). estimate_minutes: 45. Files: `tests/integration/test_build_progress_reload_resume.py`. DoD: (a) start a build, advance to step 5 via stub SSE; (b) tear down the EventSource and re-mount the component (simulating reload); (c) assert exactly one `GET /session/{id}/build-status` is fired; (d) assert seed produces `<progress value="50">` BEFORE any subsequent SSE event; (e) feed `step_complete{6}` over fresh SSE, assert value advances to 60 within 2 seconds. Single-call assertion is load-bearing per QA Plan FAIL list. xfail because `/build-status` endpoint and component do not exist yet. **Committed before T1/T2/T3 impl per Rule 12.** parallel_slice_candidate: yes.
- [ ] **TX-int-4 (xfail)** — auto-clear-on-retry: failed bar unmounts and remounts indeterminate on next `building` transition (T5 path A). estimate_minutes: 35. Files: `tests/integration/test_build_progress_retry.py`. DoD: drive component to `failed` state via TX-int-2 setup, then dispatch a fresh `status: building` chat-stream event; assert: failed component unmounts, fresh component mounts in indeterminate state (no `value` attribute on `<progress>`), single repaint between unmount and remount (no flicker — measured via JSDOM mutation observer count or Playwright's `page.locator(...).count()` timeline). xfail because component does not exist yet. **Committed before T5 impl per Rule 12.** parallel_slice_candidate: yes.

### Fault-injection harnesses (Xayah-introduced)

Each harness targets one specific failure mode the QA Plan FAIL list or §Goal "survives a full page reload mid-build" promises. Run as part of the integration suite; each may be marked xfail until its corresponding impl path lands.

- [ ] **TX-fault-1** — SSE stream cut mid-build (network drop after step 5). estimate_minutes: 40. Files: `tests/integration/test_build_progress_fault_sse_drop.py`. DoD: stub factory emits steps 1-5 complete, then closes the TCP connection without a terminal event. Assertion: BFF's `_sse_fallback_get` (already present at `tools/demo-studio-v3/main.py:344`) fires, the UI eventually reaches a terminal `complete` or `failed` state from session-doc fields within 30s, and the component does NOT silently disappear. **Committed before T3 impl per Rule 12.** parallel_slice_candidate: yes.
- [ ] **TX-fault-2** — terminal event arrives without preceding `step_start` (out-of-order). estimate_minutes: 25. Files: `tests/integration/test_build_progress_fault_out_of_order.py`. DoD: stub factory emits `build_complete` as the FIRST event (no `step_*` prelude). Assertion: component transitions cleanly to terminal state, percent jumps to 100, no thrown error in console. parallel_slice_candidate: yes.
- [ ] **TX-fault-3** — `step_complete.step > totalSteps` integration check. estimate_minutes: 20. Files: `tests/integration/test_build_progress_fault_overflow_step.py`. DoD: stub factory emits `step_start{1,totalSteps:10}` then `step_complete{step:11}`. Assertion: bar clamps to 100%, no JS error, label still shows a sensible `stepName`. End-to-end counterpart of TX-unit-7. parallel_slice_candidate: yes.
- [ ] **TX-fault-4** — `build_complete` arrives twice (idempotency). estimate_minutes: 25. Files: `tests/integration/test_build_progress_fault_double_terminal.py`. DoD: stub factory emits `build_complete`, then a duplicate `build_complete` 200ms later (simulating BFF retry or upstream stutter). Assertion: dwell timer fires exactly once (1.5s window), color-shift transition fires exactly once, no double-mount of the verify placeholder. Asserts the QA Plan FAIL list "remounts the `<progress>` element instead of re-classing it" guarantee. **Committed before T9 impl per Rule 12.** parallel_slice_candidate: yes.
- [ ] **TX-fault-5** — SSE opens then closes within 10s with zero events (timeout guard). estimate_minutes: 30. Files: `tests/integration/test_build_progress_fault_silent_sse.py`. DoD: stub factory accepts the connection, holds it open for 10s, sends nothing, closes. Assertion: indeterminate `<progress>` (no `value` attr) remains visible with label "Starting build…" — does NOT silently unmount. Matches QA Plan failure-modes bullet "Build is triggered but no `step_start` event arrives within 10s". parallel_slice_candidate: yes.
- [ ] **TX-fault-6** — page-reload AFTER `build_complete` (terminal seed-only path). estimate_minutes: 25. Files: `tests/integration/test_build_progress_fault_reload_post_terminal.py`. DoD: drive build to terminal-complete state, simulate reload. Assert: `GET /session/{id}/build-status` returns terminal state from session-doc fields (no upstream factory call); UI shows the verify-placeholder bar in `verify-green` (per ADR-1/ADR-2 seam in T9), not the build bar; no SSE connection opened. Matches QA Plan failure-modes bullet "Page reload after `build_complete`". **Committed before T1 impl per Rule 12.** parallel_slice_candidate: yes.

### Cross-ADR contract tests

ADR-1 owns the build channel; ADR-2 will reuse the multiplexer + UI slot for verify. These two tests freeze the seam shape now so ADR-2 cannot drift.

- [ ] **TX-seam-1** — contract shape stability: `BuildProgress` interface snapshot. estimate_minutes: 15. Files: `tests/contract/test_build_progress_shape.py` (or a JS snapshot test colocated with the module). DoD: snapshot of the `BuildProgress` TypeScript-style interface (or runtime shape via `Object.keys`) committed alongside the test. Any change to field names, types, or the `status` enum breaks the snapshot — ADR-2 must explicitly update it. Asserts D2's "single load-bearing seam" promise. parallel_slice_candidate: no.
- [ ] **TX-seam-2** — DOM-slot reuse: same `<progress>` element accepts both `event: build` and `event: verification` chunks. estimate_minutes: 30. Files: `tests/integration/test_build_progress_slot_reuse.py`. DoD: mount the component, drive build to `build_complete`, dwell 1.5s, then synthesise an `event: verification` `step_start` chunk in the same EventSource stream. Assertion: same `<progress>` DOM node persists (`element === sameElement` via JS reference check), only its className shifts from `build-blue` to `verify-green`, no `unmount` lifecycle fires. Asserts D5 cross-ADR contract: "one UI component, two data sources, no duplication". **Committed before T9 impl per Rule 12.** parallel_slice_candidate: no.

### Architectural ambiguity surfaced (report-back to team-lead)

Three points worth flagging to Aphelios + Swain before impl starts:

1. **Translator surface shape is undefined.** D2 names the contract but does not specify whether `applyEvent` takes a raw SSE chunk string (and parses) or a pre-parsed event object. TX-unit-* assume the former (string in, state out — purer, no parser dependency in tests). Aphelios's T2 should pin this in his impl breakdown; tests will pivot if the surface is the latter.
2. **`/build-status` upstream call is not idempotent-defined.** D6 says "makes a single upstream `GET /build/{buildId}` call to factory" for `building` state. If the user reloads twice in 5s, do we hit factory twice, or do we cache for N seconds? TX-int-3 only asserts a single call per page-load; multi-reload behaviour is undefined. Worth a 2-line clarification in D6 or a follow-up plan.
3. **Color-shift transition mechanism for TX-fault-4 idempotency.** The QA Plan FAIL list says "remounts the `<progress>` element instead of re-classing it" is a fail. That implies the transition uses `classList.replace` not `replaceChild`. T9 should make this explicit; TX-seam-2 hard-asserts it via DOM-node identity. If T9 implements via `replaceChild` for any reason, TX-seam-2 will fail and we'll need to amend.

### Notes on isolation, commits, and ordering

- This section was authored in worktree `xayah/adr-1-test-plan` (branch `adr-1-test-plan`) per Rule 20 auto-isolation.
- Edit-only — no sibling `-tests.md` file created (D1A inline enforcement; `Write` is revoked from Xayah's tool list).
- Commit prefix: `chore: xayah breakdown for adr-1-build-progress-bar (D1A inline)`.
- Plan body has been modified — if any pre-existing Orianna body-hash signature exists, this edit invalidates it. The §Orianna approval block below has no body-hash field; no re-sign dance required, but report this edit to Sona/team-lead for awareness.

## Orianna approval

- **Date:** 2026-04-27
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** All three gates pass on this third attempt: QA-plan frontmatter (`qa_co_author: lulu` present), QA-plan body (four canonical sub-headings — Acceptance criteria / Happy path / Failure modes / QA artifacts expected — all present), and §UX Spec linter. Plan has clear owner (Swain), all seven OQs resolved 2026-04-27, tests_required satisfied by T6 (xfail integration test) + T7 (unit tests). Trigger-surface scope explicitly confined to ADR-5. No overengineering smells: D1 reuses existing transport, D5 commits to zero factory changes, OQ5 defers SSE polling fallback to v2.

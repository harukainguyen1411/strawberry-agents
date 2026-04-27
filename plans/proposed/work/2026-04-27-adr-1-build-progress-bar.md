---
slug: adr-1-build-progress-bar
title: "ADR-1 — Live build progress bar (factory S3 → studio v3 UI)"
project: bring-demo-studio-live-e2e-v1
concern: work
status: proposed
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
- There is no UI element that renders step-by-step progress; the `deployBtn` is the only build affordance and it carries no granularity.
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

Introduce a small frontend translator (`buildProgress.js` or a function block in `studio.js`) that consumes raw `event: build` chunks from `/logs` and produces a UI-progress object:

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

Frontend startup sequence on page-load with `status == "building"`: (1) call `/build-status` once → seed the bar; (2) open `EventSource('/session/{sessionId}/logs')` → fan in subsequent steps.

This avoids a flash-of-empty-progress on reload and keeps the SSE stream as the only event-shape source-of-truth in steady state.

## UX Spec

### User flow

1. User is in a session, `status == "configuring"`. No progress bar visible. `deployBtn` shows "Deploy Demo".
2. Build is triggered (mechanism owned by ADR-5 — see §Out of scope). Session doc transitions `configuring` → `building` and gains a `buildId`.
3. Chat `/stream` emits `status: building`. Frontend **mounts the progress component above the chat input**, full-column-width. `deployBtn` retains its coarse "Building…" text-flip (unchanged from today) — the progress component is additive, not a replacement.
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

Pure-function tests of `applyEvent` against canned SSE chunk fixtures: `step_start`, `step_complete`, `step_error`, `build_complete`, `build_error`, malformed/unknown event names (must no-op without crash).

### T8 — Component visual smoke (Lulu / Caitlyn)

`kind: review`
`estimate_minutes: TBD by Lulu`

Visual review of the rendered component on `feat/demo-studio-v3` deployment against the §UX Spec wireframe.

### T9 — Hand-off transition stub (ADR-2 seam)

`kind: feature`
`estimate_minutes: TBD by Aphelios`

Implement the 1.5s dwell + 200ms color-shift hard-swap mechanism on `build_complete`. ADR-1 ships the dwell timer and the color-shift CSS class; the `verify` mode of the same component is wired up later in ADR-2. Until ADR-2 lands, the post-hand-off slot shows a placeholder bar in `verify-green` with label "Verifying…" indeterminate. This is the documented seam between ADR-1 and ADR-2 — both ADRs amend the same component.

## Verification

- All unit tests in T7 pass green in CI.
- Page-reload resume test in T6 passes green.
- Akali QA Plan §QA Plan executes against `feat/demo-studio-v3` deployment with all checkpoints green.
- `tests/test_build_status_endpoint.py` covers all five states (configuring/building-with-buildId/building-no-events-yet/complete/failed).
- Pre-push hook + CI green; PR e2e green; PR-lint detects required `Design-Spec:`, `Accessibility-Check:`, `Visual-Diff:`, `QA-Report:` markers.

## QA Plan

**Akali Playwright script** (browser-environment isolation: incognito; ENV URL: `https://demo-studio-4nvufhmjiq-ew.a.run.app` once PR #120 lands, otherwise `https://demo-studio-266692422014.europe-west1.run.app`).

### Setup

1. Open incognito browser context.
2. Navigate to ENV URL `/`.
3. **Sign in via real Firebase Auth flow** — click "Sign in with Google", complete OAuth in popup with `duong@missmp.eu`. Do **not** use nonce URL bypass. Capture screenshot `01-signed-in.png`.

### Per-step actions

| Step | Action | Pass criterion | Screenshot |
|---|---|---|---|
| 1 | Click "+ New session" | Lands in new session, `status == "configuring"`. `deployBtn` reads "Deploy Demo". No progress bar visible. | `02-new-session.png` |
| 2 | Click "Deploy Demo" (trigger mechanism owned by ADR-5 sanity sweep) | Session transitions to `status == "building"`. Progress bar appears within 2 seconds **directly above the chat input row**, full-column-width. Bar is **native `<progress>` indeterminate** with label "Starting build…" (or already determinate if first `step_start` arrived fast). DOM check: `<progress>` element has no `value` attribute when indeterminate. | `03-build-triggered.png` |
| 3 | Wait up to 10 seconds | Bar is determinate. `value` ≥ 0 and ≤ 100. Label reads "Step N of 10 — {step name}". | `04-progress-mid.png` |
| 4 | Wait until any `step_complete` event observed (network panel `text/event-stream` channel for `/session/.../logs` shows `event: build` with `step_complete` data) | Bar `value` jumped by ≥ 10. Label updated to next step name. | `05-step-advance.png` |
| 5 | **Page reload mid-build** (Cmd+R) | Bar reappears within 2 seconds at the current step (not 0%). Network shows one `GET /session/{id}/build-status` call followed by re-opened `EventSource`. | `06-reload-mid-build.png` |
| 6 | Wait for `build_complete` | Bar fills to 100%. Label reads "Build complete". Component dwells visible for **~1.5 seconds** (timer-measured: 1400-1600ms acceptable). Then **hard-swap with 200ms color shift** (build-blue → verify-green) to ADR-2's verification placeholder in the same DOM slot — same `<progress>` element re-classed, no remount, no reflow. | `07a-build-complete-100pct.png` (during dwell), `07b-handoff-color-shift.png` (mid-transition), `07c-verify-placeholder.png` (post-handoff) |
| 7 | Open browser console | No JS errors. No SSE reconnect errors. EventSource is closed (readyState === 2). | `08-console-clean.png` |

### Failure-path lane (separate test run)

| Step | Action | Pass criterion | Screenshot |
|---|---|---|---|
| F1 | Pre-set the session config to one that fails factory step 4 (e.g. invalid translation key) | Build runs, fails at step 4 | — |
| F2 | Trigger build, wait | Bar freezes at 30-40% (step 3 completed, step 4 errored). Bar turns red. Label reads "Build failed at {softened iOS step copy}: {error.message}". A × close button is visible inside the failed bar, keyboard-focusable. | `09-build-failed.png` |
| F3a | Click the × close button | Component unmounts immediately. `deployBtn` restored to "Deploy Demo" enabled state. | `10a-failed-manual-dismiss.png` |
| F3b | (Separate run) Re-trigger build instead of dismissing | Failed bar auto-clears on `configuring` → `building` transition; fresh indeterminate bar mounts with no flicker (single repaint between unmount and remount). | `10b-failed-auto-clear-on-retry.png` |

### Pass / fail criteria

**PASS** if all checkpoints in the happy path AND the failure path render their expected UI within the time budgets, AND no JS console errors are observed, AND `head_sha:` of the deployed revision matches the commit under test (per QA two-stage architecture ADR D6.f).

**FAIL** if any progress bar fails to render within 5 seconds of `status == "building"`, or shows incorrect step / percent versus the SSE event stream observed in DevTools Network panel, or the failure path silently hides the bar without rendering the error inline.

`cite_kind: verified` markers required on every observation Akali claims (per QA two-stage ADR D2).

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

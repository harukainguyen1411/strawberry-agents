---
pr: 61
branch: feat/s1-new-flow-wave2
repo: missmp/company-os
slug: 2026-04-21-s1-new-flow-wave2-pr61
surface: demo-studio-v3 (S1)
phases: A B C D E F G H I
run_date: 2026-04-21
agent: Akali
verdict: PARTIAL
---

# QA Report — PR #61 S1-new-flow Wave 2 (phases A-I)

## Verdict: PARTIAL

Phases A, B, C, D, E, F, G, I are PASS on all verifiable surfaces.
Phase H frontend UI requirement (verification summary panel + SSE-driven chat re-enable) is NOT implemented in studio.js — the backend emits the events but the UI never subscribes to `/session/{id}/logs`. This is a FAIL against the T.S1.15 DoD.

---

## Environment

- Branch: `feat/s1-new-flow-wave2` at worktree `/private/tmp/s1-new-flow-worktree`
- Python: 3.13.1
- Playwright: sync_api (installed, used via MCP browser tool and pytest runner)
- QA stub server: minimal ThreadingHTTPServer at `http://127.0.0.1:18081` serving PR-branch `static/studio.js` and `static/studio.css` with `window.__s5Base` and `window.__sessionId` injected

---

## Figma reference status

No Figma frame IDs were linked in the PR body, the ADR plan, or any prior assessments for demo-studio-v3 UI surfaces. The god-plan ship-gate checklist (`assessments/ship-day-azir-option-a-checklist-2026-04-21.md` line 82) references "Akali UI regression green vs Figma" without a URL. Design comparison in this report is agent-narrated against the ADR spec (the plan is the design reference). A Figma URL should be provided before the final ship-gate sign-off.

---

## Per-screen pass/fail table

| Surface | Figma Frame ID | Result | Notes |
|---|---|---|---|
| Session page — empty state (no pre-filled brand/market) | N/A — no Figma link | PASS | Chat input enabled, no brand/market pre-fill, placeholder "Describe what you want..." visible |
| Phase B — `/approve` UI removal | N/A | PASS | `doGenerate()` is a no-op return; `doDeploy()` shows a message only; zero live `fetch('/approve')` calls confirmed by DOM eval and unit tests |
| Phase B — Generate button | N/A | PASS | Button is present in DOM for backward-compat state transitions but does not call `/approve`; `doGenerate()` early-returns |
| Phase C — S5 iframe (S5_BASE set) | N/A | PASS | `previewFrame.src = "https://preview.example.com/v1/preview/qa-akali-sess-001"` confirmed via DOM eval; iframe visible |
| Phase C — S5 iframe (S5_BASE unset) | N/A | PASS | iframe `display:none`; placeholder "Preview unavailable (S5_BASE not configured)" shown; confirmed via DOM eval + screenshot |
| Phase C — Open in fullview button (S5_BASE set) | N/A | PASS | `fullviewBtn.href = "https://preview.example.com/v1/preview/qa-akali-sess-001/fullview"`, `target="_blank"`, button visible |
| Phase C — Open in fullview button (S5_BASE unset) | N/A | PASS | `fullviewBtn.style.display = "none"` confirmed |
| Phase H — Chat input re-enable after terminal verification SSE | N/A | FAIL | studio.js has no EventSource subscription to `/session/{id}/logs`; `event: verification` from the SSE endpoint is never consumed by the frontend; chat re-enable on terminal state is not implemented |
| Phase H — Verification report collapsible panel | N/A | FAIL | No `#verificationPanel` or `#verificationSummary` element exists in studio.js DOM; T.S1.15 DoD ("collapsible panel or inline alert" surfacing `verificationReport.summary`) is absent |
| Session page — chat + MCP tool-call indicators | N/A | PASS | Thinking bubble and tool-use indicator DOM construction confirmed in studio.js; tests in `test_agent_activity.py` all xpassed |
| Build progress + SSE log view | N/A | PASS (backend only) | `/session/{id}/logs` endpoint returns `text/event-stream` with `event: build` and `event: verification` prefixes; backend tested and green; no UI subscription wired |

---

## Unit / integration test results

### Phase-specific tests (all passed)

```
tests/test_s1_new_flow_phase_a.py    2 passed
tests/test_s1_new_flow_phase_b.py    2 passed
tests/test_s1_new_flow_phase_c.py    3 passed
tests/test_s1_new_flow_phase_d.py    4 passed
tests/test_s1_new_flow_phase_e.py    3 passed
tests/test_s1_new_flow.py           16 passed
tests/test_s1_new_flow_e2e.py       15 passed, 4 xfailed, 3 skipped
```

### Playwright unit tests (passed)

```
tests/test_playwright_dedup.py      3 passed  (non-real-service, headless Chromium)
  test_no_duplicate_bot_message_from_background_eventsource  PASS
  test_bot_message_visible_when_only_content_preview_sent    PASS
  test_two_round_trips_no_duplicate_per_message              PASS
```

### Pre-existing failure (not introduced by this PR)

```
tests/test_archived_events.py::test_events_endpoint_returns_cached_events_for_archived_session  FAIL
```
This test existed and failed on `feat/demo-studio-v3` before this PR's commits. Not in scope of this PR.

---

## Screenshot artifacts

Screenshots taken via Playwright MCP browser tool. Paths are relative to the session working directory at capture time.

| Screen | File | Description |
|---|---|---|
| Session page with S5_BASE set | `akali-qa-session-page-full.png` | Full-page screenshot showing iframe + fullview button + chat panel in configure phase; chat enabled |
| Session page without S5_BASE | `akali-qa-no-s5base-placeholder.png` | Full-page screenshot showing "Preview unavailable (S5_BASE not configured)" placeholder; fullview button absent |

Video: not captured (stub server flow is synchronous/instant; no real agent interaction; full E2E video requires staging deployment with live Anthropic managed agent).

---

## DOM evaluation findings (Phase C critical path)

From `browser_evaluate()` on the S5_BASE-set session page:

```json
{
  "iframe_src": "https://preview.example.com/v1/preview/qa-akali-sess-001",
  "iframe_visible": true,
  "fullview_href": "https://preview.example.com/v1/preview/qa-akali-sess-001/fullview",
  "fullview_visible": true,
  "s5_base": "https://preview.example.com",
  "chat_input_disabled": false,
  "send_btn_disabled": false
}
```

From `browser_evaluate()` on the S5_BASE-unset session page:

```json
{
  "iframe_style_display": "none",
  "iframe_src": "",
  "placeholder_inner_html": "<span>Preview unavailable (S5_BASE not configured)</span>",
  "fullview_btn_style": "none",
  "s5_base": null
}
```

---

## Phase H gap — detailed finding

**What the ADR requires (T.S1.15 DoD):**
> "Playwright test: after SSE terminal event, Build button is enabled; verification summary panel is visible."

**What Phase H plan requires (ADR §Phase H):**
> When the SSE stream delivers a terminal `verificationStatus` event:
> - Re-enable the chat input and Build button in the UI.
> - Surface the `verificationReport` summary in the UI (collapsible panel or inline alert).

**What is present in the PR:**

Backend (`main.py`):
- `run_s4_poller` emits `event: verification` on the per-session asyncio queue (PASS)
- `GET /session/{id}/logs` streams these via SSE (PASS)

Frontend (`static/studio.js`):
- Has exactly one `EventSource` connection: `GET /session/{sessionId}/stream` (agent SSE)
- No `EventSource` or `fetch` subscription to `GET /session/{sessionId}/logs`
- No `addEventListener('verification', ...)` handler
- No `#verificationPanel`, `#verificationSummary`, or equivalent DOM element
- No `setInputEnabled(true)` call triggered by verification terminal state

**Conclusion:** The backend pipes are built and tested. The frontend wire from the SSE `/logs` endpoint to the chat-re-enable and summary panel is absent. Phase H is a backend-only partial implementation.

---

## Phase B — residual comment references (informational)

`studio.js` in the PR branch contains two comment-only references to `/approve`:

- Line 660: `// Phase B (S1 new-flow): doGenerate no longer calls /approve.`
- Line 839: `// Phase B (S1 new-flow): doDeploy no longer calls /approve.`

These are dead comments documenting the removal — no live `fetch('/approve')` calls remain. Unit test `test_studio_js_has_no_approve_fetch_calls` confirms zero live calls via regex. The regex excludes comment lines correctly. This is a PASS.

---

## Required actions before merge

1. **Phase H frontend (blocking):** Wire `GET /session/{sessionId}/logs` SSE in `studio.js`. On `event: verification` with terminal `status` (`passed` or `failed`): call `setInputEnabled(true)` and render a collapsible `verificationReport.summary` panel. Add the Playwright test per T.S1.15 DoD.
2. **Figma URL (advisory):** Provide the Figma URL for demo-studio-v3 session page frames before final ship-gate sign-off so future Akali runs can do pixel-level diff rather than spec-narrated comparison.

---

## Non-blocking observations

- The `"Generate demo"` button remains in the DOM (hidden by default via `generateBar.classList hidden`). When shown it calls the no-op `doGenerate()`. This is by design per Phase B ("button hidden by default; shown only for backward-compat UI state transitions") but is mildly confusing — the button label "Generate demo" implies action. No change required per plan.
- `doDeploy()` now adds a message "Build is triggered by the agent via MCP. Check the chat for progress." instead of calling `/approve`. The Deploy button label remains "Deploy Demo". This is acceptable per Phase B.
- The `"Open full screen"` button in the preview toolbar (line 962–963 in PR studio.js) now opens `s5Base + '/v1/preview/' + sessionId + '/fullview'` instead of `/session/{id}/preview`. This is correct and aligns with Phase C.

---
slug: deploybtn-only-build-trigger
title: deployBtn-only build trigger — remove agent trigger_factory path in demo-studio-v3
project: bring-demo-studio-live-e2e-v1
concern: work
status: approved
owner: karma
priority: P0
tier: quick
created: 2026-04-27
last_reviewed: 2026-04-27
qa_plan: required
qa_co_author: senna
tests_required: true
architecture_impact: minor
complexity: normal
orianna_gate_version: 2
---

## Context

demo-studio-v3 has two parallel build-trigger paths today:

1. **Agent-driven** — agent invokes the `trigger_factory` tool registered in `tools/demo-studio-v3/tool_dispatch.py::TOOLS`. Fires the build directly with no UI affordance. Currently the more common path during conversational flow.
2. **User-clicked** — `deployBtn` (created at `tools/demo-studio-v3/static/studio.js:99`, click handler at `:1051`, endpoint `POST /session/{id}/build` at `tools/demo-studio-v3/main.py:2635`). The button is `display: none` by default (`tools/demo-studio-v3/static/studio.css:186`) and only revealed by `showDeployButton()` when SSE event has `awaitingApproval: true` or agent text matches `/ready to deploy|approve|click.*deploy/i`.

The active project (`projects/work/active/bring-demo-studio-live-e2e-v1.md`) DoD constrains: "Build button is **not** an agent tool call." Today's reality violates that constraint. ADR-1 (`plans/approved/work/2026-04-27-adr-1-build-progress-bar.md`) was just amended to flag this gap. Duong's hands-off decision: collapse to deployBtn-only.

## Goal

The user-clicked `deployBtn` becomes the **sole** build trigger. The agent retains its conversational role (gather config, summarize, ask for approval) but loses the ability to invoke a build tool. Specifically:

- `trigger_factory` is unregistered from the agent's tool list and dispatch table.
- `SYSTEM_PROMPT` is updated to remove any "call the build tool" instruction; replacement guidance directs the agent to signal approval and stop.
- The existing `awaitingApproval → showDeployButton()` reveal gate is preserved unchanged. **Audit (T3) must document the upstream signal path** — this is one of: (a) a `set_phase`/`set_status` tool call the agent already makes, (b) text-match on agent output via `/ready to deploy|approve|click.*deploy/i` in the SSE chat handler, or (c) an explicit `awaitingApproval: true` flag emitted by another tool. T3 records which one(s) remain operative after `trigger_factory` removal so a follow-up plan can audit reliability.

No UI/UX changes ship with this plan. No S2 changes. Code-check QA only (visual QA waived per Duong instruction).

**Signal path (T3 audit):**
- **PATH A — text-regex (PRIMARY, OPERATIVE):** `static/studio.js:887` — `_applyPhaseHeuristics` matches accumulated agent text against `/ready to deploy|approve|click.*deploy/i` and calls `showDeployButton()`. With the updated `SYSTEM_PROMPT` directing the agent to tell the user to click Deploy, agent utterances will match this regex. This is the sole operative path post T1.
- **PATH B — Firestore snapshot:** `static/studio.js:940` — `d.awaitingApproval` read from Firestore doc. No Python server code writes `awaitingApproval` to Firestore anywhere in `tools/demo-studio-v3/`. **Inoperative** unless an external process sets the field.
- **PATH C — SSE chat event:** `static/studio.js:1193` — `data.awaitingApproval` on chat events. No server code emits this field. **Inoperative.**
- **PATH D — SSE status event:** `static/studio.js:1236` — `data.awaitingApproval` on status events. No server code emits this field. **Inoperative.**
- **Summary:** PATH A (text regex at `studio.js:887`) is the sole operative `awaitingApproval` signal path post trigger_factory removal. No gap; no stop-the-line condition. Reliability hardening of PATH A (making the regex more precise or adding a structured signal) is deferred to a follow-up plan per §Out of scope.

## Tasks

### T1 — Remove trigger_factory from tool registry (impl)

- kind: impl
- estimate_minutes: 20
- files: `tools/demo-studio-v3/tool_dispatch.py`
- detail: Delete the `trigger_factory` entry from the `TOOLS` list (currently around line ~75). Delete the corresponding entry from the dispatch table (the `_HANDLERS` dict around line ~319 — verify exact handler name on disk; likely `_handle_trigger_factory` or close variant). Keep the handler function definition itself; annotate it with `# DEPRECATED: removed from TOOLS — see plan 2026-04-27-deploybtn-only-build-trigger. Function body retained one PR cycle as defence-in-depth; delete in follow-up.`
- DoD: `TOOLS` list no longer contains `trigger_factory`; `_HANDLERS` dict no longer routes `"trigger_factory"`; orphan function carries DEPRECATED comment; file imports/syntax clean.

### T2 — Update SYSTEM_PROMPT to drop build-tool instructions (impl)

- kind: impl
- estimate_minutes: 15
- files: locate via `rg "SYSTEM_PROMPT\s*=" tools/demo-studio-v3/` (likely a top-level prompt module; implementer to confirm).
- detail: Remove all sentences referencing `trigger_factory` or "call the build tool" / "invoke the build". Insert replacement guidance with this contract: "When the user has approved the configuration, indicate the build should start so the Deploy button appears. DO NOT invoke any build tool — there is no such tool. The user clicks Deploy to start the build." Exact wording is the implementer's call; the contract is: agent must signal `awaitingApproval` (via whichever mechanism T3 identifies) and stop.
- DoD: `rg -n "trigger_factory" tools/demo-studio-v3/` returns no hits in prompt strings (only the DEPRECATED handler from T1); SYSTEM_PROMPT contains explicit "do not invoke any build tool" guidance.

### T3 — Audit and document the awaitingApproval signal path (impl/audit)

- kind: impl
- estimate_minutes: 25
- files: read-only audit across `tools/demo-studio-v3/main.py`, `tools/demo-studio-v3/tool_dispatch.py`, `tools/demo-studio-v3/static/studio.js`. Plan-side write: append findings to this plan's §Goal (this file) under a new "Signal path (T3 audit)" sub-bullet — Talon's edit, in-place.
- detail: Trace how `awaitingApproval: true` reaches `showDeployButton()` once `trigger_factory` is gone. Identify (a) any tool besides `trigger_factory` that sets approval state, (b) the SSE chat-handler regex/text-match path, (c) any other `awaitingApproval`-emitting site. Confirm at least one path remains operative. If audit reveals NO surviving path, STOP — this becomes a follow-up plan, not a code change in this PR. Document the path in plan §Goal.
- DoD: Plan §Goal has a "Signal path (T3 audit)" sub-section listing every file:line that emits `awaitingApproval: true` or matches the deploy-text regex; a one-line summary states which path remains primary post-T1.

### TX1 — xfail integration test: trigger_factory not registered (xfail-then-pass)

- kind: xfail
- estimate_minutes: 25
- files: `tools/demo-studio-v3/tests/integration/test_tool_registry_no_trigger_factory.py` (new). <!-- orianna: ok -->
- detail: Per Rule 12 — commit this xfail test on the branch BEFORE T1 lands. Test imports the tool registry (`TOOLS` list or equivalent accessor like `get_registered_tools()`) and asserts `"trigger_factory"` is not among the registered tool names. Marked xfail initially; flip to pass once T1 ships in the same branch. Test references this plan slug in a docstring.
- DoD: Test file present; xfail-then-pass commit sequence visible in branch history; CI green on the pass commit.

### TX2 — xfail integration test: agent system prompt forbids trigger_factory (xfail-then-pass)

- kind: xfail
- estimate_minutes: 35
- files: `tools/demo-studio-v3/tests/integration/test_agent_does_not_call_trigger_factory.py` (new). <!-- orianna: ok -->
- detail: Per Rule 12 — xfail-first. Mock the Anthropic client at the SDK boundary; assert that (a) the system prompt string passed to the client does NOT contain `trigger_factory`, and (b) the system prompt contains an explicit do-not-invoke-build-tool instruction (assert on a stable substring like `"DO NOT invoke any build tool"` or `"no such tool"` — implementer chooses, must match T2 wording). Optional secondary assertion: if the test simulates an agent response with text matching `/build|deploy|ship/i`, none of the returned `tool_use` blocks have `name: "trigger_factory"` — but this is bounded by the mock setup, so primary assertions are on the prompt itself.
- DoD: Test file present; xfail-then-pass commits in branch history; CI green on the pass commit.

## QA Plan

**UI involvement:** no

### Acceptance criteria

Reviewer (Senna) confirms via code-check:
- `TOOLS` list and `_HANDLERS` dict in `tool_dispatch.py` no longer reference `trigger_factory`.
- `SYSTEM_PROMPT` no longer instructs the agent to invoke a build tool; explicit do-not-invoke-build-tool guidance is present.
- The orphan `_handle_trigger_factory` function (or equivalent name) carries the DEPRECATED comment per T1.
- T3 audit findings are recorded in §Goal of this plan and identify at least one surviving `awaitingApproval` signal path.

### Happy path (user flow)

The green-path test scenarios that must pass — Vi runs:
- TX1 passes — `trigger_factory` is absent from the registered tool names; the tool registry import succeeds and the assertion holds.
- TX2 passes — the system prompt string passed to the Anthropic SDK contains no `trigger_factory` reference and contains the explicit do-not-invoke-build-tool substring.
- Manual smoke (Senna or Vi, not Akali): start a session, drive the agent to the "approval" turn, confirm `deployBtn` appears via the surviving signal path identified in T3, click it, and confirm `POST /session/{id}/build` fires. (Code-flow check, not a visual diff — no screenshot required.)

### Failure modes (what could break)

Regression guards prevent these breakage modes:
- A stale test under `tools/demo-studio-v3/tests/` that depends on `trigger_factory` being registered in `TOOLS` would silently fail post-T1; Vi must sweep the existing unit + integration suite green and flag/update/remove any test that references `trigger_factory` registration in the same PR.
- A residual fixture or debug path that routes by string name `"trigger_factory"` would surface a `NameError` if the handler body were deleted; the orphan function retention (T1) plus the `_HANDLERS` dispatch removal converts that into a clear log instead of a silent failure.
- The pre-push TDD-gate hook (Rule 12) confirms the xfail-then-pass commit sequence on the branch — guards against an impl commit landing without the xfail predecessor for TX1/TX2.
- The pre-commit unit-test hook for `tools/demo-studio-v3/` package must remain green — guards against import-level breakage from the registry edit.

### QA artifacts expected

QA-Waiver: visual QA waived per Duong instruction — code-check only.

No artifacts ship for this plan beyond the test files themselves (TX1, TX2). Specifically: no Akali report, no Playwright video, no screenshots, no Figma diff. The PR body will carry the `QA-Waiver:` line above in lieu of a `QA-Report:` link.

## Out of scope

- Deleting the `_handle_trigger_factory` function body entirely — deferred to a follow-up cleanup PR (one PR cycle of defence-in-depth retention).
- UI changes to `deployBtn` visibility logic, CSS, or `showDeployButton()` regex.
- S2-side changes (build orchestrator, factory worker, deploy pipeline).
- The seed-config-on-session-create work (separate plan).
- Reliability hardening of the surviving `awaitingApproval` signal path — if T3 audit finds the path is fragile, that is a follow-up plan, not part of this scope.
- Playwright/Akali pass, visual diff, Figma comparison — UI surface unchanged.

## Decision log

- **2026-04-27** [hands-off-autodecide] — Keep the orphan `_handle_trigger_factory` function body for one PR cycle rather than deleting it in this PR. Rationale: defence-in-depth — if any caller still routes by string name (e.g. a stale fixture, a debug path), we want the dispatch failure to surface a clear log rather than a silent NameError. Follow-up cleanup PR removes the body.
- **2026-04-27** [hands-off-autodecide] — TX2 asserts on the system prompt string rather than on a live agent transcript. Rationale: a transcript-level test would require either a live Anthropic call (fragile, costly, non-deterministic) or a heavy mock harness (out of scope for a quick-lane plan). Asserting on the prompt's instruction-to-the-model is a stable proxy for "agent will not call this tool" given the tool is also unregistered (TX1).
- **2026-04-27** [hands-off-autodecide] — `qa_co_author: not-required` and no `UX-Waiver:`. Rationale: no UI surface ships in this plan. The §UX Spec gate (Rule 22) targets UI-touching plans; this plan touches `tool_dispatch.py`, `SYSTEM_PROMPT`, and tests only. The `deployBtn` existence and visibility logic are preserved unchanged.
- **2026-04-27** [hands-off-autodecide] — T3 is a read-only audit task with a plan-edit deliverable rather than a code change. Rationale: the dispatch context flagged "verify and document"; if the audit reveals no surviving signal path, that is a stop-the-line discovery worth a separate plan, not silent code addition inside this one. Keeping T3 audit-only enforces that boundary.

## References

- `projects/work/active/bring-demo-studio-live-e2e-v1.md` — DoD constraint "Build button is not an agent tool call".
- `plans/approved/work/2026-04-27-adr-1-build-progress-bar.md` — ADR-1 amendment flagging the dual-path gap.
- `tools/demo-studio-v3/tool_dispatch.py` — `TOOLS` list (~line 75), `_HANDLERS` dict (~line 319). Paths relative to the work workspace repo (`~/Documents/Work/mmp/workspace/<branch>/`).
- `tools/demo-studio-v3/static/studio.js:99` — `deployBtn` creation; `:1051` click handler.
- `tools/demo-studio-v3/static/studio.css:186` — `display: none` default.
- `tools/demo-studio-v3/main.py:2635` — `POST /session/{id}/build` endpoint.
- Strawberry Rule 12 — xfail-first TDD gate.

## Scope amendment 2026-04-27 (post-review)

Post-review findings from Senna (BLOCKER B1) and Lucian (IMPORTANT I1) identified two gaps that the original plan did not size:

- **T4** — Wire `doDeploy()` in `static/studio.js` to `POST /session/{id}/build`. The original plan left `doDeploy()` as a no-op (system message only, no `fetch()`). Combined with the `trigger_factory` MCP removal, the build path was completely dead. Fix: add `fetch('/session/' + sessionId + '/build', {method: 'POST', credentials: 'same-origin'})` in `doDeploy()`, modelled on the `doStop()` pattern (error handling, response shape, message rendering). Endpoint confirmed live at `main.py:2635`. Fixes Senna B1.

- **T5** — Strip `trigger_factory` from `mcp_app.py`'s registered MCP tool list (L131, L289-294, L329 — `_handle_trigger_factory` handler + `trigger_factory` tool registration + `_TOOL_REGISTRY` entry). The managed-agent runtime (`MANAGED_AGENT_ID` path) could still hit `trigger_factory` via `/mcp`, leaving T2 DoD unmet. Additionally: add a `# DEPRECATED — Wave 6 deletion target; kept until then` banner at the top of `setup_agent.py` and update its embedded `SYSTEM_PROMPT` copy to drop all `trigger_factory` references. Do not delete `setup_agent.py` — Wave 6's job. Fixes Lucian I1 and completes T2 DoD.

**Rationale:** original plan undersized the surface; `mcp_app.py` and `studio.js` `doDeploy()` were outside original scope but are required for a complete build path. Post-review scope expansion is bounded: no S2 changes, no UI CSS, no agent-proxy changes.

## Orianna approval

- **Date:** 2026-04-27
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** §QA Plan now uses the canonical four sub-headings; both `check_qa_plan_body` and `plan-structure-lint.sh` exit 0. Plan has clear owner (Karma), P0 priority, concrete file targets and DoD per task, and TX1/TX2 xfail-first tests satisfy Rule 12 for `tests_required: true`. No UI surface so §UX Spec is correctly absent; visual QA-Waiver is justified and recorded in §QA artifacts expected. Scope is tight (tool_dispatch.py + SYSTEM_PROMPT + audit) with explicit out-of-scope bounding and follow-up deferrals captured in §Decision log.

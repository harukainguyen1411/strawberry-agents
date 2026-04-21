---
status: proposed
orianna_gate_version: 2
concern: work
parent_plan: 2026-04-21-demo-studio-v3-vanilla-api-ship.md
owner: aphelios
created: 2026-04-21
complexity: complex
tests_required: true
tags:
  - demo-studio
  - vanilla-api
  - re-architecture
  - work
  - task-breakdown
---

# Task decomposition — Demo Studio v3 Vanilla Messages API Ship (Option B)

<!-- orianna: ok — all bare module, file, env-var, HTTP-path, and Firestore-path tokens in this file (agent_proxy.py, conversation_store.py, tool_dispatch.py, stream_translator.py, config_mgmt_client.py, factory_bridge.py, setup_agent.py, managed_session_client.py, managed_session_monitor.py, session_store.py, session.html, static/session.js, .env.example, deploy.sh, server.ts, mcp_app.py, main.py, firestore/indexes.json, /session/{id}/chat, /session/{id}/stream, /dashboard/managed-agents/*, /v1/config/{id}, demo-studio-sessions/{id}/conversations/{seq}, DEMO_STUDIO_MCP_URL, DEMO_STUDIO_MCP_TOKEN, MANAGED_AGENT_ID, MANAGED_ENVIRONMENT_ID, MANAGED_VAULT_ID, MANAGED_AGENT_DASHBOARD, MANAGED_SESSION_MONITOR_ENABLED, IDLE_WARN_MINUTES, IDLE_TERMINATE_MINUTES, SCAN_INTERVAL_SECONDS, ANTHROPIC_API_KEY, CLAUDE_MODEL, MAX_TOKENS, MAX_TURNS, SYSTEM_PROMPT, ConversationStore.append, ConversationStore.load, client.messages.stream, tool_dispatch.dispatch, tool_result.content, config_mgmt_client.fetch_schema, config_mgmt_client.fetch_config, config_mgmt_client.patch_config, factory_bridge.trigger_build, web_search_20241022, integration/demo-studio-v3-waves-1-4, integration/demo-studio-v3-vanilla-api, tdd-gate.yml, managed-agent-lifecycle-retirement.md, managed-agent-dashboard-retirement.md) reference files, routes, Firestore paths, env vars, SDK methods, or branches inside the missmp/company-os work workspace OR are prospective future-ADR filenames. This task file creates no strawberry-agents files under those names; parent plan carries the same claim-contract preamble. -->

## Context

Parent: `plans/proposed/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md` <!-- orianna: ok -->
(follow through `approved/` and `in-progress/` subdirs as the gate promotes it; frontmatter `parent_plan:` carries the basename). <!-- orianna: ok -->


This file decomposes phases A–F of the parent's §8 into tasks. Rule 12 (xfail test before impl on same branch) is honored: every `feat` / `refactor` task has a preceding `test` task. Per-task `estimate_minutes` is capped at 60 (plan-structure §D4); larger units are split. Xayah's parallel test-plan file provides the concrete assertions; tasks here cite DoD hooks that Xayah's file will fill in.

Executor tier notes (parent §12 Handoff): Phase A/B/C → Viktor (complex builder). Phase D → Ekko/Jayce (mechanical). Phase E → Vi off Xayah's test plan. Phase F → Heimerdinger + Ekko.

## Phase dependency graph

```
A (agent_proxy + conv_store + stream_translator)
   └── blocks ──► B (tool_dispatch + five handlers)
                     └── blocks ──► C (SSE route rewire + UI event names)
                                       └── blocks ──► E (E2E smoke)
                                                        └── blocks ──► F (ship gate)
D (deletion sweep) runs parallel with A/B/C, must land before E.
```

Inter-phase blocking explicit: A→B, B→C, A/B/C→E, D→E, E→F.

## Test plan

Test-authoring authority is **Xayah** (see Sona's parallel brief). Xayah's test-plan file is the source of truth for concrete assertions across all phases; this file references Xayah's test IDs through DoD hooks ("xfail test `T.A.1` committed", "E2E scenario N green"). <!-- orianna: ok -->

Minimum coverage expected per parent plan's "Test plan" section:

1. **E2E smoke v2 — 8 scenarios** against staging (parent §"Test plan" 1–8): empty-session Slack trigger, agent config via tool call → S2, preview iframe from S5, fullview new-tab, build cold S3→S4 round-trip, verification pass in UI, iterate-warm same projectId, verification fail→iterate→pass. Each with video + screenshots per Rule 16.
2. **Unit + xfail** per parent "Test plan" tail: `conversation_store` round-trip (task T.A.1 below), <!-- orianna: ok --> `tool_dispatch` unknown-tool + `is_error: true` surface (T.B.1), <!-- orianna: ok --> `stream_translator` per-event mapping (T.A.5a–T.A.5f), tool-use loop termination + `MAX_TURNS` cap (T.A.7a–T.A.7c). <!-- orianna: ok -->
3. **Per Rule 12** every impl commit in this breakdown is preceded by an xfail commit on the same branch; the xfail commit cites the parent plan slug `2026-04-21-demo-studio-v3-vanilla-api-ship`.

Xayah's file, once published, will enumerate exact assertion IDs mapped back to the T.* IDs below.

## Tasks

Phase group labels use **T.<PHASE>.<N>** (parent §8 phase letters A–F). Tasks for a single large work unit split into lettered sub-tasks (e.g. T.A.5a..f) to respect the 60-min cap.

### Phase A — Agent-proxy rewrite + conversation persistence

Branch: `integration/demo-studio-v3-vanilla-api` or the revert-branch per parent §7 Q4 pick (a). <!-- orianna: ok -->
Anchor: parent §3.3, §3.4, §5.1, §5.3, §5.4.

- [ ] **T.A.1** — Add xfail test for `conversation_store` Firestore round-trip. kind: test | estimate_minutes: 45 | blocked_by: none | files: `company-os/tools/demo-studio-v3/tests/test_conversation_store.py` (new) | detail: xfail unit test asserting `ConversationStore.append` + `ConversationStore.load` round-trip ordering by `seq` (write 3 messages out-of-order, read back ordered, assert `seq` monotonic). Parent §3.3. Firestore emulator-backed. | DoD: xfail test committed; CI `tdd-gate.yml` sees it. <!-- orianna: ok -->
- [ ] **T.A.2a** — Implement `ConversationStore.append` method. kind: feat | estimate_minutes: 45 | blocked_by: T.A.1 | files: `company-os/tools/demo-studio-v3/conversation_store.py` (new) | detail: `append(session_id, message) -> seq` using Firestore transaction to compute monotonic `seq` (read max + 1, do not trust timestamps). Schema per parent §3.3. | DoD: append path unit test green; transaction retries on contention. <!-- orianna: ok -->
- [ ] **T.A.2b** — Implement `ConversationStore.load` + `load_since`. kind: feat | estimate_minutes: 45 | blocked_by: T.A.2a | files: `company-os/tools/demo-studio-v3/conversation_store.py` (extend) | detail: `load(session_id)` returns ordered list; `load_since(session_id, seq)` returns tail for SSE replay. Order strictly by `seq` field, not timestamps. | DoD: T.A.1 flips green for round-trip case. <!-- orianna: ok -->
- [ ] **T.A.2c** — Implement `ConversationStore.truncate_for_model`. kind: feat | estimate_minutes: 45 | blocked_by: T.A.2b | files: `company-os/tools/demo-studio-v3/conversation_store.py` (extend) | detail: `truncate_for_model(messages, max_tokens)` drops oldest non-system messages until under limit; preserves tool_use/tool_result pairing. Parent §5.1. | DoD: unit test on 20-message transcript truncated to 5k tokens preserves last user+assistant+tool_result chain. <!-- orianna: ok -->
- [ ] **T.A.2d** — Enforce single-boundary invariant on `conversation_store.py`. kind: refactor | estimate_minutes: 30 | blocked_by: T.A.2c | files: repo-wide Grep + `company-os/tools/demo-studio-v3/conversation_store.py` | detail: Grep confirms nothing outside `conversation_store.py` reads/writes the `demo-studio-sessions/{id}/conversations/{seq}` subcollection directly (mirrors SE boundary). Add a module-header comment pinning the invariant. Parent §5.1. | DoD: Grep returns one file. <!-- orianna: ok -->
- [ ] **T.A.3** — Add xfail test for `SYSTEM_PROMPT` constant wiring. kind: test | estimate_minutes: 30 | blocked_by: none | files: `company-os/tools/demo-studio-v3/tests/test_system_prompt.py` (new) | detail: xfail asserts `from agent_proxy import SYSTEM_PROMPT` returns a non-empty string (module-level constant), and `setup_agent` is not imported from S1 entry. Parent §5.4 + §10 Q2 pick (a). | DoD: xfail committed; references parent §5.4. <!-- orianna: ok -->
- [ ] **T.A.4** — Extract `SYSTEM_PROMPT` to `agent_proxy.py`; decommission `setup_agent` imports. kind: refactor | estimate_minutes: 60 | blocked_by: T.A.3 | files: `company-os/tools/demo-studio-v3/agent_proxy.py`, `company-os/tools/demo-studio-v3/setup_agent.py` | detail: Lift system-prompt string out of `setup_agent.py` into `agent_proxy.py` as module-level `SYSTEM_PROMPT: str`. Mark `setup_agent.py` deprecated; full delete is phase D (T.D.1). Remove remaining `setup_agent` imports. | DoD: T.A.3 flips green; Grep `from setup_agent` returns 0 hits outside `setup_agent.py` itself. <!-- orianna: ok -->
- [ ] **T.A.5a** — Add xfail test: `stream_translator` maps `content_block_start`. kind: test | estimate_minutes: 20 | blocked_by: none | files: `company-os/tools/demo-studio-v3/tests/test_stream_translator.py` (new) | detail: xfail: `content_block_start` event → no browser event emitted (consumed for state only). Parent §5.5. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.A.5b** — Add xfail test: text `content_block_delta` maps to `text_delta`. kind: test | estimate_minutes: 20 | blocked_by: T.A.5a | files: `company-os/tools/demo-studio-v3/tests/test_stream_translator.py` (extend) | detail: xfail: text delta → `{event: "text_delta", data: {text: "..."}}`. Parent §3.5. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.A.5c** — Add xfail test: tool_use `content_block_delta` maps to `tool_use`. kind: test | estimate_minutes: 20 | blocked_by: T.A.5a | files: `company-os/tools/demo-studio-v3/tests/test_stream_translator.py` (extend) | detail: xfail: tool_use input_json_delta accumulates then emits `{event: "tool_use", data: {name, input}}` on `content_block_stop`. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.A.5d** — Add xfail test: `message_delta` with stop_reason maps to `turn_end`. kind: test | estimate_minutes: 20 | blocked_by: T.A.5a | files: `company-os/tools/demo-studio-v3/tests/test_stream_translator.py` (extend) | detail: xfail: `message_delta` carrying `stop_reason` + `usage` → `{event: "turn_end", data: {stop_reason, usage}}`. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.A.5e** — Add xfail test: error event maps to `error`. kind: test | estimate_minutes: 20 | blocked_by: T.A.5a | files: `company-os/tools/demo-studio-v3/tests/test_stream_translator.py` (extend) | detail: xfail: error frame → `{event: "error", data: {code, message}}`. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.A.5f** — Add xfail test: `message_stop` maps to stream close. kind: test | estimate_minutes: 20 | blocked_by: T.A.5a | files: `company-os/tools/demo-studio-v3/tests/test_stream_translator.py` (extend) | detail: xfail: `message_stop` → no browser event but signals adapter to close sink. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.A.6a** — Implement `stream_translator.py` text + tool_use paths. kind: feat | estimate_minutes: 60 | blocked_by: T.A.5b, T.A.5c | files: `company-os/tools/demo-studio-v3/stream_translator.py` (new) | detail: Pure module; no I/O. Map Messages API streaming events for text deltas and tool_use blocks to parent §3.5 stable browser events. | DoD: T.A.5b + T.A.5c flip green; Grep confirms no network/Firestore imports. <!-- orianna: ok -->
- [ ] **T.A.6b** — Implement `stream_translator.py` turn_end + error + stop paths. kind: feat | estimate_minutes: 45 | blocked_by: T.A.6a, T.A.5d, T.A.5e, T.A.5f | files: `company-os/tools/demo-studio-v3/stream_translator.py` (extend) | detail: Add `message_delta` → `turn_end`, error frame → `error`, `message_stop` close signal. | DoD: T.A.5d/e/f flip green. <!-- orianna: ok -->
- [ ] **T.A.7a** — Add xfail test: tool-use loop `end_turn` terminates cleanly. kind: test | estimate_minutes: 30 | blocked_by: T.A.1, T.A.5a | files: `company-os/tools/demo-studio-v3/tests/test_agent_proxy_loop.py` (new) | detail: xfail with mocked stream: `stop_reason=end_turn` after one round persists assistant message and returns. Parent §5.3 pseudocode. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.A.7b** — Add xfail test: tool-use loop dispatches tool then terminates. kind: test | estimate_minutes: 30 | blocked_by: T.A.7a | files: `company-os/tools/demo-studio-v3/tests/test_agent_proxy_loop.py` (extend) | detail: xfail: `tool_use` → dispatch (mocked) → append `tool_result` → follow-up turn `end_turn`. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.A.7c** — Add xfail test: tool-use loop hits `MAX_TURNS` cap. kind: test | estimate_minutes: 30 | blocked_by: T.A.7a | files: `company-os/tools/demo-studio-v3/tests/test_agent_proxy_loop.py` (extend) | detail: xfail: manufactured infinite tool-use loop raises `MaxTurnsExceeded` at `MAX_TURNS=20`. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.A.8a** — Implement `agent_proxy.run_turn` skeleton + `messages.stream` wiring. kind: feat | estimate_minutes: 60 | blocked_by: T.A.2b, T.A.4, T.A.6b, T.A.7a | files: `company-os/tools/demo-studio-v3/agent_proxy.py` (rewrite) | detail: Skeleton per parent §5.3: load conversation, append user msg, enter `client.messages.stream` ctx manager, fan events through `stream_translator` into `sse_sink`. No tool handling in this task (stub). | DoD: T.A.7a flips green. <!-- orianna: ok -->
- [ ] **T.A.8b** — Implement tool-use branch in `run_turn` with dispatch stub. kind: feat | estimate_minutes: 45 | blocked_by: T.A.8a, T.A.7b | files: `company-os/tools/demo-studio-v3/agent_proxy.py` (extend) | detail: On `stop_reason=="tool_use"`: extract each `tool_use` block; call `tool_dispatch.dispatch` (raises `NotImplementedError` until phase B — test uses mock); append `tool_result` blocks; loop. | DoD: T.A.7b flips green. <!-- orianna: ok -->
- [ ] **T.A.8c** — Implement `MAX_TURNS` safety cap + `UnexpectedStopReason`. kind: feat | estimate_minutes: 30 | blocked_by: T.A.8b, T.A.7c | files: `company-os/tools/demo-studio-v3/agent_proxy.py` (extend) | detail: Hard cap at `MAX_TURNS=20`; raise `MaxTurnsExceeded`. Unknown `stop_reason` raises `UnexpectedStopReason`. Module exports: `run_turn`, `SYSTEM_PROMPT`, `CLAUDE_MODEL="claude-sonnet-4-6"`, `MAX_TOKENS`, `MAX_TURNS`. | DoD: T.A.7c flips green; Grep confirms no `managed_session_client` / `setup_agent` imports. <!-- orianna: ok -->
- [ ] **T.A.9** — Declare Firestore composite index for conversations subcollection. kind: feat | estimate_minutes: 45 | blocked_by: T.A.2b | files: `company-os/tools/demo-studio-v3/firestore/indexes.json` (or equivalent), `company-os/tools/demo-studio-v3/conversation_store.py` | detail: Composite index `demo-studio-sessions/{id}/conversations` ordered by `seq ASC`. If no declarative index config exists in the work workspace, document in `conversation_store.py` docstring and defer creation to phase F deploy (T.F.2). Parent §3.3. | DoD: index config committed OR deferred task explicitly linked. <!-- orianna: ok -->

Phase A exit: single-turn conversation runs end-to-end with no tools on staging Messages API; Firestore round-trip verified; SSE streams text deltas. Gates phase B.

### Phase B — Tool-dispatch registry with all five tools

Anchor: parent §3.4, §5.2.

- [ ] **T.B.1a** — Add xfail test: `tool_dispatch.dispatch` unknown-tool returns is_error. kind: test | estimate_minutes: 30 | blocked_by: T.A.8c | files: `company-os/tools/demo-studio-v3/tests/test_tool_dispatch.py` (new) | detail: xfail: `dispatch("nonexistent", {}, ctx)` returns `tool_result` dict with `is_error: true`, does not raise. Parent §3.4. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.B.1b** — Add xfail test: `TOOLS` export shape + `HANDLERS` key parity. kind: test | estimate_minutes: 30 | blocked_by: T.B.1a | files: `company-os/tools/demo-studio-v3/tests/test_tool_dispatch.py` (extend) | detail: xfail: `TOOLS` is non-empty list of dicts each with `name` + (`input_schema` OR `type`); `HANDLERS` keys equal the handler-bearing subset of `TOOLS` names (excluding `web_search`). | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.B.2a** — Implement `tool_dispatch.py` skeleton + TOOLS list. kind: feat | estimate_minutes: 45 | blocked_by: T.B.1b | files: `company-os/tools/demo-studio-v3/tool_dispatch.py` (new) | detail: Export `TOOLS` (5 defs: 4 custom + `web_search_20241022`), `HANDLERS` (empty dict populated in T.B.4/6/8). Parent §3.4. | DoD: T.B.1b flips green; web_search entry has `type: web_search_20241022`. <!-- orianna: ok -->
- [ ] **T.B.2b** — Implement `dispatch` function with unknown-tool path. kind: feat | estimate_minutes: 30 | blocked_by: T.B.2a | files: `company-os/tools/demo-studio-v3/tool_dispatch.py` (extend) | detail: `async def dispatch(name, input, ctx) -> dict`. Unknown tool → `{"is_error": True, "content": "unknown tool: " + name}`. Handler-present names delegate to `HANDLERS[name]`. | DoD: T.B.1a flips green. <!-- orianna: ok -->
- [ ] **T.B.3** — Add xfail tests for `get_schema` + `get_config` handlers. kind: test | estimate_minutes: 45 | blocked_by: T.B.2b | files: `company-os/tools/demo-studio-v3/tests/test_tool_dispatch.py` (extend) | detail: 2 xfail cases: (a) `get_schema` handler calls mocked `config_mgmt_client.fetch_schema()` once and wraps result as `tool_result.content`. (b) `get_config` handler calls `fetch_config(session_id)` similarly. Parent §5.2. | DoD: 2 xfail cases. <!-- orianna: ok -->
- [ ] **T.B.4** — Implement `get_schema` + `get_config` handlers. kind: feat | estimate_minutes: 60 | blocked_by: T.B.3 | files: `company-os/tools/demo-studio-v3/tool_dispatch.py` (extend) | detail: Thin proxies to existing `config_mgmt_client.py`. Lazy import. Error mapping (NotFound/Unauthorized/ServiceUnavailable) mirrors TS MCP `server.ts` user-facing strings per parent §5.2. | DoD: T.B.3 flips green; Grep-compare on 3 error paths against `server.ts`. <!-- orianna: ok -->
- [ ] **T.B.5a** — Add xfail test: `set_config` success path. kind: test | estimate_minutes: 30 | blocked_by: T.B.2b | files: `company-os/tools/demo-studio-v3/tests/test_tool_dispatch.py` (extend) | detail: xfail: `set_config` handler with valid `(path, value)` calls `config_mgmt_client.patch_config(session_id, path, value)` exactly once. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.B.5b** — Add xfail tests: `set_config` 403 + 503 error mapping. kind: test | estimate_minutes: 30 | blocked_by: T.B.5a | files: `company-os/tools/demo-studio-v3/tests/test_tool_dispatch.py` (extend) | detail: 2 xfail cases: 403 → "unauthorized" string; 503 → "config service unavailable" string matching TS MCP `server.ts`. | DoD: 2 xfail cases. <!-- orianna: ok -->
- [ ] **T.B.6** — Implement `set_config` handler + TS MCP `server.ts` string parity. kind: feat | estimate_minutes: 60 | blocked_by: T.B.5b | files: `company-os/tools/demo-studio-v3/tool_dispatch.py` (extend) | detail: `handle_set_config` proxies `config_mgmt_client.patch_config`. Catch-and-map S2 errors to exact user-facing strings from TS MCP `server.ts`. Add a compare-table comment listing pairs. Parent §5.2. | DoD: T.B.5a + T.B.5b flip green. <!-- orianna: ok -->
- [ ] **T.B.7** — Add xfail test for `trigger_factory` handler. kind: test | estimate_minutes: 30 | blocked_by: T.B.2b | files: `company-os/tools/demo-studio-v3/tests/test_tool_dispatch.py` (extend) | detail: xfail: `trigger_factory` handler calls `factory_bridge.trigger_build(session_id)` once; wraps returned `projectId` into `tool_result.content` dict. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.B.8** — Implement `trigger_factory` handler + web_search passthrough doc. kind: feat | estimate_minutes: 45 | blocked_by: T.B.7 | files: `company-os/tools/demo-studio-v3/tool_dispatch.py` (extend) | detail: `handle_trigger_factory` proxies to `factory_bridge.trigger_build`. Module docstring notes `web_search_20241022` has no handler (Anthropic executes server-side; content blocks pass through `agent_proxy` unmodified). Parent §3.4. | DoD: T.B.7 flips green; HANDLERS has 4 keys. <!-- orianna: ok -->
- [ ] **T.B.9** — Wire `agent_proxy.run_turn` to real `tool_dispatch.dispatch`. kind: feat | estimate_minutes: 45 | blocked_by: T.B.4, T.B.6, T.B.8 | files: `company-os/tools/demo-studio-v3/agent_proxy.py` | detail: Replace `NotImplementedError` stub (planted in T.A.8b) with `await tool_dispatch.dispatch(block.name, block.input, ctx)`. Pass `SessionContext` with `session_id`, auth, request-scoped clients. | DoD: integration test — `set_config` from mocked Anthropic stream reaches S2 and writes. <!-- orianna: ok -->

Phase B exit: round-trip `set_config` → S2 reflects write within 2 s (parent §8 phase B gate). Gates phase C.

### Phase C — SSE stream adaptation for vanilla streaming format

Anchor: parent §3.5, §5.5.

- [ ] **T.C.1a** — Add xfail test: `/session/{id}/stream` emits stable event set only. kind: test | estimate_minutes: 45 | blocked_by: T.B.9 | files: `company-os/tools/demo-studio-v3/tests/test_session_stream_route.py` (new) | detail: xfail against in-memory FastAPI/Starlette client: route emits SSE events only in `text_delta | tool_use | tool_result | turn_end | error`. No legacy managed-agent event names. Parent §3.5. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.C.1b** — Add xfail test: `turn_end` payload shape. kind: test | estimate_minutes: 30 | blocked_by: T.C.1a | files: `company-os/tools/demo-studio-v3/tests/test_session_stream_route.py` (extend) | detail: xfail: `turn_end` carries `stop_reason` + `usage` per parent §3.5. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.C.2a** — Rewire `/session/{id}/stream` to subscribe to `agent_proxy.run_turn` sink. kind: refactor | estimate_minutes: 60 | blocked_by: T.C.1b | files: `company-os/tools/demo-studio-v3/main.py`, `company-os/tools/demo-studio-v3/agent_proxy.py` (sink adapter) | detail: Replace managed-agent event subscription with `sse_sink` adapter agent_proxy writes into. Remove `managed_session_client` import from this route. | DoD: T.C.1a flips green; Grep confirms `managed_session_client` not imported by `main.py`. <!-- orianna: ok -->
- [ ] **T.C.2b** — Wire `/session/{id}/chat` to persist user message and trigger `run_turn`. kind: refactor | estimate_minutes: 45 | blocked_by: T.C.2a | files: `company-os/tools/demo-studio-v3/main.py` | detail: `/session/{id}/chat` accepts user text, writes to `conversation_store`, spawns `agent_proxy.run_turn` (async task or direct handler) which feeds the live SSE sink. | DoD: T.C.1b flips green; end-to-end chat→stream handshake works against local Anthropic mock. <!-- orianna: ok -->
- [ ] **T.C.3** — Add xfail test: browser event-name stability. kind: test | estimate_minutes: 30 | blocked_by: T.C.1a | files: `company-os/tools/demo-studio-v3/tests/test_session_stream_route.py` (extend) | detail: xfail: SSE stream in `EventSource`-style harness asserts event-name set equals parent §3.5. Parent §5.5 target: zero UI delta. | DoD: 1 xfail case; if flips green after T.C.2b lands, T.C.4 is a no-op. <!-- orianna: ok -->
- [ ] **T.C.4** — Patch `session.html` + `static/session.js` for new event set (conditional). kind: feat | estimate_minutes: 60 | blocked_by: T.C.3 | files: `company-os/tools/demo-studio-v3/session.html`, `company-os/tools/demo-studio-v3/static/session.js` | detail: **Only if T.C.3 still fails after T.C.2b.** Update `EventSource` handlers to consume `text_delta` / `tool_use` / `tool_result` / `turn_end` / `error`. Seraphine is the executor. | DoD: T.C.3 flips green; if skipped, closeout commit body notes skipped. <!-- orianna: ok -->

Phase C exit: browser renders text deltas smoothly; tool-use + tool-result indicators visible. Gates phase E.

### Phase D — Deletion sweep

Runs parallel with A/B/C; **must complete before phase E** to avoid dead-reference test churn.
Anchor: parent §4, §6, §7 Q4 pick (a).

- [ ] **T.D.1** — Delete `setup_agent.py` + `managed_session_client.py` + `managed_session_monitor.py`. kind: chore | estimate_minutes: 30 | blocked_by: T.A.4 | files: `company-os/tools/demo-studio-v3/setup_agent.py`, `company-os/tools/demo-studio-v3/managed_session_client.py`, `company-os/tools/demo-studio-v3/managed_session_monitor.py` (all removed) | detail: `git rm` the three files. Grep confirms zero hits for `managed_session_client`/`managed_session_monitor`/`setup_agent` outside the deletion commit. Parent §4. | DoD: S1 imports cleanly; Grep clean. <!-- orianna: ok -->
- [ ] **T.D.2a** — Remove `/dashboard/managed-agents/*` routes + handlers. kind: chore | estimate_minutes: 45 | blocked_by: none | files: `company-os/tools/demo-studio-v3/main.py` (route handlers) | detail: Delete the `/dashboard/managed-agents/*` route group and request handlers. Parent §4 + §6. | DoD: Grep `managed-agents` returns 0 hits in routes. <!-- orianna: ok -->
- [ ] **T.D.2b** — Remove MAD dashboard UI tab + enrichment modules. kind: chore | estimate_minutes: 45 | blocked_by: T.D.2a | files: `company-os/tools/demo-studio-v3/session.html` + `static/` (dashboard tab markup), MAD enrichment modules (Grep-identify) | detail: Delete Managed Agents tab markup, the enrichment layer reconciling Firestore with Anthropic's managed-session list, and the `MANAGED_AGENT_DASHBOARD` feature flag plumbing. | DoD: Grep returns 0 for `managed-agents`, `MANAGED_AGENT_DASHBOARD`, `managedStatus`, `degradedFields`. <!-- orianna: ok -->
- [ ] **T.D.3** — Remove MAL terminal-transition hook from `session_store`. kind: chore | estimate_minutes: 45 | blocked_by: none | files: `company-os/tools/demo-studio-v3/session_store.py` | detail: Delete "on terminal transition, stop managed session" branch inside `transition_status`. Delete `lastActivityAt` Firestore writes (parent §4). Keep SE boundary intact. | DoD: existing `session_store` unit tests green; Grep `stop_managed_session|lastActivityAt` → 0. <!-- orianna: ok -->
- [ ] **T.D.4** — Scrub env vars from `.env.example` + `deploy.sh` + Cloud Run YAML. kind: chore | estimate_minutes: 30 | blocked_by: T.D.1 | files: `company-os/tools/demo-studio-v3/.env.example`, `company-os/tools/demo-studio-v3/deploy.sh`, deploy config YAML | detail: Remove `DEMO_STUDIO_MCP_URL`, `DEMO_STUDIO_MCP_TOKEN`, `MANAGED_AGENT_ID`, `MANAGED_ENVIRONMENT_ID`, `MANAGED_VAULT_ID`, `MANAGED_AGENT_DASHBOARD`, `MANAGED_SESSION_MONITOR_ENABLED`, `IDLE_WARN_MINUTES`, `IDLE_TERMINATE_MINUTES`, `SCAN_INTERVAL_SECONDS`. Keep `ANTHROPIC_API_KEY`, `CLAUDE_MODEL`, `MAX_TOKENS`, `MAX_TURNS`. Parent §4. | DoD: ship-gate §9 env-var bullet green. <!-- orianna: ok -->
- [ ] **T.D.5** — Delete `company-os/tools/demo-studio-mcp/` repo directory. kind: chore | estimate_minutes: 30 | blocked_by: T.D.4 | files: `company-os/tools/demo-studio-mcp/` | detail: `git rm -r` the MCP service directory (or archive per team convention — see OQ-D1). Cloud Run service delete is T.F.4. Parent §4. | DoD: directory gone from S1 repo tree; CI config refs updated. <!-- orianna: ok -->
- [ ] **T.D.6a** — Author MAL-retirement ADR. kind: chore | estimate_minutes: 45 | blocked_by: T.D.1, T.D.3 | files: `plans/implemented/work/2026-04-XX-managed-agent-lifecycle-retirement.md` (new) | detail: New ADR with `supersedes:` frontmatter pointing at `plans/implemented/work/2026-04-20-managed-agent-lifecycle.md`. Body: cite parent plan as rationale, enumerate revert commit SHAs, include bullet "replaced by vanilla Messages API; no managed-session concept exists." Commit direct to main (Rule 4). | DoD: file in `plans/implemented/work/`; `supersedes:` populated. <!-- orianna: ok -->
- [ ] **T.D.6b** — Author MAD-retirement ADR. kind: chore | estimate_minutes: 45 | blocked_by: T.D.2b | files: `plans/implemented/work/2026-04-XX-managed-agent-dashboard-retirement.md` (new) | detail: Mirror of T.D.6a for MAD. `supersedes:` points at `plans/implemented/work/2026-04-20-managed-agent-dashboard-tab.md`. | DoD: file in `plans/implemented/work/`; `supersedes:` populated. <!-- orianna: ok -->
- [ ] **T.D.7** — Run Grep sweep + attach zero-hit evidence to phase-D PR. kind: chore | estimate_minutes: 20 | blocked_by: T.D.1, T.D.2b, T.D.3, T.D.4, T.D.5 | files: none (verification-only) | detail: Grep `managedSessionId`, `create_managed_session`, `setup_agent`, `MANAGED_`, `demo-studio-mcp` across S1 workspace. All five must be 0 outside the two retirement ADRs' historical citations. Ship-gate §9. | DoD: zero hits attested in PR body; any hit blocks phase E. <!-- orianna: ok -->

Phase D exit: S1 boots with neither MCP env nor managed-agent env set; all tests green. Gates phase E.

### Phase E — E2E smoke v2

Xayah's test plan authoritative for assertions; tasks below are implementation hooks.
Anchor: parent §"Test plan" (8 scenarios) + §8 phase E.

- [ ] **T.E.1** — Finalize Xayah's test-plan integration. kind: coord | estimate_minutes: 30 | blocked_by: T.C.2b, T.D.7 | files: Xayah's test-plan file (link when authored) | detail: Confirm Xayah's file covers parent "Test plan" 8 scenarios + 4 unit/xfail items. Resolve overlap with xfail tests authored in phases A/B/C (T.A.1, T.A.5a-f, T.A.7a-c, T.B.1a-b, T.B.3, T.B.5a-b, T.B.7, T.C.1a-b, T.C.3). Hand queue to Vi. | DoD: Xayah's file enumerates all test IDs mapped to T.* IDs. <!-- orianna: ok -->
- [ ] **T.E.2a** — Implement E2E scenarios 1–2 (empty-session + set_config). kind: test | estimate_minutes: 60 | blocked_by: T.E.1 | files: `company-os/tools/demo-studio-v3/tests/e2e/` (the Playwright suite location) | detail: Scenario 1: Slack slash → S1 creates session with `initialContext={}`; browser opens; vanilla agent first-turn greeting. Scenario 2: user "set brand Acme" → `tool_use: set_config` → S2 reflects within 2 s. Parent "Test plan" 1, 2. Video + screenshots per Rule 16. | DoD: 2 scenarios green on staging. <!-- orianna: ok -->
- [ ] **T.E.2b** — Implement E2E scenarios 3–4 (preview iframe + fullview). kind: test | estimate_minutes: 45 | blocked_by: T.E.2a | files: `company-os/tools/demo-studio-v3/tests/e2e/` | detail: Scenario 3: after ≥1 config write, iframe src resolves to S5. Scenario 4: fullview button opens S5 in new tab. Parent "Test plan" 3, 4. | DoD: 2 scenarios green. <!-- orianna: ok -->
- [ ] **T.E.2c** — Implement E2E scenarios 5–6 (build cold + verification pass). kind: test | estimate_minutes: 60 | blocked_by: T.E.2a | files: `company-os/tools/demo-studio-v3/tests/e2e/` | detail: Scenario 5: "build it" → `tool_use: trigger_factory` → S3 `projectId` → SSE build events → verification. Scenario 6: `verificationStatus=passed` surfaces in UI. Parent "Test plan" 5, 6. | DoD: 2 scenarios green. <!-- orianna: ok -->
- [ ] **T.E.2d** — Implement E2E scenarios 7–8 (warm iterate + verify-fail loop). kind: test | estimate_minutes: 60 | blocked_by: T.E.2c | files: `company-os/tools/demo-studio-v3/tests/e2e/` | detail: Scenario 7: same `projectId` reused across second build. Scenario 8: verification fail → iterate → pass, full loop driven by tool-use chain. Parent "Test plan" 7, 8. | DoD: 2 scenarios green. <!-- orianna: ok -->
- [ ] **T.E.2e** — Record full 8-scenario back-to-back run + attach QA report. kind: test | estimate_minutes: 45 | blocked_by: T.E.2a, T.E.2b, T.E.2c, T.E.2d | files: `assessments/qa-reports/2026-04-XX-demo-studio-v3-vanilla-api-smoke-v2.md` (new) | detail: Run all 8 scenarios back-to-back in a single recorded session. Video + screenshots stored under `assessments/qa-reports/`. QA report links video, screenshots, and one row per scenario. PR body linker per Rule 16. | DoD: report linked; all 8 green in one contiguous recording. <!-- orianna: ok -->
- [ ] **T.E.3** — Unit+xfail coverage gap-fill per Xayah. kind: test | estimate_minutes: 45 | blocked_by: T.E.1 | files: existing test files from phases A/B/C (extend where Xayah flags) | detail: Gap-fill only. Expected gaps are none (T.A.1, T.A.5a-f, T.A.7a-c, T.B.1a-b already cover the 4 parent "Test plan" tail items). If Xayah identifies none, close as no-op with commit body note. | DoD: Xayah signs off that parent "Test plan" unit+xfail coverage is complete. <!-- orianna: ok -->

Phase E exit: 8/8 Playwright scenarios green back-to-back in a single recorded staging run. Gates phase F.

### Phase F — Flag flip / ship gate

No feature flag; direct cutover.
Anchor: parent §9.

- [ ] **T.F.1** — Walk parent §9 ship-gate checklist with Duong. kind: coord | estimate_minutes: 30 | blocked_by: T.E.2e, T.E.3, T.D.6a, T.D.6b, T.D.7 | files: parent plan §9 (review only) | detail: Tick all 8 §9 checkboxes incl. Akali UI regression (Rule 16) and MAL+MAD retirement ADRs merged. Sign-off captured. | DoD: §9 check-state recorded in cutover PR body. <!-- orianna: ok -->
- [ ] **T.F.2** — Deploy vanilla-api build to prod via release-please / `ops:` pipeline. kind: chore | estimate_minutes: 45 | blocked_by: T.F.1 | files: Cloud Run revision config, `company-os/tools/demo-studio-v3/deploy.sh` | detail: Heimerdinger advises; Ekko executes. Commit-prefix `ops:` per Rule 5 since infra/deploy is touched. Prior Cloud Run revision retained for rollback per parent §9 final note. | DoD: new revision `Ready: True`; traffic routed; prior revision retained. <!-- orianna: ok -->
- [ ] **T.F.3** — Run prod smoke scenarios 1, 2, 5, 6 within 15 min of deploy. kind: test | estimate_minutes: 30 | blocked_by: T.F.2 | files: Heimerdinger prod smoke runbook | detail: Execute parent §9 prod smoke. Rule 17 auto-rollback on failure via `scripts/deploy/rollback.sh`. | DoD: 4/4 prod scenarios green OR auto-rollback triggered and completed. <!-- orianna: ok -->
- [ ] **T.F.4** — Delete `demo-studio-mcp` Cloud Run service + DNS. kind: chore | estimate_minutes: 30 | blocked_by: T.F.3 | files: GCP Cloud Run service `demo-studio-mcp`; DNS record; secret manager | detail: After prod smoke green, delete Cloud Run service, remove DNS record, delete `DEMO_STUDIO_MCP_URL` from prod secret manager. Commit-prefix `ops:`. | DoD: `gcloud run services list` no longer shows `demo-studio-mcp`; DNS NXDOMAIN; secret gone. <!-- orianna: ok -->

Phase F exit: prod cutover complete; prior revision retained for a 24-hour rollback window; MCP service deleted; parent §9 fully green.

## Task count summary

| Phase | Tasks | Notes |
|---|---|---|
| A | 21 | Split to respect 60-min cap; 12 xfail, 9 feat/refactor |
| B | 11 | 6 xfail, 5 feat |
| C | 6 | T.C.4 conditional |
| D | 9 | Mechanical deletes; parallel with A/B/C; blocks E |
| E | 7 | 8 E2E scenarios split into 2+2+2+2 + recording task + coord + unit gap-fill |
| F | 4 | Ship-gate coord + deploy + prod smoke + MCP-service delete |
| **Total** | **58** | Pre-split count was ~36; split to honor §D4 60-min cap |

## Open questions raised during decomposition

- **OQ-A1** — T.A.9: does the work workspace have a declarative Firestore index config mechanism, or are indexes managed via gcloud ad-hoc? Default: deferred to phase F deploy (T.F.2).
- **OQ-B1** — T.B.6 TS MCP `server.ts` error-string inventory: executor needs exact strings before implementation. Recommendation: Sona pre-flights a grep pass on `server.ts` to produce the inventory. <!-- orianna: ok -->
- **OQ-C1** — T.C.4 conditional on T.C.3 outcome. If T.C.3 passes after T.C.2b lands, T.C.4 is skipped.
- **OQ-D1** — T.D.5 archive-vs-delete on `demo-studio-mcp/`: parent §4 says delete or archive "per team convention". Convention not documented. Default: delete. <!-- orianna: ok -->
- **OQ-D2** — T.D.3 Firestore `lastActivityAt` field backfill: parent §7 greenfield migration implies no backfill needed; defer to D executor.
- **OQ-E1** — T.E.2a-e individual estimates are planner guesses; Vi may refine after Xayah's file lands.
- **OQ-F1** — Akali's UI regression pass (Rule 16) is listed in parent §9 but no task here assigns it. Akali named in parent §12; Evelynn routes when phase E completes.

## Parent-plan §10 open questions the breakdown depended on

- **Q1 conversation persistence** — assumed **(a) subcollection**; drove T.A.1, T.A.2a-d, T.A.9. If Duong flips to (b) packed-blob, T.A.2a rewrites and T.A.9 disappears.
- **Q2 system-prompt storage** — assumed **(a) Python constant**; drove T.A.3, T.A.4. Flip to (b) Firestore singleton adds ~2 tasks (xfail + impl for cache + SIGHUP reload).
- **Q3 tool-result size overflow** — assumed **(a) truncate 900 KB**; folded into T.B.4/T.B.6/T.B.8 as ~10-line guards, no dedicated task. Flip to (b) GCS overflow adds ~2 tasks.
- **Q4 integration-branch treatment** — assumed **(a) revert on `integration/demo-studio-v3-waves-1-4`**; drove phase-D blocking. Flip to (b) abandon-branch changes branch mechanics; task count ~same. <!-- orianna: ok -->
- **Q5 observability** — assumed **(a) structured logs**; folded into T.A.8a-c (~2 log-line additions), no dedicated task.
- **Q6 agent-health surface** — assumed **(b) remove MAD tab entirely**; drove T.D.2a-b. Flip to (a) "Recent Turns" tab adds ~3 tasks (xfail + UI + route).

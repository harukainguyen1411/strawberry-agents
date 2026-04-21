---
status: proposed
orianna_gate_version: 2
tests_required: false
concern: work
parent_plan: 2026-04-21-demo-studio-v3-vanilla-api-ship.md
complexity: complex
owner: xayah
created: 2026-04-21
tags:
  - demo-studio
  - vanilla-api
  - test-plan
  - complex-track
---

# Test Plan — Demo Studio v3 Vanilla Messages API Ship (Option B)

Companion test plan for `plans/proposed/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md` (Swain). Complex-track; authored by Xayah. <!-- orianna: ok -->

**Scope note on bare-path tokens:** this plan references backtick tokens that resolve against the `missmp/company-os` work checkout, not strawberry-agents. Every such line below carries an explicit `<!-- orianna: ok -->` suppressor per the repo-structure linter's per-line rule. Prospective test-file paths (e.g. `test_conversation_store.py`, `test_tool_dispatch.py`, `vanilla_smoke.spec.ts`, `tests/fixtures/mcp_error_strings.json`) will be created by the test implementer after promotion. <!-- orianna: ok -->

**Sibling-file vs inline-body tension:** Xayah's default protocol is to inline test plans into the parent ADR body. Duong's explicit directive for this task overrides that default and requests this sibling file. Orianna's sibling-check gate may block promotion; Sona must reconcile before `plan-promote.sh` runs. <!-- orianna: ok -->

## 0. Ground rules

- **Author role:** Xayah (complex-track test planner). This file is the test matrix — not test code. Rakan authors the unit + integration + fault-injection tests per row; Vi authors the E2E Playwright spec under Caitlyn and Xayah direction per §12 of the parent. <!-- orianna: ok -->
- **Rule 12 gating:** every row with a Rule-12-pairing field MUST be committed as an xfail test on the implementer's branch before the corresponding implementation commit. The `tdd-gate.yml` CI check enforces per-branch ordering. <!-- orianna: ok -->
- **Rule 13 gating:** rows marked `regression-guard` cover behavior already considered part of the merged surface of a preceding phase; they land alongside any bug fix that disturbs that surface. <!-- orianna: ok -->
- **Rule 15 + 16 gating:** Phase E rows are the gated scenarios for `e2e.yml`; UI-touching rows additionally require Akali's QA pass per Rule 16. <!-- orianna: ok -->
- **No silent hangs:** every fault-injection row asserts the failure surfaces as an SSE `error` event within a bounded wall-clock window. A timeout that produces no event is an automatic fail, distinct from an error event whose content is wrong. <!-- orianna: ok -->
- **Fixtures:** unit/integration fixtures under `tests/fixtures/`; Playwright fixtures under `tests/e2e/fixtures/`. Both are prospective paths in the work checkout. <!-- orianna: ok -->
- **Test count:** 54 rows total across phases A–F plus cross-phase fault-injection and regression-guard rows. <!-- orianna: ok -->

## 1. Phase A — Agent-proxy rewrite + conversation persistence

Invariants under test: <!-- orianna: ok -->

- Conversations are append-only; `seq` is monotonic per session and gapless. <!-- orianna: ok -->
- `ConversationStore.load(sid)` returns messages in `seq` order regardless of Firestore server-time skew. <!-- orianna: ok -->
- `ConversationStore` is the single boundary — no other module reads/writes the subcollection. <!-- orianna: ok -->
- `agent_proxy.run_turn` terminates on `end_turn`, loops on `tool_use`, raises on unexpected stop reasons, and respects `MAX_TURNS`. <!-- orianna: ok -->

| Test ID | Scope | Invariant | Setup | Assertion | Rule 12 pairing | Gate | Est (min) |
|---|---|---|---|---|---|---|---|
| TS.A.1 | unit | ConversationStore.append assigns monotonic gapless seq starting at 0. | Firestore emulator; empty subcollection. | Append 5 messages; collection docs have seq=0..4 with no gaps and createdAt set. | T.A.conversation-store-append | unit, tdd-gate.yml | 30 | <!-- orianna: ok -->
| TS.A.2 | unit | ConversationStore.load orders strictly by seq, not server timestamp. | Emulator; seed 5 docs with seq order 3,0,4,1,2 and createdAt times in a different order. | load() returns messages in seq ascending regardless of timestamp skew. | T.A.conversation-store-load | unit, tdd-gate.yml | 20 | <!-- orianna: ok -->
| TS.A.3 | unit | ConversationStore.load_since(sid, seq=k) returns only messages with seq greater than k, preserving order. | Emulator; seed 10 messages. | load_since(sid,4) returns exactly seq 5..9. | T.A.conversation-store-replay | unit, tdd-gate.yml | 20 | <!-- orianna: ok -->
| TS.A.4 | unit | append is idempotent on a client-supplied clientMessageId — retrying the same message does not create a duplicate seq. | Emulator; append once, retry with same clientMessageId. | Only one doc exists; returned seq matches first call. | T.A.conversation-store-idempotency | unit, tdd-gate.yml | 40 | <!-- orianna: ok -->
| TS.A.5 | unit | ConversationStore.truncate_for_model drops oldest non-system messages until token budget fits, preserves last user turn. | Fake 60k-token history; call truncate_for_model(msgs, max_tokens=32000). | Returned list under 32k tokens; last user message retained; no tool_use without paired tool_result. | T.A.conversation-store-truncate | unit, tdd-gate.yml | 45 | <!-- orianna: ok -->
| TS.A.6 | unit | Concurrent append calls against the same session produce distinct sequential seq values (no duplicates, no skips). | Emulator; 10 parallel append tasks. | All 10 complete; set of written seq values equals 0..9. | T.A.conversation-store-concurrency | unit, tdd-gate.yml | 45 | <!-- orianna: ok -->
| TS.A.7 | unit | agent_proxy.run_turn exits on stop_reason end_turn after a single streamed assistant message. | Mock messages.stream yielding one text block + message_stop with stop_reason end_turn. | run_turn returns; store has exactly 2 messages; no tool dispatch invoked. | T.A.agent-proxy-end-turn | unit, tdd-gate.yml | 30 | <!-- orianna: ok -->
| TS.A.8 | unit | agent_proxy.run_turn executes the tool-use branch once, then continues until end_turn. | Mock stream returning tool_use set_config first, then end_turn second. | Dispatch called exactly once with set_config; store has 4 messages. | T.A.agent-proxy-tool-use-then-end | unit, tdd-gate.yml | 40 | <!-- orianna: ok -->
| TS.A.9 | unit | agent_proxy.run_turn hard-caps at MAX_TURNS and raises MaxTurnsExceeded rather than looping forever. | Mock stream always returns tool_use; MAX_TURNS=3. | After 3 iterations MaxTurnsExceeded raises; SSE sink received error event with code max_turns_exceeded. | T.A.agent-proxy-max-turns | unit, tdd-gate.yml | 30 | <!-- orianna: ok -->
| TS.A.10 | unit | Unexpected stop_reason raises UnexpectedStopReason and emits an error event. | Mock stream with stop_reason pause_turn. | Raises; SSE error event with code unexpected_stop_reason. | T.A.agent-proxy-unexpected-stop | unit, tdd-gate.yml | 20 | <!-- orianna: ok -->
| TS.A.11 | integration | Boundary invariant: no module outside conversation_store module touches the subcollection. | Grep in CI over demo-studio-v3 source excluding conversation_store and its tests. | Match count is 0 for the subcollection path and Firestore writes into it. | regression-guard (SE boundary invariant extended to conversations subcollection) | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.A.12 | integration | End-to-end message round-trip: run_turn invoked twice in sequence sees the first turn's messages on the second call. | Firestore emulator + mock Anthropic stream returning text only. | Second run_turn receives messages containing first user+assistant exchange. | T.A.agent-proxy-conversation-load | integration, tdd-gate.yml | 45 | <!-- orianna: ok -->
| TS.A.13 | unit | System-prompt constant is passed through verbatim on every messages.stream call (Q2 pick a). | Patch messages.stream spy; run one turn. | Captured kwargs contain system=SYSTEM_PROMPT. | T.A.agent-proxy-system-prompt | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->

Phase A subtotal: 13 rows (12 new + 1 regression-guard).

## 2. Phase B — Tool-dispatch registry (all five tools)

Invariants under test: <!-- orianna: ok -->

- Every tool_use.name the model can emit has either a registered handler or is a known Anthropic-hosted built-in (web_search). <!-- orianna: ok -->
- Unknown tools surface as tool_result with is_error=true; the loop does not crash. <!-- orianna: ok -->
- Each handler wraps its backend client (S2/S3) with error mapping that preserves the TS MCP server error strings. <!-- orianna: ok -->
- Pure tools are idempotent in the sense of producing identical outputs for identical inputs; side-effecting tools (set_config, trigger_factory) surface duplicates to the caller rather than silently deduplicating. <!-- orianna: ok -->

| Test ID | Scope | Invariant | Setup | Assertion | Rule 12 pairing | Gate | Est (min) |
|---|---|---|---|---|---|---|---|
| TS.B.1 | unit | Registry exports exactly 5 entries with the names/types declared in parent §3.4. | Import module. | Names set equals get_schema, get_config, set_config, trigger_factory, web_search; web_search has type web_search_20241022 and no HANDLERS entry; other four have handler entries. | T.B.tool-dispatch-registry-shape | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.B.2 | unit | dispatch(get_schema,...) proxies to fetch_schema and returns the schema dict. | Mock fetch_schema returns a schema dict. | Handler returns that dict; fetch_schema called once with session context. | T.B.handler-get-schema | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.B.3 | unit | dispatch(get_config,...) proxies to fetch_config(session_id) and wraps result. | Mock. | Backend called exactly once with session id; return value wrapped per parent §5.2. | T.B.handler-get-config | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.B.4 | unit | dispatch(set_config,...) proxies to patch_config(session_id, path, value) and returns success envelope. | Mock patch_config returns ok envelope. | Backend called with correct args; envelope passed through. | T.B.handler-set-config | unit, tdd-gate.yml | 20 | <!-- orianna: ok -->
| TS.B.5 | unit | dispatch(trigger_factory,...) proxies to trigger_build(session_id); returns projectId. | Mock returns projectId. | trigger_build called once; projectId surfaces in result. | T.B.handler-trigger-factory | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.B.6 | unit | Unknown tool_use.name returns a tool_result with is_error=true and UnknownToolError payload; no exception escapes. | Dispatch nonexistent tool name. | Returned dict has is_error=true, error code unknown_tool, and includes the offending name; no raise. | T.B.handler-unknown-tool | unit, tdd-gate.yml | 20 | <!-- orianna: ok -->
| TS.B.7 | unit | Backend error mapping: S2 404 NotFound maps to exact user-facing string from TS MCP NotFound branch. | Mock raises NotFoundError. | String byte-identical to captured TS MCP snapshot. | T.B.error-map-not-found | unit, tdd-gate.yml | 25 | <!-- orianna: ok -->
| TS.B.8 | unit | Backend error mapping: S2 401 Unauthorized maps to exact TS MCP Unauthorized string. | Mock raises UnauthorizedError. | Byte-identical snapshot. | T.B.error-map-unauthorized | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.B.9 | unit | Backend error mapping: S2 503 ServiceUnavailable maps to exact TS MCP ServiceUnavailable string. | Mock raises ServiceUnavailableError. | Byte-identical snapshot. | T.B.error-map-service-unavailable | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.B.10 | unit | Idempotency (pure tool): two sequential get_config calls with identical input produce identical output; handler invoked twice (no dedup). | Mock fetch_config tracks call count. | fetch_config called twice; both results equal. | T.B.idempotency-pure-tool | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.B.11 | unit | Side-effect surfacing: two sequential set_config calls with identical input invoke backend twice; duplicate is NOT silently dropped. | Mock patch_config tracks calls. | 2 invocations; 2 tool_result blocks returned; no dedup. | T.B.side-effect-duplicate-surface | unit, tdd-gate.yml | 20 | <!-- orianna: ok -->
| TS.B.12 | integration | web_search content blocks stream through without S1 dispatch. | Mock stream yields server_tool_use + web_search_tool_result content-block sequence; HANDLERS has no entry for web_search. | dispatch never called for web_search; translator forwards the blocks to SSE unchanged; no UnknownToolError. | T.B.web-search-passthrough | integration, tdd-gate.yml | 40 | <!-- orianna: ok -->
| TS.B.13 | integration | End-to-end tool round-trip against real S2 (staging config-mgmt): set_config through dispatcher reflects within 2 s. | Staging S2 reachable; ephemeral session; real config_mgmt client. | After dispatch, GET on S2 config path returns the written value within 2 s (poll 200 ms). | T.B.integration-set-config-round-trip | integration, tdd-gate.yml | 60 | <!-- orianna: ok -->
| TS.B.14 | unit | Handler signature contract: every handler accepts (input dict, SessionContext) and returns awaitable dict. | Reflective import of each handler. | inspect.signature matches; return type annotation is awaitable dict. | regression-guard (stable contract for future handlers) | unit | 15 | <!-- orianna: ok -->

Phase B subtotal: 14 rows (13 new + 1 regression-guard).

## 3. Phase C — SSE stream adaptation

Invariants under test: <!-- orianna: ok -->

- Every Messages API streaming event type is mapped to exactly one stable browser-facing event, or explicitly dropped with a documented reason. <!-- orianna: ok -->
- Browser event payload shapes are byte-compatible with the current UI contract (parent §3.5). <!-- orianna: ok -->
- A Messages API stream that ends without message_stop triggers an error SSE event (no silent hang). <!-- orianna: ok -->
- Cancel path: consumer abort produces a cancelled event and no trailing turn_end. <!-- orianna: ok -->

| Test ID | Scope | Invariant | Setup | Assertion | Rule 12 pairing | Gate | Est (min) |
|---|---|---|---|---|---|---|---|
| TS.C.1 | unit | content_block_delta with text maps to text_delta SSE event with text payload. | Feed single delta event to translator. | Emitted SSE event has event name text_delta and data with text field. | T.C.translator-text-delta | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.C.2 | unit | content_block_start of type tool_use maps to tool_use SSE event with name and input once input JSON is complete. | Feed content_block_start tool_use + input_json_delta chunks + content_block_stop. | One tool_use event emitted after content_block_stop with complete input dict. | T.C.translator-tool-use | unit, tdd-gate.yml | 30 | <!-- orianna: ok -->
| TS.C.3 | unit | Synthetic tool_result from dispatcher maps to tool_result SSE event with name and output_summary. | Call translator.emit_tool_result. | SSE event shape matches spec in parent §3.5. | T.C.translator-tool-result | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.C.4 | unit | message_stop maps to turn_end SSE event with stop_reason and usage. | Feed final message with stop_reason end_turn and usage dict. | turn_end event payload matches. | T.C.translator-turn-end | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.C.5 | unit | All Messages API event types are exhaustively mapped — an unknown event emits a warning log, not an exception, and drops cleanly. | Feed made-up event type ping. | Warning logged with event-type name; no exception; no SSE event emitted. | T.C.translator-unknown-event | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.C.6 | unit | Text-delta coalescing: 10 small deltas within 50 ms may coalesce into fewer SSE events but byte-concatenation of emitted text must equal input text. | Feed 10 deltas totalling a known string. | Concatenated emitted text equals input exactly. | T.C.translator-coalescing | unit, tdd-gate.yml | 25 | <!-- orianna: ok -->
| TS.C.7 | unit | server_tool_use + web_search_tool_result pass-through surfaces via tool_use + tool_result events naming web_search. | Feed Anthropic-hosted web-search streaming shape. | Two SSE events emitted with name web_search; no dispatcher call. | T.C.translator-web-search | unit, tdd-gate.yml | 20 | <!-- orianna: ok -->
| TS.C.8 | integration | session stream route wires run_turn sink to translator; consumer receives correct ordered events end-to-end. | Mock Anthropic stream + real FastAPI route; HTTP client reads SSE. | Received events in order: 1+ text_delta, optional tool_use+tool_result, final turn_end. | T.C.route-stream-wiring | integration, tdd-gate.yml | 45 | <!-- orianna: ok -->
| TS.C.9 | unit | Stream abort mid-turn emits cancelled event and does NOT emit turn_end. | Start translator; abort underlying stream after 2 text deltas. | Last emitted event is cancelled; no turn_end. | T.C.translator-cancel | unit, tdd-gate.yml | 25 | <!-- orianna: ok -->
| TS.C.10 | integration | Stream that ends without message_stop (connection drop) emits error SSE event within 5 s (no silent hang). | Mock stream iterator raises after 2 deltas, no message_stop. | Within 5 s, error event emitted with code stream_terminated. | T.C.stream-abrupt-end | integration, tdd-gate.yml | 30 | <!-- orianna: ok -->

Phase C subtotal: 10 rows.

## 4. Phase D — Deletion sweep

Phase D is mechanical deletion. Most surface is covered by regression-guard rows in A/B/C. Adds here are grep-sweep verifications and boot-without-removed-env smokes. Thin unit coverage acceptable. <!-- orianna: ok -->

| Test ID | Scope | Invariant | Setup | Assertion | Rule 12 pairing | Gate | Est (min) |
|---|---|---|---|---|---|---|---|
| TS.D.1 | integration | S1 boots with no MCP URL/token env and no MANAGED_* env set. | Launch container with explicitly unset envs. | healthz returns 200 within 10 s; startup log contains no KeyError or SettingsError. | T.D.boot-without-managed-env | integration, tdd-gate.yml | 30 | <!-- orianna: ok -->
| TS.D.2 | integration | Grep sweep: managedSessionId, create_managed_session, setup_agent, MANAGED_AGENT_DASHBOARD return zero hits across demo-studio-v3. | CI grep. | Each pattern's match count is 0 (excluding retirement ADRs). | T.D.grep-sweep-managed-refs | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.D.3 | integration | Former managed-agents dashboard routes return 404 (removed), not 500. | HTTP GET each former route. | All return 404. | T.D.managed-agents-routes-gone | integration | 20 | <!-- orianna: ok -->
| TS.D.4 | integration | demo-studio-mcp Cloud Run service absent from staging project service list. | gcloud run services list. | No row with name demo-studio-mcp. | T.D.mcp-service-deleted | integration | 15 | <!-- orianna: ok -->
| TS.D.5 | unit | session_store.transition_status no longer calls the terminal-transition hook introduced by MAL. | Spy on hook; transition a session to completed. | Hook not imported; transition succeeds; no managedSessionId field read. | regression-guard (SE invariant still holds) | unit, tdd-gate.yml | 20 | <!-- orianna: ok -->
| TS.D.6 | unit | env.example contains no MANAGED_* or DEMO_STUDIO_MCP_* keys. | Parse file. | Key-set intersection with forbidden prefixes is empty. | T.D.env-example-clean | unit, tdd-gate.yml | 10 | <!-- orianna: ok -->

Phase D subtotal: 6 rows (5 new + 1 regression-guard).

## 5. Phase E — E2E smoke v2 (Rule 15)

Playwright flow on staging against real S2/S3/S4/S5 + real Anthropic Messages API. Each row maps 1:1 to a parent-plan §Test plan scenario. <!-- orianna: ok -->

| Test ID | Scope | Invariant | Setup | Assertion | Rule 12 pairing | Gate | Est (min) |
|---|---|---|---|---|---|---|---|
| TS.E.1 | E2E | Slack trigger creates session with empty conversation subcollection; first assistant turn produces greeting via vanilla path; no managed-session artefacts. | Trigger Slack slash command against staging. | Browser loads; Firestore session doc has no managedSessionId; empty conversations subcollection; first text_delta arrives within 8 s. | parent §Test plan scenario 1 | e2e.yml, Rule 15 | 60 | <!-- orianna: ok -->
| TS.E.2 | E2E | User asks to set brand; set_config tool-use round-trip; S2 reflects write within 2 s; assistant confirms. | Staging session; type message in chat UI. | SSE shows tool_use set_config + tool_result; S2 config endpoint returns brand=Acme; assistant replies with confirmation text. | parent §Test plan scenario 2 | e2e.yml, Rule 15 | 75 | <!-- orianna: ok -->
| TS.E.3 | E2E | Preview iframe src resolves to S5 and paints after at least one config write. | Scenario 2 prerequisites. | Iframe src host is S5; iframe DOM has painted content within 10 s. | parent §Test plan scenario 3 | e2e.yml, Rule 15 + Rule 16 | 45 | <!-- orianna: ok -->
| TS.E.4 | E2E | Fullview new-tab opens against S5 and loads. | Click fullview button. | New tab URL host is S5; page load event fires; no 4xx/5xx. | parent §Test plan scenario 4 | e2e.yml, Rule 15 + Rule 16 | 30 | <!-- orianna: ok -->
| TS.E.5 | E2E | Build it triggers trigger_factory, S3 returns projectId, build events stream, verification result lands. | Session with configured state; sufficient S3 quota. | SSE shows tool_use trigger_factory; Firestore session projectId populated; verificationStatus transitions through running to terminal within 5 min. | parent §Test plan scenario 5 | e2e.yml, Rule 15 | 90 | <!-- orianna: ok -->
| TS.E.6 | E2E | verificationStatus=passed surfaces in UI. | Scenario 5 completes with passing verification. | UI shows Verification passed text and the pass-color pill. | parent §Test plan scenario 6 | e2e.yml, Rule 15 + Rule 16 | 30 | <!-- orianna: ok -->
| TS.E.7 | E2E | Iterate: same projectId reused across second build (warm path). | Scenario 6 prerequisites; trigger second build via chat. | Second build's Firestore projectId equals first; S3 build endpoint invoked with same id. | parent §Test plan scenario 7 | e2e.yml, Rule 15 | 45 | <!-- orianna: ok -->
| TS.E.8 | E2E | Verification fail, iterate via set_config, then pass. Loop driven by tool-use chain alone. | Inject a known-bad config; then instruct agent to correct. | First verification terminates in failed; after at least one set_config and second trigger_factory, verification reaches passed. | parent §Test plan scenario 8 | e2e.yml, Rule 15 | 90 | <!-- orianna: ok -->
| TS.E.9 | E2E | All 8 scenarios pass back-to-back in a single recorded Playwright run (ship-gate §9). | Sequential execution with video + screenshots. | 8/8 green; QA artifact uploaded under qa-reports; Akali Figma diff attached. | ship-gate aggregate (covers Rule 16) | e2e.yml, Rule 15 + Rule 16 | 30 | <!-- orianna: ok -->

Phase E subtotal: 9 rows.

## 6. Phase F — Ship gate / prod smoke / rollback

Prod-scoped, Rule 17. Smaller subset (scenarios 1, 2, 5, 6) per parent §9. <!-- orianna: ok -->

| Test ID | Scope | Invariant | Setup | Assertion | Rule 12 pairing | Gate | Est (min) |
|---|---|---|---|---|---|---|---|
| TS.F.1 | E2E | Prod smoke executes scenarios 1, 2, 5, 6 within 15 min of deploy; failures auto-trigger rollback. | Deploy to prod; run smoke; assert rollback on induced fail. | Success path: 4/4 green, no rollback; fail path: rollback script invoked, prior revision active, alert posted. | T.F.prod-smoke-auto-rollback | ops CI + Rule 17 | 60 | <!-- orianna: ok -->
| TS.F.2 | integration | Rollback restores prior Cloud Run revision and S1 boots against the prior surface. | Deploy current, rollback, hit healthz. | healthz returns 200 on prior revision within 30 s. | T.F.rollback-cloud-run-revision | ops CI | 20 | <!-- orianna: ok -->
| TS.F.3 | integration | env.example + deploy script linter: no MANAGED_* or DEMO_STUDIO_MCP_* keys present in deployed config. | CI parses rendered deploy-config output. | Intersection with forbidden-prefix set is empty. | T.F.deploy-config-clean | unit | 10 | <!-- orianna: ok -->

Phase F subtotal: 3 rows.

## 7. Fault-injection matrix (cross-phase)

These rows target the one external-dep fault surfaces as bounded error event invariant (parent §11 mitigation bullet). Run against the vanilla agent-proxy with backends mocked at HTTP boundary. Authored by Rakan; no Playwright involvement. <!-- orianna: ok -->

| Test ID | Scope | Invariant | Setup | Assertion | Rule 12 pairing | Gate | Est (min) |
|---|---|---|---|---|---|---|---|
| TS.X.1 | fault-injection | S2 down (connection refused) during set_config handler: tool_result with is_error=true and code service_unavailable; loop continues. | Mock config_mgmt client raises connection refused. | tool_result is_error true; next stream invoked; no crash. | T.X.s2-down-set-config | integration, tdd-gate.yml | 40 | <!-- orianna: ok -->
| TS.X.2 | fault-injection | S3 down during trigger_factory: tool_result error; assistant follow-up turn received; SSE stays open. | Mock factory trigger_build raises. | Error tool_result emitted; SSE continues; eventual turn_end received. | T.X.s3-down-trigger-factory | integration, tdd-gate.yml | 40 | <!-- orianna: ok -->
| TS.X.3 | fault-injection | Anthropic 429 on stream open: retry once with backoff (under 2 s), then surface error SSE event with code rate_limited; no infinite retry. | Mock first stream call raises RateLimitError; second succeeds. | Second attempt runs; first attempt failure in logs; total wall-clock delay under 2.5 s. | T.X.anthropic-429-retry | integration, tdd-gate.yml | 45 | <!-- orianna: ok -->
| TS.X.4 | fault-injection | Anthropic persistent 429 (both attempts): single error SSE event, loop exits, no hang. | Mock both stream calls raise RateLimitError. | One error event emitted within 5 s; run_turn returns. | T.X.anthropic-429-persistent | integration, tdd-gate.yml | 30 | <!-- orianna: ok -->
| TS.X.5 | fault-injection | Handler raises uncaught Python exception: caught at dispatcher, surfaced as tool_result with is_error=true and code handler_exception; next turn proceeds. | Monkey-patch get_schema handler to raise RuntimeError. | Loop continues; no exception escapes run_turn; SSE shows tool_result error. | T.X.handler-raises | unit, tdd-gate.yml | 30 | <!-- orianna: ok -->
| TS.X.6 | fault-injection | Anthropic stream hangs mid-turn (no event for 30 s): per-event read timeout fires; error SSE event; run_turn returns. | Mock stream yields 1 delta then blocks indefinitely; set per-event timeout 10 s. | Within 12 s, error event with code stream_idle_timeout emitted; run_turn returns. | T.X.stream-idle-timeout | integration, tdd-gate.yml | 45 | <!-- orianna: ok -->
| TS.X.7 | fault-injection | Firestore write fails on append (quota exhausted): error SSE event + run_turn exit; session doc is not corrupted. | Firestore emulator with forced write-rejection for 1 call. | Error event emitted; post-state subcollection has no partial write; seq sequence unbroken. | T.X.firestore-append-fails | integration, tdd-gate.yml | 40 | <!-- orianna: ok -->
| TS.X.8 | fault-injection | Tool-result payload exceeds 900 KB truncation bound: handler truncates to 900 KB + truncated marker; no Firestore 1 MB rejection. | Mock fetch_schema returns 1.5 MB string. | Written tool_result content length under 900 KB + marker; Firestore doc size under 1 MB; assistant next turn receives the truncated content. | T.X.tool-result-overflow | unit, tdd-gate.yml | 30 | <!-- orianna: ok -->
| TS.X.9 | fault-injection | Cancel request mid-turn aborts the stream, sets a conversation-state cancel marker, emits cancelled SSE, does NOT call sessions.delete (no managed session exists). | Start turn; after 500 ms, hit cancel endpoint. | stream context exited via cancellation; cancelled SSE observed; Firestore session has cancelledAt; no HTTP call to beta/sessions. | T.X.cancel-semantics | integration, tdd-gate.yml | 50 | <!-- orianna: ok -->

Fault-injection subtotal: 9 rows.

## 8. Summary — totals and gate distribution

| Phase | Rows | New (xfail, Rule 12) | Regression-guard | E2E (Rule 15) | Fault-injection |
|---|---:|---:|---:|---:|---:|
| A | 13 | 12 | 1 | 0 | 0 |
| B | 14 | 13 | 1 | 0 | 0 |
| C | 10 | 10 | 0 | 0 | 0 |
| D | 6  | 5  | 1 | 0 | 0 |
| E | 9  | 0 (E2E-authored, not xfail) | 0 | 9 | 0 |
| F | 3  | 3  | 0 | 0 | 0 |
| X (fault-injection cross-phase) | 9 | 9 | 0 | 0 | 9 |
| Total | 54 | 52 | 3 | 9 | 9 |

E-row counts are not xfail-paired because they are authored by Vi at phase E; implementation precedes them. The tdd-gate path applies only to unit/integration rows authored on the same branch as the implementer's work. <!-- orianna: ok -->

Estimated total author effort: ~27 hours across Rakan (phases A/B/C/D/F/X ≈ 23 h) + Vi (phase E ≈ 4 h). Caitlyn owns E-row authorship sequencing per parent §12; Xayah audits the delivered tests post-implementation for coverage gaps. <!-- orianna: ok -->

## 9. Coverage gaps flagged

The following areas have incomplete mock infrastructure or open design questions and may need supplementary planning rounds once Aphelios writes the phase-A task file: <!-- orianna: ok -->

1. TS.X.3 / TS.X.4 — Anthropic 429 retry policy: parent plan does not specify count/backoff/jitter. Assumed 1 retry, ≤2 s backoff. If Viktor picks differently, re-parameterize. Ask Swain/Duong: pin retry policy in a new §5.x of the parent plan. <!-- orianna: ok -->
2. TS.X.6 — Per-event stream-idle timeout: parent does not declare a per-event read timeout. Assumed 10 s per chunk based on SDK defaults. Ask Swain: pin STREAM_IDLE_TIMEOUT_SECONDS in §3.2 or §5.3. <!-- orianna: ok -->
3. TS.X.9 — Cancel endpoint shape: parent alludes to in-process task cancellation + conversation-state marker but does not specify the HTTP surface. Assumed POST cancel route. Ask Viktor at phase A: confirm cancel surface. <!-- orianna: ok -->
4. TS.B.13 (staging round-trip): depends on staging S2 reachability with ephemeral session support. If staging S2 rejects sessions not seeded via Slack, Rakan needs a seeding fixture. Ask Heimerdinger: lightweight S2 session-seed endpoint or full Slack-to-S1 seed required? <!-- orianna: ok -->
5. TS.B.7/8/9 (TS MCP error-string snapshots): requires capturing current TS MCP error strings into a test fixture before MCP is retired. Action for Aphelios phase-B decomp: precursor task snapshot TS MCP error strings to fixture file before any phase-D deletion commit. <!-- orianna: ok -->
6. TS.A.5 (token-budget truncation): assumes tokenizer is available. SDK count_tokens is an API call; a local tokenizer is preferable for unit tests. Ask Viktor: local tokenizer dep, mock count_tokens, or char-based heuristic? <!-- orianna: ok -->
7. E2E scenario 8 (verification-fail injection): requires known-bad config that reliably fails. S4 does not expose a deterministic-fail generator. Ask Heimerdinger or S4 owner: provide canned verification-fail config fixture, or Vi hand-picks brittle input. <!-- orianna: ok -->
8. TS.F.1 (prod rollback on auto-fail): induced-failure testing in prod is risky; must be exercised in prod-adjacent canary, not live prod. Ask Heimerdinger: canary channel or staging-prod-mirror env for rollback exercise? <!-- orianna: ok -->

No gap is a blocker for promoting the parent plan through the Orianna approved gate. All are tractable during phase-A implementation planning. <!-- orianna: ok -->

## 10. Cross-references

- Parent ADR: `plans/proposed/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md` (Swain, 2026-04-21). <!-- orianna: ok -->
- Alternative Option A: `plans/proposed/work/2026-04-21-demo-studio-v3-e2e-ship-v2.md` (Azir). <!-- orianna: ok -->
- Companion in-process-merge (Option A track): `plans/proposed/work/2026-04-21-mcp-inprocess-merge.md` (Karma). <!-- orianna: ok -->
- MAL predecessor (to retire): `plans/implemented/work/2026-04-20-managed-agent-lifecycle.md`. <!-- orianna: ok -->
- MAD predecessor (to retire): `plans/implemented/work/2026-04-20-managed-agent-dashboard-tab.md`. <!-- orianna: ok -->
- Task-file cross-refs (T.A.*, T.B.*, …) resolve against Aphelios's phase-A task ADR, spawned post-signature per parent §8. Until then, Rule-12 pairings cite by descriptive name. <!-- orianna: ok -->

## Tasks

This file is a **test-matrix companion**, not an execution plan, so it carries no implementation tasks of its own. Execution of the matrix below lives on the implementer's task files (Aphelios for complex-track implementation phases; Caitlyn and Xayah drive test-impl sequencing through Rakan and Vi).

- [ ] **T.TEST.1** — Audit delivered phase-A/B/C/D/F unit + integration tests against the matrix in §1–§4, §6–§7 after Rakan lands each phase's xfail batch. kind: audit | estimate_minutes: 45
- [ ] **T.TEST.2** — Audit Vi's Playwright E2E spec (phase E, §5) against the 8 parent-plan scenarios; confirm 8/8 green back-to-back on staging before ship-gate review. kind: audit | estimate_minutes: 30
- [ ] **T.TEST.3** — Re-review coverage-gap open items in §9 after Swain pins the open Anthropic retry + stream-idle-timeout policy in the parent plan; update affected rows in place. kind: audit | estimate_minutes: 30
- [ ] **T.TEST.4** — On any bug discovered during implementation, confirm Rule-13 regression-guard test is added before the fix lands; escalate to Sona if skipped. kind: audit | estimate_minutes: 20
- [ ] **T.TEST.5** — Post-ship, fold any production-incident signatures that were not anticipated in §7 into a new fault-injection row and open a follow-up test-plan revision. kind: audit | estimate_minutes: 30

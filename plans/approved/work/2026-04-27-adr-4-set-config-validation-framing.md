---
slug: adr-4-set-config-dispatch-traceability
title: "ADR-4 — set_config dispatch traceability + tool_result is_error block contract + force-retry removal"
project: bring-demo-studio-live-e2e-v1
concern: work
status: approved
owner: azir
priority: P1
tier: complex
created: 2026-04-27
last_reviewed: 2026-04-27
qa_plan: required
qa_co_author: senna
tests_required: true
architecture_impact: minor
---

## Context

DoD steps 4–5 of `projects/work/active/bring-demo-studio-live-e2e-v1.md` (chat-loop config edits) are silently broken. The smoking-gun trace from prod session `e352044b37c04e828c7524c7034fdb75` (Ekko Cloud Run scrape, 2026-04-27):

- **S2 (`demo-config-mgmt`) returned 201 on every POST** in the 4h session window. Zero 4xx/5xx.
- **No `force=true` retry was ever exercised.** That code path did not fire.
- **S1 (`demo-studio-v3`) httpx outbound logger shows ZERO calls to `demo-config-mgmt` during the chat window** — only `api.anthropic.com`. The Aviva config the agent emitted as `tool_use` was **never POSTed to S2**.
- The session was seeded at creation (`DEFAULT_SEED` → S2 returned the seed body, hash `895b…`) and every subsequent `GET /v1/config/{sid}` returned that same `895b…` body.
- Agent narrated "Config saved successfully" multiple times. User asked for the next change. `get_config` returned the seeded Allianz body; agent gaslighted ("the brand is already Allianz, what would you like to change?") and looped.

So the originally-suspected bug — force-retry framing on validation failure (`tool_dispatch.py:223`) — is **not** what fired. The failure happens **one layer earlier**, between agent `tool_use` emission and the outbound HTTP call to S2. No S2 call ⇒ either the dispatcher returned an error before calling S2, or `tool_use` parsing dropped the input on the floor.

Force-retry itself, separately, is being deleted by ADR-4. Per Duong's call: there is no failure mode where `force=true` produces a better outcome than clean-fail-with-informative-tool_result. "Soft-fail with warnings" (the `2026-04-23-agent-owned-config-flow.md` §D7 strategy) is a mechanism that hides validation errors and gaslights the agent — it papered over a real problem (the schema stub at `/v1/schema` returning 11 fields instead of the canonical schema, so the agent guessed wrong field names and triggered validation rejections that were then forced-through). Karma's `/v1/schema` wiring plan is in promotion; once the schema is real, validation errors become rare, and when they do fire, we want them surfaced honestly so a real bug gets a real signal.

Reading the actual code path top-down, the load-bearing surfaces are:

### Surface A — `stream_translator._handle_content_block_stop` silently swallows JSON-decode errors

`tools/demo-studio-v3/stream_translator.py:253-261`:

```python
if block.get("type") == "tool_use":
    json_buf = block.get("json_buf", "") or "{}"
    try:
        tool_input = json.loads(json_buf)
    except json.JSONDecodeError:
        tool_input = {}            # ← silent fallback to empty dict; no log, no SSE
    block["input"] = tool_input
    block["complete"] = True
```

If Anthropic's stream emits a malformed or truncated `input_json_delta` sequence (for example: model hits `max_tokens=8096` mid-tool_use payload — the Aviva config is large; nested `card.front[].value` and `card.back.fields[].section` strings push token count high), the accumulated `json_buf` is truncated/invalid JSON. The translator catches `JSONDecodeError`, resets `tool_input = {}`, and continues. **Nothing is logged. No SSE error event fires. The dispatcher receives `tool_input={}`.**

### Surface B — `_handle_set_config` early-rejects on missing `config` key but returns `is_error` only inside a JSON-stringified dict

`tools/demo-studio-v3/tool_dispatch.py:171-191`:

```python
config = tool_input.get("config")
if config is None:
    missing_keys = [k for k in ("path", "value") if k in tool_input]
    detail = (
        f"set_config requires a 'config' object key (whole-JSON snapshot). "
        f"Old per-field keys detected: {missing_keys}. "
        ...
    )
    logger.warning("_handle_set_config: invalid input shape session=%s keys=%s", session_id, list(tool_input.keys()))
    return {
        "is_error": True,
        "error_code": "invalid_input",
        "content": detail,
    }
```

This DOES return `is_error: True`. **But it's lost two layers up.**

### Surface C — `agent_proxy.run_turn` builds the tool_result block for the next API call WITHOUT setting `is_error` on the block itself

`tools/demo-studio-v3/agent_proxy.py:419-442`:

```python
is_error = bool(result.get("is_error"))
...
await translator.emit_tool_result(
    tool_name=tool_name,
    tool_use_id=tool_use_id,
    output=result,
    is_error=is_error,            # ← used for SSE event only
)

# Build tool_result block for next API call.
tool_result_blocks.append({
    "type": "tool_result",
    "tool_use_id": tool_use_id,
    "content": json.dumps(result, default=str),   # ← is_error embedded INSIDE the JSON string
    # NO top-level "is_error": True !
})
```

Anthropic's tool-use content-block schema treats `is_error` as a **top-level field on the tool_result block**, not a key inside the `content` JSON. When `is_error` is absent on the block, the model treats the tool_result as a successful return and reads `content` as the success payload. The string `'{"is_error": true, "error_code": "invalid_input", "content": "..."}'` has `is_error: true` as ASCII characters in a content string the model has to *parse* to notice. Empirically, the model often does not — it treats the verbose error text as instructional context and proceeds as if the tool succeeded. This is the *actual* root cause of "agent narrates 'Config saved successfully' when nothing was saved."

### Surface D — Dispatch is unobservable in logs

There is one `logger.warning` in `_handle_set_config:182`. There is no structured `dispatch_started` / `dispatch_completed` log line in `tool_dispatch.dispatch` (`tool_dispatch.py:360-407`) or in `agent_proxy.run_turn`'s tool-use loop. Ekko's investigation (4 hours, three log scrapes) hit this directly: "agent said tool_use, did anything happen?" was unanswerable from logs alone. We had to infer from the *absence* of S2 outbound httpx calls. That is unacceptable observability for a tool-dispatch path that is the heart of the agent's effect on the world.

### Surface E — Force-retry hides validation failures from the agent

`tools/demo-studio-v3/tool_dispatch.py:212-251`: on `ValidationError`, the handler captures the details and re-issues `snapshot_config(..., force=True)`. On force success the tool_result has no `is_error`, has a `version`, and has `validation: {errors: [...], force_applied: true}` — which the agent reads as success-with-side-note and the system prompt rule 5 reinforces ("save succeeded — do NOT call set_config again"). The "soft-fail with warnings" framing was justified at authoring time as letting the agent make forward progress despite minor schema warnings. In practice it papered over the schema-stub bug (`/v1/schema` returning 11 fields). The cure is honest: delete the force-retry, surface validation failures cleanly, let the agent fix the offending fields. After Karma's schema wiring lands, validation errors become rare; force-retry has no remaining justification.

### Why this is structural, not a one-session anomaly

The Aviva tool_use likely truncated mid-payload because the `max_tokens=8096` ceiling at `agent_proxy.py:316` was hit by the agent generating a large nested config JSON. The fallback (silent empty input) + the missing top-level `is_error` on tool_result combine into a class of bugs: **any time the agent's tool_input fails to parse, the agent learns "tool succeeded with a verbose context block" and continues confidently with stale state.** This will recur on every brand the agent is asked to model whose config-snapshot exceeds ~6-7k output tokens.

### Existing-state map (ground truth)

| Surface | File / endpoint | Today's behavior |
| ------- | --------------- | ---------------- |
| Tool_use JSON parse | `stream_translator.py:253-261` | On `JSONDecodeError` silently sets `tool_input={}`; no log; no SSE; no telemetry. |
| Local input-shape rejection | `tool_dispatch.py:171-206` `_handle_set_config` | `config=None` → `{"is_error": True, "error_code": "invalid_input", ...}`; `config` non-dict → same shape. `logger.warning` fires (visible in Cloud Run logs). |
| S2 outbound | `tool_dispatch.py:211-253` | Reaches S2 only when local-shape passes. Per Ekko's logs, in the failing session this branch was never entered for Aviva tool_uses. Force-retry block at lines 222-251 fires when initial POST raises `ValidationError`. |
| Force-retry on ValidationError | `tool_dispatch.py:222-251` | Re-issues `snapshot_config(..., force=True)`; on success returns `version` + `validation.force_applied=true` with NO `is_error`. **Deleted by ADR-4.** |
| Tool_result block to Anthropic | `agent_proxy.py:438-442` | `{type: "tool_result", tool_use_id, content: json.dumps(result)}` — **no top-level `is_error` field, ever.** The local `is_error` from the result dict is read for SSE emission only. |
| Dispatch start/end logs | `tool_dispatch.dispatch` | One `logger.warning` on unknown tool; one `logger.error` on handler exception. **No structured "dispatch started for tool X with input keys Y" / "dispatch completed in Z ms" lines.** Tool execution is invisible to log-driven debugging. |
| Schema endpoint | S2 `/v1/schema` | Stub returning ~11 fields. **Sibling concern (Karma's plan in promotion).** Once real schema lands, agent writes correctly-shaped configs and validation errors become rare. ADR-4 assumes this lands in parallel; the two are mutually-reinforcing but neither blocks the other. |

## Decision

### D1 — `stream_translator` no longer silently swallows tool_use JSON-decode errors

When `json.loads(json_buf)` raises `JSONDecodeError`, the translator:

1. Logs at `logger.error` level with: `session_id`, `tool_use_id`, `tool_name`, `len(json_buf)`, `json_buf[:200]` (truncated for log-size safety; no PII concern as the model output is not user-typed text), and the exception's `pos`/`msg`.
2. Sets the block's `input` to a sentinel dict `{"__decode_error__": True, "raw_len": <int>, "decode_msg": "<str>"}` instead of an empty `{}`. This sentinel is detectable by the dispatcher (D2) and produces a distinct `error_code` ("malformed_tool_input") rather than the generic "invalid_input."
3. Emits an SSE `error` event named `tool_use_decode_error` with `{tool_name, tool_use_id, raw_len}` so the browser also sees the failure (UI may toast or just log).
4. Marks `block["complete"] = True` and `block["decode_failed"] = True` so downstream knows.

**Rationale:** silent fallback to `{}` is the load-bearing failure mode behind `e352044b…`. Any tool_use whose input fails to parse must produce a noisy, observable, structurally-typed signal so dispatch can surface it correctly.

### D2 — `_handle_set_config` returns clean `is_error` for malformed tool_input AND for S2 validation failure; force-retry deleted

The handler is rewritten end-to-end. Two outcomes only: saved or not-saved.

**Malformed tool_input branch** — if `tool_input` carries the D1 `__decode_error__` sentinel OR `config` is missing OR `config` is non-dict:

```jsonc
{
  "is_error": true,
  "error_code": "malformed_tool_input",   // or "invalid_input" for non-decode shape errors
  "content": "set_config FAILED — the tool input could not be parsed as a config object. Nothing was saved. The previous config is unchanged. <specific detail: 'tool_input was empty (likely truncated by token limit; reduce config size or split into multiple set_config calls)' OR 'config key absent' OR 'config is not an object'>. CALL get_config to verify current persisted state before any further action.",
  "saved": false,
  "diagnostic": {
    "decode_failed": <bool>,
    "raw_len": <int or null>,
    "input_keys_seen": [<list of keys actually present>]
  }
}
```

**S2 validation-error branch** — when the single `snapshot_config(session_id, config, force=False)` call raises `config_mgmt_client.ValidationError`:

```jsonc
{
  "is_error": true,
  "error_code": "validation_error",
  "content": "set_config FAILED — S2 rejected the config: <count> field(s) failed validation. Nothing was saved. The previous config is unchanged. Read the structured errors below, fix the offending fields, and call set_config again with the corrected whole-config payload.",
  "saved": false,
  "errors": [
    {"field": "card.front[0].value", "reason": "required"},
    {"field": "colors.primary",      "reason": "must match pattern ^#[0-9a-fA-F]{6}$"},
    /* ... structured per-field entries derived from S2's `details` list ... */
  ]
}
```

The `errors` list maps S2's `ValidationError.details` (which today is whatever S2 puts in the response body's `detail` for 422 or `error.details` for 400+VALIDATION_FAILED — see `config_mgmt_client.py:48-72`) into a structurally typed list of `{field, reason}` entries. Implementer must inspect S2's actual `details` shape during T-impl-dispatch and adapt the mapping; if S2's shape is already `[{field, reason}, ...]`-equivalent, this is pass-through.

**Other S2 errors** — `NetworkError`, `UnauthorizedError`, `ServiceUnavailableError`, etc., produce the existing typed `error_code` strings (`"network_error"`, `"unauthorized"`, `"service_unavailable"`, `"handler_error"`) with `is_error: true` and `saved: false`. No retries (the agent decides whether/how to retry — or surfaces the error to the user).

**Canonical save** — when `snapshot_config` returns 2xx with empty validation block:

```jsonc
{
  "version": <int>,
  "validation": {"errors": []}
}
```

No `is_error`. No `force_applied`. No `saved` field needed (absence of `is_error` plus presence of `version` is the signal). This shape preserves backward-compat with happy-path tests in `test_tool_dispatch.py` and `test_s2_set_config_post_hotfix.py`.

**Code shape for the rewritten handler (illustrative; T-impl-dispatch authors actual code):**

```python
async def _handle_set_config(tool_input: dict, session_id: str, **backends) -> Any:
    snapshot_config = backends.get("snapshot_config", _default_snapshot_config)
    sse_sink = backends.get("sse_sink")

    # D1 sentinel detection
    if tool_input.get("__decode_error__"):
        await _emit_save_failed(sse_sink, session_id)  # see D7
        return _malformed_tool_input_result(decode_failed=True, ...)

    config = tool_input.get("config")
    if config is None or not isinstance(config, dict):
        await _emit_save_failed(sse_sink, session_id)
        return _malformed_tool_input_result(decode_failed=False, ...)

    # Single POST. No force=True. No retry.
    try:
        s2_response = await snapshot_config(session_id=session_id, config=config, force=False)
    except _cmc.ValidationError as exc:
        await _emit_save_failed(sse_sink, session_id)
        return {
            "is_error": True,
            "error_code": "validation_error",
            "content": <prescriptive text per D2>,
            "saved": False,
            "errors": _structurize_s2_details(exc.details),
        }
    except _cmc.NetworkError as exc:
        await _emit_save_failed(sse_sink, session_id)
        return {"is_error": True, "error_code": "network_error", "content": "...", "saved": False}
    except _cmc.UnauthorizedError:
        await _emit_save_failed(sse_sink, session_id)
        return {"is_error": True, "error_code": "unauthorized", "content": "...", "saved": False}
    except _cmc.ServiceUnavailableError:
        await _emit_save_failed(sse_sink, session_id)
        return {"is_error": True, "error_code": "service_unavailable", "content": "...", "saved": False}

    # Canonical save.
    version = s2_response.get("version")
    if sse_sink and version is not None:
        await sse_sink("status", {"status": "config_saved", "phase": "configure", "sessionId": session_id, "configVersion": version})
    return {"version": version, "validation": s2_response.get("validation", {"errors": []})}
```

The `force` parameter remains on `config_mgmt_client.snapshot_config`'s signature (the underlying HTTP client preserves the affordance for any future hand-rolled debug invocation), but **no caller in the production code path passes `force=True`**. The handler always calls with `force=False`.

### D3 — `agent_proxy.run_turn` propagates `is_error` to the tool_result block sent to Anthropic

`tools/demo-studio-v3/agent_proxy.py:438-442` is amended:

```python
tool_result_blocks.append({
    "type": "tool_result",
    "tool_use_id": tool_use_id,
    "content": json.dumps(result, default=str),
    **({"is_error": True} if is_error else {}),    # ← top-level is_error on the block
})
```

This is the load-bearing fix. Anthropic's tool-use convention treats `is_error: true` on the block (not inside `content`) as the authoritative signal that the call failed. The model's instruction-following on `is_error` blocks is empirically much stronger than on parsing free-form prose inside content. Combined with D2's `saved: false` field inside the JSON, the agent has two converging signals: the block-level `is_error` and the structural body-level `saved: false`.

**Important — applies to ALL handlers, not just `set_config`.** The `is_error` propagation in agent_proxy must work for `get_schema`, `get_config`, and any future tool. This is a one-line amendment to the loop, not a per-handler change.

### D4 — Dispatch traceability via structured logs + per-call SSE telemetry

Two additions:

1. **Structured logs in `tool_dispatch.dispatch`.** At entry: `logger.info("dispatch_started tool=%s session=%s tool_use_id=%s input_keys=%s", tool_name, session_id, tool_use_id, list(tool_input.keys()))`. At exit: `logger.info("dispatch_completed tool=%s session=%s tool_use_id=%s duration_ms=%d is_error=%s error_code=%s", ...)`. Both lines emitted at `INFO` so they survive Cloud Run's default log level. `tool_use_id` propagated through `dispatch()`'s signature (new optional kwarg, falls back to `""` if absent).

2. **SSE `tool_dispatch` lifecycle events** named `tool_dispatch_started` / `tool_dispatch_completed`. Payload: `{tool_name, tool_use_id, duration_ms?, is_error?, error_code?}`. These are *separate* from the existing `tool_use` and `tool_result` SSE events the translator already emits — those serve the UI's chat-bubble rendering; these serve operators debugging "did the dispatch actually fire?" Browser may listen or ignore them; primary consumer is the dashboard's session-detail view (out of ADR-4 scope to wire into UI; just emit). Adding two more SSE statuses is additive per `2026-04-23-agent-owned-config-flow.md` §D6.

The combination means a future Ekko-style investigation can answer "did the dispatch fire?" in 30 seconds via either the Cloud Run log query `dispatch_started` or the SSE replay of the session.

**`tool_use_id` propagation:** `agent_proxy.py:409` becomes `await tool_dispatcher(tool_name, tool_input, session_id, tool_use_id=tu.get("id", ""))`; the inner closure at line 261 forwards it; `tool_dispatch.dispatch()` accepts it as a kwarg and includes it in both log lines and SSE payloads.

### D5 — System prompt amendments

`tools/demo-studio-v3/setup_agent.py:65-71` rules 3 and 5 are replaced; rules 6, 7 are appended. The same edits mirror into `agent_proxy.py:30-100` SYSTEM_PROMPT (the two prompts are duplicated today; both must agree).

> 3. If `set_config` returns `is_error: true` with `error_code: "validation_error"`, S2 rejected the config. **Nothing was saved.** Read `errors[].field` and `errors[].reason`; fix the offending fields in your full-config object; call `set_config` again with the corrected whole-config payload. Do not retry the same value. If the schema is unclear, call `get_schema` again rather than guessing.
>
> 5. (deleted — there is no `force_applied` path; force-retry has been removed from the codebase)
>
> 6. If `set_config` returns `is_error: true` with `error_code: "malformed_tool_input"`, your tool input could not be parsed (likely truncated by token limit). **Nothing was saved.** Call `get_config` to verify the current persisted state, then retry `set_config` with a smaller, simpler payload. Do NOT narrate "config saved" — narrate "I tried to save but the call was rejected; let me retry with a shorter payload."
>
> 7. NEVER narrate save success based on your own intent to save. Narrate based ONLY on a `set_config` tool_result that has no `is_error` field AND has a `version` field. If either is missing, the save did not succeed.

The deletion of rule 5 is structural — there is no longer a `validation.force_applied` field on any tool_result; any prompt copy referencing it is dead. T-impl-prompt scrubs the codebase for stale references (rule 5 in setup_agent.py; agent_proxy.py SYSTEM_PROMPT line 52 "If `set_config` returns a validation warning…" — replaced; line 66 "If the result includes validation errors, fix those fields and call set_config again with the corrected full config" — kept, it's compatible).

### D6 — SSE event taxonomy: two outcomes, not three

The today-emitted `event: status` `{status: "config_saved", ..., configVersion}` (`tool_dispatch.py:267-274`) is augmented by exactly one new status:

| Tool-result branch                   | SSE status emitted   | UI behavior                                                                                          |
| ------------------------------------ | -------------------- | ---------------------------------------------------------------------------------------------------- |
| Canonical save (no `is_error`)        | `config_saved` (unchanged) | Existing toast / preview iframe refresh / configVersion bump.                                        |
| Validation failed, no save           | `config_save_failed` | New: red toast "Config save failed — see chat"; do not refresh preview iframe; do not bump toolbar. |
| Malformed tool_input (D1 path)        | (no status SSE — D1 already emitted `tool_use_decode_error`) | UI's existing error-toast handler picks up `tool_use_decode_error`; same red-toast UX as `config_save_failed`. |
| Other S2 errors (network, 401, 503)   | `config_save_failed` | Same UX as validation failure — red toast; agent narrates the specific error_code in chat.            |

`config_saved` payload preserves `{status, phase: "configure", sessionId, configVersion}` exactly. `config_save_failed` payload carries `{status, phase: "configure", sessionId, configVersion: <previous version>}` so the UI can re-anchor to the last canonical save. There is **no `config_saved_with_warnings`** — that state does not exist after force-retry deletion.

Backward compatibility for the UI: existing listener at `studio.js` (search for the chat-stream consumer that today branches on `'config_saved'`) handles only `config_saved`. The new `config_save_failed` status must be added; producer obligation per `2026-04-23-agent-owned-config-flow.md` §D6 is "additively add new keys/statuses; existing consumers ignore unknown ones." Adding one new status is additive.

### D7 — Backward-compat sweep

Touched test files (sweep `grep -rn "set_config\|tool_dispatcher\|is_error\|force_applied" tools/demo-studio-v3/tests/`):

1. **`tests/test_w3_set_config_schema_flip.py`** —
   - Line 280-339 `test_set_config_validation_error_retries_with_force_and_surfaces_errors` — **deleted** (test pinned the force-retry behavior; behavior is gone).
   - Line 340 `test_set_config_validation_retry_is_bounded_to_one` — **deleted** (the "retry" being bounded is moot; there is no retry).
   - Line 627 `test_force_applied_success_result_shape` — **deleted** (the force-applied success state does not exist).
   - Line 44 `test_set_config_malformed_not_dict_rejected_before_s2`, line 82 `test_set_config_old_path_value_schema_rejected`, line 125 `test_set_config_valid_config_roundtrip_version_in_tool_result`, line 172 `test_set_config_version_appears_on_sse_status_event`, line 228 `test_set_config_session_doc_does_not_gain_version_keys` — **kept; structurally compatible.** May need minor body-shape assertion adjustments (e.g., adding `saved: false` to the malformed cases) but the test intent is preserved.
2. **`tests/test_tool_dispatch.py`** — happy paths assert `not result.get("is_error")` on canonical save. **Unchanged.** Other error-path tests assert `result.get("is_error") is True` — **compatible** with D2's superset body shape.
3. **`tests/test_s2_set_config_post_hotfix.py`** — happy path + concurrent set_config + auth headers. **Unchanged.**
4. **`tests/test_stream_translator*.py`** — TX1 adds new coverage; existing tests unchanged.

External callers of the tool_result block shape: only Anthropic itself consumes the block in the next API call. The change to add top-level `is_error` is additive per Anthropic's content-block schema and cannot break anything. The deletion of `validation.force_applied` and `validation.errors` keys (when validation passes) does not break any non-test caller (no internal Python code introspects these keys outside of tests; verified by sweep at authoring time — the only non-test reference to `force_applied` is the now-deleted system-prompt rule 5 and the now-deleted handler block).

### D8 — `2026-04-23-agent-owned-config-flow.md` §D7 explicitly superseded

ADR-4 supersedes `plans/in-progress/work/2026-04-23-agent-owned-config-flow.md` §D7 ("soft-fail with warnings"). The strategy is being deleted from the codebase, not amended. T-impl-dispatch appends a `> **Superseded by `plans/approved/work/2026-04-27-adr-4-set-config-validation-framing.md` (2026-04-27).** The "soft-fail with warnings" strategy was a mechanism that hid validation errors and gaslighted the agent. Force-retry deleted; tool_result framing flipped to clean is_error on any non-canonical save.` block to §D7 of the in-progress plan as part of the impl change-set.

### D9 — Robustness across Ekko hypotheses

The brief lists three hypotheses; ADR-4 covers all three:

1. **Local Pydantic/shape validation rejected payload** — D1+D2+D3 ensure the `is_error` propagates correctly, agent narrates failure, user sees red toast.
2. **Tool_use was dispatched but exception swallowed locally** — D4's structured logs make this visible (`dispatch_started` without `dispatch_completed` is a smoking gun). D3 also catches `Exception` in `tool_dispatcher` (`agent_proxy.py:410-417`) and constructs `is_error: True, error_code: handler_exception` — propagation through D3 fixes the silent-success symptom.
3. **Agent loop emitted tool_use but never routed to dispatch** (parsing edge / control-flow bug) — D1 + D4 surface this: D1 catches the JSON-decode case explicitly; D4's `dispatch_started` log line is *absent* if the loop genuinely skipped dispatch, making the bug detectable. ADR-4 does not fix a loop-routing bug if one exists (we have no evidence it does), but it makes such a bug observable.

## UX Spec

### User flow

1. User signs in, lands in studio shell with seeded preview.
2. User in chat asks for a config change ("make it AXA Germany").
3. Agent calls `set_config` with the proposed payload. **Branches:**
   - **Branch A — canonical save.** S2 returns 200, validation clean. Tool_result is `{version: N, validation: {errors: []}}` with NO `is_error`. SSE: `config_saved`. UI: green toast "Config saved as v<N>"; preview iframe refreshes; toolbar shows `vN`. Agent narrates success.
   - **Branch B — malformed tool_input (D1/D2 path).** Agent's tool_use JSON failed to parse (truncation, encoding edge). Tool_result is `{is_error: true, error_code: "malformed_tool_input", saved: false, ...}` AND the block carries top-level `is_error: true`. SSE: `tool_use_decode_error` (D1). UI: red toast "Config save failed — see chat"; preview iframe unchanged; toolbar unchanged. Agent narrates failure ("I tried to save but the call was rejected; let me retry with a shorter payload") and retries.
   - **Branch C — S2 ValidationError.** S2 returns 422. Tool_result is `{is_error: true, error_code: "validation_error", saved: false, errors: [{field, reason}, ...]}` AND the block carries top-level `is_error: true`. SSE: `config_save_failed`. UI: red toast; preview iframe unchanged; toolbar unchanged. Agent narrates the specific failed fields verbatim ("S2 rejected: `colors.primary` must match pattern `^#...`; `card.front[0].value` is required") and proposes corrected values for the next user turn.

There is **no fourth branch.** Force-applied saves do not exist.

### Component states

| State                                   | Toast                                         | Preview iframe         | Toolbar configVersion                     |
| --------------------------------------- | --------------------------------------------- | ---------------------- | ----------------------------------------- |
| Canonical save (Branch A)                | Green "Config saved as v<N>"                  | Refreshed              | `vN`                                       |
| Malformed tool_input (Branch B)          | Red "Config save failed — see chat"           | Unchanged              | Unchanged                                 |
| Validation failed, no save (Branch C)    | Red "Config save failed — see chat"           | Unchanged              | Unchanged                                 |

### Responsive behavior

No new components — one new red-toast variant. Inherits existing layout. No breakpoint-specific behavior changes.

### Accessibility

- New red-toast variant must meet WCAG AA against studio shell background (existing toast component is presumed compliant; impl verifies for the new variant).
- Per `plans/approved/personal/2026-04-25-frontend-uiux-in-process.md` §D5 a11y floor: focus order unchanged, no tab traps, the new variant announces via existing `aria-live="polite"` region.

### Wireframe

No Figma needed. Visible delta:

```
toolbar:  configVersion v3        (Branch A — bumped)   OR    configVersion v3 (unchanged from prior, Branches B/C)
toast:    "Config saved as v3"               (green, Branch A)
          "Config save failed — see chat"    (red,   Branches B/C)
```

UX-Waiver does not apply — toast color is a visible delta; §UX Spec is required.

## Tasks

Total estimate: ~210 minutes. Three streams (xfails ‖ impl-core ‖ impl-ui) base from `feat/demo-studio-v3`. See §Dispatch.

### QA Tasks

- [ ] **TQ1** — Akali Playwright RUNWAY per §QA Plan §Akali Playwright RUNWAY scope. Single session covering Branch A (canonical save) and Branch C (validation failure — induce by submitting non-hex color). Branch B (malformed tool_input) is **integration-tested only** (TX1+TX2+TX3) — inducing live in browser requires forcing token-truncation which is fragile. estimate_minutes: 40. Files: `assessments/qa-reports/2026-04-27-adr-4-set-config-framing.md` (new). DoD: video covering Branches A and C; per-branch screenshot with observation narrative (Rule 16) covering toast color + toolbar state + iframe state; QA report linked from PR via `QA-Report:`. parallel_slice_candidate: wait-bound.

### Test Tasks (TDD — land before impl per Rule 12)

- [ ] **TX1** — xfail: `test_stream_translator_tool_use_decode_error_logs_and_sentinels` — feed the translator a synthetic `input_json_delta` stream with malformed JSON (truncated mid-string); assert the resulting tool_use block has `input == {"__decode_error__": True, "raw_len": <int>, "decode_msg": <str>}` AND `block["decode_failed"] is True`; assert `logger.error` was called with structured fields; assert sse_sink received an `error` event named `tool_use_decode_error` with the right payload. estimate_minutes: 30. Files: `tools/demo-studio-v3/tests/test_stream_translator_decode_error.py` (new). DoD: `@pytest.mark.xfail(reason="ADR-4 D1 pending")`; uses translator's existing test patterns; committed on `test/adr-4-dispatch-traceability-xfails`. parallel_slice_candidate: no.
- [ ] **TX2** — xfail: `test_handle_set_config_decode_error_sentinel_returns_malformed_tool_input` — call `_handle_set_config` directly with `tool_input={"__decode_error__": True, "raw_len": 4096, "decode_msg": "Unterminated string"}`; assert `result["is_error"] is True`, `result["error_code"] == "malformed_tool_input"`, `result["saved"] is False`, `result["diagnostic"]["decode_failed"] is True`, `result["diagnostic"]["raw_len"] == 4096`. Also: `tool_input={}` (no decode-sentinel) returns `error_code: "invalid_input"` with `result["diagnostic"]["decode_failed"] is False`. AND a third sub-test: `tool_input={"config": {"some": "valid"}}` with `snapshot_config` mocked to raise `_cmc.ValidationError(details=[...])` returns `is_error: True`, `error_code: "validation_error"`, `saved: False`, `errors: [...]` (structured per-field list), AND `snapshot_config` is called **exactly once** with `force=False` (regression test for force-retry deletion). estimate_minutes: 35. Files: `tools/demo-studio-v3/tests/test_set_config_framing.py` (new). DoD: xfail-marked. parallel_slice_candidate: no.
- [ ] **TX3** — xfail: `test_run_turn_propagates_is_error_to_tool_result_block` — drive `agent_proxy.run_turn` end-to-end with a mocked Anthropic stream that emits a `set_config` tool_use the dispatcher returns `{is_error: True, error_code: "malformed_tool_input", ...}` for; capture the `tool_result_blocks` appended to the conversation store; assert the persisted block has top-level `"is_error": True` AND `"content"` carries the JSON-stringified result. estimate_minutes: 30. Files: same file as TX2 (or a new `test_run_turn_tool_result_propagation.py` if the test fits more naturally there). DoD: xfail-marked. parallel_slice_candidate: no.
- [ ] **TX4** — xfail: `test_dispatch_emits_lifecycle_logs_and_sse` — call `tool_dispatch.dispatch(tool_name="get_schema", ...)` with a fake sse_sink; assert two log lines (`dispatch_started`, `dispatch_completed`) at INFO with the structured fields; assert sse_sink received `tool_dispatch_started` and `tool_dispatch_completed` events with `tool_use_id` propagated. estimate_minutes: 25. Files: `tools/demo-studio-v3/tests/test_tool_dispatch_traceability.py` (new). DoD: xfail-marked; uses `caplog` fixture for log capture. parallel_slice_candidate: no.
- [ ] **TX6** — xfail: SSE event taxonomy parametrize across canonical-save and save-failed branches (no third branch); assert emitted status string per branch; assert payload shape including `configVersion: <previous>` on `config_save_failed`. estimate_minutes: 15. Files: `tools/demo-studio-v3/tests/test_set_config_framing.py` (same as TX2). DoD: xfail-marked. parallel_slice_candidate: no.

(TX5 — force-retry framing test from prior revision — **deleted** per scope change; force-retry is gone.)

### Implementation Tasks

- [ ] **T-impl-translator** — Amend `stream_translator._handle_content_block_stop` per D1: log on JSONDecodeError, set sentinel input, mark `decode_failed`, emit `tool_use_decode_error` SSE. estimate_minutes: 35. Files: `tools/demo-studio-v3/stream_translator.py`. DoD: TX1 flips to pass. parallel_slice_candidate: no — central translator change.
- [ ] **T-impl-dispatch** — Rewrite `_handle_set_config` per D2: detect `__decode_error__` sentinel and return `malformed_tool_input` shape; on missing/non-dict `config` return `invalid_input` shape; on `ValidationError` return `validation_error` shape with structured `errors: [{field, reason}, ...]` list; on other typed S2 exceptions return appropriate `error_code` with `saved: false`. **Delete the force-retry block at lines 222-251 entirely.** Apply D6 SSE event differentiation (`config_saved` for canonical, `config_save_failed` for any non-canonical S2 outcome). Append the "Superseded by ADR-4" note to `plans/in-progress/work/2026-04-23-agent-owned-config-flow.md` §D7 (D8). estimate_minutes: 55. Files: `tools/demo-studio-v3/tool_dispatch.py`, `plans/in-progress/work/2026-04-23-agent-owned-config-flow.md`. DoD: TX2, TX6 flip to pass. parallel_slice_candidate: no.
- [ ] **T-impl-runturn** — Amend `agent_proxy.run_turn` per D3: add top-level `is_error: True` to the tool_result block when `result.get("is_error")`. Plumb `tool_use_id` into the dispatcher closure (D4). estimate_minutes: 30. Files: `tools/demo-studio-v3/agent_proxy.py`. DoD: TX3 flips to pass. parallel_slice_candidate: yes — touches a different file from T-impl-dispatch; can land in the same PR but coded in parallel.
- [ ] **T-impl-traceability** — Amend `tool_dispatch.dispatch` per D4: structured `dispatch_started`/`dispatch_completed` INFO logs with `tool_use_id`, `duration_ms`, `is_error`, `error_code`. Emit `tool_dispatch_started` / `tool_dispatch_completed` SSE events via the sse_sink override. Accept `tool_use_id` kwarg (default `""`). estimate_minutes: 35. Files: `tools/demo-studio-v3/tool_dispatch.py` (same as T-impl-dispatch — combine into one branch). DoD: TX4 flips to pass. parallel_slice_candidate: combine into T-impl-dispatch's branch.
- [ ] **T-impl-prompt** — Replace `setup_agent.py` rules 3 and 5 (rule 5 deleted entirely); append rules 6, 7 (D5). Mirror the relevant edits in `agent_proxy.py:30-100` SYSTEM_PROMPT block. Scrub all references to `force_applied` and `validation warning` from both prompt files. estimate_minutes: 25. Files: `tools/demo-studio-v3/setup_agent.py`, `tools/demo-studio-v3/agent_proxy.py`. DoD: text matches D5; no `force_applied` references remain in either prompt; committed on the same impl branch as T-impl-runturn. parallel_slice_candidate: combine into T-impl-runturn's branch.
- [ ] **T-impl-test-cleanup** — Delete the three force-retry-pinning tests in `tests/test_w3_set_config_schema_flip.py` (per D7): line-280 `test_set_config_validation_error_retries_with_force_and_surfaces_errors`, line-340 `test_set_config_validation_retry_is_bounded_to_one`, line-627 `test_force_applied_success_result_shape`. Verify the remaining tests in that file still pass against the new handler shape (minor assertion tweaks allowed; structural intent preserved). estimate_minutes: 20. Files: `tools/demo-studio-v3/tests/test_w3_set_config_schema_flip.py`. DoD: pytest green; no test in the file references `force_applied` or asserts force-retry behavior. parallel_slice_candidate: lands with T-impl-dispatch (same branch — coupled to handler change).
- [ ] **T-impl-ui** — In `tools/demo-studio-v3/static/studio.js` (chat-stream consumer that today branches on `'config_saved'`):
  - Add `case 'config_save_failed'`: red toast "Config save failed — see chat"; no preview refresh; no version bump.
  - Keep `'config_saved'` happy-path.
  - Add handler for the `tool_use_decode_error` SSE event (red toast "Config save failed — see chat" — same UX as `config_save_failed`; the user doesn't need to distinguish parse failure from validation failure).
  - **No `config_saved_with_warnings` case** — that state does not exist.
  estimate_minutes: 30. Files: `tools/demo-studio-v3/static/studio.js`. DoD: TQ1 confirms toast per branch; committed on `feat/adr-4-ui-toasts` from `feat/demo-studio-v3`. parallel_slice_candidate: yes — independent file from impl-core branches.
- [ ] **T-merge** — Merge xfail branch into impl branch(es); de-xfail; pytest green; open PR(s) against `feat/demo-studio-v3`. Single PR preferred (handler+translator+runturn+prompt+UI all coupled by contract). estimate_minutes: 35. Files: all touched test files. DoD: PR open with `QA-Report:` (TQ1) and TX1, TX2, TX3, TX4, TX6 green in CI; PR body cites ADR-4 with `Plan-Ref:` line. parallel_slice_candidate: no.

### Dispatch

All worktrees base from `feat/demo-studio-v3` in `~/Documents/Work/mmp/workspace/`. Always `git pull` `feat/demo-studio-v3` before branching.

| Stream         | Branch                                              | Tasks                                                                                       | Notes                                                                                                                           |
| -------------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Tests          | `test/adr-4-dispatch-traceability-xfails`           | TX1, TX2, TX3, TX4, TX6                                                                     | Land xfails first per Rule 12. Vi-tier (Senna co-author per qa_co_author).                                                       |
| Impl-core      | `feat/adr-4-dispatch-traceability`                  | T-impl-translator, T-impl-dispatch, T-impl-runturn, T-impl-traceability, T-impl-prompt, T-impl-test-cleanup | Jayce-tier. Most-coupled set; one branch.                                                                                        |
| Impl-UI        | `feat/adr-4-ui-toasts`                              | T-impl-ui                                                                                   | Jayce-tier. **Parallel-safe with Impl-core** — different file paths, no shared state.                                            |
| Merge/QA       | merged onto a single PR branch (impl-core base)     | T-merge, TQ1                                                                                | Serial after both impl streams green. TQ1 wait-bound on a deployable Cloud Run revision of the merged branch.                    |

## QA Plan

**UI involvement:** yes

One new red-toast variant. Akali Playwright RUNWAY required per Rule 16.

### Acceptance criteria

Reviewer (Senna) confirms via code-check + Akali confirms via Playwright:

- `stream_translator` on `JSONDecodeError`: log line at ERROR with structured fields; sentinel input dict; SSE `tool_use_decode_error` event.
- `_handle_set_config` on decode-sentinel input: returns `is_error: true`, `error_code: "malformed_tool_input"`, `saved: false`, `diagnostic.decode_failed: true`.
- `_handle_set_config` on missing/non-dict `config` (no decode-sentinel): returns `error_code: "invalid_input"`, `saved: false`, `diagnostic.decode_failed: false`.
- `_handle_set_config` on `ValidationError`: returns `is_error: true`, `error_code: "validation_error"`, `saved: false`, `errors: [{field, reason}, ...]`. **Calls `snapshot_config` exactly once with `force=False`.** No second call. No `force_applied` field anywhere in the result.
- `agent_proxy.run_turn` tool_result block: top-level `"is_error": true` when `result.get("is_error")` is truthy.
- Canonical save: no `is_error`, `version`, `validation.errors == []`. No `force_applied`. No `saved` field needed.
- SSE statuses: `config_saved` on canonical save; `config_save_failed` on any non-canonical S2 outcome (validation, network, 401, 503).
- `tool_dispatch.dispatch`: `dispatch_started` and `dispatch_completed` log lines and SSE events emitted with `tool_use_id`.
- System prompt rules 3, 6, 7 match D5; rule 5 deleted; no `force_applied` references remain in either `setup_agent.py` or `agent_proxy.py` SYSTEM_PROMPT.
- UI toast renders per §UX Spec (green for success, red for failure — no amber/warning state).
- `2026-04-23-agent-owned-config-flow.md` §D7 carries the "Superseded by ADR-4" note.

### Happy path (user flow)

1. Akali signs in via Google (`missmp.eu` test account); lands in studio shell.
2. Akali clicks "New session"; lands in `/session/{sid}` with seeded Allianz preview.
3. Akali types: "make the brand AXA Germany". Agent calls `set_config` (canonical save). UI: green toast "Config saved as v2"; preview iframe refreshes to AXA branding; toolbar `v2`. **Branch A verified.**
4. Akali types: "set the primary color to 'navy blue' (the words, not a hex code)". Agent calls `set_config`; S2 returns 422. UI: red toast "Config save failed — see chat"; preview unchanged; toolbar still `v2`. Agent narrates the structured field-level errors verbatim ("S2 rejected: `colors.primary` must match pattern `^#[0-9a-fA-F]{6}$`") and proposes a corrected hex value for the next user turn. **Branch C verified — and crucially, the agent does NOT silently succeed; force-retry is gone.**

(Branch B — malformed tool_input — is integration-tested only via TX1+TX2+TX3; not part of the live Playwright run because inducing token-truncation in production is fragile.)

### Akali Playwright RUNWAY scope

Per the project doc §ADR-sequencing block (the 2026-04-27 RUNWAY scope-gap learning), this ADR's QA scope **mandates** sign-in via Google as part of the test path. No nonce-URL bypass.

1. **Sign-in path.** Open `feat/demo-studio-v3` Cloud Run revision URL in fresh Playwright context. Click "Sign in with Google". Complete auth with `missmp.eu` test account (creds via `tools/decrypt.sh`). Land in studio shell.
2. **Branch A — canonical save.** AXA Germany prompt. Wait for green toast. Screenshot toolbar `v2` + preview iframe (AXA blue). Observation narrative.
3. **Branch C — validation failed (clean fail, no force-retry).** Navy-blue prompt. Wait for red toast. Screenshot toolbar (still `v2`) + unchanged preview. Observation narrative including agent's chat narration of the structured field-level errors AND explicit confirmation that the agent does NOT report success (regression check for the gaslighting symptom from session `e352044b…`).

Browser isolation: incognito (fresh context per run). Env URL: feat-branch Cloud Run revision (Akali confirms with Duong before run).

QA report path: `assessments/qa-reports/2026-04-27-adr-4-set-config-framing.md`. Linked in PR body via `QA-Report:`.

Figma-Ref: not required. Visual-Diff: not required.

### Failure modes (what could break)

- **D3 propagation regression on a future agent_proxy refactor.** A future change to `run_turn` could drop the top-level `is_error` again. Mitigation: TX3 is a structural test; CI catches the regression.
- **Stream translator change breaks happy-path tool_use parsing.** TX1 covers the decode-failure path but not the happy path. Existing translator tests (`test_stream_translator*.py`) cover the happy path; impl must run those green before merge.
- **SSE consumer in `studio.js` does not exhaustively switch on status.** T-impl-ui must verify the existing handler shape; new statuses must be explicit cases, not fall-through.
- **Agent ignores block-level `is_error: true` and proceeds optimistically.** Empirically rare in Anthropic's tool-use convention but possible. Mitigation: D5's prompt rules 6+7 belt-and-braces. If observed in post-merge live testing, follow-up plan tightens copy.
- **Karma's `/v1/schema` wiring lands later than expected.** ADR-4 is independent of that landing — validation errors still surface honestly after ADR-4 lands; they just remain *common* until the schema is real. The agent loop handles them per rule 3 (read errors → fix fields → retry). No coupling.
- **Backward-compat tests fail.** D7 enumerates the three w3 tests being deleted and the others kept-with-minor-tweaks. Risk: a test we missed asserts shape after a force-retry success path. Mitigation: `grep -rn "force_applied\|force=True\|force_retry" tools/demo-studio-v3/tests/` during T-impl-test-cleanup; any not-yet-listed test is amended/deleted on the same branch.
- **Existing in-flight sessions whose agent prompt was loaded before the deploy.** A session active at deploy time keeps the old SYSTEM_PROMPT in its conversation context (rule 5 cached upstream). Such a session's agent might still expect `force_applied`. Mitigation: SYSTEM_PROMPT is re-injected at the start of every `run_turn` (`agent_proxy.py:237 system: str = SYSTEM_PROMPT`), so the *new* prompt takes effect on the next user turn after the deploy. No stuck sessions.

### QA artifacts expected

- Akali Playwright video covering Branches A and C.
- Per-branch screenshots with observation narratives (Rule 16).
- QA report at `assessments/qa-reports/2026-04-27-adr-4-set-config-framing.md` linked via `QA-Report:` in PR body.
- Pytest run output showing TX1, TX2, TX3, TX4, TX6 green post-merge (CI artifact suffices).

## Cross-ADR Boundaries

| Boundary                                    | This ADR                                          | Other ADR / plan                                                       | Contract                                                                                                                                                            |
| ------------------------------------------- | ------------------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Default config seed at session creation     | not touched                                       | `plans/approved/work/2026-04-27-adr-3-default-config-greeting.md`     | ADR-3 establishes the seeded baseline. ADR-4 governs subsequent agent-driven edits.                                                                                  |
| Build progress bar                          | not touched                                       | `plans/approved/work/2026-04-27-adr-1-build-progress-bar.md`           | ADR-1 mounts on `status: building`. ADR-4 emits `status: config_saved` and `config_save_failed` and `tool_use_decode_error`. Different statuses, same SSE channel — additive. |
| Verification service                        | not touched                                       | `plans/approved/work/2026-04-27-adr-2-verification-service.md`         | Out of phase.                                                                                                                                                       |
| Schema endpoint (S2 `/v1/schema` wiring)    | depended-on (ADR-4 surfaces validation honestly; Karma's plan reduces frequency) | Karma's `/v1/schema` wiring plan (in promotion)                         | Karma's plan replaces the 11-field stub with the canonical schema. After it lands, agent writes correctly-shaped configs and validation errors become rare. ADR-4 makes the rare occurrences honest. **Mutually reinforcing; neither blocks the other.** |
| `get_config_template(brand_hint?)` tool     | not in scope                                      | Karma's quick-lane plan (separate, sibling)                             | Template tool reduces *frequency* of large config payloads (smaller payload → less likely to truncate → less likely to hit D1 path). Orthogonal but synergistic.   |
| §D7 of agent-owned-config-flow              | **supersedes** §D7                                | `plans/in-progress/work/2026-04-23-agent-owned-config-flow.md`         | §D7 said "soft-fail with warnings"; ADR-4 deletes that strategy. T-impl-dispatch appends the "Superseded by ADR-4" note in the in-progress plan as part of the impl change-set. |
| System prompt protocol                      | amends rule 3; **deletes rule 5**; adds 6, 7      | `tools/demo-studio-v3/setup_agent.py`, `tools/demo-studio-v3/agent_proxy.py:30-100` | D5 specifies new wording; T-impl-prompt lands the change.                                                                                                            |

## Related (out-of-scope sibling concerns)

- **S2 in-memory-dict storage substrate.** Per Ekko's investigation: S2 is `min-instances=1` Cloud Run with `_session_configs: dict` in-memory; works for single-user demos but fragile across redeploys. ADR-3 D2 accepted this as v1 risk. ADR-4 inherits the same posture (any `set_config` writes to in-memory S2; a redeploy mid-session loses state). Not in ADR-4 scope; flagged for awareness. Karma owns the long-term Firestore migration.

## Open Questions

### OQ-1 — Did the failing session's agent emit valid JSON that we just lost, OR did Anthropic truncate the output mid-tool_use?

**Status: not blocking.** Distinguishing the two requires Anthropic-side telemetry we don't have. ADR-4's D1 covers both: the translator handles `JSONDecodeError` regardless of cause, and the prompt rule 6 instructs the agent to "retry with a smaller, simpler payload" — which addresses the truncation hypothesis specifically. If post-merge live testing shows `tool_use_decode_error` events firing repeatedly with `raw_len` near 8096, that confirms truncation as the dominant cause and triggers a follow-up to either (a) increase `max_tokens` cap (currently 8096 at `agent_proxy.py:316`), (b) introduce a `set_config_partial(section: str)` tool to allow the agent to write configs in chunks, or (c) optimize the JSON serialization (drop whitespace, abbreviate keys) — all out of ADR-4 scope.

## References

- `projects/work/active/bring-demo-studio-live-e2e-v1.md` — project goal, DoD steps 4–5.
- `plans/in-progress/work/2026-04-23-agent-owned-config-flow.md` §D7 — soft-fail decision being **superseded** (T-impl-dispatch annotates).
- `plans/approved/work/2026-04-27-adr-1-build-progress-bar.md` — sibling ADR; SSE channel additive coexistence.
- `plans/approved/work/2026-04-27-adr-2-verification-service.md` — sibling ADR; out-of-phase.
- `plans/approved/work/2026-04-27-adr-3-default-config-greeting.md` — sibling ADR; pre-edit baseline.
- Karma's `/v1/schema` wiring plan — sibling concern in promotion; reduces frequency of validation errors but does not block ADR-4.
- `tools/demo-studio-v3/stream_translator.py:253-261` — `JSONDecodeError → {}` silent fallback (D1 target).
- `tools/demo-studio-v3/tool_dispatch.py:146-296` — `_handle_set_config` (D2 target — full rewrite; force-retry block deleted).
- `tools/demo-studio-v3/tool_dispatch.py:360-407` — `dispatch` (D4 target).
- `tools/demo-studio-v3/agent_proxy.py:401-454` — `run_turn` tool-use loop (D3 target).
- `tools/demo-studio-v3/agent_proxy.py:30-100` — SYSTEM_PROMPT (D5 target — rule 5 deleted, force_applied references scrubbed).
- `tools/demo-studio-v3/setup_agent.py:65-71` — system prompt rules 3, 5 (D5 target — rule 5 deleted).
- `tools/demo-studio-v3/config_mgmt_client.py:48-139` — S2 client + ValidationError mapping (read-only here; reference for D2's structured-errors mapping).
- Prod session `e352044b37c04e828c7524c7034fdb75` — root-cause trace (Ekko Cloud Run scrape, 2026-04-27).

## Orianna approval

- **Date:** 2026-04-27
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Structural gates (QA-plan frontmatter, QA-plan body, UX Spec linter) all pass. Owner azir is clear, tier complex with qa_co_author senna and tests_required true is consistent with the multi-surface scope. Decisions D1–D9 are all load-bearing and grounded in the prod session `e352044b…` root-cause trace. Tasks are concrete with files, DoD, estimates, and an xfails-first plan (TX1-4, TX6) that satisfies Rule 12. Force-retry deletion is coherent end-to-end: code path removed, three w3 tests scheduled for deletion, system prompt rule 5 deleted, D8 supersedes 2026-04-23 §D7 with an explicit annotation task. §UX Spec covers all branches and the new red-toast variant; §QA Plan mandates Akali Playwright with Google sign-in and per-branch observation narratives per Rule 16.

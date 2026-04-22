---
agent: senna
concern: work
repo: missmp/company-os
pr: 32
pr_title: "feat: demo-studio v3 — Managed Agents + MCP architecture"
branch: feat/demo-studio-v3
head_sha: 75a1c7c1ca4e263e52f20c70ebbe892308a12cd8
review_scope: "Option B vanilla Messages API ship — commits 775a05a..75a1c7c (14 commits)"
plan: plans/in-progress/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md
date: 2026-04-22
verdict: NO-GO
---

# Senna — Code-Quality & Security Review of PR #32 (Option B vanilla API ship)

Scope-fenced review of the 14 commits comprising Waves 1–5 + the B2/B3/B4/B6/B7 fix chain
on `feat/demo-studio-v3` (`775a05a`..`75a1c7c`). The branch itself contains 558 commits
ahead of `main`; everything outside the Option B ship window is excluded from this review
per the task brief.

**Files examined (in scope):**
- `tools/demo-studio-v3/agent_proxy.py` (+485/-… — SYSTEM_PROMPT + `run_turn` core)
- `tools/demo-studio-v3/conversation_store.py` (new, +222)
- `tools/demo-studio-v3/stream_translator.py` (new, +263)
- `tools/demo-studio-v3/tool_dispatch.py` (new, +247)
- `tools/demo-studio-v3/main.py` (+234 — chat + stream rewire, new auth wrappers)
- `tools/demo-studio-v3/static/studio.js` (+22 — `handleSSE` helper)
- `tools/demo-studio-v3/templates/session.html` (+25 — new, standalone)
- `tools/demo-studio-v3/auth.py` (read-only, for cross-check against new auth wrappers)

**Out of scope (per task brief — not flagged):**
- Wave 6 deletions (`setup_agent.py`, MCP server, managed-agent SSE branch in `/chat` + `/stream`).
- Wave 7 Playwright E2E — Akali's lane.
- The 302 pre-existing ruff errors (documented by Vi).
- `test_chat_anthropic_401_returns_sanitized_502` implementation (Wave-6+).
- ADR / plan-contract fidelity (Lucian's lane; his review sits alongside at
  `assessments/work/2026-04-22-lucian-pr32-option-b-plan-fidelity.md`).

---

## Verdict: NO-GO

Two issues are blockers independently. See "Blocker list" below the findings.

---

## CRITICAL

### C1 — `require_vanilla_chat_session` is an authentication bypass
**File:** `tools/demo-studio-v3/main.py:95-129` (new in this PR; commit `c7b5c33` Wave 4)
**Route affected:** `POST /session/{session_id}/chat` (line 1688, `_sid: str = Depends(require_vanilla_chat_session)`)

The new dependency has **three independent defects** versus the `require_session` it replaces
(`auth.py:101-117`):

1. **No cookie↔path binding on the valid-cookie branch.** `require_session` rejects with 401
   when `path_session_id != verify_session_cookie(ds)` (auth.py:114-115). The new wrapper
   (main.py:120-123) returns the cookie's `sid` without checking it against
   `request.path_params["session_id"]`. A user holding a valid `ds_session` cookie for
   session A can POST to `/session/B/chat` and inject a message into B's ConversationStore.
   Server-side, the chat handler then uses the **path** `session_id` (body/log/dispatch),
   and `_sid` is discarded (underscored name). Cross-session message injection.

2. **`session_token` branch is a presence-only bypass.** Lines 113, 126-127:
   `if st: return request.path_params.get("session_id", "")`. **Any non-empty value**
   of a cookie named `session_token` — a trivially-forgeable name — is treated as valid
   auth for an arbitrary path session_id. There is no signature check, no registry lookup,
   no binding. `curl -b 'session_token=x' -X POST https://.../session/<victim-sid>/chat
   -d '{"message":"…"}'` succeeds. The inline comment "(test/legacy compatibility)"
   does not justify mounting this on a production route; legacy/test wiring belongs behind
   an env gate (e.g. `if os.getenv("ALLOW_LEGACY_SESSION_TOKEN") == "1"`) or in test fixtures
   only.

3. **Unused local imports inside a per-request function.** Lines 108-109 import `Cookie as
   _Cookie` and `Request as _Request` and then never use them. Minor style, flagged under
   MEDIUM (M3).

This is the S33-C1 pattern from the Senna memory (PR #61 Wave 2 F): any FastAPI auth
dependency reading cookies manually instead of delegating to `Depends(require_session)`
is assumed broken until proven otherwise. It's broken here in both directions.

**Remediation:** delete `require_vanilla_chat_session` entirely. Use
`_sid: str = Depends(require_session)` on `POST /session/{id}/chat` exactly as the
managed-agent path had it before Wave 4. If test fixtures need a bypass, inject
`X-Internal-Secret` (which is the already-shipped internal-bypass mechanism) or use
FastAPI's `dependency_overrides` to substitute the dependency under test — don't widen
the production surface.

**Test-quality note:** whichever tests forced the Wave-4 dep-rewrite were exercising
the wrong abstraction. Any test that currently relies on a raw `session_token` cookie
should be rewritten to either (a) forge a valid `ds_session` via
`create_session_cookie(sid)` from `auth.py:69`, or (b) set `X-Internal-Secret`.

---

### C2 — Assistant replies are persisted as the literal string `"[streamed]"`, breaking multi-turn
**File:** `tools/demo-studio-v3/agent_proxy.py:350-361` (`run_turn`, `end_turn` branch)

```python
store.append({"role": "assistant", "content": "[streamed]"})
```

Two downstream consequences:

1. **Conversation context is destroyed.** On turn N+1, `_build_messages` (line 260-270)
   reloads history via `store.load(session_id)` and ships it to Anthropic. The assistant
   turns in that history all have `content == "[streamed]"` — a three-word marker — not
   the actual text the model emitted. The model loses all memory of what it has said,
   including any tool_use decisions summarised inline. It will re-do GATHER, re-ask for
   brand/market, re-call `get_schema`, etc.

2. **Anthropic API shape is invalid on any turn that used tools.** When stop_reason was
   `tool_use`, the assistant's tool_use blocks are never written to the store. The loop
   DOES write `tool_result` blocks to the store as `{"role": "tool", ...}` → rewritten
   to `{"role": "user"}` in `_build_messages:268-269`. So on the next API call Anthropic
   receives: `user: "hi"`, `user: [tool_result ...]` — a `tool_result` with **no preceding
   `tool_use` block from the assistant**. Anthropic's API rejects this with a 400 error
   ("tool_result found but no corresponding tool_use"), which then gets caught in
   `run_turn`'s catch-all and surfaced as `upstream_unavailable`/`rate_limited`/raises.
   Every multi-turn tool-using conversation breaks at turn 2.

The inline comment at line 353-354 explicitly acknowledges the problem:
`"The assistant text was streamed; reconstruct from SSE is complex — store a summary
marker instead."` — but the "marker" strategy is **load-bearing on first turn only**.

**Test-coverage gap:** no multi-turn integration test exists. I grepped:
`grep -rn "multi.turn|second_turn|turn_2|two turns|follow_up" tests/` → zero matches
against `run_turn`. All Wave 2/3 tests either single-shot or fake the store entirely.

**Remediation options, in order of preference:**
- (a) Accumulate assistant text + tool_use blocks in `StreamTranslator` (via
  `content_block_delta` text deltas and `content_block_stop` for tool_use), expose via
  `StreamTranslator.get_assistant_blocks()`, and persist the **full block list** as
  `{"role": "assistant", "content": [...blocks...]}`. This is the Anthropic-documented
  shape for resumable conversations.
- (b) If (a) is deferred, at minimum persist the actual streamed text (accumulate
  `text_delta` chunks) and the list of tool_use blocks that fed the tool-use branch.
  Don't write the literal `"[streamed]"`.
- (c) Add an xfail test `test_run_turn_second_turn_preserves_tool_use_history` that drives
  two turns and asserts Anthropic sees a valid alternation — this test **must be red**
  against the current implementation to pin this as a bug-fix-with-regression-test
  (Rule 13) when (a) lands.

---

## HIGH

### H1 — Tool-result content leaks upstream URLs via `str(exc)` (S28 pattern, recurrence)
**File:** `tools/demo-studio-v3/tool_dispatch.py:172-196` (`_map_error`) and
`tools/demo-studio-v3/tool_dispatch.py:203-247` (`dispatch` → `return _map_error(exc, ...)`)

The Wave 3 error wrapper reads:

```python
return {
    "is_error": True,
    "error_code": code,
    "content": str(exc),            # <-- leaks
    "tool_name": tool_name,
}
```

`_default_patch_config` (lines 89-109) calls `requests.patch(f"{url}/v1/config/{encoded}", ...)`
without wrapping `requests.exceptions.RequestException`. A `ConnectionError` /
`ConnectTimeout` / `SSLError` **stringifies with the full URL**:
`HTTPSConnectionPool(host='config-mgmt-xyz.run.app', port=443): Max retries exceeded with
url: /v1/config/<sid> (Caused by ...)`. That string lands in the `content` field of the
returned dict, which is then:

- Emitted to the browser via `StreamTranslator.emit_tool_result` (stream_translator.py:77-106),
  **and**
- Sent back to Anthropic as a `tool_result.content` block (agent_proxy.py:401-405) — so the
  URL ends up in the model's context window and can be reflected in subsequent assistant
  messages.

The `config_mgmt_client.py:76,88` internal calls DO wrap via `NetworkError(str(e))` but
that same string is then rethrown and **still contains the URL**. `_map_error` passes the
wrapped exception's `str()` through unchanged.

This is the exact pattern Senna flagged on PR #57 (S28 memory entry) and on PR #61 I6 (S33).
The fix is known: never stringify raw HTTP exceptions. Log `type(exc).__name__` +
`getattr(exc, "status_code", None)` and return a **fixed** `content` string — something
like `"backend_error"` — that does not depend on the exception's representation.

**Remediation:**
```python
return {
    "is_error": True,
    "error_code": code,
    "content": code,                    # generic; never includes URL
    "tool_name": tool_name,
}
```
(or a short human-readable label derived from `code`.) Keep `str(exc)` in `logger.error`
only. Add a regression test that patches `_default_patch_config` to raise
`requests.exceptions.ConnectionError("... url: https://secret.run.app/v1/config/…")`,
dispatches `set_config`, and asserts the returned dict's `content` field does **not**
contain the substring `"secret"` or `"run.app"` (negative-assertion pattern — S30 memory).

### H2 — `/session/{id}/stream` vanilla path runs `run_turn` independently of the chat dispatcher, double-billing LLM calls
**File:** `tools/demo-studio-v3/main.py:2268-2313` and `main.py:1756-1781`
(`_vanilla_dispatch_chat` + `_vanilla_sse_generator`)

The wiring as currently shipped:

1. Client POSTs `/session/{id}/chat` → handler (line 1688+).
2. Chat handler `asyncio.create_task(_vanilla_dispatch_chat(...))` (line 1746).
3. `_vanilla_dispatch_chat` calls `run_turn(... sse_sink=_noop_sink)` (main.py:1774-1778) —
   a full LLM turn whose events are thrown away (`_noop_sink` is a no-op coroutine).
4. Client's EventSource (opened in studio.js before the POST per design) is handled by
   `session_stream` → `_vanilla_sse_generator` → line 2290 `await run_turn(...)` — a
   **second** full LLM turn, this one streamed to the browser.

Two live `run_turn` coroutines against the same `session_id` → **two `client.messages.stream(...)`
calls billed** per user message, **two passes of ConversationStore.append for the tool
blocks**, and a race over who writes the `[streamed]` assistant marker first (interleaving
seq numbers).

The code comments in `_vanilla_dispatch_chat` (main.py:1767-1772) suggest the intent was
that `_vanilla_dispatch_chat` "only triggers ConversationStore.append so the message is
persisted" — but the code actually calls `run_turn`, not `store.append`. The docstring
describes the desired behaviour; the implementation does not match.

**Remediation — pick one:**
- (a) Make `_vanilla_dispatch_chat` a pure "persist the user message" call:
  ```python
  ConversationStore(session_id=session_id).append(
      {"role": "user", "content": message, "user_message_id": user_message_id}
  )
  ```
  ...and let the SSE stream's `_run_vanilla` be the sole `run_turn` caller.
- (b) Inverse: let `_vanilla_dispatch_chat` own `run_turn` and write events into an
  asyncio Queue keyed by session_id; let `_vanilla_sse_generator` drain that queue
  instead of spawning its own `run_turn`. This avoids the "browser must open SSE
  before POST" ordering dependency.

Either way, one session_id → one concurrent `run_turn` invariant must be enforced
(e.g. a `_running_turns: set[str]` guard or an `asyncio.Lock` per session).

**Test-coverage gap:** zero integration test covers "POST /chat + open SSE stream
simultaneously"; all tests patch `run_turn` and assert it's called once in isolation.
An integration test with a fake `client.messages.stream` counting invocations per session
would have caught this.

### H3 — Orphaned background `_run_vanilla` task on client disconnect; no `request.is_disconnected()` check on vanilla SSE
**File:** `tools/demo-studio-v3/main.py:2273-2313`

`_vanilla_sse_generator` spawns `asyncio.create_task(_run_vanilla())` and then loops on
`await queue.get()`. Two leaks:

1. **No disconnect polling.** Compare to the managed `_poll_stream` (same file, lines
   2327, 2370) which checks `await request.is_disconnected()` each iteration. The vanilla
   generator has no such check — it will sit on `queue.get()` for as long as `run_turn`
   takes to complete (worst case: `max_turns=20` × Anthropic stream latency ≈ minutes of
   server-side work with zero consumer). Starlette eventually times out the response, but
   the generator's own frame doesn't unwind cleanly.

2. **`_run_vanilla` is not cancelled when the generator is closed.** `asyncio.create_task`
   returns a handle that is immediately discarded. When the response frame is GC'd or
   Starlette closes it (client disconnect, timeout, cancel), `_run_vanilla` keeps running
   to completion — full `run_turn` burn, LLM billing, Firestore writes — with no consumer.
   The task is orphaned.

**Remediation:** keep a reference to the task and register cleanup:
```python
task = asyncio.create_task(_run_vanilla())
try:
    while True:
        if await request.is_disconnected():
            task.cancel()
            break
        try:
            item = await asyncio.wait_for(queue.get(), timeout=1.0)
        except asyncio.TimeoutError:
            continue
        if item is None:
            break
        event, data = item
        yield f"event: {event}\ndata: {json.dumps(data, default=str)}\n\n"
finally:
    task.cancel()
    with contextlib.suppress(asyncio.CancelledError):
        await task
```

### H4 — `_vanilla_sse_generator` leaks `str(exc)` to the browser (and therefore to anyone who can open the SSE)
**File:** `tools/demo-studio-v3/main.py:2296-2297`

```python
except Exception as exc:  # noqa: BLE001
    await queue.put(("error", {"code": "stream_terminated", "message": str(exc)}))
```

If `_agent_proxy_mod.get_client()` raises (e.g. `KeyError: 'ANTHROPIC_API_KEY'` with
message containing the env var name — benign) or if `run_turn` lets an Anthropic
authentication error through (shouldn't, but defense in depth), `str(exc)` includes
the URL or the key fragment. Same class of bug as H1.

**Remediation:** replace `"message": str(exc)` with `"message": "stream_terminated"`
(or a short fixed string). Log `str(exc)` server-side only.

### H5 — `dispatch` can enter a 20-iteration tight loop when Anthropic returns `stop_reason=tool_use` with only `server_tool_use` blocks
**File:** `tools/demo-studio-v3/agent_proxy.py:272-437` (the `while turn_count < max_turns` loop)

`StreamTranslator.get_completed_tool_uses()` (stream_translator.py:132-137) filters on
`b.get("type") == "tool_use"` — it **excludes** `server_tool_use` (used by Anthropic-hosted
`web_search`, translator.py:158-179). If the model calls only `web_search` and no
client-dispatched tools in a given step, the API will still set `stop_reason = tool_use`
when the turn is waiting for the next call, but `tool_uses` will be `[]`. The loop then:

1. Enters the `elif stop_reason == "tool_use":` branch (line 363).
2. Iterates an empty `tool_uses` list (no dispatches, no appends).
3. Hits `continue` (line 417).
4. Re-runs the API with the **same** `messages` list (line 278).
5. Anthropic's response to the same input will look nearly identical → same shape → same
   loop iteration.
6. After 20 iterations, `MaxTurnsExceeded` fires and the user gets an `error` SSE.

Before hitting max_turns, this burns 20 full LLM calls with zero forward progress — ~$10
of wasted Anthropic spend per stuck turn if the model is sonnet-4 at 8096 max_tokens.

**Remediation:** when `stop_reason == "tool_use"` and the filtered `tool_uses` is empty,
treat this as a terminal condition — persist + return:
```python
if stop_reason == "tool_use" and not tool_uses:
    logger.warning(
        "run_turn: tool_use stop with no client-dispatched blocks (server-only); terminating turn"
    )
    await sse_sink("turn_end", {"stop_reason": "end_turn", "usage": {}})
    return
```
Or, more correctly: collect `server_tool_use` blocks too, and count *any* progress
(server or client) as forward. The zero-progress guard is the right bug fix regardless.

### H6 — `_default_trigger_build` nests `asyncio.run` inside an executor — will deadlock / misbehave under real load
**File:** `tools/demo-studio-v3/tool_dispatch.py:112-117`

```python
async def _default_trigger_build(session_id: str, **kwargs) -> Any:
    import factory_bridge
    return await asyncio.get_event_loop().run_in_executor(
        None, lambda: asyncio.run(factory_bridge.trigger_factory(session_id))
    )
```

Problems compound:

1. `factory_bridge.trigger_factory` **is already `async`**. Wrapping an async call in
   `asyncio.run` inside an executor thread is the classic anti-pattern: it spawns a new
   event loop on a worker thread, runs the coroutine there, and shreds any shared context
   (contextvars, loop-bound resources, sync primitives keyed to the main loop). If
   `trigger_factory` ever obtains an `httpx.AsyncClient` or acquires an `asyncio.Lock`
   on the main loop, it will silently misbehave or deadlock.
2. `asyncio.get_event_loop()` is deprecated in 3.10+ when called outside a running loop
   context; in an already-async function the idiomatic replacement is
   `asyncio.get_running_loop()`. But you don't need the loop at all — just `await` the
   coroutine:
   ```python
   async def _default_trigger_build(session_id: str, **kwargs) -> Any:
       import factory_bridge
       return await factory_bridge.trigger_factory(session_id)
   ```
3. `factory_bridge.trigger_factory` today is a pure-sync scaffold (factory_bridge.py:17-43)
   with no awaits — so the current manifestation is "mostly fine" because no event-loop
   bound state is touched. This finding is about the code as written, which will break
   the instant `trigger_factory` grows a real `httpx.AsyncClient` call (BD.F.2 per plan).

**Remediation:** delete the executor wrapper. Use `await factory_bridge.trigger_factory(...)`
directly. Add a unit test that `_default_trigger_build` runs on the same event loop as its
caller (patch `trigger_factory` to capture `asyncio.get_running_loop().__hash__()` and
assert equality with the test's loop).

---

## MEDIUM

### M1 — `handleSSE` in `studio.js` is dead code (added but never called)
**File:** `tools/demo-studio-v3/static/studio.js:547-567` (commit `75a1c7c`)

Grep confirms: the function is defined once and referenced nowhere. The actual tool_use /
tool_result handling in the same file uses `eventSource.addEventListener('tool_use', …)`
(line 1115) and `addEventListener('tool_result', …)` (line 1122) directly — the dispatcher
is unused. The commit message claims it "add(s) handleSSE function to studio.js" but the
wiring is missing.

**Remediation:** either (a) delete `handleSSE`, or (b) route the two `addEventListener`
bodies through `handleSSE(type, JSON.parse(e.data))` to consolidate status-indicator logic.
Pick one; shipping dead code that looks load-bearing misleads future readers.

### M2 — `ConversationStore.truncate_for_model` does not scrub orphan `tool_result` without matching `tool_use`
**File:** `tools/demo-studio-v3/conversation_store.py:178-204`

`_paired` drops assistant messages whose `tool_use` has no matching result, but it does
**not** drop tool-role messages whose `tool_result.tool_use_id` has no matching `tool_use`.
If truncation drops an early assistant turn that contained a tool_use, the later
`tool_result` block becomes an orphan and Anthropic will 400 on the subsequent call
("tool_result found but no corresponding tool_use").

This is academic today because C2 means `tool_use` blocks are never persisted in the
first place — but once C2 is fixed, M2 becomes load-bearing.

**Remediation:** collect tool_use ids in a second pass and drop tool-role messages whose
only block references a missing id. Or implement pair-aware truncation that drops
tool_use + tool_result as an atomic unit.

### M3 — `require_vanilla_chat_session` imports symbols it never uses
**File:** `tools/demo-studio-v3/main.py:108-109`

```python
from fastapi import Cookie as _Cookie
from starlette.requests import Request as _Request
```

Neither binding is referenced in the function body. Import churn on every request. Minor,
but suggests the function was refactored mid-flight and the cleanup pass was skipped.
Even if C1 is fixed by deletion, this points at a review-quality smell.

### M4 — `ConversationStore._store` is class-level shared state across instances
**File:** `tools/demo-studio-v3/conversation_store.py:44-48`

`_store: dict[str, list[dict]] = {}` and `_seq_counters: dict[str, int] = {}` are class
attributes, not instance attributes. Two concurrent test runs inside the same process,
or a future refactor that ever instantiates two stores with colliding session_ids,
will share state. Unit tests that rely on "fresh store" behaviour must remember to clear
the class-level dict; none of the existing tests do. Test contamination hazard.

Also: there is no mechanism to evict retired session state. Long-running Cloud Run
instances will accumulate per-session message lists indefinitely, proportional to total
sessions served by that instance.

**Remediation:** move `_store` to an instance attribute keyed by `self`, OR (since the
comment claims "Shared across instances with the same session_id within a process") make
it explicit by making the class a proper multi-session store (methods take session_id
as arg, no constructor needed) and add a `prune(session_id)` or LRU eviction. Either
shape beats the current half-shared-half-instance design.

### M5 — Orphan `templates/session.html` is not wired by any route
**File:** `tools/demo-studio-v3/templates/session.html` (new, commit `2938c6a`)

The template was added to satisfy `test_preview_wiring.py`'s Bug-5 regression pins (they
grep for the file's existence + the `window.__s5Base` substring). **No FastAPI route
invokes Jinja2 against it.** The actual session page is rendered inline in `main.py`
(lines 1644-1680) using `json.dumps` for safe interpolation.

Two risks:

1. The test passes via textual grep but does not exercise real server behaviour — a
   classic vacuous-pass pattern (test-quality signal).
2. If anyone ever wires this template via `TemplateResponse("session.html", {"session_id":
   session_id, ...})` expecting safe rendering, the Jinja default autoescape will
   HTML-escape inside `data-session-id="{{ session_id }}"` fine, but the `<script>` block
   on line 18-22 uses `{{ session_id_json }}` / `{{ csrf_token_json }}` / `{{ s5_base_json }}`
   placeholders that require the caller to pass **pre-`json.dumps`'d** values. A caller
   who passes raw strings will produce `window.__sessionId = my-sid-with-"-injection;` →
   script-context XSS. The template is a footgun for future maintainers.

**Remediation:** either delete the file (the inline main.py rendering is the production
path) and relax the test to grep main.py directly, OR wire the template as the real
renderer and replace the `_json` placeholders with `{{ session_id|tojson }}` so the
template is self-safe. Shipping a standalone-looking template that isn't actually the
code path is the worst of both worlds.

### M6 — `StreamTranslator.handle_stream_error` emits `str(error)` to the browser
**File:** `tools/demo-studio-v3/stream_translator.py:120-126`

```python
async def handle_stream_error(self, *, error: Exception) -> None:
    logger.error("StreamTranslator: stream error %r", error)
    await self._sink("error", {
        "code": "stream_terminated",
        "message": str(error),
    })
```

Same family as H1 / H4. Today not reached from any code path (`run_turn` handles its own
exceptions and calls `_sink("error", …)` with sanitised messages), but the method is
public and tempting. Replace `str(error)` with a fixed short label.

### M7 — `_default_patch_config` doesn't close the thread-pool executor's `requests.patch` on cancellation
**File:** `tools/demo-studio-v3/tool_dispatch.py:89-109`

`loop.run_in_executor(None, _do_patch)` dispatches to the default thread pool. If the
caller's coroutine is cancelled (e.g. client disconnect via H3), the awaiter unwinds
but the thread keeps running `requests.patch` to completion. `requests` has no timeout
on the patch call (no `timeout=` kwarg on line 100-104), so a slow/hung backend ties up
a thread indefinitely. Under sustained load, the default executor (size ~= min(32,
cpu_count+4)) saturates and every `set_config` dispatch queues.

**Remediation:** set `timeout=(5, 30)` (connect, read) on `requests.patch`. Apply the
same fix to `fetch_schema` and `fetch_config` in `config_mgmt_client.py:74,86` — they
have the same missing-timeout issue but predate this PR.

---

## LOW

### L1 — `datetime.datetime.utcnow()` deprecated in Python 3.12+
**File:** `conversation_store.py:95`, `main.py:2720`

Use `datetime.datetime.now(datetime.UTC)` — `utcnow()` emits a DeprecationWarning in 3.12
and is scheduled for removal. Non-blocking.

### L2 — Anthropic 429 retry loses accumulated translator state
**File:** `agent_proxy.py:320-346`

On 429, `run_turn` retries the SAME stream call but reuses the SAME `translator` instance
(line 280 — constructed once per iteration). The translator has already processed the
first attempt's `content_block_*` events into `_pending_blocks`. The retry will re-process
events on top of that state → indices collide, `_pending_blocks[index]` overwrites mid-stream.

If the first attempt got as far as `tool_use` input partially streamed, the retry's
`input_json_delta` will append to the stale buffer.

**Remediation:** call `translator.reset_for_next_message()` (stream_translator.py:139-142)
before the retry. Or construct a fresh translator for the retry.

### L3 — `logger` vs `logging` inconsistency in `StreamTranslator`
**File:** `stream_translator.py:75`

One `logging.warning(...)` call mixed in with `logger.warning(...)` / `logger.error(...)`
everywhere else. Uses the root logger instead of the module logger. Cosmetic, one-line fix.

### L4 — `run_turn` doesn't persist message text; `user_message_id` from `_vanilla_dispatch_chat` is not threaded
**File:** `agent_proxy.py:253` + `main.py:1774`

`_vanilla_dispatch_chat` passes `user_message` but not `user_message_id`. `run_turn`
calls `store.append({"role": "user", "content": user_message})` — no `user_message_id`
field. The chat handler's ack returns `user_message_id` in the JSON response, but there
is no way for the client to correlate a subsequent SSE event with that ID.

This also means the `clientMessageId` idempotency guard (conversation_store.py:88-92) is
never exercised by the real chat flow.

### L5 — `ConversationStore.load(session_id)` takes a parameter instead of using `self.session_id`
**File:** `conversation_store.py:111-115`

API smell — the instance is bound to a session_id at construction time, but `load` takes
an override. Callers can (and do — see main.py:2284) pass `self.session_id` back in, which
is redundant. Worse: a caller passing a *different* session_id gets that other session's
messages, defeating the "bound instance" pretext.

**Remediation:** `load()` should use `self.session_id`. Same for `load_since`.

---

## NITS

- **`agent_proxy.py:226`** — `from stream_translator import StreamTranslator` is inside
  `run_turn`, paying import cost per call. Hoist to module level.
- **`agent_proxy.py:244-249`** — `async def tool_dispatcher` re-assigns a parameter name
  as a nested function; mypy strict mode will complain (`# type: ignore[misc]` present
  on the fallback, not the primary path). Cosmetic.
- **`conversation_store.py:160-176`** — the `while ... for ... pop(i); break` pattern is
  O(n²) in worst case and makes the intent opaque. A single linear pass that rebuilds the
  list excluding dropped indices would be clearer and faster.
- **`tool_dispatch.py:78,86,93`** — `asyncio.get_event_loop()` (deprecated) instead of
  `asyncio.get_running_loop()` in already-async functions.
- **`main.py:1746`** — the fire-and-forget `asyncio.create_task(_vanilla_dispatch_chat(...))`
  is also orphaned. If the task raises after the chat handler returns, Python will log
  "Task exception was never retrieved" at interpreter shutdown, not at failure time. Wrap
  in a helper that logs on done.
- **`main.py:2282`** — `_store = _CS(session_id=session_id)` — the underscore prefix
  suggests "private" but this is a local variable in a nested function. Misleading.
- Commit `634a7a7` reverts change from commit `ccc2402` in the same PR — both stay in
  history. A squash or interactive rebase at PR-prep time would be cleaner, but Rule 11
  forbids rebase in this codebase; accept.

---

## Positive observations (not findings — just noting what's right)

- **Rule 12 compliance**: every impl commit is preceded on this branch by a corresponding
  xfail-skeleton commit (e.g. `f9a17aa` W1 xfails → `775a05a` W1 impl;
  `4202dac` W2 xfails → `27f9d71` W2 impl; etc.). The TDD chain is clean.
- **SYSTEM_PROMPT single-sourcing (T.A.4)**: lifted cleanly from `setup_agent.py`;
  `setup_agent.py`'s copy is marked for Wave 6 deletion, not duplicated as a drift risk.
- **Tool schemas**: defined in `tool_dispatch.py:23-68` with `web_search` correctly shaped
  as the Anthropic-hosted type (no `input_schema` block). HANDLERS registry correctly
  excludes `web_search` (no client-side dispatch).
- **`StreamTranslator.emit_tool_result` error promotion** (stream_translator.py:97-106):
  correctly hoists `is_error` / `error_code` / `code` to the SSE top level, so browser
  + tests can assert without digging into `output_summary`.
- **Cookie name canonicalisation**: new code uses `COOKIE_NAME` constant from `auth.py`
  (e.g. main.py:112) instead of the hardcoded `"session"` string — avoids the S33 C1
  cookie-name bug from PR #61.
- **`max_tokens=8096` + `stream_idle_timeout_seconds` per-read** — both bounded; no
  unbounded await anywhere in the happy path.
- **Tool result size guard**: the 900 KB Firestore cap at agent_proxy.py:383-392 is a
  correct pre-commit truncation, preventing 1 MB Firestore write failures.
- **Wave 6 xfails are honest**: `test_chat_returns_json_ack_no_streaming` and
  `test_chat_body_has_no_sse_framing_or_agent_reply` in `test_sse_server_l1.py` are
  strict-xfailed with clear "Wave 6 deletion" reasons — not stale.
- **Aphelios-precursor xfails** in `test_tool_dispatch.py:260+` dynamically `pytest.xfail`
  when the fixture file is absent — correct handling of a not-yet-landed dependency;
  not stale.

---

## Blocker list (NO-GO)

1. **C1** — auth bypass on `POST /session/{id}/chat` (cross-session injection +
   presence-only `session_token`).
2. **C2** — multi-turn conversations are structurally broken (assistant replies stored
   as `"[streamed]"`, tool_use blocks never persisted); Anthropic will 400 on turn 2 of
   any tool-using session.

H1 (URL leak), H2 (double-LLM-billing), H3 (orphan task), H5 (20-iter burn) and H6
(nested `asyncio.run`) are **strongly recommended** before merge but are not
independently blocking if Duong accepts the risk and files explicit follow-ups. I would
still vote NO on the merge PR with only C1+C2 unfixed.

---

## Recommended test additions before re-review

Each of the following would have caught a finding above:

- `test_require_vanilla_chat_session_binds_cookie_to_path` — POST with ds_session for
  session A, path session B → expect 401.
- `test_require_vanilla_chat_session_rejects_presence_only_session_token` — POST with
  `session_token=x` (no ds_session), arbitrary path → expect 401.
- `test_run_turn_second_turn_preserves_tool_use_history` — drive 2 turns; assert
  messages list sent to Anthropic on turn 2 contains the first turn's assistant tool_use
  blocks (or, if (a)-remediation is chosen, the real streamed text).
- `test_tool_dispatch_error_content_does_not_leak_url` — patch `_default_patch_config` to
  raise `ConnectionError("... url: https://secret.run.app/...")`, dispatch, assert
  `"secret.run.app"` absent from returned `content`.
- `test_chat_vanilla_single_run_turn_per_message` — POST + open SSE, patch
  `client.messages.stream` to count invocations, expect exactly 1 call per session_id.
- `test_vanilla_sse_cancels_run_turn_on_disconnect` — open stream, close client,
  assert the detached `_run_vanilla` task is cancelled within a bounded timeout.
- `test_run_turn_terminates_on_server_only_tool_use` — return `stop_reason=tool_use`
  with only a `server_tool_use` block; assert single-call termination rather than
  20-iteration loop.

---

— Senna

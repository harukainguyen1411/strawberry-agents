---
date: 2026-04-22
concern: work
status: proposed
author: sona
---

# Chat SSE deadlock — root cause and fix plan

## The bug (end-user symptom)

- User opens a session page on `http://localhost:8080/session/<id>`.
- User types a message and clicks **Send**.
- `POST /chat` returns 200.
- `GET /stream` is open with status 200.
- UI is stuck on **"Sending…"** forever. No agent bubbles ever render. No `text_delta` / `tool_use` / `turn_end` events arrive at the browser.
- If user hard-refreshes the page, chat history may replay (because `/history` endpoint hydrates past events via Firestore), but the live turn never finishes.

## The actual root cause

The vanilla-path handshake between `POST /chat` and `GET /stream` in `main.py` is inverted. `_run_vanilla` (the function that actually calls `anthropic.messages.create`) is only spawned from inside `GET /stream` — and only when a new stream connection opens AND `_vanilla_pending[session_id]` already has a message waiting at that moment.

Actual flow on a fresh session:

1. Page load → `studio.js` calls `connectStream()` → browser opens `GET /stream` #1.
2. Server enters `_vanilla_sse_generator` (main.py:2319). Creates / reuses `_vanilla_sse_queues[session_id] = Queue()`. Checks `_vanilla_pending[session_id]` — **empty** (no chat sent yet). Skips `asyncio.create_task(_run_vanilla(...))`. Falls through to `while True: await sse_queue.get()`.
3. User sends → `POST /chat` → `_vanilla_dispatch_chat` (main.py:1819) simply does:
   ```python
   _vanilla_pending[session_id].put(message)
   ```
   It **does NOT spawn `_run_vanilla`**.
4. The already-open `/stream` #1 from step 2 is still blocked in `await sse_queue.get()`. Nothing ever puts anything into that queue for this session — because the only thing that would (`_run_vanilla`) is never launched.
5. Result: chat hangs forever on the first send. Only way to get any output is to close the stream and reopen it (page reload, reconnect) — which, on the new connection, sees `_vanilla_pending` non-empty and finally spawns `_run_vanilla`.

## Anchors

- `main.py:103` — `_vanilla_pending: dict[str, asyncio.Queue] = {}`
- `main.py:1810` — `/chat` fires `asyncio.create_task(_vanilla_dispatch_chat(...))`
- `main.py:1819-1836` — `_vanilla_dispatch_chat`: enqueues message and returns. No task spawn.
- `main.py:2319-2373` — `_vanilla_sse_generator`: creates per-session queue, checks pending, only spawns `_run_vanilla` **if** pending non-empty at generator entry.
- `main.py:2367-2372` — the exact check that skips spawning run_vanilla on the initial fresh stream connection.
- `static/studio.js:1261` — page load calls `connectStream()` before the user ever sends.

## Evidence

Server log for one session:
```
session_vanilla_path session_id=9ce3baae...
vanilla_dispatch_chat: message queued session_id=9ce3baae...
GET /session/9ce3baae.../stream HTTP/1.1 200 OK (duration_ms=389.2)
GET /session/9ce3baae.../stream HTTP/1.1 200 OK (duration_ms=391.9)
```

`/stream` returns in ~389ms and exits cleanly — the generator found no pending message at entry, blocked briefly, was interrupted by the browser reconnecting on SSE retry, and no events were ever emitted. Zero Anthropic API calls followed the queue.

## Why earlier "fixes" missed it

- **StreamTranslator fix (`2eac576`)** — handled synthesized SDK events. Real fix, but for a condition that never triggered because `_run_vanilla` never ran in the first place.
- **studio.js event-name rename (`7b8a96e`)** — corrected `text` → `text_delta` and `done` → `turn_end` on the consumer side. Necessary but not sufficient — the consumer was listening for events that the producer never emitted.
- **Viktor's per-session queue xfail (`c94311f`)** — correctly anticipated the reconnect-loses-events class, but the implementation was killed before landing and would not have addressed the real bug (which is not about queue scope; it's about who spawns `_run_vanilla` and when).

## Fix shape

Spawn `_run_vanilla` from `_vanilla_dispatch_chat` (the `/chat` path), not from `_vanilla_sse_generator` (the `/stream` path). Reverse the coupling:

- **`/chat`** owns lifecycle of the turn. When a new user message arrives:
  - Ensure `_vanilla_sse_queues[session_id]` exists.
  - `asyncio.create_task(_run_vanilla(session_id, message))` — exactly one per user message.
  - `_run_vanilla` writes `text_delta`, `tool_use`, `tool_result`, `turn_end`, `error`, `cancelled` events into `_vanilla_sse_queues[session_id]` via its sink, terminates with sentinel `None`.
- **`/stream`** is pure consumer. On connect:
  - Ensure `_vanilla_sse_queues[session_id]` exists.
  - Loop: `item = await queue.get(); if None: break; yield frame`.
  - Never spawns anything.
  - On `turn_end` or sentinel, the generator exits and cleanup pops both dicts (same as today).
- `_vanilla_pending` can be retired entirely — the dispatch path spawns the task directly; there is no "message waiting for a stream to pick it up" anymore.

## Invariants that must hold after the fix

1. Exactly one `_run_vanilla` task per successful `POST /chat` (H2 invariant).
2. A reconnecting `/stream` during a mid-turn **does not** re-invoke the LLM — it just reattaches to the existing per-session queue. If the turn already finished and cleaned up, the reconnect gets an empty queue and closes quickly (acceptable — `/history` covers replay).
3. `text_delta | tool_use | tool_result | turn_end | error | cancelled` are the only event types that escape to the browser (Wave 4 §T.C.2a invariant, already enforced by `_VANILLA_APPROVED` set).
4. Two rapid `POST /chat` calls on the same session are serialized — the second waits until the first task completes, otherwise events from the two turns would interleave in the same queue. Simplest: a per-session `asyncio.Lock`, acquired inside `_run_vanilla`, or reject with 409 when a turn is already in flight.
5. Session-scoped queues are cleaned up on `turn_end` / `error` / sentinel to avoid dict growth.

## Test plan (xfail-first per Rule 12)

- **xfail test 1 — fresh send delivers events.** Simulate `POST /chat` with message "hi", then open `GET /stream`, assert at least one `text_delta` event arrives within 10s before `turn_end`.
- **xfail test 2 — mid-turn reconnect.** Start a turn, close the stream after one `text_delta`, reopen, assert remaining events + `turn_end` still arrive on the new connection. (This is the original scope Viktor had; keep it.)
- **xfail test 3 — exactly-once run_turn.** Mock `agent_proxy.run_turn`; send one chat; open stream twice mid-turn; assert `run_turn` called exactly once.
- **xfail test 4 — concurrent sends serialized.** Send two `/chat` back-to-back; assert second either 409s or queues, never interleaves events in the stream.

All tests live at `tools/demo-studio-v3/tests/test_chat_sse_handshake.py`.

## Implementation steps (in order)

1. **xfails** — author the four tests above, committed with `test(demo-studio-v3): xfail chat SSE handshake invariants (fresh send, reconnect, exactly-once, serialized)`.
2. **Refactor `_vanilla_dispatch_chat`** (main.py:1819) — spawn the run_vanilla task directly; stop using `_vanilla_pending`. Ensure `_vanilla_sse_queues[session_id]` exists before spawning so the task's sink has somewhere to write.
3. **Refactor `_vanilla_sse_generator`** (main.py:2319) — remove the `_vanilla_pending` check and the conditional `create_task(_run_vanilla)` branch. It becomes pure consumer.
4. **Retire `_vanilla_pending`** — remove the dict, the imports if any, and the cleanup pop.
5. **Add serialization guard** — per-session `asyncio.Lock` (stored in a third dict keyed on session_id) held inside `_run_vanilla`; or early 409 in `/chat` when a lock is held. Pick whichever keeps tests green.
6. **Verify locally** — on `http://localhost:8080`, fresh session, single send, chat renders progressively. No page reload needed.
7. **Keep prior xfails green** — `test_stream_translator_text_event.py`, `test_f_new_03_build_trigger_loop.py`, and Viktor's reconnect xfail (`c94311f`) must still pass.

## Out of scope (explicit)

- Managed-agent path removal (`/chat` fallback branch, `/api/managed-sessions`, `setup_agent.py`, `managed_session_client.py`, REQUIRED_ENV_VARS entries). That is the Wave 6 sweep Heimerdinger already punch-listed in `assessments/work/2026-04-22-managed-agent-deploy-cleanup.md`. Separate plan.
- Firebase auth (separate parked plan, human-blocked on IAM).
- UI polish punch list (Lulu's `assessments/work/2026-04-22-chat-ui-polish-punchlist.md`).

## Not obvious

- The UI appears to "sort of work" because `/history` hydrates past events from Firestore on every page load. That's why prior QA runs sometimes showed chat output — they were seeing the hydrated replay, not live events. Fresh sessions with no history look dead.
- `studio.js` recovery behavior (auto-retry on SSE close) happens to paper over the bug on subsequent turns because the retried `/stream` connection sees `_vanilla_pending` non-empty and finally spawns `_run_vanilla`. That's why chat "sometimes works the second time". But the first turn on a fresh session always hangs.
- The reason the stream duration is ~390ms (not forever, not instant) is the browser's EventSource default reconnect policy: open → no events for a brief window → implicit close/retry → open again. The server is just waiting on an empty queue the whole time.

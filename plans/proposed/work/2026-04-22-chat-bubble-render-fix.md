---
date: 2026-04-22
concern: work
status: proposed
author: sona
---

# Chat bubble render — frontend field mismatch & chunk accumulation

## The end-user symptom

After the SSE-deadlock backend fix landed (`2026-04-22-chat-sse-deadlock-fix.md`), the
server now successfully:

- Accepts `POST /chat`, spawns `_run_vanilla_turn`,
- Calls `anthropic.messages.create` (confirmed in local log: `HTTP/1.1 200 OK`),
- Streams `text_delta` / `tool_use` / `tool_result` events into the per-session queue,
- `GET /stream` drains them over the wire (verified via raw curl — 2195 bytes of valid
  SSE frames including `text_delta {"text": "I"}`, `tool_use {"name": "get_schema"}`,
  `tool_result {...}`).

**But the browser chat panel shows no agent bubbles.** The user message appears once,
the banner says "Responding..." indefinitely, and nothing else renders. Fresh Playwright
reproduction with `session/b07b52983d554a4cbdbeb8cfa3c2cca6` confirms this.

## Root cause

Two linked bugs in `static/studio.js`:

### Bug 1 — field-name mismatch in `_renderTextEvent`

`stream_translator.py:238` emits:

```python
await self._sink("text_delta", {"text": text})
```

…so the SSE `data` payload is `{"text": "I'll get started"}`.

But `studio.js:730` reads the wrong field:

```js
function _renderTextEvent(data) {
  var mid = data.message_id || '';
  var content = stripToolXml(data.content || '');   // ← data.content is undefined
  if (!content) return;                              // ← always bails
  ...
}
```

Result: every single `text_delta` event is silently dropped by the renderer. Zero
bubbles are appended to `#chatMessages`.

### Bug 2 — no accumulation across deltas

Each `text_delta` carries only the latest fragment (e.g. `"I"`, `"'ll get"`,
`" started"`). The renderer is designed for whole-message events with a stable
`data.message_id`; because vanilla deltas carry no `message_id`, even after Bug 1
is fixed each delta would create its own new `<div class="msg msg-bot">`, producing
a stream of tiny single-word bubbles instead of one growing bubble.

The correct behaviour: the **first** `text_delta` in a contiguous assistant-text
segment opens one bubble; subsequent deltas append into it; a `tool_use` event (or
`turn_end`) terminates that segment so the next text block after a tool_result
opens a fresh bubble.

## Anchors

- `tools/demo-studio-v3/stream_translator.py:238` — `await self._sink("text_delta", {"text": text})`
- `tools/demo-studio-v3/static/studio.js:728-763` — `_renderTextEvent(data)` reads `data.content`
- `tools/demo-studio-v3/static/studio.js:1116-1123` — `text_delta` event listener calls `_renderTextEvent`
- `tools/demo-studio-v3/static/studio.js:1125-1130` — `tool_use` listener (currently only sets status)
- `tools/demo-studio-v3/static/studio.js:1140-1151` — `turn_end` listener

## Evidence

Raw SSE captured via `curl -N /stream` at 2026-04-22T04:27Z, session `8ec3c38c…`:

```
event: text_delta
data: {"text": "I"}

event: text_delta
data: {"text": "'ll get started right away! Let me research Aviva's brand"}

event: text_delta
data: {"text": " and fetch the config schema simultaneously."}

event: tool_use
data: {"id": "toolu_01KSj…", "name": "get_schema", "input": {}}

event: tool_result
data: {"name": "get_schema", "tool_use_id": "toolu_01KSj…", "output_summary": {...}, "is_error": false}

event: text_delta
data: {"text": "Excellent! I"}
…
```

Browser DOM after `/chat` + 10s wait:

```html
<!-- #chatMessages -->
<div class="msg msg-user">Hi, let's configure a demo for Aviva in the UK for motor insurance.</div>
<!-- No msg-bot nodes — Bug 1 drops every text_delta -->
```

`#agentBannerText` is stuck on `"Responding..."` because only `turn_end` clears it and
the user never perceives progress meanwhile.

## Fix shape

Narrow patch to `static/studio.js` only. No backend changes.

### Patch 1 — accept both field names in `_renderTextEvent`

```js
function _renderTextEvent(data) {
  var content = stripToolXml(data.text || data.content || '');
  if (!content) return;
  …
}
```

### Patch 2 — accumulate contiguous text_delta chunks into one bubble

Introduce `currentAssistantNode` + `currentAssistantText` module state. Rules:

- **On text_delta**:
  - If `currentAssistantNode` is null → create new `<div class="msg msg-bot">`, append, set `currentAssistantNode` and `currentAssistantText = ""`.
  - Append the delta text to `currentAssistantText`.
  - Render `renderMarkdown(currentAssistantText)` into `currentAssistantNode`.
  - `scrollToBottom()`.
- **On tool_use**: `currentAssistantNode = null` (any following text_delta starts a
  fresh bubble below the tool group).
- **On turn_end / cancelled / error**: `currentAssistantNode = null`.

Keep the existing `renderedMessages` map + `message_id` path untouched so the
history-replay rendering (which does carry a stable message_id from Firestore)
continues to deduplicate on reload.

### Patch 3 — phase-advance heuristic robust to incremental text

The existing regex-based phase hints (`ready to deploy` → show Deploy button) check
the per-delta content. After accumulation, we check `currentAssistantText` once at
each delta, which is more reliable.

## Test plan (xfail-first per Rule 12)

Two JS-renderer unit tests at
`tools/demo-studio-v3/tests/test_chat_text_delta_rendering.py` — they import the JS
via a minimal DOM stub (jsdom-style, or since we're Python, we actually test the
accumulation contract by invoking `_renderTextEvent` through a headless harness).

**Simpler alternative**: add the tests as pytest-playwright or as an httpx+BeautifulSoup
integration test that:

- Boots a FastAPI test client with `agent_proxy.run_turn` patched to emit a
  scripted sequence of `text_delta` / `tool_use` / `turn_end` events through the
  sink.
- Opens a Playwright-controlled browser against the live ASGI app.
- Sends one `/chat`, then waits for `.msg-bot` to appear with expected text content.

For this plan (overnight ship), the pragmatic choice:

**xfail T1 — text_delta field compatibility.** Author a pytest that loads
`static/studio.js` into a `py-mini-racer` or `node -e` subprocess, feeds a synthetic
`data = {text: "hello"}` object to `_renderTextEvent`, and asserts the resulting
DOM has `.innerText.includes("hello")`. Currently fails because `data.content` is
read, not `data.text`.

**xfail T2 — chunks accumulate into one bubble.** Feed three text_delta deltas
(`"a"`, `"b"`, `"c"`) and assert `#chatMessages` contains exactly one `.msg-bot`
with `innerText === "abc"`. Currently fails (either zero bubbles because of Bug 1,
or three bubbles after Bug 1 patch without Bug 2 patch).

**xfail T3 — tool_use separates bubbles.** Feed `[text "a", tool_use, text "b"]`
and assert two `.msg-bot` bubbles with texts "a" and "b" respectively.

If py-mini-racer isn't installed, fall back to a plain `node` subprocess that
requires a minimal jsdom; we already have node in the toolchain for the MCP
server work. Time-box this at 15 min; if it blows up, skip unit tests and rely
on the Playwright live-DOM assertion below.

**Live smoke test (mandatory, always)**:

After fix commits, open the session page in Playwright MCP, send one message,
poll `#chatMessages .msg-bot` — must appear within 15s, text must contain the
first `text_delta` fragment the backend emitted, and the bubble must keep
growing as more deltas arrive.

## Implementation steps

1. **xfails** — `tests/test_chat_text_delta_rendering.py` covering T1/T2/T3. If
   node/JS harness isn't feasible, convert to Playwright-live DOM assertions run
   via the existing `tests/integration/` directory.
2. **studio.js patch** — apply Patches 1, 2, 3 above. Single commit.
3. **Local verify** — kill-restart not needed (studio.js is static; hard-refresh
   the browser tab). Playwright:
   - Open a fresh session via `POST /session` + `/auth/session/<id>?token=…`.
   - Send "Configure a demo for Aviva UK motor insurance".
   - Wait for ≥1 `.msg-bot` node within 15s.
   - Assert bubble text contains agent response (not just "Responding...").
   - Take screenshot; save to `assessments/qa-reports/2026-04-22-chat-bubble-render-live.png`.
4. **Regression tests** — `pytest tools/demo-studio-v3/tests/` — all green.
5. **Commit** — `fix(demo-studio-v3): studio.js text_delta field + chunk accumulation`.

## Invariants after the fix

1. A `text_delta {"text": T}` event appends `T` to the current bubble (or opens
   a new bubble if none is open).
2. A `tool_use` event closes the current bubble so the next `text_delta` opens
   a new one.
3. A `turn_end` / `cancelled` / `error` event closes the current bubble and
   resets `currentAssistantNode` to null.
4. History replay via `/history` (carrying stable `message_id`) continues to
   dedupe via `renderedMessages` exactly as before — the accumulation path only
   runs for live deltas (which carry no `message_id`).

## Out of scope

- Persisting the streamed assistant message to Firestore via `ConversationStore`
  — already handled by `run_turn` on `end_turn` stop (see `agent_proxy.run_turn`).
- Tool-group UI (the existing `currentToolGroup` / `currentToolGroupItems` path).
- Error-event formatting polish — Lulu's UI punch list covers that.
- Backend SSE changes (field rename, adding `message_id` per delta) — would force
  a translator test churn we don't need for this ship.

## Not obvious

- The code comment at `studio.js:1237` says "// Reset tool group after each agent
  message (mirrors SSE 'text' handler)" — stale reference to the legacy managed
  `text` event type. Preserve the comment but update to say `text_delta` for
  future readers.
- `data.content` was probably correct for the legacy managed-agent path that
  sent whole messages (content + metadata). The vanilla translator sends chunks
  and chose `text` to match the Anthropic SDK delta shape. The rename got lost
  between Soraka's event-name rename (`text` → `text_delta`) and this data-shape
  work.

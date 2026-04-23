---
slug: 2026-04-22-local-chat-retry-with-stream-fix
surface: chat-configure-flow
date: 2026-04-22
session: bbf5a34a9be64c3bb2f762414db59767
server: http://localhost:8080
fix-commit: 2eac576
verdict: PARTIAL
---

# QA Report — Local Chat Retry with StreamTranslator Fix

## Scope

Re-run of local chat QA after commit 2eac576 (StreamTranslator fix: silently pass `text`/`InputJson`/`Thinking`/`Citation`/`Signature` events that are redundant accumulation snapshots).

Test prompt: "I want to configure a demo for Allianz, motor insurance, Germany"

## Results Table

| Check | Result | Evidence |
|---|---|---|
| StreamTranslator fix — user message renders | PASS | Screenshot qa-03-after-send.png: dark bubble visible immediately after Send |
| StreamTranslator fix — agent messages render | BLOCKED | See below |
| GATHER phase initiated | PASS | Log: `chat_accepted`, `vanilla_dispatch_chat: message queued`, `POST /v1/messages 200 OK` at 03:09:51 |
| GATHER → GENERATE → REVIEW flow | NOT REACHED | Blocked at GATHER |
| F-NEW-03 turn-boundary discipline | NOT TESTED | Agent never completed its turn |
| trigger_factory only after explicit approval | NOT TESTED | Not reached |

## Partial Pass: StreamTranslator fix confirmed correct in code

The old code (pre-2eac576) logged `StreamTranslator: unknown event type 'text' — dropping` for every text chunk, blocking the chat. The new code silently ignores those events (pass), and the fix is verified correct in `stream_translator.py` lines 78-84.

The user message rendered immediately (screenshot qa-03-after-send.png) — this confirms the send path works. The fix is code-correct.

## Blocker: SSE reconnect race condition loses the agent turn

After the Anthropic API responded (03:09:51, 6-second latency), the agent turn completed but zero events reached the browser. Root cause identified from log analysis:

1. The first `/stream` SSE connection (established at 03:09:01) consumed the user message from `_vanilla_pending[session_id]` and launched `_run_vanilla` as an asyncio task.
2. The browser (Playwright) re-connected to `/stream` at 03:09:51 — a new `_vanilla_sse_generator` instance was created with a new local `sse_queue`.
3. The `_run_vanilla` task was writing events into the **old** `sse_queue` from the original connection, which was no longer being consumed.
4. Result: agent turn completed but all events were discarded. Browser stuck in "Sending..." indefinitely. History API shows 0 events. `/stream` endpoint returns no data.

This is a pre-existing architecture issue distinct from the StreamTranslator bug — the sse_queue is local to each HTTP connection, so any SSE reconnect during a long agent turn loses the turn output.

## Screenshots

- `qa-01-session-initial.png` — CONFIGURE stage, session loaded, empty chat
- `qa-02-message-typed.png` — User message typed in input
- `qa-03-after-send.png` — PASS: User message bubble visible, "Sending..." indicator
- `qa-04-gathering.png` through `qa-11-final-stuck-state.png` — "Sending..." stuck, no agent reply

## Verdict: PARTIAL

StreamTranslator fix is code-correct and the user message renders (partial pass for the fix). The full GATHER → GENERATE → REVIEW → F-NEW-03 flow could not be validated because the SSE reconnect race condition prevented the agent response from reaching the browser. This is a separate bug that needs a fix (persistent sse_queue keyed on session_id rather than connection-local) before the full flow can be QA'd.

**F-NEW-03: NOT TESTED** (agent never completed turn)
**StreamTranslator fix: PASS on code review, BLOCKED on E2E due to unrelated SSE reconnect bug**

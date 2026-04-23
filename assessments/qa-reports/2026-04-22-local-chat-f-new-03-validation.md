# QA Report — Local Chat F-NEW-03 Validation

**Date:** 2026-04-22
**Target:** localhost:8080 (demo-studio-v3 uvicorn, local)
**Session tested:** bbf5a34a9be64c3bb2f762414db59767 (fresh, Allianz / motor/DE)
**QA agent:** Akali (sonnet)
**Verdict:** FAIL (blocked by pre-existing regression — F-NEW-03 not reachable)

---

## Summary

The GATHER→GENERATE→REVIEW chat flow could not be executed end-to-end. After the user message was sent, the Anthropic API call completed successfully, but the agent's text response was silently discarded by `StreamTranslator` due to an SDK event type mismatch. The session entered a zombie "Sending..." state with no agent reply, no tool calls, and no events registered. F-NEW-03 behavior (whether `trigger_factory` fires in the same turn as the review question) could not be observed.

---

## Test Steps and Results

| Step | Expected | Actual | Pass/Fail |
|------|----------|--------|-----------|
| Navigate to `/dashboard` | Dashboard loads with session list | Dashboard loaded; session list visible; nonce URLs present | PASS |
| Auth via nonce URL | Land in authenticated session | Authenticated via session `4f6819d3` nonce; then navigated to new session | PASS |
| Create fresh session via `/session/new` | 201 with new sessionId | 201 returned; session `bbf5a34a` created | PASS |
| Send "I want to configure a demo for Allianz, motor insurance, Germany" | Agent enters GATHER state, asks clarifying questions | Message accepted (`chat_accepted`, `vanilla_dispatch_chat: message queued`); Anthropic API returned 200 OK | PASS (send OK) |
| Agent GATHER response visible in chat | Clarifying question rendered in chat | **Zero messages in chat; UI stuck on "Sending..."** for 12+ min | FAIL |
| GENERATE phase (tool calls visible) | Tool calls streamed to UI | No tool calls; no events; `/events` and `/messages` arrays empty | FAIL (not reached) |
| REVIEW state (agent stops, waits for approval) | Review summary rendered; input re-enabled | Not reached | FAIL (not reached) |
| Send "yes, build it" | `trigger_factory` fires in next turn | Not reached | FAIL (not reached) |
| F-NEW-03: no `trigger_factory` in review turn | Tool call absent in same turn as review question | Not verifiable | INCONCLUSIVE |

---

## Root Cause: StreamTranslator SDK Incompatibility

**Log evidence** (from `/private/tmp/demo-studio-v3-8080.log`):

```
chat_accepted session_id=bbf5a34a9be64c3bb2f762414db59767 message_len=64
vanilla_dispatch_chat: message queued session_id=bbf5a34a9be64c3bb2f762414db59767
HTTP Request: POST https://api.anthropic.com/v1/messages "HTTP/1.1 200 OK"
StreamTranslator: unknown event type 'text' — dropping   [x6]
```

**Root cause:** `agent_proxy.py` iterates `client.messages.stream()` which, with Anthropic SDK v0.94.1, yields high-level `ParsedMessageStreamEvent` objects — including `TextEvent` (`.type == "text"`) — in addition to raw protocol events. `StreamTranslator.process_event()` only handles raw events (`content_block_start`, `content_block_delta`, `content_block_stop`, `message_stop`). The `TextEvent` type falls through to the `else` branch at `stream_translator.py:79` and is dropped. Since the GATHER-phase agent response is pure text (a clarifying question), all response content is dropped and never persisted.

**This bug is pre-existing** — it was not introduced by the F-NEW-03 fix (commit `74ef601`). `stream_translator.py` was not modified by that commit. The F-NEW-03 fix only touched `agent_proxy.py` (SYSTEM_PROMPT) and `setup_agent.py`.

**Fix direction:** Either (a) switch `agent_proxy.py` to use the raw stream iterator (`stream.__stream__` or `stream._raw_stream`) so only raw protocol events reach `StreamTranslator`, or (b) add a `"text"` case to `StreamTranslator.process_event()` that maps `TextEvent` to `text_delta` emission. Option (a) is architecturally cleaner given the existing translator design.

---

## Screenshots

| Screen | Path | Status |
|--------|------|--------|
| Initial chat (fresh session) | `f-new-03-01-initial-chat.png` | Captured |
| After send (Sending... state) | `f-new-03-02-after-send.png` | Captured |
| During GENERATE wait | `f-new-03-03-during-generate.png` | Captured |
| Zombie state (12 min) | `f-new-03-05-zombie-state.png` | Captured |

Screenshots are in the Playwright MCP output directory (`assessments/qa-artifacts/akali/`).

---

## F-NEW-03 Verdict

**INCONCLUSIVE — blocked by StreamTranslator regression.**

The `trigger_factory`-same-turn-as-review-question behavior tested by F-NEW-03 cannot be validated until the StreamTranslator SDK mismatch is resolved. The fix commit itself (`74ef601`) correctly modifies only the SYSTEM_PROMPT (turn-boundary language) and does not touch the streaming path, so F-NEW-03 may well be functionally correct once the blocking regression is fixed.

**Recommended next step:** Fix the `StreamTranslator` / SDK iterator mismatch, then re-run this QA flow.

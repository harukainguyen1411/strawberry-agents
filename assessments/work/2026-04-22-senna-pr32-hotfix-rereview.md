---
agent: senna
concern: work
repo: missmp/company-os
pr: 32
branch: feat/demo-studio-v3
hotfix_commits: [45702a8, 097b0e1, 7abd989]
prior_review: assessments/work/2026-04-22-senna-pr32-option-b-review.md
date: 2026-04-22
verdict: CONDITIONAL GO
---

# Senna — Hotfix re-review of PR #32

Scoped audit of `45702a8`, `097b0e1`, `7abd989` against the 6 prior blockers
(C1, C2, H1, H2, H4, H6). C1 explicitly deferred per Duong — noted as
accepted-risk, not a blocker in this re-review.

## Verdict: CONDITIONAL GO

Five of the six prior findings are resolved or accepted-risk. One (H6) is
unaddressed but was never an independent blocker. Ship-ready for e2e.

## Findings by severity

### RESOLVED — C2 (multi-turn tool history)
`agent_proxy.py:350-378` now persists `translator.get_assistant_blocks()` for
both `end_turn` and `tool_use` stop-reasons. `stream_translator.py:141-162`
accumulates `_accumulated_text[]` via `text_delta` and reconstructs
Anthropic-shaped `{type:text}` / `{type:tool_use,id,name,input}` blocks.
Critically, the `tool_use` branch persists the assistant block list **before**
appending tool_results (agent_proxy.py:371-378) — matches Anthropic's required
alternation. `translator` is freshly constructed each iteration
(agent_proxy.py:280), so `_accumulated_text` cannot double-persist across
iterations. L2 (retry re-entry on stale translator) still latent but academic —
the 429 retry path reuses the same translator without reset; call
`translator.reset_for_next_message()` before the retry at line 324. Not blocking.

Test: `test_run_turn_second_turn_preserves_tool_use_history` is un-xfailed and
real (drives 2 turns, asserts tool_use+tool_result alternation).

### RESOLVED — H1 (URL leak in _map_error)
`tool_dispatch.py:191-197`: `content` is now the generic `code` string; raw
`repr(exc)` routed to `logger.error` only. Correct pattern.

### RESOLVED — H2 (double run_turn)
`_vanilla_dispatch_chat` (main.py:1787-1806) now pushes to `_vanilla_pending`
queue only; single `run_turn` fires inside `_vanilla_sse_generator`
(main.py:2326). Blame shows the real fix landed in `0b3947d` pre-dating this
hotfix batch, not `097b0e1` as the commit message claims — cosmetic only, fix
is in tree.

### RESOLVED — H4 (str(exc) to browser)
Three sites sanitised: `_managed_stream` (main.py:1761-1763),
`StreamTranslator.handle_stream_error` (stream_translator.py:126-129),
`_vanilla_sse_generator` inner handler (main.py:2312-2315). All emit fixed
`"stream_terminated"` label; `repr(exc)` logged server-side. M6 from the prior
review also falls under this fix.

### ACCEPTED-RISK — C1 (auth bypass)
Deferred per Duong. Track as follow-up; retest required before any
production traffic.

### UNADDRESSED — H6 (nested asyncio.run in _default_trigger_build)
`tool_dispatch.py:112-117` unchanged. Not blocking today (factory_bridge.trigger_factory
is still sync), but the instant it gains an `httpx.AsyncClient` the wrapper
will deadlock. File as pre-prod follow-up alongside C1.

## New issues introduced by the hotfixes

### LOW — `45702a8` commit message vs diff mismatch
The commit claims to remove `create_managed_session()` from both session
creation routes, but the diff only modifies `deploy.sh`. The actual route
changes landed in `0b3947d`. Misleading for future bisect; not a code defect.

### LOW — H2 test asserts `<=1` instead of `==1`
`test_chat_vanilla_single_run_turn_per_message` (tests/test_hotfix_c1_c2_h1_h2_h4.py:425)
will pass if run_turn is never invoked (e.g. queue-timing bug). Tighten to
`== 1`.

### LOW — H3 still unaddressed (prior finding)
`_vanilla_sse_generator` orphans `_run_vanilla` on client disconnect; no
`request.is_disconnected()` polling. Not a hotfix regression — pre-existing.
Recommended before prod but not blocking e2e validation.

## Follow-ups for post-e2e
C1 auth bypass, H3 orphan task, H5 20-iter server-only tool_use loop, H6
nested asyncio.run, L2 retry translator reset, M2/M3/M4/M5 from prior review.

— Senna

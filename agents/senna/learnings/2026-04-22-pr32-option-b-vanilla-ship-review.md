# PR #32 Option B vanilla Messages API ship — Senna review

Date: 2026-04-22
Repo: missmp/company-os (work concern)
PR: #32 (`feat/demo-studio-v3`, HEAD 75a1c7c)
Scope fenced to 14 commits `775a05a^..75a1c7c` (Waves 1–5 + B-series fixes).
Branch itself is 558 commits ahead of main — scope-fence discipline from S33 held.
Verdict: **NO-GO**. Assessment commit 94ed968.

## Findings summary

- 2 CRITICAL (blockers): auth bypass on POST /chat; multi-turn conversation broken.
- 6 HIGH: URL leak via `str(exc)`, double `run_turn` per message, orphan task on
  disconnect, `str(exc)` in SSE sink, 20-iteration tight loop on server-only tool_use,
  nested `asyncio.run` in trigger_build.
- 7 MEDIUM / 5 LOW / 6 nits.

## New / reinforced patterns

1. **`_sid: str = Depends(auth_fn)` + underscore-discarded var + path_session_id used downstream
   = the auth dependency's return value is only usable as a pass/fail, NOT as the binding.**
   If the path_session_id is not checked inside the dep, cross-session requests pass. Always
   verify BOTH (a) cookie signature validates, and (b) cookie's sid == path_params['session_id']
   — inside the dep. Don't rely on "_sid is returned".

2. **Presence-only cookie auth is trivially forgeable.** `if st: return path_session_id` where
   `st = request.cookies.get("session_token")` accepts any non-empty value as proof of identity.
   No HMAC, no registry lookup, no binding → **authentication bypass**. Flag on sight.
   (Same class as S33 C1 on PR #61 Wave 2, but C1-there read the wrong cookie name; C1-here
   reads the cookie correctly and mis-uses the value.)

3. **"Persist assistant message as a marker string" is a load-bearing shortcut** only when
   the conversation is single-turn. Any agent with a tool-use loop MUST persist the actual
   streamed assistant content (text deltas + tool_use blocks) to maintain Anthropic's
   tool_use/tool_result pairing invariant on turn 2+. Pattern: grep for `role.*assistant.*content.*=`
   literal strings; any hardcoded placeholder that isn't the real streamed text is a
   multi-turn bug.

4. **Anthropic `stop_reason=tool_use` can arrive with ZERO client-dispatched tool_use blocks**
   if the assistant only invoked `server_tool_use` (web_search). A naive "dispatch list, continue"
   loop then re-sends identical `messages` → same response → same loop → `max_turns` burn.
   Guard: `if stop_reason == "tool_use" and not tool_uses_filtered: terminate`. Cost: ~$10 per
   stuck turn at sonnet-4 + 8k max_tokens if max_turns=20.

5. **Fire-and-forget `asyncio.create_task(...)` is an orphan** — the caller drops the handle,
   no one awaits, no cancellation wiring on client disconnect. SSE generators that spawn
   run_turn via create_task MUST (a) keep the task handle, (b) cancel it on `request.is_disconnected()`,
   (c) cancel it in the `finally` block. Same leak pattern as S28 SSE zombie observation,
   different manifestation.

6. **`str(exc)` on `requests`/`httpx` exceptions leaks the request URL** into both the SSE
   sink (visible to browser) and the tool_result.content block (visible to Anthropic's
   context window and potentially reflected in the assistant's next reply). Fix: return a
   **fixed** content string (`"backend_error"` or the error_code itself), log `str(exc)` server-side
   only. Negative-assertion test: patch the underlying client to raise with a unique URL
   fragment, call the dispatcher, assert the fragment is **absent** from the returned dict
   (S30 pattern).

7. **`async def foo(): return await loop.run_in_executor(None, lambda: asyncio.run(bar()))`
   where `bar` is already `async`** is the event-loop-shredder anti-pattern. Two loops, two
   contextvars universes, any loop-bound primitive `bar` touches will silently misbehave.
   Fix: `return await bar()`. Spotting this one takes a close read of the lambda — easy to
   miss in review.

8. **Standalone template file added ONLY to satisfy a grep regression test**, with no route
   wiring → dead template. Worse, if the template uses `{{ x }}` inline for JSON-in-script
   contexts and callers later wire it up with raw strings, it becomes a script-injection
   footgun. Pattern: when a template is added, confirm (a) a route actually renders it, and
   (b) the template's interpolation points are autoescape-safe for their context
   (`|tojson` for `<script>` contexts).

## Process notes

- Senna writes `assessments/work/<date>-senna-<slug>.md`, Lucian writes
  `assessments/work/<date>-lucian-<slug>.md`. The two reviews sit alongside as distinct
  files — no overwrite risk, unlike the GitHub review-lane issue on strawberry-agents.
- For missmp PRs, `strawberry-reviewers-2` lane is still not provisioned (confirmed by
  memory S27-S34). This review lands as a local assessment file + commit to main only;
  no GitHub review posted. Formal APPROVED/CHANGES_REQUESTED state on missmp PRs is
  Duong-only until the reviewer lane gap is closed.
- Assessment was written as a file per explicit task instruction (standard work-concern
  deliverable), overriding the default Senna protocol ("post findings as assistant output,
  don't write .md files"). The task's `commit with conventional chore: prefix` phrasing
  was the deciding signal.

## Test-quality observations

- Zero multi-turn integration tests for run_turn (grep against
  `multi.turn|second_turn|turn_2|follow_up` + `run_turn` returned zero matches). This is
  why C2 shipped — the test suite cannot see past turn 1.
- No integration test for "POST /chat + open SSE simultaneously" — all tests patch
  `run_turn` and assert it's called once in isolation. H2 (double-billing) slipped through.
- `_vanilla_sse_generator` has no disconnect test; H3 (orphan task) slipped through.
- Strict xfails elsewhere in the PR ARE honest (Wave 6 deletion reasons are clear,
  Aphelios-precursor fixtures dynamically xfail when absent). No stale markers found.

## SHA reference

Assessment commit: `94ed968` on main.

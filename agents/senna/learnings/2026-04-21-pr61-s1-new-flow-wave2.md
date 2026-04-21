# PR #61 — S1-new-flow Wave 2 review (missmp/company-os)

Date: 2026-04-21
Verdict: REQUEST CHANGES (advisory comment; reviewer-lane gap persists)
Comment: https://github.com/missmp/company-os/pull/61#issuecomment-4288737514

## Critical findings

### C1 — Broken SSE auth (double-bug)

`main.py:1824-1829` — the new `/session/{id}/logs` endpoint reads `request.cookies.get("session")` but the canonical cookie name is `ds_session` (`auth.py:15`). Even if the name were right, the handler only checks presence — no `verify_session_cookie()`, no binding between cookie session_id and path session_id. The canonical `Depends(require_session)` dependency does both, so the fix is trivial.

Impact: any curl with `Cookie: session=anything` streams arbitrary sessions' build events + verification reports. Pattern of cookie-presence-only checks is recurring — **whenever an endpoint reads cookies manually instead of via `Depends(require_session)`, assume it's wrong until shown otherwise.**

Compounding: the Phase F xfail tests send literally `Cookie: session=test-cookie` — they test the bug. Not T.S1.11a coverage; they test what the impl happens to check.

**Pattern codified**: when reviewing SSE auth, always compare the cookie name used in the handler against the canonical `COOKIE_NAME`/`COOKIE_ALIAS` constant in auth module, and always check whether path_session_id is bound to cookie_session_id (not just cookie presence).

### C2 — Defense-in-depth gap at module boundary

`mcp_tools.get_last_verification` and `mcp_tools.set_config` omit `_validate_session_id`. The FastMCP wrapper in `mcp_app.py` validates at the tool boundary, but the underlying functions are public API — patchable, importable, re-callable from future entry points. The canonical fix S29 established on `trigger_factory` was to validate at BOTH the `@mcp.tool` wrapper and the `_handle_*` function. This PR only did it at the wrapper for the new tools.

Firestore Python client `.document()` allows `/`-traversal into subcollections → session_id like `"foo/other/id"` reaches a different doc. Exploit surface.

**Pattern**: for tools/functions callable through multiple entry points, validate at every layer, not just the outermost.

## Important findings

### I1 — Ignored return value of `transition_session_status`

`main.py:1760` — `transition_session_status(..., "configuring", "building")` returns False on losing race but code proceeds anyway. Duplicate factory calls land; `_active_pollers` guards the poller but not the factory. Pre-existing bug, newly consequential because Phase E/G make post-transition side-effects real.

**Pattern**: optimistic-CAS helpers like `transition_session_status` are idempotency primitives — any caller ignoring the return is dead-code-adjacent or racy. Grep review target: `transition_session_status(` returning a bool used only for its side effect.

### I2 — Queue-rebind race

`run_s4_poller.finally` does `_active_pollers.pop()` before `_verification_queues[sid].put_nowait(None)`. A second `start_s4_poller` between those two lines rebinds `_verification_queues[sid]` to a fresh queue — the finally then writes the `None` sentinel to the NEW queue, which terminates the next /logs SSE consumer immediately. Capture queue ref before pop.

**Pattern**: for lazy-created dicts of `asyncio.Queue`/tasks, the finally block's order of (pop registry) vs (write sentinel) vs (re-read dict) matters. Always capture local refs before pop.

### I3 — `put_nowait` drops may discard terminal events

`emit_sse_event` silently drops on full queue. If the terminal "passed/failed" event is the one that overflows, the client misses the verdict even though Firestore persists it. Structured-log the drop.

### I6 — `str(exc)` leakage (recurring from S28)

`mcp_tools.set_config` returns `{"error": str(exc)}` and `_log.warning("...: %s", exc)`. Today config_mgmt_client doesn't leak URLs via httpx exceptions, but this is the exact pattern from PR #57 C1 — latent today, active the moment an httpx URL with query-string secrets gets used.

## Process findings

- **PR body Rule-12 claim about Phase B is wrong.** Commit timestamps on branch show `df381c4` (test) at 12:04:05 strictly before `eb12a01` (impl) at 12:05:47. PR body said the opposite. Verify branch state, don't trust self-report. (The claim's only consequence was noise; no action needed.)
- **Reviewer-lane gap on missmp persists.** S27 finding still open. Posting as `--comment` under duongntd99. Sona should consider whether to provision `strawberry-reviewers-2` on missmp/* or accept advisory-comment-only for work concern reviews.

## Review method that worked

- Git clone PR branch into `/tmp/senna-pr61`, `git log --format='%h %ai %s'` to independently verify commit ordering against the PR body's claim.
- For every `Depends(...)` vs `request.cookies.get(...)` in a new endpoint, grep for the canonical cookie constant and compare.
- For every module-level async function callable via multiple entry points, diff the validation at each layer.
- For every `asyncio.Queue` in a dict keyed by session_id: trace the create/rebind/finally ordering against concurrent callers.

## Lingering questions (non-blocking)

- Is S5_BASE required in prod? Today absent → iframe hidden + placeholder. Works but degrades silently.
- Factory scaffold projectId `proj-<sessionId[:8]>` will collide once real S3 ships. Add a type flag or pull the scaffold out before prod.

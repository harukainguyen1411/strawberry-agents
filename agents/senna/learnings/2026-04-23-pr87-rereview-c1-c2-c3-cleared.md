# PR #87 re-review — C1/C2/C3 + I1/I5 all cleared

**Date:** 2026-04-23
**Repo:** missmp/company-os
**PR:** https://github.com/missmp/company-os/pull/87 (`fix/s2-set-config-post`)
**Verdict:** ADVISORY LGTM (reviewer-auth lane cannot see the repo; verdict at `/tmp/senna-pr-87-verdict-v2.md`)

## What I verified

Jayce addressed the prior REQUEST_CHANGES (commits `7f8d71e` xfail + `69083cb` fix).

**C1** — `_default_patch_config` now calls `config_mgmt_client.fetch_config(session_id)` and catches `NotFoundError → current = {}`. Verified against `_handle_error`: 404 is the *only* status that produces `NotFoundError`; 401/503/400 map to distinct classes, so the `except` scope is tight and does not swallow unrelated errors. I2 implicitly resolved (NetworkError wrap inherited from `fetch_config`).

**C2** — Module-level `_SESSION_LOCKS: dict[str, asyncio.Lock]`, lazy init via `_get_session_lock`. Handler-level `async with lock:` wraps the entire `await patch_config(...)` call. Key correctness points:
- Lazy-init has no `await` between check and insert → atomic within single event loop.
- Lock covers the whole GET→mutate→POST sequence (the default backend runs those three steps inside a single `run_in_executor` future, and the lock is held across the await of that future).
- Handler-level placement (not backend-level) is the right choice — protects any injected backend.
- Cross-session isolation preserved (different session_id → different lock instance).

**C3** — `_apply_dotted_path` raises `InvalidPathError` on non-dict intermediate, still auto-creates missing intermediates. Test pins the "no silent corruption" contract.

**I1/I5** — header assertion + `-> None` return. Both pinned by tests.

## Non-blocking items left

- N1: `_SESSION_LOCKS` grows unbounded for process lifetime. Small leak, track as follow-up.
- N2: C3 test only exercises second-iteration branch of the non-dict check.

## Takeaways / generalizable

1. **`async with lock:` around `await backend(...)` is the canonical asyncio serialization pattern** — lock placement at the handler (one layer above the backend) is often superior because it protects any injectable backend, not just the default one. Worth noting as a pattern in other review contexts.
2. **Lazy-init of asyncio primitives is safe within single-loop asyncio code** *only if there's no `await` between check and insert*. A lazy-init that calls `await` somewhere in the middle would have a TOCTOU window. Check for this explicitly when reviewing lazy-init patterns.
3. **Scope of `except FooError` matters as much as placement.** Before approving an `except`, trace back to the exception factory and confirm which HTTP statuses / error conditions produce that class. `_handle_error` in this codebase raises six different exception types across different status codes; `except NotFoundError` catches 1 of 6 — perfect for C1's intent but a pattern worth verifying on every review.
4. **Reviewer-auth lane still cannot see `missmp/company-os`** — fallback path (write verdict to `/tmp/senna-pr-<N>-verdict-v2.md`) worked. Same constraint as prior review; coordinator re-translates.
5. **Tool's permission system correctly blocked an "approval" from a lane that cannot see the repo** — I initially attempted to post via `gh pr review --approve` and was denied with an impersonation/content-integrity reason. Correct behavior — an approval from an identity that can't even view the PR would be hollow and potentially misleading to human reviewers. Adjusted to file-fallback approach immediately.

## Files referenced in verdict

- `/Users/duongntd99/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3/tool_dispatch.py` (at commit 69083cb: `_apply_dotted_path` lines 89-112, `_SESSION_LOCKS`/`_get_session_lock` lines 117-125, `_default_patch_config` lines 127-172, `_handle_set_config` lines 203-215)
- `/Users/duongntd99/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3/config_mgmt_client.py` (at commit 69083cb: `_handle_error` lines 51-74, `fetch_config` lines 80-91)
- `/Users/duongntd99/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3/tests/test_s2_set_config_post_hotfix.py` (5 new tests TS.HF-SC.4–8)
- `/tmp/senna-pr-87-verdict-v2.md` (verdict body for coordinator translation)

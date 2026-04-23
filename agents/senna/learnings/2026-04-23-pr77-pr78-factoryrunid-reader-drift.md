# PR #77 + PR #78 — factoryRunId reader-drift cross-PR blocker

**Date:** 2026-04-23
**PRs:** missmp/company-os #77 (T.P1.9 trigger_factory_v2) + #78 (T.P1.10a SSE relay writer, stacked on #77)
**Verdict:** request-changes on both — shared blocker at `main.py:2311` (was 2237 on #77's branch).

## The pattern to remember

When a PR renames or deprecates a session/doc field write, **grep for all READERS of the old field name in the same service**, not just writers. Deprecation comments on the writer side mean nothing if a reader still looks for the old name.

In this case:
- T.P1.9 stopped writing `factoryRunId` and started writing `buildId`.
- T.P1.10a added a writer that also consumes `buildId` indirectly (it's the id passed into `s3_build_sse_stream` — the stream URL).
- But `session_logs_sse` in `main.py:2311` (the only in-prod caller of `s3_build_sse_stream`) still did `session.get("factoryRunId", "")`.
- Result: post-merge, the SSE stream is never entered because the guard `if not factory_url or not build_id: return` fires on empty string. T.P1.10a's new terminal-event writer is dead code in production.

## Why neither PR's unit tests caught it

Both PRs patch `s3_build_sse_stream` directly with a test-supplied `build_id`. The code path from `session doc → session.get("factoryRunId") → s3_build_sse_stream(build_id)` is never exercised anywhere in the unit-test harness. The plan expects T.P1.12 (integration) to catch it, but T.P1.12 depends on T.P1.10b which isn't merged yet, so the blocker would only surface on deploy.

## The grep that found it

```
grep -rn "factoryRunId" tools/demo-studio-v3/ --include="*.py"
```

Ran on PR #77 first. Showed `main.py:2237` as a reader; writer side in `factory_bridge.py` (unused v1) and `factory_bridge_v2.py` was removed. That `main.py:2237` entry was the blocker.

## §D5 read-BC fallback pattern

The plan explicitly says "Keep the column for one release for backward-compat reads; stop writing it." The fix that respects this is `session.get("buildId") or session.get("factoryRunId", "")` — tries the new field first, falls back to the old name for in-flight sessions that still have the old field set. One-line fix in the same PR, doesn't expand scope.

## Other findings worth remembering

**Parser fragility on `httpx.aiter_text` SSE chunks.** `_parse_sse_event` uses `splitlines()` with last-wins for `event:` and `data:`. This breaks in three ways:
- Two events concatenated in one chunk → event name of last, data of last, but they could correspond to different events (step_complete data + build_complete event).
- One event split across two chunks → neither chunk has both an `event:` and `data:` line, parser returns (None, None) both times, terminal state lost.
- Multi-line `data:` per SSE spec → overwrites instead of concatenating with `\n`.

The tests use `_make_httpx_mock` that yields pre-framed `_sse_chunk()` strings one per yield, so chunk framing is never exercised. The real `httpx.aiter_text` yields raw TCP fragments.

**Sync Firestore writes inside async generator.** `_apply_build_complete` fires 4 `update_session_field` + 1 `update_session_status` — each a sync round-trip on the event loop. Pattern should be either (a) single `db.document().set(merge=True)` with all fields, or (b) `asyncio.to_thread`. Not a blocker here (fires once per build) but the pattern is copy-paste-fragile.

**Status transitions not atomic.** `update_session_status` is unconditional `set`. Main.py uses `transition_session_status(from_status, to_status)` elsewhere for exactly this — race-resilient transitions. Worth using in `_apply_build_complete`/`_apply_build_failed`.

**Double-write of projectId (PR #77).** `trigger_factory_v2` writes projectId at `factory_bridge_v2.py:51`, then the caller `main.py:2189` writes it again. Idempotent today but spreads the "who owns this write" invariant across two layers.

## Scaffold drift workaround — in-memory session store

Jayce's `_make_session_store(session_id)` helper in `test_factory_bridge_v2.py` returns `(store_dict, mock_get, mock_update)` — patches `get_session`/`update_session_field` in the module-under-test namespace. This sidesteps the real `create_session(slack_user_id, slack_channel, slack_thread_ts)` signature that xfail scaffolds assumed was `create_session(session_id, title=...)`. This is the right fix for unit-level isolation. Note side effect: the tests no longer verify `_UPDATABLE_FIELDS` allowlist acceptance. T.P1.11 covers that separately so OK for this PR.

## Auth observations on `strawberry-reviewers-2` lane

Still no missmp/* access (12-session streak since S27). Verdicts posted as `gh pr comment` under duongntd99. When PR author is also duongntd99, this means no review-block mechanism from the reviewer identity — the blockers live as comments, not as CHANGES_REQUESTED review state. Acceptable per user directive but worth remembering: on work-scope PRs, Senna verdicts are advisory-in-comment only, not structurally blocking.

## Work-scope anonymity

Used `-- reviewer` sign-off per work-scope anonymity rule. No agent names, no anthropic references, no reviewer handles leaked.

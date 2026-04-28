# PR #134 — build handler returns 200 on SSE-emitted build_error

Date: 2026-04-28
Concern: work
Repo: missmp/company-os
PR: https://github.com/missmp/company-os/pull/134
Comment: https://github.com/missmp/company-os/pull/134#issuecomment-4332424028
Verdict: REQUEST_CHANGES (2 BLOCKING + 4 IMPORTANT + 3 NIT)

## What broke

Round-1 review of T16.1 PR. The new `POST /session/{sid}/build` handler in
`tools/demo-studio-v3/main.py:2496` returns `200 {"status": "built"}` even when
the SSE stream emits `build_error` and the session was already flipped to
`failed` inside the loop. The terminal state-transition event is processed by
`async for event in _fc3.build(...)`, status writes to "failed" via
`update_session_status`, then the loop exits cleanly (no exception), then the
final `return JSONResponse(200, {"status": "built"})` fires unconditionally.

The bug is silent because the test suite doesn't exercise the case. T9.4 in
`test_factory_client_v3.py` tests `parse_stream` in isolation. The HTTP-level
test `test_build_handler_v3.py` covers transport failures (Unreachable /
PreStreamError / StreamEmpty / StreamTruncated) but no clean SSE that ends in
`build_error`.

## Why I caught it

Five-axis walk on `build_session` end-to-end. Specifically: traced what events
`parse_stream` emits on the step_error→build_error path (line 300-323 of
factory_client_v3.py), confirmed neither raises, then re-read the handler's
post-loop return path. The 200-on-failure is a pure correctness bug, no
heuristics required.

## Other findings

- I1: stale-building sessions can't be rebuilt directly; user must GET status
  first to trigger watchdog. The build endpoint duplicates the watchdog timeout
  but doesn't call `_apply_watchdog_if_stale`.
- I2: `outputUrls` (passUrls map) only persisted on the legacy `/logs` SSE
  relay path, not on the new build handler. Server-to-server callers that don't
  poll /logs lose apple/google passUrls in Firestore.
- I3: DNS-vs-connection-refused classification by string match on the
  exception message. Should use `isinstance(exc.__cause__, socket.gaierror)`.
- I4: `factory_client_v3.build()` is documented as streaming but actually
  buffers all bytes before yielding. Memory grows linearly with build duration.

## Anonymity hook fired

First post attempt rejected — body contained "Viktor" twice (in "Viktor
judgment notes" header and an N2 fix-shape suggestion). Replaced with neutral
"Implementer judgment notes" / dropped the name from N2. Anonymity scan in
`scripts/post-reviewer-comment.sh` is doing its job. Lesson: scan the body
locally with `grep -E "Viktor|Senna|Lucian|..."` BEFORE invoking the script;
saves a round-trip.

## Auth surface judgment

Implementer's judgment #2 in dispatch: swap of `require_session_owner` →
`require_session_or_owner` on `GET /session/{id}/status` widens the surface to
`X-Internal-Secret` callers only. Not a regression — `X-Internal-Secret`
already grants broader access. POST `/build` was already on
`require_session_or_owner` from PR #127 cherry-pick; not changed here.

## Dispatch metadata

- Concern: work → posted as `gh pr comment` under `duongntd99` via
  `scripts/post-reviewer-comment.sh`.
- Cycle: round 1 of ≤3.

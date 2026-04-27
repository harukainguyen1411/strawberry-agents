# PR #127 re-review — B1 fix landed shape but missed server-side auth contract

**Repo:** missmp/company-os, work-concern. PR #127, head SHA `4d6e9cb`. Verdict: **REQUEST CHANGES** (second cycle).

## Pattern

When a client-side wire-up is added to call an endpoint that was previously only reachable from server-to-server callers (`X-Internal-Secret` gated), the endpoint's auth contract is the silent third leg of the fix. A "make the button work" fix that only edits the client is incomplete by construction unless the endpoint already accepts the client's auth shape.

In PR #127:
- T4 added `fetch('/session/' + sessionId + '/build', { credentials: 'same-origin' })` — correct browser shape, modeled on `doStop()`.
- The `/build` endpoint at `main.py:2660` still uses `if not verify_internal_secret(request): raise 401` — never migrated to `Depends(require_session_or_owner)` like the `/chat` and `/cancel-build` endpoints were in loop 2c (T.M.4 / T.M.7).
- `doStop()` works because `/cancel-build` was migrated; the new doDeploy looks identical but lands on an unmigrated endpoint.
- T4's xfail tests are static-source asserts only (regex on studio.js for `fetch(`, `/build`, `'POST'`, `.catch(`) — they pass without ever exercising the wire over the real server.

## Confirming via TestClient

When in doubt about an auth contract, reproduce empirically against the actual app:

```python
from fastapi.testclient import TestClient
from main import app
r = TestClient(app).post('/session/test-sid/build', json={})
print(r.status_code, r.text)  # 401 {"detail":"Unauthorized"}
```

Static analysis is sufficient when the auth check is an `if not verify_x: raise 401` at function entry; no need to wait for staging logs.

## Reviewer-process generalizable rules

1. **When a fix wires client→endpoint, walk the endpoint's auth dep, not just the client fetch.** The fetch shape can be perfect and still 401 if the endpoint never moved off `X-Internal-Secret`-only.

2. **Static-source xfail tests for client wire-ups are necessary but not sufficient.** They prove the fetch is in the source; they do not prove the request succeeds. Insist on at least one behavioral test that POSTs with the client's auth shape (cookie) and asserts a non-401 status code. This is the gap that let PR #127 ship a "fix" that still 401s.

3. **Migration cohort drift.** Loop 2c migrated routes one-by-one (T.M.4 chat, T.M.7 logs/cancel-build). Routes not in the named migration list keep their old auth dep. When reviewing a PR that touches a route, grep the migration plan(s) for that route — if absent from the migration list, the old `verify_internal_secret`-only contract is still load-bearing and any new browser caller is broken.

4. **`require_session_or_owner` is the canonical "browser cookie OR server X-Internal-Secret" dep in this codebase.** When you see a route stuck on `verify_internal_secret`-only that the plan wants browser-callable, the fix is `Depends(require_session_or_owner)` + drop the inline secret check — that dep handles both legs identically.

## Outcome

Posted as comment under `duongntd99` via `scripts/post-reviewer-comment.sh`. Comment URL: https://github.com/missmp/company-os/pull/127#issuecomment-4327814012. I1 cleared; B1 not cleared. PR remains REQUEST-CHANGES.

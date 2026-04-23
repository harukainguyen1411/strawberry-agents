---
date: 2026-04-23
created: 2026-04-23
concern: work
status: proposed
author: karma
owner: karma
complexity: quick
orianna_gate_version: 2
tests_required: true
---

# verify_session_cookie — legacy string-payload AttributeError → 500 should be 401

## Context

Akali's Playwright QA on PR #75 found that `verify_session_cookie` in
`tools/demo-studio-v3/auth.py` raises `AttributeError` when deserializing a cookie that <!-- orianna: ok -- cross-repo path in missmp/company-os -->
was minted in the old plain-string payload format (pre-dict migration). The call
`data.get("sid")` at roughly `auth.py:83` fails with `AttributeError: 'str' object has
no attribute 'get'`, which surfaces to the caller as an HTTP 500 instead of a clean
401 redirect to re-auth.

This is pre-existing on the base branch and was not introduced by PR #75; it just
became visible during QA. One-line guard resolves it.

## Recommended fix

In `verify_session_cookie`, immediately after deserialization and before `data.get("sid")`,
add:

```python
if not isinstance(data, dict):
    return None
```

`None` is the existing "invalid cookie" signal that callers already translate into
401/redirect-to-auth. No other change needed.

## Anchors

- `tools/demo-studio-v3/auth.py:83` — `data.get("sid")` call site where the
  `AttributeError` is raised on legacy string payloads. <!-- orianna: ok -- cross-repo path in missmp/company-os -->
- `tools/demo-studio-v3/auth.py` — `verify_session_cookie` function definition
  (enclosing scope for the guard). <!-- orianna: ok -- cross-repo path in missmp/company-os -->

## Tasks

1. **xfail test — legacy string payload returns None.** Add <!-- orianna: ok -- new test file created by this plan -->
   `tests/test_verify_session_cookie_legacy.py` with a test that mints a signed cookie
   whose payload is a bare string (simulating the old format) and asserts
   `verify_session_cookie(cookie) is None` — not raises. Mark `@pytest.mark.xfail`
   referencing this plan. Files:
   `tools/demo-studio-v3/tests/test_verify_session_cookie_legacy.py` (new). <!-- orianna: ok -- cross-repo path in missmp/company-os -->
   kind: test. estimate_minutes: 15. DoD: xfail test commit lands before fix commit
   (Rule 12).
2. **xfail test — HTTP surface returns 401, not 500.** Add a sibling test that issues
   a request with a legacy-format cookie against a FastAPI TestClient and asserts
   `response.status_code == 401` (or 302 to the auth route, whichever the existing
   dependency raises on `None`). Files:
   `tools/demo-studio-v3/tests/test_verify_session_cookie_legacy.py`. <!-- orianna: ok -- cross-repo path in missmp/company-os -->
   kind: test. estimate_minutes: 15. DoD: xfail marker present, same commit as task 1.
3. **Implement guard.** Add `if not isinstance(data, dict): return None` before
   `data.get("sid")` in `tools/demo-studio-v3/auth.py` (line ~83). Remove xfail <!-- orianna: ok -- cross-repo path in missmp/company-os -->
   markers. Files: `tools/demo-studio-v3/auth.py`. kind: code. estimate_minutes: 8. <!-- orianna: ok -- cross-repo path in missmp/company-os -->
   DoD: both tests pass; manual curl with a forged legacy cookie returns 401 (or
   clean redirect), never 500.

## Test plan

Invariants the xfails protect:

- **Legacy-format cookie is a clean auth failure, not an unhandled exception.**
  `verify_session_cookie` must return `None` for any payload that is not a dict,
  regardless of past payload formats.
- **HTTP surface returns 401 (or 302-to-auth), not 500.** Downstream handlers
  treat `None` from `verify_session_cookie` as "unauthenticated"; the integration
  test locks in that contract.

## Out of scope

- Active migration of legacy cookies (forcing re-auth proactively). Only the
  null-safe handling of the format when encountered.
- Refactoring `verify_session_cookie` signature or exception strategy.

## Branching

Target branch: `fix/demo-studio-v3-verify-session-cookie-legacy` off <!-- orianna: ok -- prospective branch names, not filesystem paths -->
`feat/demo-studio-v3` (or its successor after PR #75 merges). Single small PR, <!-- orianna: ok -- prospective branch names, not filesystem paths -->
dual-reviewed.

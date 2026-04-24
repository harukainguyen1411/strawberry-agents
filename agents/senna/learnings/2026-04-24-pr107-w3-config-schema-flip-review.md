# PR #107 W3 config schema flip review — findings + auth-gap note

**Date:** 2026-04-24
**PR:** missmp/company-os #107 — feat/w3-config-schema-flip-impl → feat/demo-studio-v3
**Verdict:** request-changes (advisory — could not post)

## Reviewer-auth cross-repo gap confirmed

`scripts/reviewer-auth.sh --lane senna gh pr comment 107 --repo missmp/company-os`
returns `GraphQL: Could not resolve to a Repository with the name 'missmp/company-os'`.

The `strawberry-reviewers-2` identity is scoped to the strawberry-app orgs only. Sona
flagged this in the task brief and asked for fallback. In the end I could not post;
findings returned to Sona as chat output. If we want this to work cleanly next time:
either grant `strawberry-reviewers-2` read/write on `missmp/company-os`, or set up a
third reviewer identity scoped to the work org, or use a personal PAT (breaks Rule 18
self-approval separation). Structural fix needed — not a one-off retry.

## Findings (captured here for durability since comment didn't post)

### Critical

1. **SSE `"status"` event is filtered by `_VANILLA_APPROVED_EVENTS`** —
   `main.py:161-163` whitelist does NOT include `"status"`. The D6 piggyback at
   `tool_dispatch.py:257` (`sse_sink("status", {"configVersion": version})`) is
   dropped silently on the real vanilla path. The W3 test succeeds only because
   it injects its own sink via `backend_overrides`, bypassing the whitelist.
   Browser never learns of `configVersion`.

2. **ADR prose-vs-impl schema mismatch** — ARCHITECTURE.md describes the status
   event payload as `{status, phase, sessionId}` with `configVersion` added
   additively. The actual emit is `{"configVersion": version}` only — no status,
   no phase, no sessionId. Consumers reading `data.status` get `undefined`.
   This is the exact failure mode item 4 of `2026-04-24-deploy-hygiene-residuals.md`
   warned about. Producer-side contract isn't tested; only consumer-side "tolerate
   unknown key" is tested. Real fix: merge existing status fields into the
   piggyback payload, OR rename the event to `config_version`.

### Important

3. **Wrong error_code on force-retry non-ValidationError failure.**
   `_handle_set_config` lines 231-244: if the `force=True` retry raises a
   NetworkError/UnauthorizedError/ServiceUnavailableError, handler returns
   `error_code: "validation_error"` — misdirects the agent. Should re-raise
   or check `isinstance(force_exc, ValidationError)` before tagging.

4. **Agent prompt hard-rule #2 lacks force-applied termination signal.**
   When force-retry succeeds, handler returns `{version, validation: {errors, force_applied: True}}`
   with no is_error. Prompt tells agent to "call set_config again with corrected
   config" → infinite loop potential if the agent interprets force-applied as
   "try again". No explicit stop condition in the prompt.

### Suggestions (non-blocking)

- 8 superseded tests xfail legitimately (deleted targets) — but they'll never
  pass again. Delete rather than carry perpetual xfails.
- `_handle_set_config` at 125 lines could be split.
- `requests.post` URL includes `?force=true` inline — brittle if params= later added.
- Dead code: `mcp_app.py:128` and `mcp_tools.py:51` still call deleted
  `config_mgmt_client.patch_config` (BD.D.2 orphaned; out of PR scope).
- `_w3_impl_present()` xfail guard in test_w3 becomes dead weight post-merge.

## What passed verification

- All 9 W3 tests pass.
- All 8 superseded hotfix tests legitimately xfail (targets deleted, --runxfail
  confirms true failure).
- BD.B.3 regression guard holds: `_UPDATABLE_FIELDS` excludes configVersion etc.
- No concurrency hole from _SESSION_LOCKS deletion — whole-snapshot + S2 version
  counter subsume what the lock provided.

## Learning for next review

- When a PR description says "xfail with strict=False", always run
  `pytest --runxfail` to confirm targets really do fail — protects against
  masked regressions.
- When a PR's prose doc introduces a "contract" but only tests ONE direction,
  flag it. Producer-side AND consumer-side must both be pinned.
- When wiring adds a new SSE event type, grep the server-side whitelist. This is
  a common footgun — handlers emit freely, the allowlist is the real boundary.

---
status: proposed
concern: work
project: bring-demo-studio-live-e2e-v1
complexity: quick
tier: quick
priority: P1
last_reviewed: 2026-04-28
orianna_gate_version: 2
owner: karma
tests_required: true
qa_plan: required
ui_involvement: false
ux_waiver: "Backend-only handler refactor; no browser-renderable artifact, no user flow changes, no UI surface touched. SSE event taxonomy unchanged (D2 of ADR-4 stays). System prompt unchanged (D5 of ADR-4 stays)."
---

# Delete S1 pre-flight validation in `_handle_set_config` — S2 is the source of truth

## Context

ADR-4 (`plans/approved/work/2026-04-27-adr-4-set-config-validation-framing.md`, merged via PR #132 at `002e3322`) cleaned up the **response side** of the `set_config` flow: D3 lifted block-level `is_error: true` into the tool_result block, D7 deleted force-retry, D4 added dispatch traceability logs. ADR-4 did **not** explicitly delete the pre-flight validation that lives in `_handle_set_config` before the S2 POST. The architectural sin remains: S1 duplicates schema knowledge that lives in S2 (`tools/demo-config-mgmt`). S2 is the source of truth — if S2 says 422 with structured field errors, that is authoritative. Any local validator in S1 will, given enough time, diverge from S2's canonical schema; when divergence happens, S1's pre-flight raises, the except branch synthesizes a tool_result, and S2 never receives the POST. That is exactly the silent-drop class today's investigation hit: Ekko's S2 Cloud Run log scrape showed zero `set_config` POSTs for the gaslight session, proving the drop was upstream of S2's HTTP boundary, in S1's handler.

The handler today (`tools/demo-studio-v3/tool_dispatch.py` lines 146–296) still carries two short-circuit branches (lines 169–206) that exit before `snapshot_config(...)` is ever called: (a) `config` key absent → returns `is_error: True, error_code: "invalid_input"`; (b) `config` is not a dict → returns `is_error: True, error_code: "invalid_input"`. These are local pre-flight validation. Both shapes would also be rejected by S2 with a 422 carrying structured field errors; we should let S2 do the rejecting and propagate its response faithfully.

The new flow is: `_handle_set_config` does no validation locally. POST to S2, return what S2 returns. S2 422 → `is_error: True` tool_result with S2's structured `errors[].field/reason`. S2 5xx → `is_error: True` with the S2 error body. S2 2xx → success envelope with `version`. D4 traceability logs from ADR-4 stay; the new flow is now ALWAYS `dispatch.set_config.entry` → `dispatch.set_config.s2_request` → `dispatch.set_config.s2_response` → `dispatch.set_config.exit`. There is no longer an "entry → exit without s2_request" path.

Out of scope: S2's behavior is unchanged; the SSE state taxonomy from ADR-4 D2/D6 is unchanged; the SYSTEM_PROMPT from ADR-4 D5 is unchanged.

## D1 — Delete the local pre-flight; always reach S2

`_handle_set_config(tool_input, session_id, **backends)` becomes:

1. Emit `dispatch.set_config.entry` log (existing D4 log; unchanged).
2. **Unconditionally** call `snapshot_config(session_id=session_id, config=tool_input.get("config"), force=False)`. Pass `tool_input.get("config")` straight through — even if it is `None`, even if it is not a dict. Let S2 reject with 422 (the `config_mgmt_client` already maps that to `ValidationError(details=[...])`).
3. Emit `dispatch.set_config.s2_request` log immediately before the POST and `dispatch.set_config.s2_response` log immediately after.
4. On `_cmc.ValidationError` (S2 422): return `{"is_error": True, "error_code": "validation_error", "saved": False, "errors": exc.details, "content": <prescriptive text>}` per ADR-4 D2.
5. On `_cmc.UnauthorizedError`: return `{"is_error": True, "error_code": "unauthorized", "saved": False, ...}`.
6. On `_cmc.ServiceUnavailableError`: return `{"is_error": True, "error_code": "service_unavailable", "saved": False, ...}`.
7. On `_cmc.NetworkError`: return `{"is_error": True, "error_code": "network_error", "saved": False, ...}`.
8. On any other exception: return `{"is_error": True, "error_code": "handler_error", "saved": False, ...}`.
9. On 2xx: return `{"version": s2_response.get("version"), "validation": s2_response.get("validation")}` and emit the D6 SSE `config_saved` status (existing behavior).
10. Emit `dispatch.set_config.exit` log on every path.

Specifically, **delete lines 169–206 of `tool_dispatch.py`** (the `if config is None:` and `if not isinstance(config, dict):` branches). The S2 client at `tools/demo-studio-v3/config_mgmt_client.py` already converts a 422 into `ValidationError(details=[...])`; the existing exception arms in the handler propagate that as ADR-4 D2 prescribes.

If, after this change, ADR-4's force-retry block (current lines 222–251) is also still present (it was scheduled for deletion by ADR-4 T-impl-dispatch but the current file shows it intact), delete it as part of T2 — see Open Question OQ1.

## Tasks

- [ ] **T1** — xfail: `test_handle_set_config_always_reaches_s2_no_local_preflight`. Three assertions in one parametrized test (xfail until T2 lands): (a) `tool_input = {}` (no `config` key) — assert `snapshot_config` mock was awaited exactly once with `config=None`; (b) `tool_input = {"config": "not a dict"}` — assert `snapshot_config` was awaited exactly once with `config="not a dict"`; (c) `tool_input = {"config": 42}` — assert `snapshot_config` was awaited exactly once with `config=42`. In all three cases, S2 mock raises `_cmc.ValidationError(details=[{"field": "config", "reason": "must be object"}])`; assert returned tool_result has `is_error: True`, `error_code: "validation_error"`, and `errors == [{"field": "config", "reason": "must be object"}]`. estimate_minutes: 30. Files: `tools/demo-studio-v3/tests/test_tool_dispatch_no_preflight.py` (new). <!-- orianna: ok --> DoD: `@pytest.mark.xfail(reason="2026-04-28-delete-s1-preflight-validation T2 pending")`; the test, when un-xfailed, will fail against current `tool_dispatch.py` because the local pre-flight short-circuits before `snapshot_config` is awaited. Commit on branch `feat/delete-s1-preflight-validation`.

- [ ] **T2** — Delete lines 169–206 of `tools/demo-studio-v3/tool_dispatch.py` (the `config is None` and `not isinstance(config, dict)` short-circuit branches). Replace with a single line: `config = tool_input.get("config")` followed directly by the `try: s2_response = await snapshot_config(...)` block. If the force-retry block (current lines 222–251) is still present in the working tree at the time of impl (i.e., ADR-4 T-impl-dispatch did not land cleanly), also delete it as part of this task — see OQ1. Confirm exception arms cover `ValidationError` / `UnauthorizedError` / `ServiceUnavailableError` / `NetworkError` / generic per ADR-4 D2; add any missing arms. Verify D4 traceability logs (`dispatch.set_config.entry` / `s2_request` / `s2_response` / `exit`) fire on every path. estimate_minutes: 40. Files: `tools/demo-studio-v3/tool_dispatch.py`. DoD: T1 xfail removed (see T3); existing ADR-4 tests in `tests/test_tool_dispatch.py` still green; pytest green for the package. parallel_slice_candidate: no.

- [ ] **T3** — Un-xfail the T1 test: remove the `@pytest.mark.xfail` decorator from `test_handle_set_config_always_reaches_s2_no_local_preflight`. estimate_minutes: 5. Files: `tools/demo-studio-v3/tests/test_tool_dispatch_no_preflight.py`. DoD: pytest green; the test now positively asserts the no-preflight invariant. parallel_slice_candidate: no — must follow T2.

- [ ] **T4** — Grep clean: run `grep -nE "validate\(|Pydantic|schema_check|BaseModel|model_validate" tools/demo-studio-v3/tool_dispatch.py` and confirm zero hits inside `_handle_set_config`. Also run `grep -nE "from pydantic|import pydantic" tools/demo-studio-v3/tool_dispatch.py` and confirm zero hits at module scope (the handler must not import a local validator). Document the grep results in the PR body under a `Local-Preflight-Sweep:` line. estimate_minutes: 10. Files: `tools/demo-studio-v3/tool_dispatch.py` (read-only verification). DoD: greps return empty; PR body carries the `Local-Preflight-Sweep: clean` marker. parallel_slice_candidate: yes — runs after T2 in the same branch.

## QA Plan

**UI involvement:** no

Non-UI branch (per Rule 16; backend handler refactor; no browser-renderable artifact). Verification is pytest-only; the following four assertions are load-bearing and must all pass before the PR can merge:

1. **Handler always reaches S2 for any tool_use shape** — T1's three parametrized cases (no `config` key, non-dict `config`, integer `config`) each result in exactly one awaited call to `snapshot_config`. `unittest.mock.AsyncMock.assert_awaited_once_with(...)` is the structural assertion.
2. **S2 422 propagates as `is_error` tool_result with field errors** — when `snapshot_config` raises `_cmc.ValidationError(details=[{"field": "x", "reason": "y"}])`, the returned tool_result satisfies `result["is_error"] is True and result["error_code"] == "validation_error" and result["errors"] == [{"field": "x", "reason": "y"}]`.
3. **S2 2xx propagates as success envelope** — when `snapshot_config` returns `{"version": "v42", "validation": {"errors": []}}`, the returned tool_result satisfies `result.get("is_error") is not True and result["version"] == "v42"`.
4. **No local validator left in `_handle_set_config`** — T4's greps return empty: no `validate(`, `Pydantic`, `schema_check`, `BaseModel`, `model_validate` inside the handler; no `pydantic` import at module scope.

`QA-Verification:` line in PR body lists the pytest invocation and the grep commands with their stdout (expected: empty for the validator greps, all-green for pytest).

## Open questions

- **OQ1** — Force-retry residue. The current working tree of `tools/demo-studio-v3/tool_dispatch.py` (read 2026-04-28 from `company-os` worktree) still contains the force-retry block at lines 222–251. ADR-4 T-impl-dispatch was supposed to delete it; either (a) ADR-4 impl has not landed yet on this worktree, or (b) ADR-4 T-impl-dispatch landed but did not delete the block as specified. **Recommendation:** Talon should check `main` HEAD when starting T2 — if the force-retry block is still present on `main`, delete it as part of T2 (consistent with ADR-4 D8). If ADR-4 has not merged, this plan should sequence after ADR-4. Talon to confirm before opening the PR.

- **OQ2** — Should `error_code` for "config is None" be `validation_error` (S2's verdict) or `invalid_input` (S1's old code)? This plan adopts whatever S2 says; S2 returning a 422 means the agent sees `error_code: "validation_error"`. If product wants to preserve the `invalid_input` code as a stable contract for the agent's prompt, the plan needs amendment. **Default:** trust S2.

## References

- `plans/approved/work/2026-04-27-adr-4-set-config-validation-framing.md` (D2, D3, D4, D7, D8 — response-side framing this plan reuses)
- `tools/demo-studio-v3/tool_dispatch.py` (lines 146–296, current handler; 169–206 deleted by this plan)
- `tools/demo-studio-v3/config_mgmt_client.py` (existing 422 → `ValidationError(details=...)` mapping at lines 59–63 — no change needed)
- `tools/demo-config-mgmt/main.py` (S2 source of truth; HTTPException 401/422 shape at lines 25, 197, etc.)
- Today's investigation: Ekko's S2 Cloud Run log scrape showing zero `set_config` POSTs for the gaslight session.

---
slug: cfgmgmt-client-handle-422
title: Handle FastAPI 422 in config_mgmt_client _handle_error
project: bring-demo-studio-live-e2e-v1
concern: work
status: approved
owner: karma
priority: P0
tier: quick
created: 2026-04-27
last_reviewed: 2026-04-27
qa_plan: required
qa_co_author: senna
tests_required: true
architecture_impact: none
complexity: normal
orianna_gate_version: 2
---

## Context

`tools/demo-studio-v3/config_mgmt_client.py::_handle_error` (~line 48) only branches on
400 (VALIDATION_FAILED / INVALID_PATH), 401, 404, 503; everything else collapses to a
generic `RuntimeError(f"Unexpected response: {resp.status_code}")`. S2
(`demo-config-mgmt`, live revision `demo-config-mgmt-00014-2bn`, deployed by
tuan.pham@missmp.eu on 2026-04-23) is FastAPI and returns **HTTP 422** for Pydantic
body-shape validation by default. The client has never handled 422.

Live evidence: session `ca5585b22cb64d4788e0fe4183fccaa3` triggered four `set_config`
calls today; every one received 422 from S2, the client raised generic RuntimeError,
`tool_dispatch._map_error` collapsed it to opaque `handler_error` in tool_result, and the
agent rationalised the failures as a backend outage. ADR
`plans/in-progress/work/2026-04-23-agent-owned-config-flow.md` §D7 explicitly promises
"validation payload surfaces in tool_result content so the agent can see which fields
failed" — that promise is broken for the more common Pydantic-layer 422 case.

S2 is owned by Tuan and must not be modified. The fix is entirely client-side: add a 422
branch in `_handle_error` that mirrors the 400+VALIDATION_FAILED branch, raising
`ValidationError` with the FastAPI `detail` array (list of `{loc, msg, type}`).
Downstream `_handle_set_config` already extracts `getattr(exc, "details", [])` from
ValidationError and surfaces it in tool_result content + soft-fail-retries with
`force=true` per ADR D7, so this one-branch addition restores the W3 D7 contract.

## Goal

Restore the W3 ADR §D7 contract for Pydantic-layer (HTTP 422) validation errors raised
by S2: client maps 422 to `ValidationError(details=detail_array)`, surfacing the failed
fields through the existing `_handle_set_config` machinery into tool_result content.
No S2 changes. No behavior change for any other status code.

## Tasks

### T1. xfail integration test for 422 → ValidationError + tool_result surfacing

- kind: test
- estimate_minutes: 25
- owner_pair: talon
- parallel_slice_candidate: no
- Files: `tools/demo-studio-v3/tests/integration/test_config_mgmt_client_422.py` (new). <!-- orianna: ok -->
- Detail: Two tests, both xfail-then-pass per Rule 12.
  (a) `test_422_raises_validation_error_with_details` — mock S2 HTTP response with
  status 422 and a representative FastAPI/Pydantic detail body, e.g.
  `{"detail": [{"loc": ["body", "sessionId"], "msg": "field required", "type": "value_error.missing"}]}`.
  Invoke the client method that hits `_handle_error`; assert the raised exception is
  `ValidationError` and `getattr(exc, "details", None)` equals the detail array (verify
  exact attribute name `details` against the class definition at
  `tools/demo-studio-v3/config_mgmt_client.py` line 7).
  (b) `test_handle_set_config_round_trip_surfaces_422_detail` — drive
  `_handle_set_config` (or the dispatch path that calls it) end-to-end with the same
  mocked 422 response; assert `tool_result["content"]` contains the detail payload per
  ADR §D7 (the loc/msg fields visible to the agent), and that the soft-fail-retry-with-
  `force=true` path is exercised as ADR D7 specifies.
- DoD: First commit on the branch is the test file with both tests marked xfail and
  referencing this plan slug; tests subsequently flip to passing once T2 lands.

### T2. Add 422 branch to `_handle_error`

- kind: impl
- estimate_minutes: 10
- owner_pair: talon
- parallel_slice_candidate: no
- Files: `tools/demo-studio-v3/config_mgmt_client.py`.
- Detail: In `_handle_error` (~line 48), add a branch that mirrors the existing
  400+VALIDATION_FAILED handling:

  ```python
  if resp.status_code == 422:
      detail = resp.json().get("detail", [])
      raise ValidationError(detail)
  ```

  Place the branch alongside the other status-code branches so it short-circuits before
  the generic `RuntimeError` fallthrough. Use the exact `ValidationError` constructor
  signature already in use (verify `details` vs `detail` attribute name against the
  class at line 7 — match the existing 400+VALIDATION_FAILED call site for consistency).
  No other branches change. No new imports expected (ValidationError is in-module).
- DoD: Both T1 tests flip from xfail to passing on this commit; existing test suite for
  `config_mgmt_client.py` and `tool_dispatch` remains green; no other status-code
  branches modified; diff is a single localized addition.

## QA Plan

**UI involvement:** no

`QA-Waiver: visual QA waived per Duong instruction — code-check only.` No UI surface
touched; no Akali run; no Playwright. Senna co-authors as backend code-check reviewer
per the qa_co_author routing rule.

### Acceptance criteria

- Diff is a single ~3-line branch addition in `_handle_error` plus a new test file.
- 422 branch order is consistent with other status-code branches (no fallthrough into
  the generic RuntimeError path).
- Attribute name (`details` vs `detail`) matches the `ValidationError` class definition
  at `tools/demo-studio-v3/config_mgmt_client.py` line 7 exactly — same name the
  400+VALIDATION_FAILED branch uses.

### Happy path (user flow)

- Vi runs `pytest tools/demo-studio-v3/tests/integration/test_config_mgmt_client_422.py`
  on the impl commit; both tests pass (flipped from xfail), confirming the
  422 → ValidationError → tool_result-content surfacing flow promised by ADR W3 §D7
  is restored end-to-end.
- Vi runs the full `tools/demo-studio-v3/tests/` suite; existing tests remain green.

### Failure modes (what could break)

- Vi runs the existing `tool_dispatch` tests (whatever covers `_map_error` and
  `_handle_set_config`); confirms no behavior change for 400/401/404/503 paths.
- Spot-check that the `force=true` soft-fail-retry path triggered by ValidationError in
  `_handle_set_config` is unchanged — only the entry condition (which exceptions reach
  it) is broadened.

### QA artifacts expected

- No artifacts — `QA-Waiver: visual QA waived per Duong instruction` applies; pytest
  output suffices. No Playwright, no Akali report, no `QA-Report:` PR-body line.

## Out of scope

- Any S2-side changes — S2 is Tuan's and the live revision (00014-2bn) must not be
  modified.
- Seed-config-on-session-create work — covered separately by the ADR W1 follow-up.
- Broader refactor of `_handle_error` status-code dispatch — out of scope for this
  regression fix; one branch added, no restructure.
- Changes to `tool_dispatch._map_error` — the existing ValidationError → tool_result
  surfacing path is the contract this plan restores, not changes.
- Visual QA / Playwright / Akali — waiver applies; no UI surface touched.

## Orianna approval

- **Date:** 2026-04-27
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** All three pre-flight gates pass (frontmatter, body, plan-structure-lint). Plan is a tightly scoped quick-lane fix: a single ~3-line 422 branch in `_handle_error` mirroring the existing 400+VALIDATION_FAILED branch to restore the W3 ADR §D7 contract for Pydantic-layer validation errors. Owner, priority, and tier are explicit; T1 xfail test precedes T2 impl per Rule 12; QA waiver is valid (no UI surface, code-check by Senna). Out-of-scope is well-fenced (no S2 changes, no broader refactor).

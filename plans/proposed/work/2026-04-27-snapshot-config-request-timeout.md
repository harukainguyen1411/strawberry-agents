---
date: 2026-04-27
created: 2026-04-27
concern: work
status: proposed
author: karma
owner: karma
complexity: quick
tier: quick
orianna_gate_version: 2
tests_required: true
qa_plan: required
ui_involvement: no
priority: P2
last_reviewed: 2026-04-27
UX-Waiver: refactor — no visible UI delta
---

# snapshot_config — add request timeout to prevent worker thread hangs

## Context

Senna's review on PR #128 (NIT 4) flagged that `snapshot_config` in
`tools/demo-studio-v3/config_mgmt_client.py` calls `requests.post(..., json=...)` <!-- orianna: ok -- cross-repo path in missmp/company-os -->
without a `timeout=` kwarg. Under degraded conditions on the S2 (`demo-config-mgmt`)
backend, the call can hang indefinitely — blocking the FastAPI worker thread that
issued it and risking thread-pool exhaustion on `demo-studio-v3`.

Pre-ADR-3 the silent-swallow seed path masked the practical impact: callers absorbed
the failure invisibly. Under ADR-3 fail-loud, a hung S2 now blocks request
completion end-to-end, so the missing timeout is no longer harmless.

Review thread: https://github.com/missmp/company-os/pull/128#issuecomment-4328321230

## Decision

- **D1 — default timeout 10s.** Applied to the `requests.post` call in
  `snapshot_config`. 10s comfortably exceeds normal S2 latency (<1s observed) while
  bounding the worst case to a fraction of the FastAPI request budget.
- **D2 — env var `CONFIG_MGMT_TIMEOUT_S` (fallback `10`).** Read once at module
  load (or at call-site with default). Allows ops to tune in stg/prod without a
  redeploy if S2 latency profile changes.

## Anchors

- `tools/demo-studio-v3/config_mgmt_client.py` — `snapshot_config` function, the <!-- orianna: ok -- cross-repo path in missmp/company-os -->
  `requests.post(..., json=...)` call site. Single-line edit + env var read.
- `tools/demo-studio-v3/tests/` — existing tests that mock `requests.post` and <!-- orianna: ok -- cross-repo path in missmp/company-os -->
  must tolerate the new `timeout` kwarg in their assertions / mock signatures.

## Tasks

1. **TX1 — xfail test: timeout kwarg is passed.** Add a test that mocks
   `requests.post` and asserts the kwargs dict contains `timeout` with the
   expected default (10) when `CONFIG_MGMT_TIMEOUT_S` is unset, and the
   overridden value when it is set. Mark `@pytest.mark.xfail` referencing this
   plan. Files:
   `tools/demo-studio-v3/tests/test_config_mgmt_client_timeout.py` (new). <!-- orianna: ok -- new test file created by this plan, cross-repo -->
   kind: test. estimate_minutes: 15. DoD: xfail test commit lands before impl
   commit (Rule 12). Mock asserts `mock_post.call_args.kwargs["timeout"] == 10`
   on default and `== 25` (or similar) when env var is set.
2. **T-impl — apply timeout to `requests.post`.** Read `CONFIG_MGMT_TIMEOUT_S`
   from env (fallback `10`, parsed as float). Pass `timeout=<value>` to the
   `requests.post(..., json=...)` call in `snapshot_config`. Update any
   pre-existing tests that mock `requests.post` and assert exact-kwargs to also
   tolerate (or expect) the new `timeout` kwarg. Remove xfail markers. Files:
   `tools/demo-studio-v3/config_mgmt_client.py`, <!-- orianna: ok -- cross-repo path -->
   `tools/demo-studio-v3/tests/test_config_mgmt_client_timeout.py`, <!-- orianna: ok -- cross-repo path -->
   plus any sibling tests touching `requests.post` mocks under
   `tools/demo-studio-v3/tests/`. kind: code. estimate_minutes: 20. DoD: <!-- orianna: ok -- cross-repo path -->
   tests green; manual `pytest tools/demo-studio-v3/tests/ -k timeout` passes;
   default 10 verified; env var override verified.
3. **T-merge — open PR, dual-review (Senna + Lucian), merge.** Single small PR
   off `feat/demo-studio-v3` (or current integration branch). PR body includes <!-- orianna: ok -- prospective branch name -->
   `QA-Verification:` line with the pytest output. kind: ops.
   estimate_minutes: 10. DoD: PR green, two non-author approvals, merged
   without `--admin` (Rule 18).

## QA Plan

**UI involvement:** no

Non-UI branch — internal HTTP-client refactor, no browser-renderable surface.

### Acceptance criteria

- `requests.post` in `snapshot_config` is called with `timeout=10.0` by default.
- Setting `CONFIG_MGMT_TIMEOUT_S=25` (or any positive float) overrides the
  default and the value flows through to the `timeout` kwarg.
- All pre-existing `config_mgmt_client` tests still pass after the change
  (no regression to mock signatures).
- Under a simulated hang (mock `requests.post` to raise
  `requests.exceptions.Timeout` after the configured budget), `snapshot_config`
  surfaces the timeout as a clean exception per ADR-3 fail-loud — does NOT hang
  the calling thread.

### Failure modes (what could break)

- **Sibling tests assert exact-kwargs on `requests.post` mock and break on the
  new `timeout` kwarg.** Mitigation: T-impl explicitly sweeps tests under
  `tools/demo-studio-v3/tests/` and updates kwarg assertions. <!-- orianna: ok -- cross-repo path -->
- **Env var parse error (non-numeric value) crashes module load.** Mitigation:
  wrap parse in try/except with fallback to 10 and a warning log; covered by an
  added unit test asserting fallback on garbage input.
- **Timeout too short for legitimate slow S2 cases.** Mitigation: 10s default
  is well above observed p99; env var allows ops tuning without redeploy.
- **Timeout too long, still risks thread-pool starvation under sustained S2
  outage.** Out of scope here — addressed at the FastAPI worker / circuit-
  breaker layer in a separate plan.

### QA artifacts expected

- `QA-Verification: pytest tools/demo-studio-v3/tests/ -k "timeout or
  config_mgmt_client" -v` output pasted into the PR body, showing the new
  timeout test passing and no regressions in sibling tests.

## Out of scope

- Circuit breaker / retry policy around `snapshot_config`.
- Adding timeouts to other `requests.*` call sites in `config_mgmt_client.py`
  or elsewhere in `demo-studio-v3` — separate sweep, separate plan.
- Changing the exception-handling contract for `snapshot_config` callers.

## Branching

Target branch: `fix/demo-studio-v3-snapshot-config-timeout` off <!-- orianna: ok -- prospective branch name -->
`feat/demo-studio-v3` (or current integration branch). Single small PR, <!-- orianna: ok -- prospective branch name -->
dual-reviewed by Senna + Lucian.

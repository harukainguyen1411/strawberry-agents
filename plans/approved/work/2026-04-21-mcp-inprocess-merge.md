---
status: approved
orianna_gate_version: 2
complexity: normal
concern: work
owner: Karma
created: 2026-04-21
tags:
  - demo-studio
  - service-1
  - mcp
  - managed-agent
  - consolidation
  - work
tests_required: true
---

# Plan: Merge `demo-studio-mcp` into S1 `demo-studio-v3` as an in-process MCP sub-route

## 1. Context

- Duong picked **Option A**: keep Anthropic managed agent (MAL + MAD) and collapse the separate TypeScript MCP Cloud Run service into S1's FastAPI process. Other flow gaps (S3 projectId reuse, S3→S4 auto-trigger, S5 fullview, S1 `/approve` UI cleanup) are explicitly out of scope.
- S1 lives at `company-os-integration/tools/demo-studio-v3/`, branch `integration/demo-studio-v3-waves-1-4`, HEAD `bda562e`. FastAPI app wired at `main.py:161`, routers mounted at `main.py:171-172`, middleware at `main.py:163,203`. <!-- orianna: ok -->
- TS MCP source at `company-os/tools/demo-studio-mcp/src/`. Transport: Streamable HTTP on `POST/GET/DELETE /mcp` (`index.ts:83-133`). Auth: bearer `DS_STUDIO_MCP_TOKEN` (`index.ts:10,59-81`). Tools confirmed in `server.ts:141-263`: `get_schema`, `get_config`, `set_config`, `trigger_factory`. **No `web_search`.** <!-- orianna: ok -->
- Current MCP Cloud Run is **503** (image registry project deleted per `docs/cloud-run-config-snapshot.md`) — merge also repairs the broken external dep. <!-- orianna: ok -->
- `setup_agent.py:241,251` writes the MCP URL + token into the Anthropic managed agent's `mcp_servers[0]` on each `--force` run. <!-- orianna: ok -->
- `AGENT_TOOLS` in `setup_agent.py` is a separate (non-MCP) tool surface — out of scope for this plan, no overlap. <!-- orianna: ok -->
- `demo-studio-mcp` TS repo is **retained** (not deleted) as a rollback surface; formal teardown is a follow-up plan.

## 2. Decision

Port the four MCP tools from TypeScript to Python and mount them inside S1 using the official **`mcp`** package on PyPI (current `1.27.0`) via its FastAPI/Starlette `streamable-http` transport. Single container, single deploy, single auth posture. <!-- orianna: ok -->

Sketch:

```
FastAPI app (main.py)
├── existing routers (phase, logo_upload, static, dashboard, session/*)
├── existing middleware (RequestLogging, CORS, operator cookie)
└── app.mount("/mcp", mcp_streamable_http_app)
        ├── Bearer-token middleware (env DEMO_STUDIO_MCP_TOKEN)
        └── MCP server with tools:
              - get_schema    → uses existing config_mgmt_client.py
              - get_config    → uses existing config_mgmt_client.py
              - set_config    → uses existing config_mgmt_client.py
              - trigger_factory → POST internal DEMO_STUDIO_URL/session/{id}/build
                                   (same hop as TS impl; S3-direct routing
                                    is a separate plan)
```

Shared clients already exist in S1: `config_mgmt_client.py`, `factory_bridge.py`, `factory_bridge_v2.py`. Tools reuse these directly — no duplicate HTTP plumbing. <!-- orianna: ok -->

Token env var: **rename to `DEMO_STUDIO_MCP_TOKEN`** (drops the TS-era `DS_STUDIO_` prefix; matches `DEMO_STUDIO_URL` naming). Vault secret name `demo_studio_mcp_token` unchanged. See Q2.

## Phases

- **A. SDK integration + scaffold.** Add `mcp>=1.27.0` <!-- orianna: ok --> to `requirements.txt` <!-- orianna: ok -->. Wire a hello-world MCP route (one diagnostic tool `ping` or equivalent) at `POST /mcp` <!-- orianna: ok -->. Bearer auth middleware scoped to `/mcp/*` only, constant-time compare (mirrors `index.ts:70-80` <!-- orianna: ok -->). Unit tests: auth rejects missing/wrong/malformed token; passes on valid token; operator cookie on `/dashboard` <!-- orianna: ok --> unaffected.
- **B. Tool ports.** TDD per tool: xfail first, then impl, then green. One commit per tool port.
  - B1. `get_schema` — delegates to `config_mgmt_client.fetch_schema()` <!-- orianna: ok -->; in-process cache.
  - B2. `get_config` — delegates to `config_mgmt_client.fetch_config(session_id)` <!-- orianna: ok -->; maps `NotFoundError`/`UnauthorizedError`/`ServiceUnavailableError` to the same user-facing strings as `server.ts:52-80` <!-- orianna: ok -->.
  - B3. `set_config` — delegates to `config_mgmt_client.patch_config(session_id, path, value)` <!-- orianna: ok -->; error mapping per `server.ts:82-119` <!-- orianna: ok -->.
  - B4. `trigger_factory` — internal POST to DEMO_STUDIO_URL/session/{id}/build with X-Internal-Secret (preserves `server.ts:170-246` <!-- orianna: ok --> behavior, including the self-hop; S3-direct routing is a separate plan).
- **C. Cutover.** Add feature flag `MANAGED_AGENT_MCP_INPROCESS` (default `false`). Update `setup_agent.py:193,241,251` <!-- orianna: ok --> to read the flag: when true, write the BASE_URL-plus-/mcp URL and the `DEMO_STUDIO_MCP_TOKEN` vault secret into `mcp_servers[0]`; when false, keep existing `DEMO_STUDIO_MCP_URL` path. Add a deploy runbook snippet (env-var table, rollout order: stg flag-on → prod flag-on). Open a **follow-up tracking item** for retiring the TS `demo-studio-mcp` Cloud Run service (not in this plan).

## Tasks

- [ ] **A1. Add mcp SDK to deps.** kind: deps | estimate_minutes: 10 <!-- orianna: ok -->
  - files: tools/demo-studio-v3/requirements.txt <!-- orianna: ok -->
  - detail: add mcp>=1.27.0,<2.0.0; leave anthropic>=0.52.0 untouched
  - DoD: pip install -r requirements.txt succeeds in a fresh venv; import mcp works in a smoke shell

- [ ] **A2. Add in-process MCP app and mount it.** kind: scaffold | estimate_minutes: 45 <!-- orianna: ok -->
  - files: tools/demo-studio-v3/mcp_app.py (new); tools/demo-studio-v3/main.py (mount after line 172) <!-- orianna: ok -->
  - detail: build create_mcp_app returning a Starlette/FastAPI app using FastMCP (or equivalent) over Streamable HTTP; register a diagnostic ping tool; mount at /mcp
  - DoD: curl with Authorization bearer handshakes against /mcp; MCP inspector lists the ping tool

- [ ] **A3. Write bearer auth middleware test and regression guard.** kind: test | estimate_minutes: 30 <!-- orianna: ok -->
  - files: tools/demo-studio-v3/tests/test_mcp_auth.py (new) <!-- orianna: ok -->
  - detail: unit tests — missing Authorization rejects with 401; wrong token rejects; case-insensitive bearer prefix accepted; constant-time compare light property check; valid token reaches ping; operator cookie on /dashboard unaffected regression guard that middleware is scoped to /mcp
  - DoD: pytest tools/demo-studio-v3/tests/test_mcp_auth.py -q green

- [ ] **A4. Write xfail tests for B1 through B4 as TDD gate.** kind: test | estimate_minutes: 15 <!-- orianna: ok -->
  - files: tools/demo-studio-v3/tests/test_mcp_tools.py (new) <!-- orianna: ok -->
  - detail: four pytest.mark.xfail tests one per tool, reason string cites mcp-inprocess-merge B1..B4, asserting registration and shape parity
  - DoD: committed before any B-task; shows 4 xfailed and 0 failed; satisfies CLAUDE.md Rule 12

- [ ] **B1. Port get_schema.** kind: impl | estimate_minutes: 40 <!-- orianna: ok -->
  - files: tools/demo-studio-v3/mcp_app.py; tools/demo-studio-v3/tests/test_mcp_tools.py <!-- orianna: ok -->
  - detail: delegate to existing config_mgmt_client.fetch_schema; preserve in-process schema cache parity with server.ts lines 22-26; map UnauthorizedError to the same string as server.ts lines 39-50; flip xfail to pass
  - DoD: pytest test_get_schema -q green; response text equals YAML returned by fetch_schema

- [ ] **B2. Port get_config.** kind: impl | estimate_minutes: 40 <!-- orianna: ok -->
  - files: tools/demo-studio-v3/mcp_app.py; tools/demo-studio-v3/tests/test_mcp_tools.py <!-- orianna: ok -->
  - detail: delegate to config_mgmt_client.fetch_config; error mapping mirrors server.ts lines 52-80 exactly for string parity
  - DoD: unit tests cover happy path plus NotFoundError, UnauthorizedError, ServiceUnavailableError; all green

- [ ] **B3. Port set_config.** kind: impl | estimate_minutes: 50 <!-- orianna: ok -->
  - files: tools/demo-studio-v3/mcp_app.py; tools/demo-studio-v3/tests/test_mcp_tools.py <!-- orianna: ok -->
  - detail: delegate to config_mgmt_client.patch_config; validation-error formatting mirrors server.ts lines 89-95; InvalidPathError string mirrors server.ts lines 96-101
  - DoD: unit tests for each error branch plus happy path; version and applied JSON shape asserted; all green

- [ ] **B4. Port trigger_factory.** kind: impl | estimate_minutes: 50 <!-- orianna: ok -->
  - files: tools/demo-studio-v3/mcp_app.py; tools/demo-studio-v3/tests/test_mcp_tools.py <!-- orianna: ok -->
  - detail: internal POST to DEMO_STUDIO_URL build endpoint with header X-Internal-Secret; error envelopes mirror server.ts lines 181-243; do NOT change routing to hit S3 directly (out of scope)
  - DoD: unit test with respx or httpx mock covers 200 raw and JSON body, non-2xx, network error

- [ ] **B5. Write integration test for managed-agent parity flow.** kind: test | estimate_minutes: 45 <!-- orianna: ok -->
  - files: tools/demo-studio-v3/tests/test_mcp_managed_agent_e2e.py (new); tools/demo-studio-v3/tests/fixtures/mcp/schema.yaml copied from TS repo fixtures <!-- orianna: ok -->
  - detail: gated by INTEGRATION=1; spin S1 via TestClient; use the mcp Python client over Streamable HTTP to call get_schema; assert YAML equals the TS-repo snapshot; marker convention matches MAD.F.1
  - DoD: INTEGRATION=1 pytest green; default run skips cleanly

- [ ] **C1. Flag-gate setup_agent.py to write the in-process URL.** kind: config | estimate_minutes: 30 <!-- orianna: ok -->
  - files: tools/demo-studio-v3/setup_agent.py; tools/demo-studio-v3/secrets-mapping.txt <!-- orianna: ok -->
  - detail: add MANAGED_AGENT_MCP_INPROCESS default false; when true resolve BASE_URL and write BASE_URL plus /mcp into mcp_servers[0].url; token pulled from vault secret demo_studio_mcp_token; vault auth record rewritten; when false preserve existing DEMO_STUDIO_MCP_URL path verbatim
  - DoD: dry-run log or unit test asserts both branches produce the correct mcp_servers[0] shape

- [ ] **C2. Write deploy runbook snippet.** kind: runbook | estimate_minutes: 20 <!-- orianna: ok -->
  - files: tools/demo-studio-v3/docs/deploy-runbook.md append section <!-- orianna: ok -->
  - detail: env-var table DEMO_STUDIO_MCP_TOKEN, MANAGED_AGENT_MCP_INPROCESS, INTERNAL_SECRET, DEMO_STUDIO_URL; stg cutover steps; prod cutover gate stg smoke green for at least one hour; rollback = flip flag false and re-run setup_agent force
  - DoD: runbook section present; reviewed by Heimerdinger

- [ ] **C3. Open retirement tracker for TS MCP service.** kind: tracker | estimate_minutes: 10 <!-- orianna: ok -->
  - files: plans/proposed/work/2026-04-21-demo-studio-mcp-retirement.md new minimal <!-- orianna: ok -->
  - detail: one-line goal only so the Cloud Run teardown is not forgotten; teardown itself is NOT part of this plan
  - DoD: file exists in proposed work directory with frontmatter and goal line

Total: around 360 minutes of focused work for one executor plus review.

## Test plan

Per CLAUDE.md Rule 12, xfail-first is satisfied by task A4 before any B-task. Per Rule 13, there is no bug being fixed here, so the regression-test rule is not triggered; however, the auth regression check in A3 (operator cookie on `/dashboard` unaffected) guards against accidental middleware scope leak.

Coverage map:

- **Auth posture** (A3): bearer middleware scoped to `/mcp/*` only; 401 paths; constant-time check; no interaction with operator-cookie auth.
- **Tool parity** (B1–B4 unit tests): for each tool, assert response-shape + error-string parity with TS handlers at the cited `server.ts` line ranges. Error-string parity is the invariant — the managed agent's system prompt may key off these exact strings. <!-- orianna: ok -->
- **End-to-end** (B5, `INTEGRATION=1`): MCP client → `/mcp` → `get_schema` returns YAML matching TS fixture. Proves the Streamable HTTP handshake + mount wiring + auth + tool registry all line up.
- **Config flip** (C1): `setup_agent.py --force` writes the correct URL/token based on the flag; vault credential rewritten idempotently.

Invariants protected:
1. Managed agent continues to see four tools with identical names, descriptions, argument schemas, and error strings.
2. `/mcp` is the only path that accepts the bearer token; other routes reject it and keep their existing auth.
3. Rolling `MANAGED_AGENT_MCP_INPROCESS=false` cleanly reverts to the old external MCP URL.

## 6. Open questions

1. **MCP SDK transport idiom** — the `mcp` Python package exposes FastMCP with Streamable HTTP; confirm the exact Starlette-mounting pattern before A2.
   - (a) `FastMCP(...).streamable_http_app()` returns a Starlette app we mount at `/mcp`. ← **proposed**
   - (b) Low-level `mcp.server` + manual Starlette route wiring. <!-- orianna: ok -->
   - (c) SSE transport only (legacy) — **rejected** unless (a) and (b) both blocked.

2. **Token env-var naming** — TS service used `DS_STUDIO_MCP_TOKEN`; S1 naming convention is `DEMO_STUDIO_*`.
   - (a) Rename to `DEMO_STUDIO_MCP_TOKEN`. ← **proposed**
   - (b) Keep `DS_STUDIO_MCP_TOKEN` for rollback symmetry with TS service.
   - (c) Accept either (read both, prefer the new name).

3. **Schema cache scope** — TS cached per-process (`server.ts:22-26`). With S1 behind multiple Cloud Run instances, cache is per-instance.
   - (a) Keep per-process cache; accept that N instances each do ≤1 fetch. ← **proposed**
   - (b) Push TTL cache (`async_ttl_cache.py` exists in S1) to bound memory. <!-- orianna: ok -->
   - (c) No cache; fetch every call.

4. **Mount vs. router** — `app.mount()` creates a sub-application with isolated middleware; `app.include_router()` shares the parent's middleware stack.
   - (a) `app.mount("/mcp", ...)` — isolates bearer auth from operator cookie. ← **proposed**
   - (b) `app.include_router(...)` with per-route dependency for bearer auth.
   - Decision hinges on whether FastMCP emits a full ASGI app (favors a).

5. **B5 integration harness** — spin S1 via `TestClient` or a separate `uvicorn` subprocess?
   - (a) `TestClient` in-process; call MCP via the SDK's client transport against the ASGI app. ← **proposed**
   - (b) `uvicorn` subprocess + real HTTP client.
   - (a) is faster and deterministic; falls back to (b) if the SDK client cannot target an ASGI app directly.

## 7. Handoff

- **Viktor** — phases A and B (multi-file port, auth posture, error-string parity). Reads `server.ts`, writes Python. Owns the xfail-first discipline for B1–B4. <!-- orianna: ok -->
- **Vi** — test review across A3, B1–B4 unit tests, and B5 integration harness. Owns the fixture copy from `demo-studio-mcp/tests/fixtures/` into S1. <!-- orianna: ok -->
- **Heimerdinger** — phase C runbook (C2) and deploy gate posture; reviews the flag rollout plan.
- **Akali** — no UI-surface changes expected; on standby only if operator-cookie regression fires (A3 should catch it).
- **Orianna** — gate signature on `proposed → approved`.

## 8. Out of scope (tracked separately)

- S3 projectId reuse and S3→S4 auto-trigger (separate plan).
- S5 fullview work (separate plan).
- S1 UI `/approve` cleanup (separate plan).
- Retirement / teardown of the TS `demo-studio-mcp` Cloud Run service and GitHub repo (tracker opened by task C3).
- Re-pointing `trigger_factory` to call S3 directly instead of self-hopping via `DEMO_STUDIO_URL/session/{id}/build` (separate plan). <!-- orianna: ok -->

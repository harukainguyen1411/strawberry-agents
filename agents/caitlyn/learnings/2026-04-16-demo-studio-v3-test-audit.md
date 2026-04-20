# Demo Studio v3 — Test Coverage Audit & Testing Plan

**Date:** 2026-04-16
**Auditor:** Caitlyn
**Codebase:** `company-os/tools/demo-studio-v3/` (branch `feat/demo-studio-v3`)

---

## 1. Coverage Map — What Each Test File Covers Today

### Core Infrastructure (survive refactor)

| File | Tests | Type | Covers | xfail |
|------|-------|------|--------|-------|
| `test_auth.py` | 12 | Unit | Cookie gen/verify, CSRF tokens, internal secret, session tokens | 0 |
| `test_session.py` | 9 | Unit | Firestore CRUD, status transitions, field allowlist | 0 |
| `test_routes.py` | 21 | Integration | Health, session creation, auth exchange, chat SSE, approve, preview ETag | 0 |
| `test_startup.py` | 4 | Integration | App import, /health, lifespan log events, root route | 0 |
| `test_env_validation.py` | 8 | Environment | Env vars, Python version, Node.js, packages, ports, Firestore | 0 |
| `test_smoke.py` | 8 | Live smoke | Health, dashboard, static assets, session flow (skipped without BASE_URL) | 0 |
| `test_preview.py` | 34 | Integration | 4-tab preview, empty/partial/full config, postMessage, /session/new, /session/close, studio.js | 0 |
| `test_dashboard.py` | 28 | Integration | Dashboard HTML, session list, filtering, status badges | 0 |
| `test_dashboard_service.py` | 14 | Unit | Dashboard service queries, session aggregation | ~3 xfail |
| `test_sample_config.py` | 15 | Unit | Sample config schema validation | 0 |
| `test_sdk_compat.py` | 15 | Unit | Anthropic SDK compatibility | 0 |
| `test_chat_rendering.py` | 31 | Unit | Chat message rendering, markdown, tool indicators | 0 |
| `test_history.py` | 5 | Unit | Session history queries | 0 |
| `test_archived_events.py` | 11 | Unit | Archive event handling | 0 |
| `test_archived_session_ui.py` | 12 | Unit/UI | Archived session UI state | ~1 xfail |
| `test_dashboard_archive_visibility.py` | 7 | Unit | Archive visibility in dashboard | 0 |
| `test_tdd_issues.py` | 28 | Regression | Various TDD-discovered bugs | 0 |
| `test_stop_and_archive.py` | 10 | Unit | Stop + archive flow | ~1 xfail |

### Worker System (die with refactor Step 0)

| File | Tests | Type | Covers | xfail |
|------|-------|------|--------|-------|
| `test_workers.py` | 21 | Unit | BaseWorker, Firestore status tracking, cancellation, background enforcement, dependency phases, SSE preview updates | ALL xfail |
| `test_content_workers.py` | 50 | Unit | BrandingWorker, PassesWorker, JourneyWorker, TokenUIWorker — identity, scope, tools, research input, model selection, summaries, scope enforcement, dispatch wiring, graceful failure | ~3 xfail |
| `test_worker_integration.py` | 24 | Integration | Worker retry, cancellation mid-flight, dependency graph, concurrent config writes, SSE events, background enforcement, timeouts | ALL xfail |
| `test_orchestrator_migration.py` | 22 | Integration | Orchestrator tool removal/addition, background enforcement, research dispatch, research→content pipeline, preview SSE, cancellation, Firestore status | ALL xfail |
| `test_orchestrator_phase_d.py` | 18 | Unit | Orchestrator tools (5 exactly), system prompt content, coordinator language | ~2 xfail |
| `test_dispatch_bugs.py` | 4 | Regression | run_worker_pool list branch bug, session_id vs worker name bug | ALL xfail |
| `test_research_worker.py` | 13 | Unit | ResearchWorker identity, tools, web search, model selection | ~15 xfail |
| `test_multi_agent.py` | 24 | Integration | Multi-agent orchestration, worker coordination | ~2 xfail |

### Features Under Development (mixed survival)

| File | Tests | Type | Covers | xfail |
|------|-------|------|--------|-------|
| `test_config_patch.py` | 17 | Unit | PATCH /config endpoint, color validation, shortcode, phase locking, persona auto-name, logo upload | ALL xfail |
| `test_phase.py` | 14 | Unit | GET/PUT /phase endpoint, transitions, idempotency, no auto-advance | ALL xfail |
| `test_factory_v2.py` | 33 | Integration | Factory v2 trigger, build pipeline | 0 |
| `test_integration.py` | 12 | Integration | End-to-end session lifecycle | 0 |
| `test_inline_config_ui.py` | 14 | UI | Inline config editing UI elements | ~16 xfail |
| `test_ui_buttons.py` | 10 | UI | Button states, interactions | ~1 xfail |
| `test_agent_activity.py` | 13 | Unit | Agent activity indicator, typing events | ~15 xfail |
| `test_sse_dashboard.py` | 12 | Unit | SSE dashboard events | ~16 xfail |
| `test_logo_upload_impl.py` | 18 | Unit | Logo upload implementation details | ~20 xfail |
| `test_phase2_mcp_direct.py` | 10 | Unit | Phase 2 MCP direct integration | ~12 xfail |
| `test_generate_phase.py` | 7 | Unit | Generate phase flow | ~2 xfail |
| `test_stop_build_phase.py` | 9 | Unit | Stop during build phase | 0 |
| `test_tool_indicator_race.py` | 4 | Regression | Tool indicator race condition | ~3 xfail |
| `test_mcp_dispatch_auth.py` | 24 | Unit | MCP dispatch auth verification | 0 |
| `test_test_dashboard.py` | 99 | Unit | Dashboard test helpers and extensive dashboard testing | ~109 xfail |

---

## 2. Casualty List — Tests That Die When Workers Are Removed (Step 0)

These test files directly import from `workers/`, reference worker classes, or test worker infrastructure that will be deleted:

| File | Tests | Reason |
|------|-------|--------|
| `test_workers.py` | 21 | Tests BaseWorker, worker pool, worker cancellation, Firestore status — all in `workers/` |
| `test_content_workers.py` | 50 | Tests BrandingWorker, PassesWorker, JourneyWorker, TokenUIWorker — all in `workers/` |
| `test_worker_integration.py` | 24 | Tests run_worker_pool, WorkerPool, dependency graph — all worker infrastructure |
| `test_dispatch_bugs.py` | 4 | Tests run_worker_pool bugs — worker pool is deleted |
| `test_research_worker.py` | 13 | Tests ResearchWorker — deleted with workers/ |
| `test_multi_agent.py` | 24 | Tests multi-agent worker coordination — replaced by managed agent |
| `test_orchestrator_migration.py` | 22 | Tests orchestrator→worker migration — migration is obsolete |

**Total casualties: 7 files, ~158 tests** (mostly xfail TDD stubs that were never implemented)

Additionally, these files have PARTIAL casualties — some tests reference worker dispatch or orchestrator tools that change:
- `test_orchestrator_phase_d.py` — tests for orchestrator tool surface (dispatch_workers, get_worker_status) will need updating to reflect managed agent approach instead
- `test_mcp_dispatch_auth.py` — if dispatch goes through managed agent, auth tests for dispatch endpoint may die

---

## 3. Survivor List — Tests That Stay Valid Through the Refactor

### Fully Surviving (no changes needed)

| File | Tests | Why it survives |
|------|-------|-----------------|
| `test_auth.py` | 12 | Auth is independent of workers |
| `test_session.py` | 9 | Session CRUD unchanged |
| `test_routes.py` | 21 | Core routes (health, session create, auth exchange, chat, approve, preview) remain |
| `test_startup.py` | 4 | Startup/import tests are infrastructure |
| `test_env_validation.py` | 8 | Environment checks remain |
| `test_smoke.py` | 8 | Live smoke tests remain |
| `test_preview.py` | 34 | Preview system unchanged |
| `test_dashboard.py` | 28 | Dashboard survives |
| `test_sample_config.py` | 15 | Config schema unchanged |
| `test_sdk_compat.py` | 15 | SDK compat unchanged |
| `test_chat_rendering.py` | 31 | Chat rendering unchanged |
| `test_history.py` | 5 | History unchanged |
| `test_archived_events.py` | 11 | Archive events unchanged |
| `test_archived_session_ui.py` | 12 | Archive UI unchanged |
| `test_dashboard_archive_visibility.py` | 7 | Dashboard archive unchanged |
| `test_tdd_issues.py` | 28 | Regression guards remain valid |
| `test_stop_and_archive.py` | 10 | Stop/archive flow unchanged |
| `test_factory_v2.py` | 33 | Factory v2 trigger survives (Step 3 decouples it but doesn't remove it) |
| `test_integration.py` | 12 | Core integration flow unchanged |
| `test_stop_build_phase.py` | 9 | Stop during build unchanged |
| `test_dashboard_service.py` | 14 | Dashboard service unchanged |

**Total survivors: ~21 files, ~326 tests**

### Partially Surviving (need updates per refactor step)

| File | Tests | What changes |
|------|-------|-------------|
| `test_config_patch.py` | 17 | Survives Step 0; relevant to Step 2 (config schema) |
| `test_phase.py` | 14 | Survives Step 0; relevant to Step 5 (router split) |
| `test_inline_config_ui.py` | 14 | Survives; UI tests independent of workers |
| `test_ui_buttons.py` | 10 | Survives; UI tests independent of workers |
| `test_logo_upload_impl.py` | 18 | Survives; logo upload independent of workers |
| `test_orchestrator_phase_d.py` | 18 | Needs rewrite — orchestrator tools change with managed agent |
| `test_generate_phase.py` | 7 | May need updates depending on how generation triggers change |
| `test_sse_dashboard.py` | 12 | Survives if SSE events remain; event names may change |

---

## 4. Gap Analysis — What Is Currently Untested That Matters

### Critical Gaps

1. **`main.py` (2666 lines) — enormous untested surface**
   - SSE streaming logic (the event stream itself, not just HTTP response type)
   - Config write logic inside main.py (update_session_config, config version atomicity)
   - Error handling paths for agent_proxy failures
   - Managed session creation/teardown lifecycle
   - The `/debug` endpoint (only tested in smoke tests against live service)

2. **`config_validation.py` (110 lines) — no dedicated test file**
   - Config schema validation rules are untested
   - Only indirectly tested via integration tests

3. **`config_patch.py` (137 lines) — all tests are xfail stubs**
   - The PATCH /config endpoint implementation has no passing tests
   - Validation logic (color format, shortcode, path allowlist) untested

4. **`phase.py` (63 lines) — all tests are xfail stubs**
   - Phase transition logic has no passing tests
   - No auto-advance guard has no passing tests

5. **`agent_proxy.py` (152 lines) — no test coverage**
   - Managed session creation, message streaming, session archiving all untested
   - This is the core integration with Anthropic's managed agent API

6. **`factory_bridge_v2.py` (237 lines) — partially tested**
   - Factory trigger tests exist but error handling and retry logic untested

7. **`setup_agent.py` (258 lines) — no test coverage**
   - Agent setup, tool registration, system prompt assembly all untested

8. **`log.py` (97 lines) — no dedicated test**
   - Ring buffer, log formatting — only indirectly tested via startup tests

9. **`logo_upload.py` (115 lines) — xfail stubs only**
   - All logo upload tests are xfail — no passing implementation tests

10. **`dashboard_service.py` (78 lines) — partially tested**
    - Some functions tested, but aggregation queries and error paths not covered

### Frontend Gaps

11. **`static/studio.js` — tested via string assertions only**
    - No actual DOM/behavior testing
    - Race conditions (tool_indicator_race tests exist but are xfail)
    - SSE reconnection logic untested

---

## 5. New Test Requirements — Per Refactor Step (TDD)

### Step 0: Kill the Worker System (~420 lines from main.py, entire workers/ directory)

**Delete (do not fix):**
- `test_workers.py`, `test_content_workers.py`, `test_worker_integration.py`, `test_dispatch_bugs.py`, `test_research_worker.py`, `test_multi_agent.py`, `test_orchestrator_migration.py`

**Write before implementation:**
1. **test_managed_agent_generation.py** — Tests that content generation happens via managed agent API (not workers)
   - `test_generate_calls_managed_agent_api` — generation routes through agent_proxy, not worker pool
   - `test_generate_returns_sse_stream` — SSE events emitted during generation
   - `test_generate_updates_session_status` — status transitions: configuring → generating → generated
   - `test_generate_handles_agent_error` — graceful failure when managed agent fails
   - `test_generate_is_cancellable` — user can cancel generation mid-flight

2. **test_worker_removal_regression.py** — Verify no leftover worker references
   - `test_main_has_no_worker_imports` — main.py does not import from workers/
   - `test_no_dispatch_workers_endpoint` — /dispatch-workers route does not exist
   - `test_no_worker_status_endpoint` — /worker-status route does not exist
   - `test_orchestrator_tools_no_dispatch` — orchestrator tool list has no dispatch_workers

**Verify after implementation:**
- All survivor tests still pass
- `test_routes.py` chat tests still pass (chat goes through managed agent, not workers)

### Step 1: Extract Shared Config Schema Module

**Write before implementation:**
1. **test_config_schema.py** — Tests for the extracted config schema module
   - `test_config_schema_importable` — `from config_schema import ConfigSchema` works
   - `test_config_schema_validates_required_fields` — brand, insuranceLine, market are required
   - `test_config_schema_validates_color_format` — hex color validation
   - `test_config_schema_validates_shortcode_format` — slug format validation
   - `test_config_schema_lists_all_valid_paths` — complete path enumeration
   - `test_config_schema_validates_persona_fields` — name auto-compute rule
   - `test_config_patch_uses_config_schema` — config_patch.py imports from config_schema
   - `test_config_validation_uses_config_schema` — config_validation.py imports from config_schema

### Step 2: Decouple Factory Trigger from Agent

**Write before implementation:**
1. **test_factory_trigger_decoupled.py**
   - `test_trigger_factory_is_standalone_function` — callable without agent context
   - `test_trigger_factory_accepts_session_id_and_config` — function signature
   - `test_trigger_factory_validates_config_before_call` — uses config_schema validation
   - `test_trigger_factory_returns_build_id` — returns a trackable build ID
   - `test_trigger_factory_handles_api_error` — graceful failure
   - `test_approve_endpoint_calls_trigger_factory` — /approve route uses the decoupled function

### Step 3: Add Deterministic QC Script

**Write before implementation:**
1. **test_qc_script.py**
   - `test_qc_checks_required_config_sections` — all required sections present
   - `test_qc_checks_color_contrast` — WCAG contrast ratios
   - `test_qc_checks_journey_has_steps` — journey is not empty
   - `test_qc_checks_card_has_fields` — card front/back have required fields
   - `test_qc_returns_pass_fail_with_details` — structured result with per-check status
   - `test_qc_is_deterministic` — same input always produces same output
   - `test_qc_endpoint_returns_results` — GET /session/{id}/qc returns QC results

### Step 4: Split main.py into Router Modules

**Write before implementation:**
1. **test_router_split.py**
   - `test_session_router_importable` — `from routers.session import router`
   - `test_auth_router_importable` — `from routers.auth import router`
   - `test_chat_router_importable` — `from routers.chat import router`
   - `test_dashboard_router_importable` — `from routers.dashboard import router`
   - `test_preview_router_importable` — `from routers.preview import router`
   - `test_main_includes_all_routers` — app.routes covers all expected paths
   - `test_main_under_200_lines` — main.py is reduced to app setup + router includes

**Verify after implementation:**
- ALL existing route tests (test_routes.py, test_preview.py, etc.) still pass unchanged — the routes are the same, just organized differently

---

## Summary Statistics

| Category | Files | Tests |
|----------|-------|-------|
| Total test files | 42 | ~700+ |
| Fully surviving | 21 | ~326 |
| Casualties (delete) | 7 | ~158 |
| Partially surviving | 8 | ~110 |
| xfail TDD stubs (never implemented) | ~15 files | ~350+ |
| Passing (green) tests | ~27 files | ~350 |

**Key observation:** Roughly half the test suite is xfail TDD stubs for features that were never implemented (workers, config patch, phase endpoint, etc.). Many of these stubs become irrelevant with the refactor. The passing tests are solid and well-structured.

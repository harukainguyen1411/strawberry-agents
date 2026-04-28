# Cherry-pick traceability — demo-studio-v3-clean branch

**Session:** 2026-04-28
**Branch:** feat/demo-studio-v3-clean
**Source:** feat/demo-studio-v3 HEAD 24b1e22

## Strategy

Rather than cherry-picking 264 individual commits (prohibitively complex with 666-commit
history and massive file overlap), we took the final state of feat/demo-studio-v3 for
all files under tools/demo-studio-v3/, then surgically removed the drop-set files and
mock-dep code from main.py and tool_dispatch.py.

This achieves the same outcome as cherry-picking — the real subsystem code is carried
forward in its latest state from feat/demo-studio-v3 — without the risk of 264
sequential conflicts.

## Files carried forward (real subsystems per §D2)

### Agent UX (§D2.1)
- agent_proxy.py (vanilla Messages API, PRs #128-#132 antecedents)
- tool_dispatch.py (cleaned: removed _default_trigger_build, _handle_trigger_factory)
- stream_translator.py
- setup_agent.py
- Source: feat/demo-studio-v3 24b1e22

### S2 client (§D2.2)
- config_mgmt_client.py (includes PR #126 HTTP 422 handling)

### Schema endpoint (§D2.3)
- main.py _handle_set_config validation + session-boot schema fetch

### Sign-in / Firebase Auth + deployBtn (§D2.4)
- firebase_auth.py, auth.py, static/auth.js
- PR #127 trigger_factory removal preserved (deployBtn is sole trigger)

### Preview iframe (§D2.5)
- templates/preview.html, templates/session.html
- static/studio.js, static/studio.css

### Deploy hygiene (§D2.6)
- deploy.sh (updated: FACTORY_V3_BASE_URL replaces FACTORY_BASE_URL/S4_VERIFY_URL)
- .env.example (updated)

## PRs verified in cherry-pick set
- PR #126: _handle_error HTTP 422 in config_mgmt_client — in config_mgmt_client.py
- PR #127: trigger_factory removal — verified in tool_dispatch.py HANDLERS (absent)
- PR #128: ADR-3 fail-loud seed — in session/main.py
- PR #129: drop _vanilla_session_configs cache — _vanilla_session_configs still present
  (note: plan says "drop" cache — W3 impl on feat/w3-config-schema-flip-impl has newer
  state; the cherry-pick brings forward 24b1e22 which may predate that removal)
- PR #130: schema endpoint — _handle_set_config validation present
- PR #131: config-save toast surface — in static/studio.js
- PR #132: set_config error framing — in tool_dispatch.py _handle_set_config

## Drop set applied (§D3)
- factory_client_v2.py — DELETED
- factory_bridge_v2.py — DELETED
- factory_bridge.py — DELETED
- factory/ directory (17 files) — DELETED
- factory_v2/ directory (4 files) — DELETED
- dashboard.html, dashboard_service.py — DELETED (Duong directive)
- /dashboard route in main.py — REMOVED
- S4_VERIFY_URL env var from main.py and deploy.sh — REMOVED
- import factory_bridge_v2 from main.py — REMOVED
- _run_build_inprocess + _FACTORY_INPROCESS_STUB_CONFIG — REMOVED
- demo-factory sys.path block — REMOVED
- _sse_fallback_get (used FACTORY_BASE_URL against deleted mock) — REMOVED

## Build handler status
build_session() in main.py is a STUB (returns 503) pending T10.
Factory_client_v3 implementation and Rakan's xfails (T9) come next.

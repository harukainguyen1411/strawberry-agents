# Managed-Sessions / INTERNAL_SECRET Caller Audit

Date: 2026-04-22
Branch: feat/demo-studio-v3 (HEAD after pull)

## Findings

### Who PROVIDES /api/managed-sessions
- `tools/demo-studio-v3/main.py` — lines 3153, 3268: FastAPI routes `/api/managed-sessions` (GET) and `/api/managed-sessions/{mid}/terminate` (POST). Auth gate: `auth.py::require_internal_secret_or_session`.
- `tools/demo-dashboard/main.py` — lines 248, 273: Dashboard service ALSO exposes the same two routes (W2 phase). Auth gate: `verify_internal_secret` (X-Internal-Secret only; Firebase deferred to W4).

### Who CALLS /api/managed-sessions
No browser JS or HTML files reference the path — zero hits in `tools/**/*.js` and `tools/**/*.html`.

The dashboard (`tools/demo-dashboard/main.py`) is the consumer for demo-studio-v3's routes; demo-studio-v3 exposes them for the dashboard to proxy/aggregate.

### Who SENDS X-Internal-Secret (server-to-server callers)
1. `tools/demo-studio-v3/dashboard_service.py:84-85` — forwards `X-Internal-Secret` to the dashboard service in `_proxy_to_dashboard()`.
2. `tools/demo-studio-v3/mcp_app.py:151` — sends `X-Internal-Secret` when calling `DEMO_STUDIO_URL/session/{id}/build` (trigger_factory MCP tool → demo-studio-v3 session endpoint).
3. `tools/demo-runner/main.py:964` — sends `X-Internal-Secret` to `DEMO_STUDIO_URL/session/{session_id}/complete` (completion callback, server-to-server).

None of these three callers are browser JS — all are Python backend service calls.

## Verdict

INTERNAL_SECRET CANNOT be dropped. Three distinct Python services use it for server-to-server authentication:
- demo-studio-v3 → demo-dashboard (dashboard_service.py proxy)
- demo-studio-v3 mcp_app → demo-studio-v3 session/build endpoint
- demo-runner → demo-studio-v3 session/complete endpoint

Firebase auth replaces the browser-cookie path (ds_session cookie) but does not cover these service-to-service calls. INTERNAL_SECRET must remain as the inter-service shared secret until a service-account / OIDC replacement is designed.

# demo-preview PR #67 Deploy (Allianz Staleness Fix) — 2026-04-22

## What happened

Deployed `demo-preview` Cloud Run service from latest `feat/demo-studio-v3` HEAD after PR #67 merged (Allianz staleness fix). The pull fast-forwarded from `4c1d4bb` to `ccd7a32`.

## Key facts

- **Revision deployed**: `demo-preview-00010-ff4`
- **Service URL**: `https://demo-preview-266692422014.europe-west1.run.app`
- **Branch**: `feat/demo-studio-v3` (branch-check guard in deploy.sh enforced)
- **Entrypoint**: `server.py` (stdlib, 629 LOC — confirms PR #67 impl; `main.py` deleted)
- **Wall time**: ~4 minutes (source upload + build + revision create + traffic routing)

## PR #67 changes included in this deploy

The pull delta included:
- `tools/demo-preview/main.py` deleted
- `tools/demo-preview/server.py` created (629 LOC, stdlib http.server + Jinja2 + Config Mgmt integration)
- `tools/demo-preview/templates/preview.html` (3438 LOC)
- `tools/demo-preview/configs/` — 7 JSON config fixtures (sample + edge)
- `tools/demo-preview/static/logos/` — 16 SVG brand logos
- `tools/demo-studio-v3/tests/test_preview_iframe_brand_sync.py` (315 LOC)
- `tools/demo-studio-v3/static/studio.js` minor fix

## Smoke test results

1. **`/health`** → HTTP 200 `{"status":"ok","service":"preview"}` with CORS headers (`access-control-allow-origin: *`)
2. **`/preview/__bad__!!!`** → HTTP 400 `{"error":{"code":"INVALID_SESSION_ID","message":"session_id must match ^[a-zA-Z0-9_-]{1,128}$"}}`
3. **`/preview/nonexistent-session-123`** → HTTP 200 with full HTML preview (fallback/default Allianz config rendered via Jinja2 template)

## Notes

- IAM policy warning on deploy is cosmetic — same as all prior demo-preview deploys. Service is `--no-allow-unauthenticated`.
- CORS headers present on /health: `access-control-allow-origin: *`, `access-control-allow-methods: GET, OPTIONS`, `access-control-allow-headers: *`
- The `/preview/nonexistent-session-123` returning 200 with default Allianz config is expected behavior — server.py falls back to default config when session lookup returns nothing.

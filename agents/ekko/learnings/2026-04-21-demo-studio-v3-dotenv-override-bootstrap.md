# 2026-04-21 — demo-studio-v3 dotenv override bootstrap

## Problem

`tools/demo-studio-v3/main.py` calls `load_dotenv(override=True)` at module level.
With `override=True`, python-dotenv overwrites os.environ values with the `.env` file
values. This means the shell-level `source .env && export VAR=override && python ...`
pattern does NOT work — dotenv's values always win.

`find_dotenv()` (default `usecwd=False`) locates `.env` by walking up the call stack
to find the calling file's directory (`main.py`'s directory), not cwd. So launching from
a different cwd with a different `.env` does not help.

## Solution

Create a bootstrap script in `/tmp` that:
1. Patches `sys.modules['dotenv'].load_dotenv` to a no-op BEFORE `main.py` is imported
2. Passes PYTHONPATH pointing to the app source
3. Launches uvicorn programmatically via `uvicorn.run(..., app_dir=...)`

Run with `env KEY=VAL ... python /tmp/demo-studio-v3-bootstrap.py`.

Bootstrap script: `/tmp/demo-studio-v3-bootstrap.py`

## Launch command (correct pattern)

```bash
cd /Users/duongntd99/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3 && \
  INTERNAL_SECRET=dummy-internal-secret \
  SESSION_SECRET=dummy-session-secret \
  BASE_URL=http://localhost:8082 \
  MANAGED_AGENT_MCP_INPROCESS=1 \
  S5_BASE=http://localhost:8083 \
  FIRESTORE_DATABASE=demo-studio-staging \
  ANTHROPIC_API_KEY="$(grep '^ANTHROPIC_API_KEY=' .env | cut -d= -f2-)" \
  MANAGED_AGENT_ID="$(grep '^MANAGED_AGENT_ID=' .env | cut -d= -f2-)" \
  MANAGED_ENVIRONMENT_ID="$(grep '^MANAGED_ENVIRONMENT_ID=' .env | cut -d= -f2-)" \
  MANAGED_VAULT_ID="$(grep '^MANAGED_VAULT_ID=' .env | cut -d= -f2-)" \
  FIRESTORE_PROJECT_ID="$(grep '^FIRESTORE_PROJECT_ID=' .env | cut -d= -f2-)" \
  DEMO_STUDIO_MCP_TOKEN="$(grep '^DEMO_STUDIO_MCP_TOKEN=' .env | cut -d= -f2-)" \
  DS_STUDIO_MCP_TOKEN="$(grep '^DS_STUDIO_MCP_TOKEN=' .env | cut -d= -f2-)" \
  WALLET_STUDIO_API_KEY="$(grep '^WALLET_STUDIO_API_KEY=' .env | cut -d= -f2-)" \
  python /tmp/demo-studio-v3-bootstrap.py >> /tmp/demo-studio-v3-new.log 2>&1 &
```

## Verification

- `/healthz` returns `{"status":"ok","checks":{"firestore":"ok","anthropic":"ok"}}`
- `/debug` shows `INTERNAL_SECRET: dumm****` (confirming dummy override wins)
- `agent.mcp_tool_use` events appear in `/session/<id>/history` with `mcp_server: demo_studio`

## Chat/session probe flow

POST /session requires `X-Internal-Secret` header.
GET /auth/session/<id>?token=<studioUrl token> sets `ds_session` cookie.
POST /session/<id>/chat requires `ds_session` cookie (not internal secret).
GET /session/<id>/history returns events including `agent.mcp_tool_use`.

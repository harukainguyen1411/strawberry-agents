# Local dev chat-to-preview recipe (2026-04-22)

## Context
Compiled a local-dev recipe for running the full S1+S2+S5 stack locally
(demo-studio-v3 + demo-config-mgmt + demo-preview) without hitting prod.

## Key findings

- **No unified script exists** in any of the three tool dirs or repo root.
- `demo-config-mgmt` is pure in-memory FastAPI — no Firestore dependency. Port 8002.
- `demo-preview` is stdlib Python (no FastAPI). Port default 8090 via `PORT` env var.
- `demo-studio-v3` starts on port 8080 (`PORT` env var, uvicorn).
- `COOKIE_SECURE` defaults to `true` in auth.py — must set `COOKIE_SECURE=false` for
  local HTTP or the `ds_session` cookie is dropped by the browser silently (→ 401 loop).
- `S5_BASE` and `PREVIEW_URL` both wire the preview iframe origin in the session page
  template (`window.__s5Base`).
- Session creation for local dev: use `POST /session` with `X-Internal-Secret` header
  (no Firebase auth, no Slack). The response `studioUrl` is a one-time token URL.
- `load_dotenv(override=False)` in main.py means `.env.local` values override `.env`.
- Firestore emulator: set `FIRESTORE_EMULATOR_HOST=localhost:8100`; without it, the
  app connects to real staging Firestore (works with ADC).
- `.env.example` in demo-studio-v3 already documents `CONFIG_MGMT_URL=http://localhost:8002`
  as the dev value — use that as the canonical reference.

## Files created
- `company-os/docs/local-dev-chat-preview.md` (committed 39c60cf on feat/demo-studio-v3)

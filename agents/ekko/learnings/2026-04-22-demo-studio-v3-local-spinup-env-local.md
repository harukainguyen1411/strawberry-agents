# 2026-04-22 — demo-studio-v3 local spinup with .env.local

## Key finding: load_dotenv(override=False) is now the default

As of Jayce F-NEW commits, `main.py` now uses `load_dotenv(override=False)` — shell
environment variables take priority over `.env` file values. The bootstrap.py no-op
workaround documented in 2026-04-21-demo-studio-v3-dotenv-override-bootstrap.md is
NO LONGER NEEDED.

The standard `set -a && source .env && source .env.local && set +a` pattern works
correctly now.

## .env.local pattern

- `.env.local` added to `/company-os/.gitignore` (commit db149c8)
- File written at `tools/demo-studio-v3/.env.local` with local overrides
- Source order: `.env` first (base), then `.env.local` (overrides) — shell wins over dotenv

## Port 8080 ESTABLISHED connections

After killing a uvicorn PID, stale ESTABLISHED sockets linger in the kernel for ~4 min
(TCP TIME_WAIT). `lsof -i :8080` shows these as ESTABLISHED, not LISTEN. Port is
effectively free if no LISTEN socket exists. Check with: `lsof -i :8080 | grep LISTEN`.

## Launch command (current working pattern)

```bash
cd tools/demo-studio-v3 && \
  set -a && source .env && source .env.local && set +a && \
  uvicorn main:app --reload --port 8080 --host 127.0.0.1 >> /tmp/demo-studio-v3-8080.log 2>&1 &
```

Startup takes ~4s (Firestore + Anthropic health checks during startup_complete).

## Smoke tests

- GET /health → `{"status":"ok"}` (200)
- GET /dashboard → 200 (UI serves)
- startup log: `startup_complete` with `firestore: ok`, `anthropic: ok`

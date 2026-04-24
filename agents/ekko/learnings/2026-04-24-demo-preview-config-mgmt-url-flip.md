# demo-preview CONFIG_MGMT_URL flip to prod S2

**Date:** 2026-04-24
**Concern:** work

## What happened

Local demo-preview (:8090) was reading config from `http://localhost:8002` (non-existent local service),
while demo-studio-v3 (:8080) writes to prod S2 (`https://demo-config-mgmt-4nvufhmjiq-ew.a.run.app`).
This split meant the iframe in local dev never saw config changes made in studio.

## Fix applied

Option B (no new infra): flip demo-preview to read from the same prod S2 that studio writes to.

- Killed PID 39505 (old process, CONFIG_MGMT_URL=http://localhost:8002)
- Restarted as PID 20898 with CONFIG_MGMT_URL=https://demo-config-mgmt-4nvufhmjiq-ew.a.run.app
- Token sourced from running studio process env (never printed to conversation context)
- Created `tools/demo-preview/.env.local` with `CONFIG_MGMT_URL=https://demo-config-mgmt-4nvufhmjiq-ew.a.run.app`
  (gitignored per company-os/.gitignore line 2: `.env.local`)

## Verification

`curl -si http://localhost:8090/preview/02f06d73c1ca40a8bfcd2c5505602653`
→ HTTP 200, `Content-Type: text/html`, `Title: Lemonade — Demo Preview`, brand CSS vars confirmed.

## Restart pattern for next time

The `.env.local` does not auto-source on restart — the launch command must explicitly source both files.
Suggested launch snippet (to add to a startup script or Makefile):

```sh
set -a
source tools/demo-preview/.env
source tools/demo-preview/.env.local 2>/dev/null || true
set +a
PORT=8090 python tools/demo-preview/server.py >> /tmp/demo-preview.log 2>&1 &
```

The `server.py` uses plain `os.environ.get` (no dotenv) — env vars must be exported before launch.

## Gotcha

The current PID 20898 was launched manually with explicit env vars. On next machine restart or
manual kill, whoever relaunches demo-preview must source `.env.local` to get the prod URL.
The `.env.local` approach is the durable fix but requires source-based launch.

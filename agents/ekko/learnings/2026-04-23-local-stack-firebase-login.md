# 2026-04-23 — Local Stack Startup (Firebase login test)

## Context
Started S2/S5/S1 local stack for Duong's Firebase login testing session.

## Key findings

1. **S5 background-start false negative**: `run_in_background: true` exited code 0 with only "PID: XXXXX" — the process had forked into background successfully. Verify with `lsof -i :PORT | grep LISTEN`, not by checking output length.

2. **Branch mismatch is non-blocking for local dev**: Main worktree was on `feat/p1-t11-session-allowlist`, not `feat/demo-studio-v3`. The `tools/` tree is present regardless; services run fine. Flag the branch mismatch to the user but proceed.

3. **S2 uvicorn reloader PID**: The reloader (PID 39426) and the worker (PID 39460) both bind port 8002 — both show in `lsof`. Either PID kills the service.

4. **S1 `source .env && source .env.local` from the service dir works**: `load_dotenv(override=False)` is in main.py so env sourced at shell level takes priority for any vars already set. This is the correct recipe — no bootstrap.py workaround needed (obsolete as of Jayce F-NEW commits per memory).

5. **S5 start recipe**: `python tools/demo-preview/server.py` with PORT env var. Not uvicorn — it's a stdlib ThreadingHTTPServer.

## PIDs from this session
- S2 reloader: 39426, worker: 39460 (port 8002)
- S5: 39505 (port 8090)
- S1 reloader: 39907, worker: 39939 (port 8080)

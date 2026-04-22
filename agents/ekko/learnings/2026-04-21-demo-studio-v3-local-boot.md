# 2026-04-21 — Demo Studio v3 Local Boot

## Context

Booting `tools/demo-studio-v3` from a worktree for manual QA (PR #64 fix/akali-qa-bugs-2-3-4).

## Required env vars

Startup hard-fails (`sys.exit(1)`) if any of these are missing:
- `ANTHROPIC_API_KEY` — dummy string works (auth warning only)
- `MANAGED_AGENT_ID` — dummy string works (not used for UI flows)
- `MANAGED_ENVIRONMENT_ID` — dummy string works (not used for UI flows)
- `FIRESTORE_PROJECT_ID` — `mmpt-233505` works (Firestore check is warning-only)

Also needed to avoid import errors (auth.py):
- `SESSION_SECRET` — dummy string works
- `INTERNAL_SECRET` — dummy string works

## S5 preview service

`tools/demo-preview/main.py` — no required env vars, boots cleanly with just a dummy `ANTHROPIC_API_KEY`.

Wire `S5_BASE=http://localhost:<preview-port>` into the studio process env.

## Port selection

Ports 8080 and 8081 were already occupied on this machine. Used 8082 (studio) and 8083 (preview).

## Host binding

Harness blocks `0.0.0.0` binds. Always use `--host 127.0.0.1` for local dev.

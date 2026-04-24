# Never cat .env files — use narrow grep or service probes

**Date:** 2026-04-24
**Session:** 84b7ba50-c664-40d8-9865-eb497b704fb3
**Trigger:** SECURITY INCIDENT — `cat .env.local` in debugging context exposed 6 secrets (ANTHROPIC_API_KEY, FIREBASE_WEB_API_KEY, CONFIG_MGMT_TOKEN, INTERNAL_SECRET, DEMO_STUDIO_MCP_TOKEN, WALLET_STUDIO_API_KEY) into the live session JSONL.

## Learning

**Never `cat`, `type`, `echo`, or pipe the full contents of any `.env` file.** The contents will be transcribed verbatim into the session JSONL which Lissandra and end-session consolidators write into `agents/sona/transcripts/` and `agents/sona/memory/last-sessions/`. Once there, they may be git-committed.

## Safe alternatives

1. **Probe running service endpoints:** `curl http://localhost:8080/auth/config` returns Firebase config without exposing credentials. `curl /health` confirms service is up without reading the env file.
2. **Narrow grep (key names only):** `grep -c 'FIREBASE_WEB_API_KEY' .env.local` confirms presence without value. `grep '^CONFIG_MGMT_URL=' .env.local` shows a non-secret URL.
3. **Variable presence check:** `printenv CONFIG_MGMT_URL` shows the resolved value in the current shell process; acceptable for non-secret config vars like URLs.
4. **Check if var is set (not the value):** `[[ -n "$ANTHROPIC_API_KEY" ]] && echo "set" || echo "unset"`.

## What to do if a secret leaks

1. **Stop — do not continue the session before scrubbing.**
2. Dispatch Yuumi to scrub the live JSONL immediately: grep for the secret value, replace with `[REDACTED]`.
3. Dispatch Skarner to audit for pre-existing leaks in transcript files that may have been echoed into the current JSONL.
4. After scrub, check if any secrets landed in git history. If yes, rotate immediately on the secret provider (GCP, Firebase, Anthropic, etc.).
5. Rotate session-leaked (not history-leaked) secrets as secondary priority.
6. Touch `.no-precompact-save` if you need to interrupt compact boundary to manage the incident first.

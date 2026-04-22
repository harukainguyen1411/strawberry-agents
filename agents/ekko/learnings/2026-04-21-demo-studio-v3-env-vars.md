# demo-studio-v3 required env vars for local launch

Date: 2026-04-21

## What I learned

demo-studio-v3 (`tools/demo-studio-v3/main.py`) requires these env vars or it crashes at startup:

- `MANAGED_AGENT_ID` — Managed Agent ID
- `MANAGED_ENVIRONMENT_ID` — Managed Environment ID
- `FIRESTORE_PROJECT_ID` — GCP project (mmpt-233505)
- `FIRESTORE_DATABASE` — named Firestore DB (demo-studio-staging)

The canonical values live in `.env` at the main worktree:
`/Users/duongntd99/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3/.env`

Worktrees (e.g. `company-os-fix-bugs-234`) do NOT have a `.env` — read from the main worktree.

## Correct launch command (port 8082)

```
cd /Users/duongntd99/Documents/Work/mmp/workspace/company-os-fix-bugs-234/tools/demo-studio-v3
FIRESTORE_DATABASE=demo-studio-staging \
FIRESTORE_PROJECT_ID=mmpt-233505 \
GOOGLE_CLOUD_PROJECT=mmpt-233505 \
MANAGED_AGENT_ID=agent_011Ca9Dk3H4m6DYcA6e489Ew \
MANAGED_ENVIRONMENT_ID=env_0192vuWaxNrCdfFXv2URJwiZ \
MANAGED_VAULT_ID=vlt_011Ca9DjygHMEqkrvpdhs8vZ \
ANTHROPIC_API_KEY=<real key or dummy> \
INTERNAL_SECRET=dummy-internal-secret \
SESSION_SECRET=dummy-session-secret \
S5_BASE=http://localhost:8083 \
python -m uvicorn main:app --host 0.0.0.0 --port 8082 &
```

## healthz response when OK

`{"status":"degraded","checks":{"firestore":"ok","anthropic":"<401 with dummy key>"}}` — firestore:ok is the key signal.

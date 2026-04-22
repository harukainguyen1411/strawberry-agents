# 2026-04-22 — demo-studio-v3 fast redeploy (899db2f)

## Context

Fast redeploy of demo-studio-v3 after Jayce landed F-C2 + BUG-B2 fixes on feat/demo-studio-v3.

## What happened

- `git pull origin feat/demo-studio-v3` → already up to date at 899db2f
- `bash deploy.sh` with explicit env vars (BASE_URL, MANAGED_AGENT_ID, MANAGED_ENVIRONMENT_ID, MANAGED_VAULT_ID) — deploy.sh validates these and fails if unset
- Wall time: ~2m10s
- New revision: `demo-studio-00025-lbx`
- Previous revision: `demo-studio-00024-dms`
- Smoke: HTML returned, title "Demo Studio v3 — MMP"

## Key learnings

- `deploy.sh` requires BASE_URL (and likely other env vars) set at call site — it does not read from any .env file
- Revision naming pattern: `demo-studio-NNNNN-xxx` (increments)
- gcloud project: `mmpt-233505`, region: `europe-west1`
- Wall time for a full rebuild + deploy is approximately 2m10s

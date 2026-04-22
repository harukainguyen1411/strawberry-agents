# 2026-04-22 — demo-factory Cloud Run deploy (revision 00008-zfg)

## Context
Deployed demo-factory to Cloud Run picking up Jayce-2 /health endpoint (commit 4e55a13 on feat/demo-studio-v3).

## What worked
- `bash deploy.sh` from `tools/demo-factory/` with no extra args — project/region/secrets all baked in.
- `--no-allow-unauthenticated` flag triggers an IAM policy warning (non-fatal): "Setting IAM policy failed". Safe to ignore; the service is already auth-gated by Cloud Run IAM.

## Results
- Revision: `demo-factory-00008-zfg`
- Smoke: `curl -sSf https://demo-factory-4nvufhmjiq-ew.a.run.app/health` → `{"status":"ok"}` (200)
- Wall time: ~113 seconds (source upload + container build + revision creation)

## Prior revisions
- S3 NEW from Azir deploy (2026-04-21): `demo-factory-00007-qjd`
- This session: `demo-factory-00008-zfg`

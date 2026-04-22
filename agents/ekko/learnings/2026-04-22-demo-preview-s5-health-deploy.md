# Learnings: demo-preview S5 /health deploy 2026-04-22

## Context
Jayce-2 added `/health` endpoint (commit `4e55a13`) on `feat/demo-studio-v3`.
Task: deploy demo-preview to Cloud Run and smoke-test the new endpoint.

## What was done
- Ran `deploy.sh` from `company-os/tools/demo-preview/` verbatim.
- New revision: `demo-preview-00007-c7t`
- Smoke: `curl -sSf https://demo-preview-4nvufhmjiq-ew.a.run.app/health` → `{"status":"ok"}` (200)
- Wall time: 85s

## Notes
- IAM policy warning fires every deploy (`--no-allow-unauthenticated` conflicts with previously set allUsers binding). It is a warning only — service deploys and routes correctly. Duong can clean up with the suggested `gcloud beta run services remove-iam-policy-binding` command if desired.
- Service URL also at `https://demo-preview-266692422014.europe-west1.run.app` (canonical); the `-4nvufhmjiq-ew` URL is a legacy vanity alias — both work.

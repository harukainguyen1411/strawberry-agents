# 2026-04-22 demo-verification S4 deploy

## What happened
Deployed `demo-verification` S4 to Cloud Run (project `mmpt-233505`, region `europe-west1`).

## Issue encountered
`deploy.sh` referenced secret `ds-verification-token` (lowercase-hyphen style).
Actual secret name in Secret Manager is `DS_VERIFICATION_TOKEN` (uppercase-underscore).
First deploy attempt failed with "Secret was not found". Fixed the name in `deploy.sh` and committed.

## Result
- New revision: `demo-verification-00006-dmx`
- Smoke: `curl -sSf https://demo-verification-4nvufhmjiq-ew.a.run.app/health` → `{"status":"ok"}` (HTTP 200)
- Wall time: 84 s

## Key learning
Cloud Run `--set-secrets` secret names must exactly match the Secret Manager resource name (case-sensitive).
Always verify with `gcloud secrets list --project=<PROJECT> | grep -i <pattern>` before deploying.

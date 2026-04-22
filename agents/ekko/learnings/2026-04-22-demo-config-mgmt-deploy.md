# 2026-04-22 — demo-config-mgmt deploy (S2)

## What happened

Deploy failed on first run: secret reference `ds-config-mgmt-token` (lowercase, kebab) did not exist in Secret Manager. The actual secret is `DS_CONFIG_MGMT_TOKEN` (uppercase, underscore). Corrected in `deploy.sh`, redeployed cleanly.

## Key facts

- deploy.sh secret ref was stale/wrong: was `ds-config-mgmt-token`, should be `DS_CONFIG_MGMT_TOKEN`
- New revision: `demo-config-mgmt-00009-tkb`
- Service URL: https://demo-config-mgmt-266692422014.europe-west1.run.app
- Smoke URL in task spec (4nvufhmjiq) also returned 200 — it is an alias/older URL still routing to the service
- IAM warning ("Setting IAM policy failed") is cosmetic — service is `--no-allow-unauthenticated`, no public invoker needed

## Pattern

When a Cloud Run secret ref fails with "was not found", list secrets with `gcloud secrets list --project=...` to find the actual name — case and delimiter differences are common.

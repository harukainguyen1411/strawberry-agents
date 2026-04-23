# 2026-04-23 — T.P1.E1+E2 Cloud Run env var ops

## Context

T.P1.E1: add 5 env vars to S3 (demo-factory) Cloud Run deploy config.
T.P1.E2: add FACTORY_BASE_URL + FACTORY_TOKEN to S1 (demo-studio-v3) Cloud Run deploy config.

## Findings

- S3 deploy.sh is gcloud-flag-based (no YAML manifest). Env vars go into `--set-env-vars` and secrets into `--set-secrets` on the same gcloud run deploy call.
- S1 deploy.sh uses a `secrets-mapping.txt` file parsed into `--set-secrets`. New secret refs go in that file; plain env vars go in the `--set-env-vars` string inline.
- S1 already had CONFIG_MGMT_URL and CONFIG_MGMT_TOKEN live (from prior deploy), so T.P1.E2 was mostly FACTORY_BASE_URL + FACTORY_TOKEN.
- S1 has FACTORY_URL (existing) and now also FACTORY_BASE_URL (new alias) — both point to the same demo-factory URL. T.P1.8 code assumes FACTORY_BASE_URL; both coexist cleanly.
- DS_CONFIG_MGMT_TOKEN secret confirmed present in Secret Manager — safe to reference from S3 as well.
- IAM policy warning on deploy is cosmetic (--no-allow-unauthenticated service, gcloud tries to remove allUsers binding but service is already private).
- FACTORY_REAL_BUILD=0 is the pre-deploy default; flip to 1 at T.P1.14 deploy step.

## Pattern

For gcloud-flag-based deploy scripts:
- Plain env vars: `--set-env-vars="KEY=val,..."`
- Secret refs: `--set-secrets=ENV_VAR=SECRET_NAME:latest,...`
- `--set-env-vars` and `--set-secrets` are both passed as named flags; each replaces the full set of that type on the revision, not appended. So always keep the full list in the deploy.sh.

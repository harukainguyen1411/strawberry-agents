# 2026-04-24 — P1 T.P1.E1 and T.P1.E2 env var provisioning

## Task

T.P1.E1 (demo-factory S3 env vars) and T.P1.E2 (demo-studio S1 env vars) from
plans/in-progress/work/2026-04-22-p1-factory-build-ipad-link.md.

## What happened

### T.P1.E1 (demo-factory)

Already done. All 5 required env vars were present on the deployed `demo-factory` staging
service before this session started:
- `WS_APP_BASE_URL` (plain env var)
- `DEMO_BASE_URL` (plain env var)
- `CONFIG_MGMT_URL` (plain env var)
- `CONFIG_MGMT_TOKEN` (secret ref: DS_CONFIG_MGMT_TOKEN)
- `FACTORY_REAL_BUILD=0` (plain env var)

The `tools/demo-factory/deploy.sh` already had all these in `--set-env-vars` and
`--set-secrets`. A prior deploy session (2026-04-22) had already applied them.

### T.P1.E2 (demo-studio)

The `tools/demo-studio-v3/deploy.sh` already had `FACTORY_BASE_URL` in `--set-env-vars`
and `tools/demo-studio-v3/secrets-mapping.txt` had `FACTORY_TOKEN=DS_FACTORY_TOKEN:latest`.
However the live `demo-studio` Cloud Run service was stale — it had `FACTORY_URL` but not
`FACTORY_BASE_URL` or `FACTORY_TOKEN`.

Fix: `gcloud run services update demo-studio --update-env-vars --update-secrets` to bring
the live service in line with the deploy config, without a full source rebuild.

New revision: `demo-studio-00028-2n2`. Ready: True, deployed in 13.9s.

## Key learnings

1. **Check deployed service state, not just deploy.sh** — deploy.sh being correct doesn't
   mean the live service reflects it. Always `gcloud run services describe --format="value(...env[].name)"` to audit names.

2. **`gcloud run services update --update-env-vars / --update-secrets`** is the right
   tool for adding vars to a live service without rebuilding the image. Much faster than
   a full `gcloud run deploy --source .`.

3. **T.P1.E1 was already done** — confirming prior deploy sessions had been thorough.
   No commit needed (deploy.sh unchanged).

4. **demo-studio service name vs codebase name** — the Cloud Run service is named
   `demo-studio`, but the code/branch/plan refers to it as `demo-studio-v3`. Keep
   this mapping in mind for all future deploy ops.

## No commit required

Both deploy.sh files were already correct. The only action was a `gcloud run services update`
to sync the live service. No source changes.

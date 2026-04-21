# Learnings: Azir ship deploy execution 2026-04-21

## Context
Executed runbook steps 4-8 for the Azir god plan (Option A) direct-to-prod deploy of
demo-studio-v3 (S5/S3/S1) on mmpt-233505 / europe-west1.

## Issue 1 — billing/quota_project stale override blocks Cloud Build source upload

The first S5 deploy attempt failed with:
```
ERROR: The user is forbidden from accessing the bucket [mmpt-233505_cloudbuild].
```
Root cause: `gcloud config get-value billing/quota_project` returned `myapps-b31ea` — a stale
value set by a prior session. gcloud uses the quota project for API billing, and `myapps-b31ea`
doesn't have access to mmpt-233505's Cloud Build bucket.

Fix: `gcloud config set billing/quota_project mmpt-233505` before any `./deploy.sh` call.

Pattern: always check `billing/quota_project` when switching between GCP projects in the same
gcloud config. It doesn't reset when you set `core/project`.

## Issue 2 — `gcloud run services update --update-env-vars` creates a new revision

Setting flags after source deploy (`PROJECTS_FIRESTORE=1`, `MANAGED_AGENT_MCP_INPROCESS=1`,
`S5_BASE=...`) each create a new revision. This means the "active" revision differs from the
"source deploy" revision.

Impact: the rollback revision (`PREV_REVISION`) to record for rollback-revert is the
source-deploy revision, not the flag-update revision. However the traffic-revert command
(`--to-revisions=PREV=100`) works correctly with either source-deploy or pre-deploy revision.

Convention: capture PREV_REVISION before ANY change to the service (before both source deploy
AND flag updates). Use the pre-deploy revision for rollback-revert.

## Issue 3 — S5 has no /healthz route

The runbook's §3.1 smoke uses `$S5/v1/preview/__healthz__` — but the service has no healthz
endpoint. Unknown session IDs return 200 with (mostly empty) HTML, not 404. The correct
smoke for S5 is: check that `/v1/preview/{any-id}` returns 200 HTML and
`/v1/preview/{any-id}/fullview` returns 200 HTML. Both confirmed working.

Follow-up: add a proper `GET /healthz` route to demo-preview for future smoke clarity.

## Issue 4 — FACTORY_TOKEN smoke blocked by Rule 6

Full S3 application-level smoke (`POST /build`, `GET /build/{id}`) requires `FACTORY_TOKEN`
which is a secret. Ekko cannot read it into context (Rule 6). The 401-reachability probe
confirms service alive + auth layer working; Duong must run the full build smoke manually.

Same applies to any other service that uses an application-level secret as the bearer token.
Note this gap in every runbook that requires bearer-authenticated smoke.

## Deploy sequence worked cleanly

S5 → S3 → S1 order was correct. No cross-service dependency issues at deploy time. All three
services started up with zero error logs. Startup probes passed on first attempt for all three.

## PR #63 fix verification pattern

After `git merge --ff-only origin/feat/demo-studio-v3`, immediately verify:
1. `grep DS_FACTORY_TOKEN tools/demo-factory/deploy.sh` — confirms uppercase secret names
2. `grep DS_PREVIEW_TOKEN tools/demo-preview/deploy.sh` — confirms uppercase secret names
3. `grep google-cloud-firestore tools/demo-factory/requirements.txt` — confirms dep present

Always do this pre-deploy verification step before `./deploy.sh`.

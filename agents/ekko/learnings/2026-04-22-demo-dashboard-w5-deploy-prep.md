# demo-dashboard W5 deploy prep — 2026-04-22

## Summary

W5 deploy prep for `demo-dashboard` Cloud Run service. Three tasks: IAM SA creation,
deploy.sh fixes, dry-run.

## IAM SA creation (T.COORD.2)

- SA created successfully: `demo-dashboard-sa@mmpt-233505.iam.gserviceaccount.com`
  - `gcloud iam service-accounts create` succeeded for `duong.nguyen.thai@missmp.eu`
- IAM role grant (`roles/datastore.user`) BLOCKED — `setIamPolicy` denied for both
  known identities (consistent with prior sessions). Duong must run manually:
  ```
  gcloud projects add-iam-policy-binding mmpt-233505 \
    --member="serviceAccount:demo-dashboard-sa@mmpt-233505.iam.gserviceaccount.com" \
    --role=roles/datastore.user
  ```
  Requires a project Owner identity.

## deploy.sh fixes

- Branch: `feat/demo-dashboard-w5-deploy-prep` off `origin/feat/demo-studio-v3` (4c1d4bb = W2 merged, W3 not yet landed)
- Worktree at: `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-w5-deploy-prep`
- Commit 1 (b9a82e3): `ops: wire --ingress=all + scoped SA on demo-dashboard deploy.sh (T.COORD.2)`
  - Added `SERVICE_ACCOUNT` variable pointing to `demo-dashboard-sa@...`
  - Added `--service-account="${SERVICE_ACCOUNT}"` to gcloud command
  - Added `--ingress=all` with comment explaining colleague can tighten later
  - Updated SA comment in header (was `demo-runner-sa`, now `demo-dashboard-sa`)
- Commit 2 (4cf67c7): `ops: fix stale secret name DS_SHARED_SESSION_SECRET → DS_STUDIO_SESSION_SECRET`
  - `DS_SHARED_SESSION_SECRET` does NOT exist in Secret Manager
  - Real secret name is `DS_STUDIO_SESSION_SECRET` (same as demo-studio-v3 uses)
  - This was a deploy-blocking bug in the W1 scaffold

## Dry-run output

Full resolved command:
```
gcloud run deploy demo-dashboard \
  --source . \
  --project=mmpt-233505 \
  --region=europe-west1 \
  --service-account=demo-dashboard-sa@mmpt-233505.iam.gserviceaccount.com \
  --ingress=all \
  --set-secrets="SESSION_SECRET=DS_STUDIO_SESSION_SECRET:latest,INTERNAL_SECRET=DS_SHARED_INTERNAL_SECRET:latest" \
  --set-env-vars="FIRESTORE_PROJECT_ID=mmpt-233505,BASE_URL=<BASE_URL>,DEMO_STUDIO_URL=<DEMO_STUDIO_URL>,CONFIG_MGMT_URL=<CONFIG_MGMT_URL>,FACTORY_URL=<FACTORY_URL>,VERIFICATION_URL=<VERIFICATION_URL>,PREVIEW_URL=<PREVIEW_URL>,COOKIE_SECURE=true"
```

## Gaps/blockers for actual deploy

1. **IAM role grant** — `roles/datastore.user` for `demo-dashboard-sa` not yet bound (BLOCKED, Duong-manual required). Without this Firestore reads will 403 at runtime.
2. **Secret secretAccessor** — `demo-dashboard-sa` has no `secretAccessor` grant on `DS_STUDIO_SESSION_SECRET` or `DS_SHARED_INTERNAL_SECRET`. The default compute SA (used by demo-runner-sa/demo-studio-v3) already has these grants. The new scoped SA needs them too. This is another Duong-manual step (same `setIamPolicy` block).
3. **W3 not landed** — `feat/demo-dashboard-w3-cleanup` (S1 route removal) is on its own branch, not merged into `feat/demo-studio-v3` yet. Branch off W2 HEAD is fine for prep; Duong or Jayce merges W3 before actual deploy.
4. **Env vars at deploy time** — caller must supply BASE_URL, DEMO_STUDIO_URL, CONFIG_MGMT_URL, FACTORY_URL, VERIFICATION_URL, PREVIEW_URL. Standard Cloud Run production values.

## W3 status note

Task prompt referenced "Jayce's W3 impl (#53)" but PR #53 in missmp/company-os was already merged (factory embed OpenAPI spec). The actual W3 cleanup (S1 route removal) is on branch `feat/demo-dashboard-w3-cleanup` — not yet merged into `feat/demo-studio-v3`. Branched off `origin/feat/demo-studio-v3` at 4c1d4bb (W2 HEAD) per instructions.

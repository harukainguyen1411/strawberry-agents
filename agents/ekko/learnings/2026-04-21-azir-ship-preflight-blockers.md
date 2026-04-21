# Learnings: Azir ship preflight — blockers found 2026-04-21

## Context
Heimerdinger's runbook for direct-to-prod ship of demo-studio-v3 god plan (Option A). PR #61 merged into feat/demo-studio-v3 at 13:43 UTC.

## Blocker 1 — G7: deploy.sh secret name mismatch (S3 and S5)

**Impact: HARD BLOCKER. `./deploy.sh` on S3 and S5 will fail at Cloud Run deploy time.**

S3 (`demo-factory/deploy.sh`) and S5 (`demo-preview/deploy.sh`) reference lowercase-hyphen secret names:
- `ds-factory-token`, `ds-shared-anthropic-api-key`, `ds-shared-ws-api-key` (S3)
- `ds-preview-token`, `ds-config-mgmt-token` (S5)

But Secret Manager on `mmpt-233505` only has UPPERCASE_UNDERSCORE variants:
- `DS_FACTORY_TOKEN`, `DS_SHARED_ANTHROPIC_API_KEY`, `DS_SHARED_WS_API_KEY`
- `DS_PREVIEW_TOKEN`, `DS_CONFIG_MGMT_TOKEN`

The live services are already running with uppercase secret bindings (confirmed via `gcloud run services describe --format=json`). The `deploy.sh` scripts are stale — they predate when the secrets were renamed in Secret Manager (or were never updated after).

**Fix:** Patch S3 and S5 `deploy.sh` to use uppercase names before deploying:
```
S3: ds-factory-token → DS_FACTORY_TOKEN, ds-shared-anthropic-api-key → DS_SHARED_ANTHROPIC_API_KEY, ds-shared-ws-api-key → DS_SHARED_WS_API_KEY
S5: ds-preview-token → DS_PREVIEW_TOKEN, ds-config-mgmt-token → DS_CONFIG_MGMT_TOKEN
```

## Blocker 2 — G4: google-cloud-firestore missing from requirements.txt

**Impact: HARD BLOCKER if `PROJECTS_FIRESTORE=1` is enabled.**

PR #61 added `PROJECTS_FIRESTORE` implementation to `demo-factory/main.py` with `from google.cloud import firestore` (lazy import inside `_get_firestore_client()`). This import will raise `ImportError` at runtime if the library is not in the container image.

`demo-factory/requirements.txt` on `feat/demo-studio-v3` does NOT include `google-cloud-firestore`. PR #60 (`fix/s3-firestore-dep`) has the fix (`google-cloud-firestore>=2.19.0`) but is not yet merged.

**Fix:** Merge PR #60 before deploying S3 with `PROJECTS_FIRESTORE=1`. Since PR #60 is authored by duongntd99, it must be reviewed and merged by harukainguyen1411 or via web UI.

**Workaround if PR #60 cannot be merged in time:** Deploy S3 WITHOUT setting `PROJECTS_FIRESTORE=1` (leave it 0/unset). The service will use in-memory project state. Set the flag only after PR #60 merges and S3 is redeployed.

## Blocker 3 — MCP handshake smoke cannot be run by Ekko

**Impact: STOP on step §2.3a.**

The MCP handshake (runbook §2.3a) requires reading `DS_STUDIO_MCP_TOKEN` from Secret Manager into a local Python script. Rule 6 prohibits Ekko from reading secret values into local context. Duong must run this smoke manually.

## Non-blockers confirmed clean

- Check 4 (G8): `DEMO_FACTORY_TEST_MODE` NOT set on live demo-factory. OK.
- Check 6 (G6): No `INTERNAL_SECRET` or `X-Internal-Secret` references in demo-factory Python after PR #61. OK — S3 does not need the INTERNAL_SECRET binding.
- gcloud auth: must use `duong.nguyen.thai@missmp.eu` for `mmpt-233505` operations (not `harukainguyen1411@gmail.com`). Set via `gcloud config set account duong.nguyen.thai@missmp.eu`.
- SA situation: all three services run as default compute SA (`266692422014-compute@developer.gserviceaccount.com`), not their dedicated SAs. The compute SA has `roles/editor` + `roles/secretmanager.secretAccessor` at project level — covers both Firestore and secret access.
- DS_STUDIO_MCP_TOKEN exists in SM. Secret-level IAM policy returned empty (no resource-level bindings), but project-level `roles/secretmanager.secretAccessor` on the compute SA covers access.
- All DS_* uppercase secrets exist: DS_CONFIG_MGMT_TOKEN, DS_SHARED_ANTHROPIC_API_KEY, DS_SHARED_INTERNAL_SECRET, DS_SHARED_WS_API_KEY, DS_STUDIO_DEMO_SERVICE_TOKEN, DS_STUDIO_FIRECRAWL_KEY, DS_STUDIO_MCP_TOKEN, DS_STUDIO_SESSION_SECRET, DS_VERIFICATION_TOKEN, DS_FACTORY_TOKEN, DS_PREVIEW_TOKEN.

## PREV_REVISIONs captured
- S1: demo-studio-00014-fc5
- S3: demo-factory-00005-dvs
- S5: demo-preview-00005-ktj

## company-os worktree state after preflight
- `/Users/duongntd99/Documents/Work/mmp/workspace/company-os` is on `feat/demo-studio-v3` at `e86da8e` (includes PR #61).
- The runbook says to deploy from this path.

# Preview Service Wrong Deploy Anatomy — 2026-04-22

## What happened

tuan.pham deployed `demo-preview-00009-frw` at 07:12 UTC from `origin/main` (company-os), overwriting Duong's revisions `00007-c7t` and `00008-6v6` which were built from `feat/demo-studio-v3`. The two branches have completely different implementations:

- `origin/main`: `server.py` (stdlib http.server, Jinja2 templates, full Config Mgmt integration, `/preview/{id}` route)
- `feat/demo-studio-v3`: `main.py` (FastAPI, no templates, `_fetch_config` is a TODO stub returning hardcoded Allianz config, `/v1/preview/{id}` route)

## Key learnings

1. **Two divergent codebases**: company-os has `tools/demo-preview/` on both `origin/main` and `feat/demo-studio-v3` with completely different entrypoints and routes. Any deploy must be branch-aware.

2. **Route contract mismatch**: The OpenAPI spec (`api/reference/5-preview.yaml`) defines `/preview/{session_id}`. The feat branch uses `/v1/preview/{session_id}`. This is a bug to flag when fixing preview-iframe-staleness.

3. **feat branch _fetch_config is a stub**: `main.py::_fetch_config` returns a hardcoded Allianz config — this is the root of preview-iframe-staleness. Config Mgmt integration has not been ported to the FastAPI rewrite.

4. **No deploy.sh on origin/main**: The deploy.sh guarding correct secret names only exists on `feat/demo-studio-v3`. Deploying from main = no guard.

5. **gcloud operation-id reuse**: Revisions 00008 and 00009 shared the same `operation-id`. This appears to be a gcloud behavior (possibly reused for rollbacks or same-run retries) — not indicative of a causal relationship.

6. **Deploy guard minimum**: Add branch check to `tools/demo-preview/deploy.sh` on feat branch. Anyone can still `gcloud run deploy --source .` directly; IAM restriction is the only hard guard but requires project Owner.

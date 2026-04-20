# GCS Config Serving for demo-ui

## Context
Migrated demo-ui from baked-in Docker configs to GCS-backed config serving so new configs appear without redeployment.

## Key decisions

- `readConfig(projectID)` helper centralises the local/GCS branching: if `GCS_BUCKET` env var is set it reads from `gs://<bucket>/configs/<id>.json`, otherwise falls back to local `configDir` — keeps local dev working with zero extra setup.
- Removed `COPY configs/ /configs/` from Dockerfile and the `ENV CONFIG_DIR=/configs` line (no longer needed since GCS is the source of truth in production).
- `go mod tidy` is required after manually editing `go.mod` — tidy adjusts versions to what the dependency graph actually resolves to, which differed from what I wrote by hand.
- `go.sum` must be committed alongside `go.mod`; the Dockerfile now copies both (`COPY go.mod go.sum main.go ./`).
- `config_store.py` in demo-factory uses `google-cloud-storage`; ensure the demo-runner service account (`demo-runner-sa@mmpt-233505.iam.gserviceaccount.com`) has `roles/storage.objectAdmin` on the bucket.

## Gotcha
The `storage.NewClient` call inside `readConfig` creates a new client per request. For a production-grade service this should be a package-level singleton. Acceptable here given the low request rate of demo-ui.

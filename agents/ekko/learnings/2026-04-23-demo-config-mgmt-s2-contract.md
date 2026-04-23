# demo-config-mgmt (S2) Prod Contract — 2026-04-23

## Summary
Read-only investigation of the live S2 service. Do NOT modify S2.

## Deployed State
- Revision: `demo-config-mgmt-00014-2bn`
- Image digest: `sha256:27c460353d3272c1880e66b4036dbd63c00cb6214a488ae87de1cadfe1e7f427`
- Deploy time: 2026-04-23T08:22:40Z (built by Cloud Build job `ba140a09`)
- Region: `europe-west1`, project `mmpt-233505`
- Deploy method: `gcloud run deploy --source .` (local upload — no git SHA in image labels)

## Source SHA
- Closest git commit: `4cbcebf` (ops: fix deploy.sh secret name DS_CONFIG_MGMT_TOKEN, 2026-04-22)
- The revision was deployed from a local working-tree snapshot via `--source .`. No embedded git SHA.
- The code in `tools/demo-config-mgmt/main.py` at HEAD matches what is running (CORS fix + F4 fix are both present in `fb1ce39`/`f7855e8` which predate the deploy).

## Full Route Contract

| Method | Path | Auth | Status |
|--------|------|------|--------|
| GET    | /health | No auth | 200 `{"status":"ok"}` |
| OPTIONS | /health | No auth | 204 (CORS preflight) |
| GET    | /v1/schema | Bearer | 200 YAML text (mock schema) |
| POST   | /v1/config | Bearer | 201 `{sessionId, config, version:1, createdAt}` |
| GET    | /v1/config/{session_id} | Bearer | 200 `{sessionId, config, version, updatedAt}` |
| PATCH  | /v1/config/{session_id} | Bearer | 200 `{sessionId, version, updatedAt, applied:[{path,status}]}` |
| GET    | /v1/config/{session_id}/versions | Bearer | 200 `{sessionId, versions:[{version,updatedAt,paths}], total}` (stub) |
| GET    | /logs | Bearer | 200 `{service, logs:[], total, hasMore}` (stub) |

## Auth
- Bearer token via `Authorization: Bearer <token>`
- Token sourced from Secret Manager secret `DS_CONFIG_MGMT_TOKEN` → env `CONFIG_MGMT_TOKEN`

## PATCH body formats
Two accepted forms:
1. Multi-update: `{"updates": [{"path": "colors.primary", "value": "#FF0000"}, ...], "expectedVersion": N}`
2. Single-field: `{"path": "colors.primary", "value": "#FF0000"}`

## Storage Backend
- PURE IN-MEMORY (`_session_configs` dict + threading.Lock)
- `FIRESTORE_DATABASE=demo-config-mgmt` env var is set but Firestore is NOT used — no `google-cloud-firestore` in requirements.txt, no Firestore import in main.py
- State is reset on every new Cloud Run instance (volatile — no persistence across restarts)

## CORS
- `Access-Control-Allow-Origin: https://demo-studio-266692422014.europe-west1.run.app` (hardcoded)
- Only /health has CORS headers; other endpoints do NOT have CORS headers in this revision

## Key Implication for S1 (demo-studio-v3)
- S1 must pass `Authorization: Bearer <token>` on every call
- PATCH supports dotted paths — S1 can write `colors.primary`, `params.firstName`, etc. individually
- No Firestore — all session state lives in the Cloud Run instance memory; if S2 scales to 0 and restarts, session state is lost

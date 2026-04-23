# Demo-preview-00010-ff4 env check

Date: 2026-04-22
Topic: CONFIG_MGMT_URL presence + brand fallback behavior

## Findings

### 1. CONFIG_MGMT_URL is SET

Revision demo-preview-00010-ff4 has:
- `CONFIG_MGMT_URL=https://demo-config-mgmt-266692422014.europe-west1.run.app`
- `PREVIEW_TOKEN` (from secret DS_PREVIEW_TOKEN)
- `CONFIG_MGMT_TOKEN` (from secret DS_CONFIG_MGMT_TOKEN)

Note: demo-studio-v3/deploy.sh uses the `4nvufhmjiq-ew.a.run.app` URL format — the
Cloud Run service is correctly using the `266692422014.europe-west1.run.app` variant
(both resolve to the same service; the hash-format URL is the stable public URL).

### 2. Unknown session IDs render Allianz — via config-mgmt (NOT baked-in fallback)

`/preview/nonexistent-test-session` → HTTP 200 + full Allianz brand HTML.

Root cause: demo-config-mgmt returns a default Allianz config (200 OK) for unknown
session IDs, rather than a 404. demo-preview's `fetch_config_from_mgmt` only triggers
`_respond_error` on HTTPError — so any 200 from config-mgmt (even a default) renders.

The baked-in `configs/` fallback in server.py is only used when `CONFIG_MGMT_URL` is
unset (dev mode). Since CONFIG_MGMT_URL IS set, there is no local-file fallback path
in production — all config comes from config-mgmt.

### 3. Implication

Real prod session IDs with an Allianz config will correctly render Allianz.
Other brands (Aviva, Lemonade) will only render if their session IDs have a
corresponding record in the demo-config-mgmt Firestore DB. Unknown session IDs
always show Allianz because config-mgmt appears to return Allianz as its
global default rather than 404.
